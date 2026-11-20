function result=verify_desktop_aecs(upstream,folder)
%VERIFY_DESKTOP_AECS Check stacked faults and generated variants on the FIM aircraft.
assert(~isfolder(folder));mkdir(folder);[~,attr]=fileattrib(folder);folder=attr.Name;
tool=fileparts(fileparts(mfilename('fullpath')));
source=fullfile(upstream,'Aircraft_fault_injector','sf_aircraft_model','Aircraft.slx');
profile=fullfile(tool,'examples','fim-paper-aecs.json');
sourceHash=fimwb.fileHash(source);model='desktop_aecs';
app=FIMWorkbench();
field=findall(app,'Tag','source');field.Value=source;
field=findall(app,'Tag','profile');field.Value=profile;
file=fullfile(folder,[model '.slx']);field=findall(app,'Tag','output');field.Value=file;
click(app,'build');assert(isfile(file),'%s',findall(app,'Tag','status').Text);
win=findall(groot,'Type','figure','Name',['Fault settings - ' model]);
grid=findall(win,'Tag','faultTable');assert(size(grid.Data,1)==45);
reference=observe(model);
for row=[38 44]
    select(grid,row);click(win,'axisValues');
    dialog=findall(groot,'Type','figure','Name','Choose sweep values');
    entry=findall(dialog,'Tag','candidateValue');assert(isa(entry,'matlab.ui.control.DropDown'));
    click(dialog,'addValue');list=findall(dialog,'Tag','valueList');assert(numel(list.Items)==1);
    list.Value=1;click(dialog,'removeValue');assert(isempty(list.Items));
    click(dialog,'addValue');click(dialog,'applyValues');
end
click(win,'clearAxes');
select(grid,1);edit(grid,1,4,true);click(win,'addFault');assert(size(grid.Data,1)==46);
select(grid,46);picker=findall(win,'Tag','faultTypePicker');picker.Value='gain';feval(picker.ValueChangedFcn,picker,[]);
edit(grid,46,4,true);
actual=observe(model);error=compare(reference,actual,0.125,2);
assert(error<1e-12);
click(win,'axisValues');dialog=findall(groot,'Type','figure','Name','Choose sweep values');
entry=findall(dialog,'Tag','candidateValue');
for v=[0.5 2],entry.Value=v;click(dialog,'addValue');end
click(dialog,'applyValues');
select(grid,1);toggle=findall(win,'Tag','axisToggle');toggle.Value=true;feval(toggle.ValueChangedFcn,toggle,[]);
click(win,'saveModel');
% The GUI supplies its own configurations to the same exporter used here.
metadata=get_param(model,'Metadata');axes=metadata.FIMWorkbenchAxes;
single=fimwb.exportModels(model,fullfile(folder,'single'),axes,'single');
campaign=fimwb.exportModels(model,fullfile(folder,'campaign'),axes,'campaign');
assert(single.completed==3 && single.failed==0 && campaign.completed==4 && campaign.failed==0);
errors=error;values=numel(reference.Data);
for kind={'single','campaign'}
    directory=fullfile(folder,kind{1});rows=readtable(fullfile(directory,'models.csv'),'Delimiter',',','TextType','string','ReadVariableNames',true);
    for k=1:height(rows)
        file=fullfile(directory,rows.model(k));w=fimwb.editor(file,'off');[~,name]=fileparts(file);
        g=findall(w,'Tag','faultTable');faults=g.Data;
        bias=0;if faults{1,4},bias=str2double(faults{1,5});end
        gain=1;if faults{46,4},gain=str2double(faults{46,5});end
        errors(end+1)=compare(reference,observe(name),bias,gain); %#ok<AGROW>
        values=values+numel(reference.Data);delete(w);close_system(name,0);
    end
end
assert(max(errors)<1e-12 && strcmp(sourceHash,fimwb.fileHash(source)));
result=table(46,single.completed,campaign.completed,values,max(errors),'VariableNames', ...
    {'editable_slots','single_models','campaign_models','compared_values','max_abs_error'});
writetable(result,fullfile(folder,'summary.csv'));
delete(win);close_system(model,0);delete(app);
fprintf('DESKTOP_AECS_PASS %d values %.12g max error\n',values,max(errors));
end

function v=observe(model)
rng(0,'twister');
out=sim(model,'ReturnWorkspaceOutputs','on','SignalLogging','on','SignalLoggingName','checked','DatasetSignalFormat','timeseries');
v=out.checked.getElement('s2').Values;
end
function error=compare(base,actual,bias,gain)
assert(isequal(base.Time,actual.Time));
expected=double(base.Data);active=base.Time>=1 & base.Time<1.05;
expected(active)=(expected(active)+bias*0.000325)*gain;
error=max(abs(expected-double(actual.Data)),[],'all');
end
function click(win,tag)
button=findall(win,'Tag',tag);feval(button.ButtonPushedFcn,button,[]);
end
function select(grid,row)
feval(grid.CellSelectionCallback,grid,struct('Indices',[row 3]));
end
function edit(grid,row,col,value)
data=grid.Data;data{row,col}=value;grid.Data=data;feval(grid.CellEditCallback,grid,struct('Indices',[row col]));
end
