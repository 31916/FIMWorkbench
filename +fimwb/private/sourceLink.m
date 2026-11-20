function metadata=sourceLink(model,source,folder)
% Preserve model metadata and resolve companions relative to the new file.
metadata=get_param(model,'Metadata');
if isempty(metadata),metadata=struct();end
origin=java.io.File(source).toPath();target=java.io.File(folder).toPath();
if origin.getRoot().equals(target.getRoot())
    ref=char(target.relativize(origin).toString());
else
    ref=source;
end
metadata.FIMWorkbenchSourceModel=strrep(ref,filesep,'/');
end
