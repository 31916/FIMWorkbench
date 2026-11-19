function [model, file, cleanup] = openSource(file)
[ok, attr] = fileattrib(file);
assert(ok && ~attr.directory, 'Model file not found: %s', file);
file = attr.Name;
[folder, model, ext] = fileparts(file);
assert(any(strcmpi(ext,{'.mdl','.slx'})), 'Use a .mdl or .slx model.');
modelWasOpen = bdIsLoaded(model);
wasOnPath = any(strcmp(strsplit(path,pathsep),folder));
if ~wasOnPath, addpath(folder,'-end'); end
cleanup = onCleanup(@() finish(model,modelWasOpen,folder,wasOnPath));
if modelWasOpen
    assert(strcmp(get_param(model,'FileName'),file), 'Another model with this name is loaded: %s', model);
    assert(strcmp(get_param(model,'Dirty'),'off'), 'Save or close the edited source model first.');
else
    load_system(file);
end
end

function finish(model,wasOpen,folder,wasOnPath)
if ~wasOpen && bdIsLoaded(model), close_system(model,0); end
if ~wasOnPath, rmpath(folder); end
end
