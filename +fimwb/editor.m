function win = editor(file,visible)
%EDITOR Find an installed fault, edit its settings and compare simulations.
if nargin<2,visible='on';end
name=loadWorkingModel(file);
upgradeMeasurement(name);
[stages,meta]=modelSlots(name);
rows=cell(numel(meta),10);
for rowIndex=1:numel(meta)
    rows(rowIndex,:)=[{meta(rowIndex).slot,meta(rowIndex).site.id},faultCells(meta(rowIndex).fault), ...
        {connection(meta(rowIndex).site,name)}];
end
shown=(1:numel(meta))';
selected=0;marked=[];
toggles=false(size(shown));values=cell(size(shown));
win=uifigure('Name',['Fault settings - ' name],'Position',[70 70 1220 690],'Visible',visible);
win.DeleteFcn=@(~,~)clearMark();
layout=uigridlayout(win,[8 1]);
layout.RowHeight={34,'1x',34,60,34,34,34,24};
top=uigridlayout(layout,[1 5],'Padding',0,'ColumnWidth',{'1x',110,120,160,110});
uieditfield(top,'text','Placeholder','Find a block, signal, port or site ID', ...
    'Tag','siteSearch','ValueChangingFcn',@(~,e)filterRows(e.Value),'ValueChangedFcn',@(src,~)filterRows(src.Value));
count=uilabel(top,'Text','');
highlight=uibutton(top,'Text','Show in model','Tag','highlightSite','ButtonPushedFcn',@showSite);
append=uibutton(top,'Text','Add fault at this site','Tag','addFault','ButtonPushedFcn',@appendFault);
remove=uibutton(top,'Text','Remove fault','Tag','removeFault','ButtonPushedFcn',@removeSelected);
grid=uitable(layout,'Data',rows,'Tag','faultTable', ...
    'ColumnName',{'Slot','Site ID','Fault type','On','Value / operator','Start (s)','Stop (s)','Noise seed','Noise period (s)','Connection'}, ...
    'ColumnFormat',{'numeric','char','char','logical','char','numeric','char','numeric','numeric','char'}, ...
    'ColumnEditable',[false false false true true true true true true false], ...
    'ColumnWidth',{45,145,95,38,130,70,70,90,110,330}, ...
    'CellEditCallback',@editCell,'CellSelectionCallback',@selectCell);
controls=uigridlayout(layout,[1 6],'Padding',0,'ColumnWidth',{65,140,85,125,'1x',130});
uilabel(controls,'Text','Fault type');
kind=uidropdown(controls,'Items',{'Select a site'},'Tag','faultTypePicker','ValueChangedFcn',@(src,~)apply('type',src.Value));
uilabel(controls,'Text','Replacement');
operator=uidropdown(controls,'Items',{'Replacement'},'Tag','operatorPicker','ValueChangedFcn',@(src,~)apply('value',src.Value));
uilabel(controls,'Text','');
uibutton(controls,'Text','Save model','Tag','saveModel','ButtonPushedFcn',@persist);
help=uilabel(layout,'Text','Select a row. Fault type lists the choices compatible with that signal or operator.','Tag','faultHelp','WordWrap','on');
campaign=uigridlayout(layout,[1 5],'Padding',0,'ColumnWidth',{110,'1x',110,180,150});
toggle=uicheckbox(campaign,'Text','Sweep off/on','Tag','axisToggle','ValueChangedFcn',@editAxes);
levels=uibutton(campaign,'Text','Choose sweep values...','Tag','axisValues','ButtonPushedFcn',@selectValues);
uibutton(campaign,'Text','Clear axes','Tag','clearAxes','ButtonPushedFcn',@clearAxes);
batch=uibutton(campaign,'Text','Run campaign','Tag','runCampaign','ButtonPushedFcn',@(~,~)run(true));
uibutton(campaign,'Text','Compare off / on','Tag','compare','ButtonPushedFcn',@(~,~)run(false));
generation=uigridlayout(layout,[1 3],'Padding',0,'ColumnWidth',{115,'1x',220});
uilabel(generation,'Text','Separate models');
mode=uidropdown(generation,'Items',{'One enabled fault per model','Campaign combinations'},'ItemsData',{'single','campaign'},'Tag','generationMode','ValueChangedFcn',@(~,~)refresh());
generate=uibutton(generation,'Text','Generate models','Tag','generateModels','ButtonPushedFcn',@generateModels);
files=uigridlayout(layout,[1 3],'Padding',0,'ColumnWidth',{195,170,'1x'});
uibutton(files,'Text','Save configuration...','Tag','saveConfiguration','ButtonPushedFcn',@saveConfiguration);
uibutton(files,'Text','Open saved results...','Tag','openResults','ButtonPushedFcn',@openResults);
uilabel(files,'Text','Additional faults at the same signal are applied in slot order.');
status=uilabel(layout,'Text','','Tag','status');
stored=get_param(name,'Metadata');
if isstruct(stored) && isfield(stored,'FIMWorkbenchAxes') && ~isempty(stored.FIMWorkbenchAxes)
    [saved,~,indices]=validateAxes(stored.FIMWorkbenchAxes,meta);
    for axisIndex=1:numel(saved)
        if strcmp(saved(axisIndex).field,'enabled'),toggles(indices(axisIndex))=true;else,values{indices(axisIndex)}=saved(axisIndex).levels;end
    end
end
filterRows('');

    function filterRows(query)
        keep=contains(string(rows(:,2)),strtrim(query),'IgnoreCase',true) | ...
            contains(string(rows(:,10)),strtrim(query),'IgnoreCase',true);
        shown=find(keep);
        grid.Data=rows(shown,:);grid.Selection=[];
        selected=0;clearMark();
        count.Text=sprintf('%d of %d faults',numel(shown),numel(meta));
        refresh();
    end

    function selectCell(~,event)
        selected=0;
        if ~isempty(event.Indices),selected=shown(event.Indices(1,1));end
        clearMark();refresh();
    end

    function refresh()
        active=selected>0;
        highlight.Enable=active;kind.Enable=active;toggle.Enable=active;levels.Enable='off';append.Enable='off';remove.Enable='off';
        choices={};toggle.Value=false;levels.Text='Choose sweep values...';
        if active
            site=meta(selected).site;
            kind.Items=reshape(site.faults,1,[]);kind.Value=rows{selected,3};
            if isfield(site,'originalOperator'),choices=operatorChoices(kind.Value,site);end
            toggle.Value=toggles(selected);
            levels.Enable=~isempty(meta(selected).fault.value);
            levels.Text=sprintf('Choose sweep values... (%d)',numel(values{selected}));
            append.Enable=~strcmp(site.kind,'operator');
            remove.Enable=~strcmp(site.kind,'operator') && nnz(strcmp(rows(:,2),site.id))>1;
            help.Text=faultDescription(kind.Value);
        else
            kind.Items={'Select a site'};
            help.Text='Select a row. Fault type lists the choices compatible with that signal or operator.';
        end
        operator.Enable=~isempty(choices);
        if isempty(choices)
            operator.Items={'Replacement'};
        else
            operator.Items=choices;operator.Value=rows{selected,5};
        end
        n=prod(cellfun(@numel,values(~cellfun(@isempty,values))))*2^nnz(toggles);
        batch.Enable=any(toggles)||any(~cellfun(@isempty,values));
        batch.Text=sprintf('Run campaign (%g)',n);
        if strcmp(mode.Value,'single')
            faults=[meta.fault];enabled=[faults.enabled];
            n=sum(cellfun(@(v)max(1,numel(v)),values(enabled)));
        end
        generate.Enable=n>0;generate.Text=sprintf('Save and generate %g model(s)',n);
    end

    function editCell(~,event)
        selected=shown(event.Indices(1));
        col=event.Indices(2);
        keys={'','','type','enabled','value','start','stop','seed','period'};
        v=grid.Data{event.Indices(1),col};
        if col==7 || (col==5 && ~ismember(rows{selected,3},{'asr','ror','lor'}))
            if strlength(string(v))==0,v=[];else,v=str2double(string(v));end
        end
        apply(keys{col},v);
    end

    function apply(key,v)
        try
            if ismember(key,{'seed','period'})
                assert(strcmp(rows{selected,3},'noise'),'Select the noise fault to edit its seed or sample period.');
            end
            f=fimwb.setFault(name,rows{selected,1},struct(key,v));
            if ~strcmp(rows{selected,3},f.type),values{selected}=[];end
            rows(selected,3:9)=faultCells(f);meta(selected).fault=f;storeAxes();
            status.Text=sprintf('Updated slot %d.',rows{selected,1});
        catch err
            status.Text=fimwb.internal.diagnosticText(err);
        end
        grid.Data=rows(shown,:);status.Tooltip=status.Text;refresh();
    end

    function clearMark()
        for h=marked
            if ishandle(h),hilite_system(h,'none');end
        end
        marked=[];
    end

    function showSite(~,~)
        try
            clearMark();block=stages{selected};
            open_system(get_param(block,'Parent'),'force');
            ports=get_param(block,'PortHandles');
            marked=[get_param(block,'Handle'),get_param(ports.Outport(1),'Line')];
            for h=marked,hilite_system(h,'find');end
            status.Text=rows{selected,10};
        catch err
            status.Text=fimwb.internal.diagnosticText(err);
        end
        status.Tooltip=status.Text;
    end

    function selectValues(~,~)
        row=selected;
        chooseValues(win,meta(row).fault,meta(row).site,values{row},@(v)acceptValues(row,v));
    end

    function acceptValues(row,v)
        values{row}=v;storeAxes();refresh();
    end

    function editAxes(~,~)
        toggles(selected)=toggle.Value;storeAxes();refresh();
    end

    function axes=currentAxes()
        axes=struct('slot',{},'field',{},'levels',{});
        for i=1:numel(meta)
            if toggles(i),axes(end+1)=struct('slot',meta(i).slot,'field','enabled','levels',[false true]);end %#ok<AGROW>
            if ~isempty(values{i}),axes(end+1)=struct('slot',meta(i).slot,'field','value','levels',values(i));end %#ok<AGROW>
        end
    end

    function storeAxes()
        metadata=get_param(name,'Metadata');
        if isempty(metadata),metadata=struct();end
        metadata.FIMWorkbenchAxes=currentAxes();set_param(name,'Metadata',metadata);
    end

    function appendFault(~,~)
        try
            slot=fimwb.addFault(name,meta(selected).slot);
            [stages,meta]=modelSlots(name);
            m=meta(end);rows(end+1,:)=[{m.slot,m.site.id},faultCells(m.fault),{connection(m.site,name)}];
            toggles(end+1)=false;values{end+1}=[];
            search=findall(win,'Tag','siteSearch');filterRows(search.Value);
            selected=find([meta.slot]==slot);grid.Selection=find(shown==selected);refresh();
            status.Text=sprintf('Added slot %d. Choose its fault type, value and On switch.',slot);
        catch err
            status.Text=fimwb.internal.diagnosticText(err);
        end
    end

    function saveConfiguration(~,~)
        suggested=fullfile(fileparts(get_param(name,'FileName')),[name '_configuration.json']);
        [file,folder]=uiputfile('*.json','Save fault settings and campaign',suggested);
        if isequal(file,0),return;end
        try
            axes=currentAxes();
            for savedIndex=1:numel(axes),axes(savedIndex).slot=find([meta.slot]==axes(savedIndex).slot);end
            config=struct('faults',[meta.fault],'axes',{axes});
            metadata=get_param(name,'Metadata');
            if isstruct(metadata) && isfield(metadata,'FIMWorkbenchSourceSHA256')
                config.sourceSha256=metadata.FIMWorkbenchSourceSHA256;
            end
            writeConfiguration(fullfile(folder,file),config);
            status.Text='Configuration saved. Select it in the launcher with the original source model to create another working copy.';
        catch err
            status.Text=fimwb.internal.diagnosticText(err);
        end
    end

    function removeSelected(~,~)
        try
            clearMark();fimwb.removeFault(name,meta(selected).slot);
            rows(selected,:)=[];toggles(selected)=[];values(selected)=[];
            [stages,meta]=modelSlots(name);storeAxes();
            search=findall(win,'Tag','siteSearch');filterRows(search.Value);
            status.Text='Fault removed. The remaining faults retain their order.';
        catch err
            status.Text=fimwb.internal.diagnosticText(err);
        end
    end

    function openResults(~,~)
        folder=uigetdir(pwd,'Open a saved comparison folder');
        if isequal(folder,0),return;end
        try
            fimwb.plotComparison(folder);
        catch err
            status.Text=fimwb.internal.diagnosticText(err);
        end
    end

    function generateModels(~,~)
        parent=uigetdir(pwd,'Choose where to create the generated models folder');
        if isequal(parent,0),return;end
        folder=fullfile(parent,[name '_models_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
        dialog=uiprogressdlg(win,'Title','Generating models','Message','Preparing...','Cancelable','on');
        finish=onCleanup(@()close(dialog));
        try
            report=fimwb.exportModels(name,folder,currentAxes(),mode.Value,@(done,total)generationProgress(dialog,done,total));
            status.Text=sprintf('%d models compiled, %d failed. Results in %s',report.completed,report.failed,report.folder);
            if report.cancelled,status.Text=['Stopped. ' status.Text];end
        catch err
            status.Text=fimwb.internal.diagnosticText(err);
        end
        status.Tooltip=status.Text;
    end

    function clearAxes(~,~)
        toggles(:)=false;values(:)={[]};storeAxes();refresh();
    end

    function run(useAxes)
        parent=uigetdir(pwd,'Choose where to create the experiment results folder');
        if isequal(parent,0),return;end
        axes=struct('slot',{},'field',{},'levels',{});
        if useAxes,axes=currentAxes();end
        folder=fullfile(parent,[name '_' char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'))]);
        dialog=uiprogressdlg(win,'Title','Running experiment','Message','Preparing simulations...','Cancelable','on');
        reset=onCleanup(@()close(dialog));
        try
            result=fimwb.experiment(name,folder,axes,@(done,total)progress(dialog,done,total),'record');
            clear reset
            status.Text=sprintf('Saved %d case(s) and baseline to %s',result.caseCount,result.folder);
            if result.failedCases>0
                status.Text=sprintf('%d completed, %d failed. Results in %s',result.completedCases,result.failedCases,result.folder);
            end
            fimwb.plotComparison(result.folder);
        catch err
            status.Text=fimwb.internal.diagnosticText(err);
        end
        status.Tooltip=status.Text;
    end

    function persist(~,~)
        try
            save_system(name);
            status.Text='Model saved.';
        catch err
            status.Text=fimwb.internal.diagnosticText(err);
        end
    end
end

function cells=faultCells(f)
seed=[];period=[];
if strcmp(f.type,'noise'),seed=f.seed;period=f.period;end
cells={f.type,f.enabled,displayValue(f.value),f.start,displayValue(f.stop),seed,period};
end

function s=displayValue(v)
if isempty(v),s='';elseif isnumeric(v)||islogical(v),s=num2str(double(v),17);else,s=char(v);end
end

function text=connection(site,model)
dst=arrayfun(@(d)sprintf('%s [%s %d]',d.path,d.kind,d.port),site.destinations,'UniformOutput',false);
text=sprintf('%s [out %d] → %s',site.source,site.port,strjoin(dst,', '));
ports=get_param([model '/' site.source],'PortHandles');
line=get_param(ports.Outport(site.port),'Line');
if line~=-1
    signal=get_param(line,'Name');
    if ~isempty(signal),text=[signal ' | ' text];end
end
text=regexprep(text,'[\r\n]+',' ');
end

function progress(dialog,done,total)
dialog.Value=done/total;
dialog.Message=sprintf('%d of %d simulations complete',done,total);
drawnow
assert(~dialog.CancelRequested,'Experiment cancelled.');
end

function keepGoing=generationProgress(dialog,done,total)
dialog.Value=done/total;dialog.Message=sprintf('%d of %d models processed',done,total);
drawnow
keepGoing=~dialog.CancelRequested;
end
