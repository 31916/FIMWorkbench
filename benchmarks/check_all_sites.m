function check_all_sites(outDir,ids)
%CHECK_ALL_SITES Materialize every catalogued site and compare fault-OFF outputs.
% Each generated slot can subsequently be turned on independently with setFault.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
if nargin<2,ids={'AT','AFC','NN','CC','SC','PM','SB1','SB2','SB3','SB4','SB5','F16'};end
if ~isfolder(outDir),mkdir(outDir);end
[~,attr]=fileattrib(outDir);outDir=attr.Name;old=pwd;c=onCleanup(@()cd(old)); %#ok<NASGU>
for i=1:numel(ids)
    id=ids{i};folder=fullfile(outDir,id);assert(~isfolder(folder),'Choose a fresh directory.');mkdir(folder);cd(folder);
    [file,T,u]=benchSource(id,root,folder);
    sites=fimwb.scan(file);
    [planned,excluded]=fimwb.plan(file,fullfile(root,'examples','profiles.json'));
    exportPlan(folder,planned,excluded);
    usable=sites(~cellfun(@isempty,{sites.faults}));
    [~,model,ext]=fileparts(file);load_system(file);
    closeOriginal=onCleanup(@()close_system(model,0));base=benchSim(model,T,u,false);clear closeOriginal;
    rows=struct('site',{},'kind',{},'fault',{},'status',{},'model',{},'slot',{},'reason',{});
    fprintf('COVER %s %d candidates, %d parameter combinations\n',id,numel(usable),numel(planned));
    probe(1:numel(usable));
    for k=reshape(find(cellfun(@isempty,{sites.faults})),1,[])
        s=sites(k);rows(end+1)=struct('site',s.id,'kind',s.kind,'fault','','status','excluded','model','','slot',0,'reason',s.reason); %#ok<AGROW>
    end
    writetable(struct2table(rows,'AsArray',true),fullfile(folder,'sites.csv'));
    assert(numel(unique({rows.site}))==numel(sites),'Unaccounted site.');
    fprintf('COVER_DONE %s installed %d unsupported %d excluded %d\n',id,sum(strcmp({rows.status},'off_verified')),...
        sum(strcmp({rows.status},'failed')),sum(strcmp({rows.status},'excluded')));
end

    function probe(indices)
        if isempty(indices),return;end
        variant=sprintf('all_%s_%04d_%04d',lower(id),indices(1),indices(end));
        output=fullfile(folder,[variant ext]);entries=num2cell(fimwb.defaultFaults(usable(indices)));
        reason='';
        try
            stages=fimwb.build(file,struct('faults',{entries}),output);
            load_system(output);release=onCleanup(@()close_system(variant,0));
            off=benchSim(variant,T,u,false);benchCompare(base,off,1,0,1,'all_slots_off');
            for z=1:numel(stages)
                h=getSimulinkBlockHandle(stages{z});
                assert(h~=-1 && strcmp(get_param(h,'Tag'),sprintf('fimwb.fault.%d',z)),...
                    'Fault slot did not persist through simulation: %s',entries{z}.site);
            end
            clear release;
        catch err
            reason=err.message;
            if exist('release','var'),clear release;end
            if isfile(output),delete(output);end
        end
        if ~isempty(reason)&&numel(indices)>1
            split=floor(numel(indices)/2);
            probe(indices(1:split));probe(indices(split+1:end));return;
        end
        for n=1:numel(indices)
            s=usable(indices(n));f=entries{n};
            if isempty(reason),state='off_verified';deliver=[variant ext];else,state='failed';deliver='';end
            rows(end+1)=struct('site',s.id,'kind',s.kind,'fault',f.type,'status',state,...
                'model',deliver,'slot',n,'reason',reason); %#ok<AGROW>
        end
    end
end

function exportPlan(folder,plan,excluded)
T=struct2table(plan,'AsArray',true);
% Values include numeric levels and operator strings. Preserve both in CSV.
T.value=string(arrayfun(@(p)jsonencode(p.value),plan,'UniformOutput',false))';
T.stop=string(arrayfun(@(p)jsonencode(p.stop),plan,'UniformOutput',false))';
writetable(T,fullfile(folder,'fault_plan.csv'));
fid=fopen(fullfile(folder,'parameter_exclusions.json'),'w','n','UTF-8');assert(fid>=0);
c=onCleanup(@()fclose(fid));fprintf(fid,'%s\n',jsonencode(excluded)); %#ok<NASGU>
end
