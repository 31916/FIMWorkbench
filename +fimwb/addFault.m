function slot=addFault(model,selected)
%ADDFAULT Append a disabled signal fault after the existing faults at a site.
model=loadWorkingModel(model);
assert(strcmp(get_param(model,'SimulationStatus'),'stopped') && strcmp(get_param(model,'FastRestart'),'off'), ...
    'Stop the simulation and turn off Fast Restart before adding a fault.');
[paths,meta]=modelSlots(model);
i=find([meta.slot]==selected);
assert(isscalar(i),'Select an existing fault.');
assert(~strcmp(meta(i).site.kind,'operator'),'An operator has one replacement. Add signal faults on its output connection.');
chain=find(arrayfun(@(m)strcmp(m.site.id,meta(i).site.id),meta));
last=chain(end);
slot=max([meta.slot])+1;
parent=get_param(paths{last},'Parent');
stage=[parent '/' sprintf('FIMWB_%03d',slot)];
assert(getSimulinkBlockHandle(stage)==-1,'The generated block name is already in use.');
ports=get_param(paths{last},'PortHandles');source=ports.Outport(1);
line=get_param(source,'Line');targets=get_param(line,'DstPortHandle');
assert(~isempty(targets) && all(targets>0),'The selected fault has no connected output.');
dirty=get_param(model,'Dirty');changed=meta(last);
changed.slot=slot;changed.fault.enabled=false;
try
    add_block(paths{last},stage,'Tag',sprintf('fimwb.fault.%d',slot));
    pos=get_param(stage,'Position');set_param(stage,'Position',pos+[110 25 110 25]);
    drawStage(stage,changed);
    ports=get_param(stage,'PortHandles');
    for target=reshape(targets,1,[]),delete_line(parent,source,target);end
    add_line(parent,source,ports.Inport(1),'autorouting','on');
    for target=reshape(targets,1,[]),add_line(parent,ports.Outport(1),target,'autorouting','on');end
    set_param(model,'SimulationCommand','update');
    assert(isequaln(get_param(stage,'UserData'),changed),'Simulink regenerated the new fault.');
catch err
    if getSimulinkBlockHandle(stage)~=-1,deleteStage(stage);end
    for target=reshape(targets,1,[])
        if get_param(target,'Line')==-1,add_line(parent,source,target,'autorouting','on');end
    end
    set_param(model,'Dirty',dirty);
    rethrow(err);
end
end
