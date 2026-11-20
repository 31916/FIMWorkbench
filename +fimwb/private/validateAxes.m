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
