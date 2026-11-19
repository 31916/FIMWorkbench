function message=diagnosticText(err)
% Simulink groups independent compile errors under a generic parent message.
messages=unique(leaves(err),'stable');
message=char(strjoin(messages,newline));
end

function messages=leaves(err)
if isempty(err.cause)
    messages=string(regexprep(err.message,'</?a(?:\s[^>]*)?>',''));
    return
end
messages=strings(0,1);
for k=1:numel(err.cause)
    messages=[messages;leaves(err.cause{k})]; %#ok<AGROW>
end
end
