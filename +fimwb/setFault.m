function setting = setFault(model,slot,changes)
%SETFAULT Change one generated slot between simulations. save_system persists it.
assert(bdIsLoaded(model)&&strcmp(get_param(model,'SimulationStatus'),'stopped'),...
    'Load the generated model and stop simulation before editing.');
loadWorkingModel(model);
validateattributes(slot,{'numeric'},{'scalar','integer','positive'});
assert(isstruct(changes)&&isscalar(changes)&&all(ismember(fieldnames(changes),...
    {'type','enabled','value','start','stop','seed','period'})),'Invalid setting change.');
paths=faultStages(model,slot);
assert(numel(paths)==1,'Expected exactly one generated fault slot %d.',slot);
block=paths{1};old=get_param(block,'UserData');next=old.fault;
if isfield(changes,'type')
    changes.type=faultType(changes.type);
    assert(ismember(changes.type,old.site.faults),'This fault type is unavailable at %s.',old.site.id);
end
if isfield(changes,'type') && ~strcmp(changes.type,next.type)
    next.value=defaultFaultValue(char(changes.type),old.site);
    if strcmp(changes.type,'noise') && isnumeric(old.site.sampleTime) && old.site.sampleTime(1)>0 && isfinite(old.site.sampleTime(1))
        next.period=old.site.sampleTime(1);
    end
end
for k=fieldnames(changes)',key=k{1};next.(key)=changes.(key);end
setting=checkFault(next,old.site);meta=old;meta.fault=setting;
try
    drawStage(block,meta);
    set_param(model,'SimulationCommand','update');
    persisted=get_param(block,'UserData');
    assert(isequaln(persisted.fault,setting),'Simulink rebuilt the edited fault slot.');
    if ~strcmp(old.fault.type,setting.type)
        metadata=get_param(model,'Metadata');
        if isstruct(metadata) && isfield(metadata,'FIMWorkbenchAxes') && ~isempty(metadata.FIMWorkbenchAxes)
            axes=metadata.FIMWorkbenchAxes;
            axes([axes.slot]==slot & strcmp({axes.field},'value'))=[];
            metadata.FIMWorkbenchAxes=axes;set_param(model,'Metadata',metadata);
        end
    end
catch err
    if getSimulinkBlockHandle(block)~=-1
        try
            drawStage(block,old);
        catch rollbackError
            err=addCause(err,rollbackError);
        end
    end
    rethrow(err);
end
end
