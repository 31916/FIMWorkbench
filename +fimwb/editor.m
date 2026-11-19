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
win=uifigure('Name',['故障設定  ' name],'Position',[80 100 960 450],'Visible',visible);
g=uigridlayout(win,[2,2]);g.RowHeight={'1x',34};g.ColumnWidth={'1x',120};
grid=uitable(g,'Data',rows,'ColumnName',{'番号','注入箇所','故障','ON','値・演算子','開始 秒','終了 秒','乱数seed','ノイズ周期 秒'},...
    'ColumnFormat',{'numeric','char',kinds,'logical','char','numeric','char','numeric','numeric'},...
    'ColumnEditable',[false false true true true true true true true],...
    'ColumnWidth',{50,200,110,42,90,75,75,80,100},'CellEditCallback',@editCell);
grid.Layout.Row=1;grid.Layout.Column=[1 2];
status=uilabel(g,'Text','故障の種類・ON・値を編集できます。終了時刻の空欄はシミュレーション終了まで有効です。');
saveButton=uibutton(g,'Text','モデルを保存','ButtonPushedFcn',@persist);
    function editCell(~,event)
        row=event.Indices(1);column=event.Indices(2);
        cols={'','','type','enabled','value','start','stop','seed','period'};
        key=cols{column};data=grid.Data;v=data{row,column};kind=rows{row,3};
        try
            if ismember(key,{'seed','period'}),assert(strcmp(kind,'noise'),'乱数seedと周期はnoiseで使用します。');end
            if strcmp(key,'value') && ~ismember(kind,{'asr','ror'}),v=parseValue(v);end
            if strcmp(key,'stop'),v=parseValue(v);end
            f=fimwb.setFault(name,rows{row,1},struct(key,v));
            data(row,3:9)={f.type,f.enabled,displayValue(f.value),f.start,displayValue(f.stop),f.seed,f.period};
            grid.Data=data;rows=data;status.Text=sprintf('番号 %d の設定を変更しました。',rows{row,1});
        catch err
            grid.Data=rows;status.Text=err.message;
        end
    end
    function persist(~,~)
        try,save_system(name);status.Text='モデルを保存しました。';
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
