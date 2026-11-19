function report = experiment(file,folder,axes,onProgress,failureMode)
%EXPERIMENT Compare all faults off with the editor settings or a factorial campaign.
% Each axis is a struct with slot, field ('enabled' or 'value'), and levels.
% A value axis enables its slot unless an enabled axis also controls that slot.
% Pass 'record' as the fifth argument to keep failed fault cases and continue.
if nargin<5,failureMode='abort';end
assert(ismember(failureMode,{'abort','record'}),'Failure mode must be abort or record.');
if nargin<4
    onProgress=[];
end
if nargin<3
    axes=struct('slot',{},'field',{},'levels',{});
end
[~,name] = fileparts(char(file));
opened = ~bdIsLoaded(name);
model = loadWorkingModel(file);
if opened
    closeModel=onCleanup(@()close_system(model,0));
end
report=execute(model,folder,axes,onProgress,failureMode);
end

function report=execute(model,folder,axes,onProgress,failureMode)
assert(strcmp(get_param(model,'SimulationStatus'),'stopped') && strcmp(get_param(model,'FastRestart'),'off'), ...
    'Stop the simulation and turn off Fast Restart before running an experiment.');
[paths,meta] = modelSlots(model);
original = [meta.fault];
[axes,counts,indices] = validateAxes(axes,meta);
total = prod(counts);
assert(total<=flintmax,'The requested number of combinations exceeds the exact case index range.');
[parent,leaf,ext]=fileparts(char(folder));
if isempty(parent),parent=pwd;end
[exists,attr]=fileattrib(parent);
assert(exists && attr.directory,'Choose an existing parent directory.');
parent=attr.Name;
folder=fullfile(parent,[leaf ext]);
assert(~isfolder(folder) && ~isfile(folder),'Choose a new results folder.');
work = tempname(parent);
[ok,msg] = mkdir(work);assert(ok,'%s',msg);
removeWork = onCleanup(@()discard(work));
rngState = rng;
resetRng = onCleanup(@()rng(rngState));
input = Simulink.SimulationInput(model);
externalInputs = {};
expression = '';
if strcmp(get_param(model,'LoadExternalInput'),'on')
    expression = get_param(model,'ExternalInput');
    externalInputs = Simulink.data.evalinGlobal(model,['{' expression '}']);
    names = cell(size(externalInputs));
    for k=1:numel(externalInputs)
        [~,key]=fileparts(tempname);
        names{k}=matlab.lang.makeValidName(['fimwb_input_' key]);
        input=input.setVariable(names{k},externalInputs{k});
    end
    input=input.setModelParameter('ExternalInput',strjoin(names,','));
end
horizon = Simulink.data.evalinGlobal(model,get_param(model,'StopTime'));
validateattributes(horizon,{'numeric'},{'real','scalar','finite'});
outputName = 'fimwb_output';
input = input.setModelParameter('StopTime',mat2str(horizon,17),'SaveOutput','on', ...
    'OutputSaveName',outputName,'SaveFormat','Dataset','DatasetSignalFormat','timeseries', ...
    'SaveTime','on','TimeSaveName','fimwb_time','LimitDataPoints','off','Decimation','1');
if isempty(find_system(model,'SearchDepth',1,'BlockType','Outport'))
    outputName='fimwb_logged';
    input=input.setModelParameter('SignalLogging','on','SignalLoggingName',outputName);
end
save(fullfile(work,'inputs.mat'),'externalInputs','rngState');
metadata = struct('model',model,'matlabRelease',version('-release'),'stopTime',horizon, ...
    'onDiskModelSHA256',fimwb.fileHash(get_param(model,'FileName')),'modelDirty',get_param(model,'Dirty'), ...
    'solver',get_param(model,'Solver'),'externalInputExpression',expression, ...
    'slots',[meta.slot],'settings',original,'axes',{axes},'caseCount',total);
writeJSON(fullfile(work,'experiment.json'),metadata);
dirty = get_param(model,'Dirty');
current = original;
touched = containers.Map('KeyType','double','ValueType','logical');
restoreOnExit = onCleanup(@()restoreSlots(model,paths,meta,touched,dirty));
forceOn = reshape(setdiff(indices(strcmp({axes.field},'value')),indices(strcmp({axes.field},'enabled'))),1,[]);
baseline = original;
[baseline.enabled] = deal(false);
if ~isempty(onProgress),onProgress(0,total+1);end
runCase(baseline,'baseline',false);
failed=0;
if ~isempty(onProgress),onProgress(1,total+1);end
for n = 1:total
    settings = original;
    position = n-1;
    for a=1:numel(axes)
        level = 1+mod(position,counts(a));
        position = floor(position/counts(a));
        settings(indices(a)).(axes(a).field) = axes(a).levels{level};
    end
    for slotIndex=forceOn
        settings(slotIndex).enabled=true;
    end
    passed=runCase(settings,sprintf('case_%04d',n),strcmp(failureMode,'record'));
    failed=failed+~passed;
    if ~isempty(onProgress),onProgress(n+1,total+1);end
end
restoreSlots(model,paths,meta,touched,dirty);
clear restoreOnExit
java.nio.file.Files.move(java.io.File(work).toPath(),java.io.File(folder).toPath(),javaArray('java.nio.file.CopyOption',0));
report = struct('folder',folder,'caseCount',total,'completedCases',total-failed,'failedCases',failed,'baseline',fullfile(folder,'baseline.csv'));

    function passed=runCase(settings,id,allowFailure)
        for i=1:numel(meta)
            if isequaln(current(i),settings(i)),continue;end
            changed=meta(i);changed.fault=settings(i);touched(i)=true;
            drawStage(paths{i},changed);
            current(i)=settings(i);
            if isequaln(current(i),original(i)),remove(touched,i);end
        end
        rng(rngState);
        passed=true;diagnostic='';sources=[];
        try
            output=sim(input);
            times=output.get('fimwb_time');
            assert(~isempty(times) && abs(times(end)-horizon)<=1e-9*max(1,abs(horizon)), ...
                'Simulation stopped before the requested horizon (%g s).',horizon);
        catch err
            if ~allowFailure,rethrow(err);end
            passed=false;diagnostic=fimwb.internal.diagnosticText(err);
        end
        if passed
            assert(ismember(outputName,output.who),'The model has no root outputs or logged signals.');
            dataset=output.get(outputName);
            assert(isa(dataset,'Simulink.SimulationData.Dataset'),'Expected a logged signal dataset.');
            sources=experimentTraces(dataset,fullfile(work,[id '.csv']));
            save(fullfile(work,[id '.mat']),'dataset');
        end
        changed=find(~arrayfun(@(a,b)isequaln(a,b),original,settings));
        overrides=struct('slot',{},'fault',{});
        if ~isempty(changed)
            overrides=struct('slot',num2cell([meta(changed).slot]),'fault',num2cell(settings(changed)));
        end
        if passed,status="completed";else,status="failed";end
        writeJSON(fullfile(work,[id '.json']),struct('id',id,'status',status,'diagnostic',diagnostic, ...
            'overrides',{overrides},'sources',{sources}));
        manifest=fullfile(work,'runs.csv');
        row=table(string(id),status,string(diagnostic),'VariableNames',{'run','status','diagnostic'});
        if isfile(manifest),writetable(row,manifest,'WriteMode','append','WriteVariableNames',false);
        else,writetable(row,manifest);end
    end

end

function restoreSlots(model,paths,meta,touched,dirty)
indices=keys(touched);
for j=1:numel(indices)
    i=indices{j};
    drawStage(paths{i},meta(i));
    remove(touched,i);
end
set_param(model,'Dirty',dirty);
end

function [axes,counts,indices] = validateAxes(axes,meta)
assert(isstruct(axes) && all(isfield(axes,{'slot','field','levels'})),'Each axis needs slot, field and levels.');
axes=reshape(axes,1,[]);counts=zeros(size(axes));indices=zeros(size(axes));
keys=strings(size(axes));
for a=1:numel(axes)
    validateattributes(axes(a).slot,{'numeric'},{'scalar','positive','integer'});
    i=find([meta.slot]==axes(a).slot);
    assert(isscalar(i),'Unknown slot %d.',axes(a).slot);
    field=char(axes(a).field);
    assert(ismember(field,{'enabled','value'}),'Axis field must be enabled or value.');
    levels=axes(a).levels;
    if isstring(levels),levels=cellstr(levels);end
    if ~iscell(levels),assert(isnumeric(levels)||islogical(levels),'Supply an array of levels.');levels=num2cell(levels);end
    assert(isvector(levels)&&~isempty(levels),'Each axis needs at least one level.');
    for k=1:numel(levels)
        setting=meta(i).fault;setting.(field)=levels{k};
        setting=checkFault(setting,meta(i).site);levels{k}=setting.(field);
    end
    axes(a).field=field;axes(a).levels=reshape(levels,1,[]);
    counts(a)=numel(levels);indices(a)=i;keys(a)=string(axes(a).slot)+"/"+field;
end
assert(numel(unique(keys))==numel(keys),'Use each slot and field only once.');
end

function writeJSON(file,data)
[fid,msg]=fopen(file,'w','n','UTF-8');assert(fid~=-1,'%s',msg);
closeFile=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(data,'PrettyPrint',true));
end

function discard(folder)
if isfolder(folder),rmdir(folder,'s');end
end
