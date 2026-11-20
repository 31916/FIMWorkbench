function settings=campaignSettings(original,axes,counts,indices,n)
% Enumerate a factorial campaign with the first axis changing fastest.
settings=original;
position=n-1;
for a=1:numel(axes)
    level=1+mod(position,counts(a));
    position=floor(position/counts(a));
    settings(indices(a)).(axes(a).field)=axes(a).levels{level};
end
forceOn=setdiff(indices(strcmp({axes.field},'value')),indices(strcmp({axes.field},'enabled')));
for i=reshape(forceOn,1,[])
    settings(i).enabled=true;
end
end
