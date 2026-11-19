function results=verify_fim_paper(upstream,folder)
%VERIFY_FIM_PAPER Exercise the 45 AECS locations from FIM Table 2 on its pinned model.
% Give an extracted original fimtool checkout and a fresh output directory.
root=fileparts(fileparts(mfilename('fullpath')));
srcDir=fullfile(upstream,'Aircraft_fault_injector','sf_aircraft_model');
src=fullfile(srcDir,'Aircraft.slx');
profile=fullfile(root,'examples','fim-paper-aecs.json');
definition=jsondecode(fileread(profile));
assert(strcmp(fimwb.fileHash(src),definition.sourceSha256),'The aircraft source differs from the pinned FIM release.');
assert(~isfolder(folder) && ~isfile(folder),'Choose a new results folder.');
mkdir(folder);[~,attr]=fileattrib(folder);folder=attr.Name;
copy=fullfile(folder,'fim_paper_aecs.slx');model='fim_paper_aecs';
assert(~bdIsLoaded(model) && ~bdIsLoaded('Aircraft'),'Close any models with the study names first.');
state=rng;restoreRng=onCleanup(@()rng(state));
reference=originalRun(src,srcDir);
app=FIMWorkbench();closeApp=onCleanup(@()delete(app));
sourceField=findall(app,'Tag','source');sourceField.Value=src;
outputField=findall(app,'Tag','output');outputField.Value=copy;
profileField=findall(app,'Tag','profile');profileField.Value=profile;
button=findall(app,'Tag','build');feval(button.ButtonPushedFcn,button,[]);
assert(isfile(copy),'The launcher could not build the paper profile: %s',findall(app,'Tag','status').Text);
window=findall(groot,'Type','figure','Name',['Fault settings - ' model]);assert(isscalar(window));
guard=onCleanup(@()closeStudy(window,model));
stages=find_system(model,'SearchUnderMasks','all','Regexp','on','Tag','^fimwb\.fault\.[0-9]+$');
metadata=cellfun(@(p)get_param(p,'UserData'),stages);
[~,order]=sort([metadata.slot]);stages=stages(order);
assert(numel(stages)==45);
% Compare the unmodified model and the all-off working copy on every native log.
normal=simulate(model);[signals,values,baselineError]=compareLogs(reference,normal);
assert(baselineError<1e-10,'The all-off model differs from its source.');
fprintf('PAPER_BASELINE %d logged signals, %d scalar values, max error %.9g\n',signals,values,baselineError);
save(fullfile(folder,'reference.mat'),'reference');
results=table();
for k=1:numel(stages)
    setting=fimwb.setFault(model,k,struct('enabled',true));
    meta=get_param(stages{k},'UserData');
    [ports,names]=observe(stages{k},meta.operandCount);
    try
        data=simulate(model);
        [checked,active,err,change]=checkStage(data,names,setting);
        assert(checked>0 && active>0 && err<1e-8,'Waveform check failed on slot %d (error %g).',k,err);
        status="passed";message="";
    catch failure
        checked=0;active=0;err=NaN;change=NaN;
        status="failed";message=string(fimwb.internal.diagnosticText(failure));
    end
    for p=ports,set_param(p,'DataLogging','off');end
    fimwb.setFault(model,k,struct('enabled',false));
    row=table(k,string(setting.site),string(setting.type),status,checked,active,err,change,message, ...
        'VariableNames',{'slot','site','fault','status','values_checked','active_values','max_abs_error','max_local_change','detail'});
    results=[results;row]; %#ok<AGROW>
    writetable(results,fullfile(folder,'cases.csv'));
    fprintf('PAPER_CASE %02d %s %s %s %d %g\n',k,setting.site,setting.type,status,active,err);
end
restored=simulate(model);[~,~,restoreError]=compareLogs(reference,restored);
writetable(table(signals,values,baselineError,restoreError,'VariableNames', ...
    {'source_logged_signals','source_scalar_values','all_off_max_error','restored_max_error'}),fullfile(folder,'baseline.csv'));
assert(restoreError<1e-10,'Restoring the fault switches did not reproduce the original model.');
% Also exercise the installed editor's experiment and plot on the original model logs.
fimwb.setFault(model,1,struct('enabled',true));
rng(0,'twister');run=fimwb.experiment(copy,fullfile(folder,'comparison'));
viewer=fimwb.plotComparison(run.folder,'off');closeViewer=onCleanup(@()delete(viewer));
filter=findall(viewer,'Tag','signalSearch');filter.Value='Left Elevator';
feval(filter.ValueChangedFcn,filter,[]);picker=findall(viewer,'Tag','signalPicker');
assert(strcmp(picker.Enable,'on') && all(contains(string(picker.Items),'Left Elevator','IgnoreCase',true)));
fimwb.setFault(model,1,struct('enabled',false));save_system(model);
assert(strcmp(fimwb.fileHash(src),definition.sourceSha256),'The original model changed.');
assert(all(results.status=="passed"),'See cases.csv for individual simulation or waveform failures.');
end

function dataset=originalRun(file,folder)
onPath=ismember(folder,strsplit(path,pathsep));
if ~onPath,addpath(folder,'-end');resetPath=onCleanup(@()rmpath(folder));end
load_system(file);closeModel=onCleanup(@()close_system('Aircraft',0));
dataset=simulate('Aircraft');
end

function data=simulate(model)
rng(0,'twister');
out=sim(model,'SimulationMode','normal','ReturnWorkspaceOutputs','on','SignalLogging','on', ...
    'SignalLoggingName','paper_signals','DatasetSignalFormat','timeseries','SaveTime','on','TimeSaveName','paper_time');
assert(abs(out.paper_time(end)-10)<1e-10,'The model did not reach the 10 s horizon.');
data=out.paper_signals;
end

function [n,count,maximum]=compareLogs(reference,actual)
n=reference.numElements;assert(actual.numElements==n,'Native signal count changed.');
labels=@(ds) string(ds.getElementNames());
[left,order]=sort(labels(reference));[right,other]=sort(labels(actual));
assert(isequal(left,right) && numel(unique(left))==n,'Native signal names changed or are ambiguous.');
count=0;maximum=0;
for j=1:n
    a=reference{order(j)};b=actual{other(j)};
    pa=regexprep(a.BlockPath.getBlock(1),'^[^/]+','');
    pb=regexprep(b.BlockPath.getBlock(1),'^[^/]+','');
    assert(strcmp(pa,pb) && a.PortIndex==b.PortIndex,'The logged block or port changed.');
    [points,err]=compareValue(a.Values,b.Values);
    count=count+points;maximum=max(maximum,err);
end
end

function [count,err]=compareValue(a,b)
count=0;err=0;
if isstruct(a)
    assert(isequal(fieldnames(a),fieldnames(b)) && isequal(size(a),size(b)));
    for n=1:numel(a)
        for f=reshape(fieldnames(a),1,[])
            [points,v]=compareValue(a(n).(f{1}),b(n).(f{1}));count=count+points;err=max(err,v);
        end
    end
else
    assert(isequal(a.Time,b.Time) && strcmp(class(a.Data),class(b.Data)) && isequal(size(a.Data),size(b.Data)));
    v=abs(double(a.Data)-double(b.Data));assert(all(isfinite(v),'all'));
    count=numel(v);if count,err=max(v,[],'all');end
end
end

function [ports,names]=observe(stage,operands)
blocks=[{stage,[stage '/Original']},arrayfun(@(k)sprintf('%s/Operand%d',stage,k),1:operands,'UniformOutput',false)];
names=[{'paper_result','paper_original'},arrayfun(@(k)sprintf('paper_operand%d',k),1:operands,'UniformOutput',false)];
ports=zeros(1,numel(blocks));
for k=1:numel(blocks)
    ph=get_param(blocks{k},'PortHandles');ports(k)=ph.Outport(1);
    set_param(ports(k),'DataLogging','on','DataLoggingNameMode','Custom','DataLoggingName',names{k});
end
end

function [checked,activeCount,err,change]=checkStage(data,names,f)
result=data.getElement(names{1}).Values;
[t,actual]=samples(result);inputs=cell(1,numel(names)-1);
for k=1:numel(inputs)
    [time,value]=samples(data.getElement(names{k+1}).Values);
    if all(value==value(1,:),'all')
        inputs{k}=repmat(value(1,:),numel(t),1);
    else
        [present,at]=ismembertol(t,time,1e-11,'DataScale',1);
        assert(all(present),'Missing input samples on the observation time grid.');
        inputs{k}=value(at,:);
    end
end
original=inputs{1};active=t>=f.start & t<f.stop;
switch f.type
    case 'bias',faulty=original+f.value;
    case 'negate',faulty=-original;
    case {'asr','p2s'},faulty=inputs{2}+inputs{3};  % the profile chooses ++ for ASR
    case 's2p',faulty=inputs{2}.*inputs{3};
    case 'ror',faulty=double(inputs{2}~=inputs{3});
    otherwise,error('Unexpected paper fault %s.',f.type);
end
expected=original;expected(active,:)=faulty(active,:);
assert(isequal(size(expected),size(actual)) && all(isfinite(actual),'all') && any(~active));
err=max(abs(expected-actual),[],'all');change=max(abs(expected-original),[],'all');
checked=numel(actual);activeCount=nnz(active)*size(actual,2);
end

function [time,value]=samples(ts)
time=double(ts.Time(:));v=double(ts.Data);
if ~ts.IsTimeFirst,v=permute(v,[ndims(v),1:ndims(v)-1]);end
value=reshape(v,numel(time),[]);
end

function closeStudy(window,model)
delete(window);close_system(model,0);
end
