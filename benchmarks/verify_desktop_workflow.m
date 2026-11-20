function results=verify_desktop_workflow(folder)
%VERIFY_DESKTOP_WORKFLOW Drive desktop callbacks and check generated model traces.
assert(~isfolder(folder),'Choose a fresh results folder.');mkdir(folder);
[~,attr]=fileattrib(folder);folder=attr.Name;
source=fullfile(folder,'desktop_source.slx');model='desktop_working';
new_system('desktop_source');
add_block('built-in/Constant','desktop_source/Input','Value','3');
add_block('built-in/Outport','desktop_source/Result');
add_line('desktop_source','Input/1','Result/1');
set_param('desktop_source','Solver','FixedStepDiscrete','FixedStep','0.1','StopTime','2');
save_system('desktop_source',source);close_system('desktop_source',0);
% Supply file chooser answers only. Model generation and UI callbacks run normally.
chooser=fullfile(folder,'chooser');mkdir(chooser);
writeFile(fullfile(chooser,'uigetdir.m'),sprintf('function out=uigetdir(varargin)\nout=''%s'';\nend\n',strrep(folder,'''','''''')));
writeFile(fullfile(chooser,'uiputfile.m'),sprintf('function [file,folder]=uiputfile(varargin)\nfile=''saved_configuration.json'';folder=''%s'';\nend\n',strrep(folder,'''','''''')));
addpath(chooser,'-begin');restore=onCleanup(@()rmpath(chooser));
app=FIMWorkbench();sourceBox=findall(app,'Tag','source');sourceBox.Value=source;
output=findall(app,'Tag','output');file=fullfile(folder,[model '.slx']);output.Value=file;
click(app,'build');assert(isfile(file),'%s',findall(app,'Tag','status').Text);
win=findall(groot,'Type','figure','Name',['Fault settings - ' model]);
grid=findall(win,'Tag','faultTable');assert(size(grid.Data,1)==1);
select(grid,1);edit(grid,1,5,'1');edit(grid,1,4,true);
click(win,'addFault');assert(size(grid.Data,1)==2,'%s',findall(win,'Tag','status').Text);
select(grid,2);kind=findall(win,'Tag','faultTypePicker');kind.Value='gain';feval(kind.ValueChangedFcn,kind,[]);
edit(grid,2,5,'2');edit(grid,2,4,true);
assert(trace(model)==8,'Expected (3 + 1) * 2 for the two stacked faults.');
click(win,'addFault');assert(size(grid.Data,1)==3);
click(win,'removeFault');assert(size(grid.Data,1)==2 && trace(model)==8,'%s',findall(win,'Tag','status').Text);
select(grid,2);
setValues(win,[2 4]);
toggle=findall(win,'Tag','axisToggle');toggle.Value=true;feval(toggle.ValueChangedFcn,toggle,[]);
select(grid,1);setValues(win,[-1 1]);
click(win,'saveModel');click(win,'saveConfiguration');
assert(isfile(fullfile(folder,'saved_configuration.json')));
delete(win);close_system(model,0);
win=fimwb.editor(file,'off');grid=findall(win,'Tag','faultTable');
assert(contains(findall(win,'Tag','runCampaign').Text,'8'));
assert(trace(model)==8);select(grid,2);
assert(findall(win,'Tag','axisToggle').Value && contains(findall(win,'Tag','axisValues').Text,'2'));
win.Visible='on';drawnow;exportapp(win,fullfile(folder,'editor.png'));
click(win,'runCampaign');
run=dir(fullfile(folder,[model '_*'],'runs.csv'));assert(isscalar(run),'%s',findall(win,'Tag','status').Text);
runs=readtable(fullfile(run.folder,run.name),'Delimiter',',','TextType','string','ReadVariableNames',true);
assert(height(runs)==9 && all(runs.status=="completed"));
for k=1:8
    i=k-1;b=[-1 1];gain=[2 4];
    expected=3+b(1+bitget(i,1));
    if bitget(i,2),expected=expected*gain(1+bitget(i,3));end
    data=readtable(fullfile(run.folder,sprintf('case_%04d.csv',k)));
    assert(all(abs(data.value-expected)<1e-12));
end
mode=findall(win,'Tag','generationMode');
dirty=get_param(model,'Dirty');filename=get_param(model,'FileName');
click(win,'generateModels');first=dir(fullfile(folder,[model '_models_*'],'models.csv'));
assert(isscalar(first),'%s',findall(win,'Tag','status').Text);
single=checkModels(first.folder,[2 4 6 12]);
mode.Value='campaign';feval(mode.ValueChangedFcn,mode,[]);click(win,'generateModels');
allRuns=dir(fullfile(folder,[model '_models_*'],'models.csv'));
second=allRuns(~strcmp({allRuns.folder},first.folder));assert(isscalar(second));
combined=checkModels(second.folder,[2 4 4 8 2 4 8 16]);
assert(trace(model)==8,'Generating files changed the editable model.');
assert(strcmp(dirty,get_param(model,'Dirty')) && strcmp(filename,get_param(model,'FileName')));
% Load the saved configuration through the launcher, including the axes.
config=findall(app,'Tag','profile');config.Value=fullfile(folder,'saved_configuration.json');
output.Value=fullfile(folder,'desktop_restored.slx');click(app,'build');
restored=findall(groot,'Type','figure','Name','Fault settings - desktop_restored');
assert(isscalar(restored) && contains(findall(restored,'Tag','runCampaign').Text,'8'));
assert(trace('desktop_restored')==8);
delete(restored);close_system('desktop_restored',0);
% A failed generated case preserves the valid models before and after it.
callback="if get_param([bdroot '/FIMWB_002'],'UserData').fault.value==3, error('fimwb:TestGeneration','Requested generation failure.'); end";
set_param(model,'InitFcn',char(callback));
axis=struct('slot',2,'field','value','levels',[2 3 4]);
failure=fimwb.exportModels(model,fullfile(folder,'with_failure'),axis,'campaign');
assert(failure.completed==2 && failure.failed==1);
set_param(model,'InitFcn','');
stopped=fimwb.exportModels(model,fullfile(folder,'cancelled'),axis,'campaign',@(done,~)done<1);
assert(stopped.cancelled && stopped.completed==1);
results=table(single,combined,8,2,1,'VariableNames', ...
    {'single_models','campaign_models','simulated_campaign_cases','successful_neighbors','cancelled_completed'});
writetable(results,fullfile(folder,'summary.csv'));
delete(win);close_system(model,0);delete(app);
delete(findall(groot,'Type','figure','Name','Baseline and fault comparison'));
disp('DESKTOP_WORKFLOW_PASS');
end

function value=trace(model)
out=sim(model,'SaveOutput','on','OutputSaveName','checked','SaveFormat','Dataset','ReturnWorkspaceOutputs','on');
v=out.checked{1}.Values.Data;assert(all(v==v(1)));value=double(v(1));
end

function count=checkModels(folder,expected)
rows=readtable(fullfile(folder,'models.csv'),'Delimiter',',','TextType','string','ReadVariableNames',true);
assert(height(rows)==numel(expected) && all(rows.status=="compiled"));
for k=1:height(rows)
    file=fullfile(folder,rows.model(k));[~,name]=fileparts(file);
    win=fimwb.editor(file,'off');assert(trace(name)==expected(k));delete(win);close_system(name,0);
end
count=height(rows);
end

function setValues(win,values)
click(win,'axisValues');
dialog=findall(groot,'Type','figure','Name','Choose sweep values');assert(isscalar(dialog));
entry=findall(dialog,'Tag','candidateValue');
for v=values,entry.Value=v;click(dialog,'addValue');end
list=findall(dialog,'Tag','valueList');assert(numel(list.Items)==numel(values));
entry.Value=values(end);click(dialog,'addValue');
assert(numel(list.Items)==numel(values) && contains(findall(dialog,'Tag','valueStatus').Text,'already'));
click(dialog,'applyValues');
end

function click(win,tag)
button=findall(win,'Tag',tag);assert(isscalar(button));feval(button.ButtonPushedFcn,button,[]);
end
function select(grid,row)
feval(grid.CellSelectionCallback,grid,struct('Indices',[row 3]));
end
function edit(grid,row,col,value)
data=grid.Data;data{row,col}=value;grid.Data=data;feval(grid.CellEditCallback,grid,struct('Indices',[row col]));
end
function writeFile(file,text)
fid=fopen(file,'w');assert(fid>=0);cleanup=onCleanup(@()fclose(fid));fprintf(fid,'%s',text);
end
