function value = defaultFaultValue(kind,site)
switch kind
    case 'bias', value=1;
    case 'gain', value=2;
    case {'stuck_at','hold_last','package_drop'}, value=0;
    case 'noise', value=.01;
    case 'delay'
        value=.1;
        if isnumeric(site.sampleTime)&&site.sampleTime(1)>0,value=site.sampleTime(1);end
    case 'asr'
        value='';
        if isfield(site,'originalOperator'),value=site.originalOperator;end
        if isempty(value),value=repmat('+',1,site.operandCount);end
        if value(1)=='+',value(1)='-';else,value(1)='+';end
    case 'ror'
        value='==';
        if isfield(site,'originalOperator') && strcmp(value,site.originalOperator),value='~=';end
    otherwise
        value=[];
end
end
