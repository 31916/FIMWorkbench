function [name,file] = loadWorkingModel(file)
% Keep model-local resources available to callbacks, Simulink and the editor.
persistent models folders
if ~isa(models,'containers.Map')
    models=containers.Map('KeyType','double','ValueType','logical');
    folders=containers.Map('KeyType','char','ValueType','double');
end
[~,name,ext]=fileparts(char(file));
loaded=bdIsLoaded(name);
if isempty(ext)
    assert(loaded,'Open the generated model or pass its full path.');
    file=get_param(name,'FileName');
    if isempty(file),return;end
else
    [ok,attr]=fileattrib(file);
    assert(ok && ~attr.directory,'Model file not found: %s',file);
    file=attr.Name;
    if loaded
        assert(strcmp(get_param(name,'FileName'),file),'A different model of the same name is open.');
    end
end
if loaded && isKey(models,get_param(name,'Handle')),return;end
candidates=modelFolders(file);
onPath=strsplit(path,pathsep);
held={};
for k=1:numel(candidates)
    dir=candidates{k};
    if isKey(folders,dir)
        folders(dir)=folders(dir)+1;
    elseif ~ismember(dir,onPath)
        addpath(dir,'-end');
        folders(dir)=1;
    else
        continue
    end
    held{end+1}=dir; %#ok<AGROW>
end
lease=onCleanup(@()releaseFolders(folders,held));
if ~loaded,load_system(file);end
handle=get_param(name,'Handle');
Simulink.addBlockDiagramCallback(handle,'PreClose','FIMWorkbenchModelFolders', ...
    @()releaseModel(models,handle,lease));
models(handle)=true;
end

function candidates=modelFolders(file)
candidates={};seen={};
while ~ismember(file,seen)
    seen{end+1}=file; %#ok<AGROW>
    folder=fileparts(file);
    if isfolder(folder) && ~ismember(folder,candidates),candidates{end+1}=folder;end %#ok<AGROW>
    if ~isfile(file),break;end
    metadata=Simulink.MDLInfo.getMetadata(file);
    if ~isstruct(metadata) || ~isfield(metadata,'FIMWorkbenchSourceModel'),break;end
    ref=metadata.FIMWorkbenchSourceModel;
    if ~ischar(ref)||isempty(ref),break;end
    target=java.io.File(ref);
    if ~target.isAbsolute(),target=java.io.File(folder,ref);end
    file=char(target.getCanonicalPath());
end
end

function releaseModel(models,handle,lease)
remove(models,handle);
delete(lease);
end

function releaseFolders(folders,held)
for k=1:numel(held)
    dir=held{k};remaining=folders(dir)-1;
    if remaining>0
        folders(dir)=remaining;
    else
        remove(folders,dir);
        if ismember(dir,strsplit(path,pathsep)),rmpath(dir);end
    end
end
end
