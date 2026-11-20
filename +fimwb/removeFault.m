function removeFault(model,slot)
%REMOVEFAULT Remove one signal stage while preserving another at that site.
model=loadWorkingModel(model);
assert(strcmp(get_param(model,'SimulationStatus'),'stopped') && strcmp(get_param(model,'FastRestart'),'off'), ...
    'Stop the simulation and turn off Fast Restart before removing a fault.');
[paths,meta]=modelSlots(model);i=find([meta.slot]==slot);assert(isscalar(i),'Unknown fault slot.');
assert(~strcmp(meta(i).site.kind,'operator') && nnz(arrayfun(@(m)strcmp(m.site.id,meta(i).site.id),meta))>1, ...
    'Keep one editable fault at each site. Turn its On switch off to disable it.');
stage=paths{i};parent=get_param(stage,'Parent');ports=get_param(stage,'PortHandles');
source=get_param(get_param(ports.Inport(1),'Line'),'SrcPortHandle');
targets=get_param(get_param(ports.Outport(1),'Line'),'DstPortHandle');
assert(all(targets>0),'The selected stage is disconnected.');
[~,backup]=fileparts(tempname);new_system(backup);guard=onCleanup(@()close_system(backup,0));
add_block(stage,[backup '/Stage']);
dirty=get_param(model,'Dirty');
try
    deleteStage(stage);
    for target=reshape(targets,1,[]),add_line(parent,source,target,'autorouting','on');end
    set_param(model,'SimulationCommand','update');
    metadata=get_param(model,'Metadata');
    if isstruct(metadata) && isfield(metadata,'FIMWorkbenchAxes') && ~isempty(metadata.FIMWorkbenchAxes)
        metadata.FIMWorkbenchAxes([metadata.FIMWorkbenchAxes.slot]==slot)=[];
        set_param(model,'Metadata',metadata);
    end
catch err
    for target=reshape(targets,1,[])
        if get_param(target,'Line')~=-1,delete_line(parent,source,target);end
    end
    add_block([backup '/Stage'],stage);ports=get_param(stage,'PortHandles');
    add_line(parent,source,ports.Inport(1),'autorouting','on');
    for target=reshape(targets,1,[]),add_line(parent,ports.Outport(1),target,'autorouting','on');end
    set_param(model,'Dirty',dirty);rethrow(err);
end
end
