function stages=faultStages(model,slot)
% Saved 1.0.0 models use the previous tag prefix for the same slot metadata.
if nargin<2,number='[0-9]+';else,number=num2str(slot);end
pattern=['^(fimwb|grfi)\.fault\.' number '$'];
stages=find_system(model,'SearchUnderMasks','all','Regexp','on','Tag',pattern);
end
