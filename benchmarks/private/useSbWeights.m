function useSbWeights(sourceFolder,work,filename)
% The Stateful Predict block in R2026a requires an ASCII path to its weights.
if all(double(sourceFolder)<128)
    addpath(sourceFolder,'-begin');
    return
end
persistent cache cleanCache
if isempty(cache) || ~isfolder(cache)
    cache='';
    for base={tempdir,work,pwd}
        if ~all(double(char(base{1}))<128),continue;end
        folder=tempname(base{1});
        [ok,~]=mkdir(folder);
        if ok,cache=folder;break;end
    end
    assert(~isempty(cache),'fimwb:SbWeightsPath', ...
        'Choose a writable folder with an ASCII-only path to load the SB network weights.');
    cleanCache=onCleanup(@()removeCache(folder));
end
source=fullfile(sourceFolder,filename);target=fullfile(cache,filename);
if ~isfile(target) || ~strcmp(fimwb.fileHash(source),fimwb.fileHash(target))
    % Private per-session directory. Publish only a complete copy for loading.
    staged=tempname(cache);
    [ok,msg]=copyfile(source,staged);assert(ok,'%s',msg);
    assert(java.io.File(staged).setWritable(true),'Cannot make the temporary weights writable.');
    [ok,msg]=movefile(staged,target,'f');assert(ok,'%s',msg);
end
addpath(cache,'-begin');
end

function removeCache(folder)
if any(strcmp(strsplit(path,pathsep),folder)),rmpath(folder);end
if isfolder(folder),rmdir(folder,'s');end
end
