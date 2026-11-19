function [cases, excluded] = plan(modelFile,profiles)
%PLAN Enumerate one fault per compatible site and per requested parameter.
% Use a struct or JSON array with type, values and optional enabled/seed/period/start/stop.
if ischar(profiles)||isStringScalar(profiles),profiles=jsondecode(fileread(profiles));end
if isstruct(profiles),profiles=num2cell(profiles);end
assert(iscell(profiles),'Expected an array of profiles.');
sites=grfi.scan(modelFile); cases=struct('site',{},'type',{},'enabled',{},'value',{},'seed',{},'period',{},'start',{},'stop',{});
excluded=struct('site',{},'type',{},'value',{},'reason',{});
for k=1:numel(profiles)
    p=profiles{k};assert(isstruct(p)&&isfield(p,'type'),'Missing profile type.');
    assert(ismember(string(p.type),["bias","gain","noise","delay","stuck_at","zero","invert","bit_flip","negate","absolute","package_drop","hold_last","asr","s2p","p2s","ror"]),...
        'Unknown fault type.');
    values={[]};
    if isfield(p,'values')
        v=p.values;p=rmfield(p,'values');
        if iscell(v),values=v;elseif ischar(v),values={v};elseif ~isempty(v),values=num2cell(v);end
    end
    for n=1:numel(sites)
        if ~ismember(p.type,sites(n).faults),continue;end
        p.site=sites(n).id;
        for j=1:numel(values)
            p.value=values{j};
            try
                cases(end+1)=checkFault(p,sites(n)); %#ok<AGROW>
            catch err
                if ~strcmp(err.identifier,'grfi:IncompatibleValue'),rethrow(err);end
                excluded(end+1)=struct('site',p.site,'type',p.type,'value',p.value,'reason',err.message); %#ok<AGROW>
            end
        end
    end
end
end
