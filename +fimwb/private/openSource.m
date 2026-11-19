function [model,file,cleanup] = openSource(file)
[~,name,ext]=fileparts(char(file));
assert(ismember(lower(ext),{'.mdl','.slx'}),'Use a .mdl or .slx model.');
wasOpen=bdIsLoaded(name);
[model,file]=loadWorkingModel(file);
cleanup=onCleanup(@()closeOwned(model,wasOpen));
if wasOpen,assert(strcmp(get_param(model,'Dirty'),'off'),'Save or close the edited source model first.');end
end

function closeOwned(model,wasOpen)
if ~wasOpen && bdIsLoaded(model),close_system(model,0);end
end
