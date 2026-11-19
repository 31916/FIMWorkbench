function f = checkFault(raw,site)
% Build one fully specified fault; refuse incompatible data and parameters.
allowed={'site','type','enabled','value','seed','period','start','stop'};
assert(isstruct(raw)&&isscalar(raw)&&all(ismember(fieldnames(raw),allowed)),...
    'Unknown or malformed fault field. Allowed: %s',strjoin(allowed,', '));
assert(isfield(raw,'site')&&isfield(raw,'type')&&strcmp(raw.site,site.id),'Invalid site.');
f=struct('site',site.id,'type',char(raw.type),'enabled',true,'value',[],...
    'seed',1,'period',0.1,'start',0,'stop',[]);
for k=fieldnames(raw)'
    key=k{1};f.(key)=raw.(key);
end
f.type=char(f.type);
assert(ismember(f.type,site.faults),'Fault %s unavailable at %s (%s).',f.type,site.id,site.dataType);
assert(islogical(f.enabled)&&isscalar(f.enabled),'enabled must be true or false.');
validateattributes(f.start,{'numeric'},{'real','scalar','finite','nonnegative'});
if ~isempty(f.stop)
    validateattributes(f.stop,{'numeric'},{'real','scalar','finite','>',f.start});
end
ts=site.sampleTime;
if iscell(ts)||isempty(ts),sample=-1;else,sample=ts(1);end
switch f.type
    case {'bias','gain','stuck_at','package_drop','noise','delay','hold_last'}
        if strcmp(f.type,'hold_last')&&isempty(f.value),f.value=0;end
        validateattributes(f.value,{'numeric','logical'},{'real','scalar','finite'});
        if any(strcmp(f.type,{'noise','delay'}))
            assert(f.value>=0,'Noise power and delay must be nonnegative.');
        end
        if strcmp(f.type,'delay') && sample>0
            ratio=f.value/sample;
            assert(abs(ratio-round(ratio))<=1e-9*max(1,ratio),'grfi:IncompatibleValue','Delay must be an integer number of source samples.');
        end
        if strcmp(f.type,'noise')
            validateattributes(f.seed,{'numeric'},{'scalar','integer','>=',1,'<=',2147483646});
            validateattributes(f.period,{'numeric'},{'scalar','real','positive','finite'});
            if sample>0
                ratio=f.period/sample;
                assert(ratio>=1 && abs(ratio-round(ratio))<=1e-9*max(1,ratio),...
                    'grfi:IncompatibleValue','Noise period must be a positive integer multiple of the source period.');
            end
        end
        if strcmp(site.dataType,'boolean')
            assert(ismember(f.value,[0,1]),'grfi:IncompatibleValue','A boolean replacement must be 0 or 1.');
        elseif contains(site.dataType,'int') && ismember(f.type,{'stuck_at','package_drop','hold_last'})
            assert(f.value==fix(f.value) && f.value>=double(intmin(site.dataType)) && ...
                f.value<=double(intmax(site.dataType)), 'grfi:IncompatibleValue','Integer replacement is outside the signal type.');
        end
    case 'asr'
        assert(ischar(f.value)||isStringScalar(f.value),'ASR needs a sign string, e.g. "+-".');
        f.value=char(f.value);
        assert(~isempty(f.value)&&all(ismember(f.value,'+-')),'Invalid ASR sign string.');
        assert(numel(f.value)==site.operandCount,'grfi:IncompatibleValue','ASR needs one sign per operand.');
    case 'ror'
        assert(ismember(string(f.value),["<","<=",">",">=","==","~="]),'Invalid relational operator.');
        f.value=char(f.value);
    otherwise
        assert(isempty(f.value),'Fault %s has no adjustable numerical value.',f.type);
end
if ismember(f.type,{'asr','ror'}) && isfield(site,'originalOperator')
    assert(~strcmp(f.value,site.originalOperator),'grfi:IncompatibleValue','Replacement equals the original operator.');
end
end
