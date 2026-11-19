function name = loadWorkingModel(file)
% Resolve a generated model without switching an already open working copy.
[~,name,ext] = fileparts(char(file));
if isempty(ext)
    assert(bdIsLoaded(name),'Open the generated model or pass its full path.');
    return
end
[ok,attr] = fileattrib(file);
assert(ok && ~attr.directory,'Model file not found.');
if bdIsLoaded(name)
    assert(strcmp(get_param(name,'FileName'),attr.Name),'A different model of the same name is open.');
else
    load_system(attr.Name);
end
end
