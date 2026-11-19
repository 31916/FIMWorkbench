function faults = defaultFaults(sites)
%DEFAULTFAULTS Choose one disabled, editable fault for each compatible site.
sites=sites(~cellfun(@isempty,{sites.faults}));
preferred={'bias','bit_flip','s2p','p2s','ror','stuck_at'};
faults=repmat(struct('site','','type','','enabled',false,'value',[]),numel(sites),1);
for k=1:numel(sites)
    index=find(ismember(preferred,sites(k).faults),1);
    if isempty(index),kind=sites(k).faults{1};else,kind=preferred{index};end
    faults(k).site=sites(k).id;
    faults(k).type=kind;
    faults(k).value=defaultFaultValue(kind,sites(k));
end
end
