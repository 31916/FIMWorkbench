function summary=run_arch_suite(outputDir,ids)
%RUN_ARCH_SUITE Verify the injector using the 2026 Falsification model families.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
if nargin<1,outputDir=fullfile(root,'verification',['run_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);end
if nargin<2,ids={'AT','AFC','NN','CC','SC','PM','SB1','SB2','SB3','SB4','SB5','F16'};end
if ~isfolder(outputDir),mkdir(outputDir);end
[~,attr]=fileattrib(outputDir);outputDir=attr.Name;
old=pwd;restore=onCleanup(@() cd(old)); %#ok<NASGU>
codes=cell(numel(ids),1);
for k=1:numel(ids)
    id=ids{k};folder=fullfile(outputDir,id);
    assert(~isfolder(folder),'Use a new output folder for %s.',id);mkdir(folder);cd(folder);
    fprintf('BEGIN %s\n',id);
    try
        res=checkModel(id,root,folder);
    catch err
        res=struct('id',id,'status','FAIL','error',getReport(err,'extended','hyperlinks','off'));
    end
    writeJSON(fullfile(folder,'result.json'),res);codes{k}=res.status;
    if strcmp(res.status,'FAIL'),fprintf(2,'FAIL %s %s\n',id,res.error);else,fprintf('PASS %s\n',id);end
end
summary=table(string(ids(:)),string(codes),'VariableNames',{'Model','Status'});
writetable(summary,fullfile(outputDir,'summary.csv'));disp(summary);
assert(all(strcmp(codes,'PASS')),'Some model tests failed. See each result.json.');
end

function res=checkModel(id,root,folder)
[file,T,u,scope]=benchSource(id,root,folder);
[~,model,ext]=fileparts(file);
initialHash=grfi.fileHash(file);
sites=grfi.scan(file);writeJSON(fullfile(folder,'sites.json'),sites);
load_system(file);sourceRelease=onCleanup(@() closeIfLoaded(model));
baseline=benchSim(model,T,u,false);
if strcmp(id,'F16')
    reference=interp1(u(:,1),u(:,2),baseline{1}.time);
    assert(all(abs(reference-baseline{1}.values)<1e-8),'Simulink and the official ODE output differ.');
end
[sink,outIndex,inner]=selectSites(model,sites,id);
fprintf('SITES %s %d eligible %d output %s internal %s\n',id,numel(sites),sum(~cellfun(@isempty,{sites.faults})),sink.id,inner.id);
b1=.25;b2=-.125;ib=1/64;
if contains(sink.dataType,'int'),b1=2;b2=-1;end
if ~isempty(inner.id)&&contains(inner.dataType,'int'),ib=1;end
cfg={entry(sink.id,'bias',false,b1),entry(sink.id,'gain',false,2)};
if ~isempty(inner.id),cfg{3}=entry(inner.id,'bias',false,ib);end
config=struct('sourceSha256',initialHash,'faults',{cfg});
% scan and simulate might load model-specific init callbacks; close the read-only source.
clear sourceRelease;
name=['fi_' lower(id)];generated=fullfile(folder,[name ext]);
grfi.build(file,config,generated);load_system(generated);
done=onCleanup(@() closeIfLoaded(name)); %#ok<NASGU>
off=benchSim(name,T,u,false);
checks=benchCompare(baseline,off,outIndex,0,1,'all_off');
grfi.setFault(name,1,struct('enabled',true));
single=benchSim(name,T,u,false);
checks(end+1)=benchCompare(baseline,single,outIndex,b1,1,'bias_only');
grfi.setFault(name,1,struct('enabled',false));grfi.setFault(name,2,struct('enabled',true));
singleGain=benchSim(name,T,u,false);
checks(end+1)=benchCompare(baseline,singleGain,outIndex,0,2,'gain_only');
grfi.setFault(name,1,struct('enabled',true));
combined=benchSim(name,T,u,false);
checks(end+1)=benchCompare(baseline,combined,outIndex,b1,2,'bias_then_gain');
grfi.setFault(name,1,struct('value',b2));grfi.setFault(name,2,struct('value',1.5));
tuned=benchSim(name,T,u,false);
checks(end+1)=benchCompare(baseline,tuned,outIndex,b2,1.5,'retuned_both');
grfi.setFault(name,1,struct('enabled',false));grfi.setFault(name,2,struct('enabled',false));
again=benchSim(name,T,u,false);
checks(end+1)=benchCompare(baseline,again,outIndex,0,1,'disabled_again');
if ~isempty(inner.id)
    grfi.setFault(name,3,struct('enabled',true));
    slots=find_system(name,'SearchUnderMasks','all','Tag','grfi.fault.3');stage=slots{1};
    ph=get_param(stage,'PortHandles');incoming=get_param(get_param(ph.Inport(1),'Line'),'SrcPortHandle');
    setLog(incoming,'grfi_original');setLog(ph.Outport(1),'grfi_faulty');
    [internal,log1]=benchSim(name,T,u,true);
    checks(end+1)=compareLocal(log1,'internal_only',ib);
    grfi.setFault(name,1,struct('enabled',true));grfi.setFault(name,2,struct('enabled',true));
    [mixed,log2]=benchSim(name,T,u,true);
    checks(end+1)=compareLocal(log2,'internal_and_output_local',ib);
    checks(end+1)=benchCompare(internal,mixed,outIndex,b2,1.5,'internal_and_output');
    set_param(incoming,'DataLogging','off');set_param(ph.Outport(1),'DataLogging','off');
    cfg{3}.enabled=true;
else
    grfi.setFault(name,1,struct('enabled',true));grfi.setFault(name,2,struct('enabled',true));
end
cfg{1}.enabled=true;cfg{1}.value=b2;cfg{2}.enabled=true;cfg{2}.value=1.5;
config.faults=cfg;writeJSON(fullfile(folder,'combination.json'),config);
save_system(name);
assert(strcmp(initialHash,grfi.fileHash(file)),'Source hash changed!');
save(fullfile(folder,'traces.mat'),'u','baseline','off','single','singleGain','combined','tuned','again','-v7');
if ~isempty(inner.id),save(fullfile(folder,'traces.mat'),'internal','mixed','log1','log2','-append');end
res=struct('id',id,'status','PASS','scope',scope,'source',file,'source_sha256',initialHash,'variant',generated,...
    'horizon',T,'candidates',numel(sites),'compatible',sum(~cellfun(@isempty,{sites.faults})),...
    'sink_site',sink.id,'internal_site',inner.id,'checks',checks,'matlab',version);
end

function f=entry(site,type,enabled,value)
f=struct('site',site,'type',type,'enabled',enabled,'value',value);
end

function [sink,outIndex,inner]=selectSites(model,sites,id)
out=[];ranks=[];interior=[];inRanks=[];
for k=1:numel(sites)
    s=sites(k);
    if ~strcmp(s.kind,'endpoint')||~ismember('bias',s.faults),continue;end
    block=[model '/' s.destinations.path];src=[model '/' s.source];
    typ=get_param(block,'BlockType');
    if strcmp(typ,'Outport')&&strcmp(get_param(block,'Parent'),model)
        out(end+1)=k; %#ok<AGROW>
        r=str2double(get_param(block,'Port'));
        if strcmp(id,'PM')&&contains(lower(block),'pace_count'),r=-1;end
        ranks(end+1)=r; %#ok<AGROW>
    elseif ~ismember(typ,{'Scope','Display','ToWorkspace','Terminator','Outport'})
        r=5;
        if strcmp(get_param(src,'Parent'),model),r=2;end
        if strcmp(get_param(src,'BlockType'),'Inport')&&strcmp(get_param(src,'Parent'),model),r=1;end
        interior(end+1)=k;inRanks(end+1)=r; %#ok<AGROW>
    end
end
assert(~isempty(out),'No numeric observation port found.');
[~,j]=min(ranks);sink=sites(out(j));outIndex=str2double(get_param([model '/' sink.destinations.path],'Port'));
inner=struct('id','');
if ~strcmp(id,'F16')
    assert(~isempty(interior),'No internal connection found.');
    [~,j]=min(inRanks);inner=sites(interior(j));
end
end

function setLog(port,name)
set_param(port,'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName',name);
end

function check=compareLocal(log,tag,bias)
check=benchCompare({log.input},{log.output},1,bias,1,tag);
end

function writeJSON(file,value)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true,'ConvertInfAndNaN',true));
end

function closeIfLoaded(model)
if bdIsLoaded(model),close_system(model,0);end
end
