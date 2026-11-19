function choices=operatorChoices(kind,site)
% Replacement values in the order of the FIM operator lists.
switch kind
    case 'lor', choices={'AND','OR','NAND','NOR','XOR','NXOR'};
    case 'ror', choices={'>','<','<=','>=','==','~='};
    case 'asr', choices={'+-','--','++','-+'};
    otherwise, choices={};
end
if nargin<2,return;end
if strcmp(kind,'lor') && isfield(site,'replacementOperators')
    choices=site.replacementOperators;
elseif strcmp(kind,'asr') && site.operandCount~=2
    choices={};
elseif isfield(site,'originalOperator')
    choices=choices(~strcmp(choices,site.originalOperator));
end
end
