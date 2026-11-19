function win = editor(file,visible)
%EDITOR Find an installed fault, edit its settings and compare simulations.
if nargin<2,visible='on';end
name=loadWorkingModel(file);
upgradeMeasurement(name);
[stages,meta]=modelSlots(name);
rows=cell(numel(meta),10);
for k=1:numel(meta)
    rows(k,:)=[{meta(k).slot,meta(k).site.id},faultCells(meta(k).fault), ...
        {connection(meta(k).site,name)}];
end
shown=(1:numel(meta))';
selected=0;marked=[];
toggles=false(size(shown));values=cell(size(shown));
win=uifigure('Name',['Fault settings - ' name],'Position',[70 90 1220 560],'Visible',visible);
win.DeleteFcn=@(~,~)clearMark();
layout=uigridlayout(win,[5 1]);
layout.RowHeight={34,'1x',34,34,24};
top=uigridlayout(layout,[1 3],'Padding',0,'ColumnWidth',{'1x',110,120});
uieditfield(top,'text','Placeholder','Find a block, signal, port or site ID', ...
    'Tag','siteSearch','ValueChangingFcn',@(~,e)filterRows(e.Value),'ValueChangedFcn',@(src,~)filterRows(src.Value));
count=uilabel(top,'Text','');
highlight=uibutton(top,'Text','Show in model','Tag','highlightSite','ButtonPushedFcn',@showSite);
grid=uitable(layout,'Data',rows,'Tag','faultTable', ...
    'ColumnName',{'Slot','Site ID','Fault type','On','Value / operator','Start (s)','Stop (s)','Noise seed','Noise period (s)','Connection'}, ...
    'ColumnFormat',{'numeric','char','char','logical','char','numeric','char','numeric','numeric','char'}, ...
    'ColumnEditable',[false false false true true true true true true false], ...
    'ColumnWidth',{45,145,95,38,100,70,70,72,100,375}, ...
    'CellEditCallback',@editCell,'CellSelectionCallback',@selectCell);
controls=uigridlayout(layout,[1 6],'Padding',0,'ColumnWidth',{65,140,85,125,'1x',130});
uilabel(controls,'Text','Fault type');
kind=uidropdown(controls,'Items',{'Select a site'},'Tag','faultTypePicker','ValueChangedFcn',@(src,~)apply('type',src.Value));
uilabel(controls,'Text','Replacement');
operator=uidropdown(controls,'Items',{'Replacement'},'Tag','operatorPicker','ValueChangedFcn',@(src,~)apply('value',src.Value));
uilabel(controls,'Text','');
uibutton(controls,'Text','Save model','Tag','saveModel','ButtonPushedFcn',@persist);
campaign=uigridlayout(layout,[1 6],'Padding',0,'ColumnWidth',{110,100,'1x',110,145,150});
toggle=uicheckbox(campaign,'Text','Sweep off/on','Tag','axisToggle','ValueChangedFcn',@editAxes);
uilabel(campaign,'Text','Sweep values');
levels=uieditfield(campaign,'text','Placeholder','JSON array, e.g. [-2,0,2]','Tag','axisValues','ValueChangedFcn',@editAxes);
uibutton(campaign,'Text','Clear axes','Tag','clearAxes','ButtonPushedFcn',@clearAxes);
batch=uibutton(campaign,'Text','Run campaign','Tag','runCampaign','ButtonPushedFcn',@(~,~)run(true));
uibutton(campaign,'Text','Compare off / on','Tag','compare','ButtonPushedFcn',@(~,~)run(false));
status=uilabel(layout,'Text','Select a row to edit its fault. Leave Stop (s) blank for an open-ended fault.','Tag','status');
filterRows('');

    function filterRows(query)
        keep=contains(string(rows(:,2)),strtrim(query),'IgnoreCase',true) | ...
            contains(string(rows(:,10)),strtrim(query),'IgnoreCase',true);
        shown=find(keep);
        grid.Data=rows(shown,:);grid.Selection=[];
        selected=0;clearMark();
        count.Text=sprintf('%d of %d sites',numel(shown),numel(meta));
        refresh();
    end

    function selectCell(~,event)
        selected=0;
        if ~isempty(event.Indices),selected=shown(event.Indices(1,1));end
        clearMark();refresh();
    end

    function refresh()
        active=selected>0;
        highlight.Enable=active;kind.Enable=active;toggle.Enable=active;levels.Enable=active;
        choices={};toggle.Value=false;levels.Value='';
        if active
            site=meta(selected).site;
            kind.Items=reshape(site.faults,1,[]);kind.Value=rows{selected,3};
            if isfield(site,'originalOperator'),choices=operatorChoices(kind.Value,site);end
            toggle.Value=toggles(selected);
            if ~isempty(values{selected}),levels.Value=jsonencode(values{selected});end
        else
            kind.Items={'Select a site'};
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
            rows(selected,3:9)=faultCells(f);meta(selected).fault=f;
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

    function editAxes(~,~)
        try
            v=[];
            if strlength(strtrim(levels.Value))>0
                assert(startsWith(strtrim(levels.Value),'['),'Enter the levels as a JSON array.');
                v=jsondecode(levels.Value);
                assert(isvector(v)&&~isempty(v),'Enter a nonempty JSON array or clear the field.');
                if ~iscell(v),v=num2cell(v);end
                for j=1:numel(v)
                    f=meta(selected).fault;f.type=rows{selected,3};f.value=v{j};
                    checkFault(f,meta(selected).site);
                end
            end
            values{selected}=v;toggles(selected)=toggle.Value;
            status.Text=sprintf('Updated campaign axes for slot %d.',rows{selected,1});
        catch err
            status.Text=fimwb.internal.diagnosticText(err);
        end
        refresh();
    end

    function clearAxes(~,~)
        toggles(:)=false;values(:)={[]};refresh();
    end

    function run(useAxes)
        parent=uigetdir(pwd,'Choose where to create the experiment results folder');
        if isequal(parent,0),return;end
        axes=struct('slot',{},'field',{},'levels',{});
        if useAxes
            for i=1:numel(meta)
                if toggles(i)
                    axes(end+1)=struct('slot',meta(i).slot,'field','enabled','levels',[false true]); %#ok<AGROW>
                end
                if ~isempty(values{i})
                    axes(end+1)=struct('slot',meta(i).slot,'field','value','levels',values(i)); %#ok<AGROW>
                end
            end
        end
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
cells={f.type,f.enabled,displayValue(f.value),f.start,displayValue(f.stop),f.seed,f.period};
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
