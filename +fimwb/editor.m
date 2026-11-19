function win=editor(file,visible)
%EDITOR Edit a generated model's individual fault switches and values.
if nargin<2,visible='on';end
[~,name,ext]=fileparts(char(file));
if isempty(ext)
    assert(bdIsLoaded(name),'Open the generated model or pass its full path.');
else
    [ok,a]=fileattrib(file);assert(ok,'Model file not found.');
    if bdIsLoaded(name)
        assert(strcmp(get_param(name,'FileName'),a.Name),'A different model of the same name is open.');
    else
        load_system(a.Name);
    end
end
stages=faultStages(name);
assert(~isempty(stages),'This model contains no generated fault slots.');
upgradeMeasurement(name);
meta=cellfun(@(p)get_param(p,'UserData'),stages,'UniformOutput',false);
[~,ix]=sort(cellfun(@(m)m.slot,meta));meta=meta(ix);
kinds={};for k=1:numel(meta),kinds=union(kinds,meta{k}.site.faults);end
kinds=reshape(kinds,1,[]);
rows=cell(numel(meta),9);
for k=1:numel(meta)
    f=meta{k}.fault;
    rows(k,:)={meta{k}.slot,f.site,f.type,f.enabled,displayValue(f.value),f.start,displayValue(f.stop),f.seed,f.period};
end
win=uifigure('Name',['Fault settings - ' name],'Position',[80 100 960 450],'Visible',visible);
g=uigridlayout(win,[2,3]);g.RowHeight={'1x',34};g.ColumnWidth={'1x',135,120};
grid=uitable(g,'Data',rows,'ColumnName',{'Slot','Injection site','Fault type','On','Value / operator','Start (s)','Stop (s)','Noise seed','Noise period (s)'},...
    'ColumnFormat',{'numeric','char',kinds,'logical','char','numeric','char','numeric','numeric'},...
    'ColumnEditable',[false false true true true true true true true],...
    'ColumnWidth',{48,190,110,42,120,75,75,90,115},'CellEditCallback',@editCell,'CellSelectionCallback',@selectCell);
grid.Layout.Row=1;grid.Layout.Column=[1 3];
status=uilabel(g,'Text','Leave Stop (s) blank to keep a fault active until the simulation ends.');
selected=0;
picker=uidropdown(g,'Items',{'Replacement'},'Enable','off','Tag','operatorPicker',...
    'Tooltip','Replacement operator for the selected row','ValueChangedFcn',@chooseOperator);
saveButton=uibutton(g,'Text','Save model','ButtonPushedFcn',@persist);
    function selectCell(~,event)
        selected=0;
        if ~isempty(event.Indices),selected=event.Indices(1,1);end
        refreshPicker();
    end
    function refreshPicker()
        choices={};
        if selected>0
            site=meta{selected}.site;kind=rows{selected,3};
            if isfield(site,'originalOperator'),choices=operatorChoices(kind,site);end
        end
        if isempty(choices)
            picker.Items={'Replacement'};picker.Enable='off';
            picker.Tooltip='Replacement operator for the selected row';
        else
            picker.Items=choices;picker.Value=rows{selected,5};picker.Enable='on';
            picker.Tooltip=['Replace the original ' site.originalOperator ' operator'];
        end
    end
    function chooseOperator(~,~)
        data=grid.Data;data{selected,5}=picker.Value;grid.Data=data;
        editCell(grid,struct('Indices',[selected 5]));
    end
    function editCell(~,event)
        row=event.Indices(1);column=event.Indices(2);
        cols={'','','type','enabled','value','start','stop','seed','period'};
        key=cols{column};data=grid.Data;v=data{row,column};kind=rows{row,3};
        try
            if ismember(key,{'seed','period'}),assert(strcmp(kind,'noise'),'Select the noise fault to edit its seed or sample period.');end
            if strcmp(key,'value') && ~ismember(kind,{'asr','ror','lor'}),v=parseValue(v);end
            if strcmp(key,'stop'),v=parseValue(v);end
            f=fimwb.setFault(name,rows{row,1},struct(key,v));
            data(row,3:9)={f.type,f.enabled,displayValue(f.value),f.start,displayValue(f.stop),f.seed,f.period};
            grid.Data=data;rows=data;status.Text=sprintf('Updated fault settings for slot %d.',rows{row,1});
        catch err
            grid.Data=rows;status.Text=err.message;
        end
        selected=row;refreshPicker();
    end
    function persist(~,~)
        try,save_system(name);status.Text='Model saved.';
        catch err,status.Text=err.message;end
    end
end

function s=displayValue(v)
if isempty(v),s='';elseif isnumeric(v)||islogical(v),s=num2str(double(v),17);else,s=char(v);end
end
function v=parseValue(v)
if ischar(v)||isstring(v)
    if strlength(string(v))==0,v=[];else,v=str2double(v);end
end
end
