function kind=faultType(value)
% Accept the FIM catalogue names and the corresponding Workbench identifiers.
assert((ischar(value)&&isrow(value))||isStringScalar(value),'Expected a fault type name.');
kind=lower(strtrim(char(value)));
switch kind
    case 'stuck-at 0',kind='zero';
    case 'bias/offset',kind='bias';
    case 'stuck-at',kind='hold_last';
    case 'time delay',kind='delay';
    case 'bit flip',kind='bit_flip';
    case 'package drop',kind='package_drop';
end
assert(ismember(kind,{'negate','invert','zero','absolute','noise','bias','hold_last','delay','bit_flip',...
    'package_drop','ror','lor','s2p','p2s','asr','gain','stuck_at'}),'Unknown fault type: %s.',kind);
end
