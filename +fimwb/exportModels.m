function report=exportModels(file,folder,axes,mode,onProgress)
%EXPORTMODELS Compile a separate working copy for each selected configuration.
% Completed files remain available if the user cancels between models.
if nargin<5,onProgress=[];end
[~,name]=fileparts(char(file));opened=~bdIsLoaded(name);
model=loadWorkingModel(file);
if opened,closeModel=onCleanup(@()close_system(model,0));end
assert(strcmp(get_param(model,'SimulationStatus'),'stopped') && strcmp(get_param(model,'FastRestart'),'off'), ...
    'Stop the simulation and turn off Fast Restart before generating models.');
assert(ismember(mode,{'single','campaign'}),'Choose single or campaign mode.');
[~,meta]=modelSlots(model);original=[meta.fault];
[axes,counts,indices]=validateAxes(axes,meta);
single=find([original.enabled]);levels=cell(size(single));
if strcmp(mode,'single')
    assert(~isempty(single),'Enable the faults to generate, using the On column.');
    for j=1:numel(single)
        a=find(indices==single(j) & strcmp({axes.field},'value'));
        if isempty(a),levels{j}={original(single(j)).value};else,levels{j}=axes(a).levels;end
    end
    total=sum(cellfun(@numel,levels));
else
    total=prod(counts);
end
assert(isfinite(total) && total<=flintmax,'There are too many combinations to enumerate.');
save_system(model);
folder=char(java.io.File(folder).getCanonicalPath());
assert(isfolder(fileparts(folder)),'Choose an existing parent folder.');
java.nio.file.Files.createDirectory(java.io.File(folder).toPath(),javaArray('java.nio.file.attribute.FileAttribute',0));
source=get_param(model,'FileName');[~,~,ext]=fileparts(source);
rows=table('Size',[0 4],'VariableTypes',{'double','string','string','string'}, ...
    'VariableNames',{'case_index','model','status','diagnostic'});
cancelled=false;
[~,token]=fileparts(tempname);
for n=1:total
    if ~isempty(onProgress) && ~onProgress(n-1,total),cancelled=true;break;end
    settings=original;
    if strcmp(mode,'campaign')
        settings=campaignSettings(original,axes,counts,indices,n);
    else
        [settings.enabled]=deal(false);
        position=n;which=1;
        while position>numel(levels{which})
            position=position-numel(levels{which});which=which+1;
        end
        i=single(which);settings(i).enabled=true;settings(i).value=levels{which}{position};
    end
    name=sprintf('fi_%s_%s_%04d',model(1:min(end,24)),token(3:10),n);
    staged=tempname(folder);mkdir(staged);
    cleanup=onCleanup(@()discard(name,staged));
    filename=[name ext];target=fullfile(folder,filename);status="compiled";diagnostic="";
    try
        [ok,msg]=copyfile(source,fullfile(staged,filename));assert(ok,'%s',msg);
        assert(java.io.File(fullfile(staged,filename)).setWritable(true),'Cannot make the model copy writable.');
        load_system(fullfile(staged,filename));
        [paths,copies]=modelSlots(name);
        assert(isequal([copies.slot],[meta.slot]) && isequaln({copies.site},{meta.site}), ...
            'The model callbacks changed the fault sites while saving or loading.');
        for k=1:numel(copies)
            if ~isequaln(copies(k).fault,settings(k))
                copies(k).fault=settings(k);drawStage(paths{k},copies(k));
            end
        end
        metadata=sourceLink(name,source,folder);
        if isfield(metadata,'FIMWorkbenchAxes'),metadata=rmfield(metadata,'FIMWorkbenchAxes');end
        set_param(name,'Metadata',metadata);
        save_system(name);close_system(name,0);
        load_system(fullfile(staged,filename));set_param(name,'SimulationCommand','update');
        for k=1:numel(paths)
            assert(getSimulinkBlockHandle(paths{k})~=-1 && isequaln(get_param(paths{k},'UserData'),copies(k)), ...
                'Fault slot %d did not survive saving and recompilation.',copies(k).slot);
        end
        close_system(name,0);
        java.nio.file.Files.move(java.io.File(fullfile(staged,filename)).toPath(),java.io.File(target).toPath(),javaArray('java.nio.file.CopyOption',0));
    catch err
        status="failed";diagnostic=string(fimwb.internal.diagnosticText(err));
    end
    clear cleanup
    rows(end+1,:)={n,string(filename),status,diagnostic}; %#ok<AGROW>
    writetable(rows,fullfile(folder,'models.csv'));
end
report=struct('folder',folder,'planned',total,'completed',nnz(rows.status=="compiled"), ...
    'failed',nnz(rows.status=="failed"),'cancelled',cancelled);
writeConfiguration(fullfile(folder,'generation.json'),struct('mode',mode,'slots',[meta.slot], ...
    'settings',original,'axes',{axes},'report',report));
end

function discard(name,folder)
if bdIsLoaded(name),close_system(name,0);end
if isfolder(folder),rmdir(folder,'s');end
end
