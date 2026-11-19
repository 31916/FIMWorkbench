function [paths,meta] = modelSlots(model)
paths = faultStages(model);
assert(~isempty(paths),'This model contains no generated fault slots.');
meta = cellfun(@(p)get_param(p,'UserData'),paths);
[slots,order] = sort([meta.slot]);
assert(numel(unique(slots))==numel(slots),'The model contains duplicate fault slot numbers.');
paths = paths(order);
meta = meta(order);
end
