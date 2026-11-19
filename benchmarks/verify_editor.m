function verify_editor(outputCsv)
%VERIFY_EDITOR Exercise the real desktop controls on each verified all-sites copy.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
ids={'AT','AFC','NN','CC','SC','PM','SB1','SB2','SB3','SB4','SB5','F16'};
scratch=tempname;mkdir(scratch);guard=onCleanup(@()rmdir(scratch,'s')); %#ok<NASGU>
old=pwd;loc=onCleanup(@()cd(old));cd(scratch); %#ok<NASGU>
row=struct('model',{},'editable_slots',{},'saved_slot',{},'max_error',{},'paired_values',{},'paired_max_error',{});
for k=1:numel(ids)
    id=ids{k};suite=fullfile(root,'verification','arch2026',id);
    r=jsondecode(fileread(fullfile(suite,'result.json')));
    before=load(fullfile(suite,'traces.mat'),'baseline','u');
    [fig,file]=fimwb.openBenchmark(id,fullfile(scratch,id),'off');
    [~,name]=fileparts(file);closeBoth=onCleanup(@()closeUI(fig,name));
    grid=findall(fig,'Type','uitable');
    assert(size(grid.Data,1)==r.compatible,'The editor is missing verified fault slots.');
    slot=find(strcmp(grid.Data(:,2),r.sink_site));
    assert(isscalar(slot)&&~grid.Data{slot,4},'Wrong starting slot.');
    % Changing the type twice also checks that the default value is refreshed.
    feval(grid.CellSelectionCallback,grid,struct('Indices',[slot 3]));
    picker=findall(fig,'Tag','faultTypePicker');
    for kind={'gain','bias'}
        picker.Value=kind{1};feval(picker.ValueChangedFcn,picker,[]);
    end
    editCell(grid,slot,4,true);editCell(grid,slot,5,'2');
    status=findall(fig,'Tag','status');
    assert(grid.Data{slot,4}&&strcmp(grid.Data{slot,5},'2'),'Cannot activate %s: %s',id,status.Text);
    editCell(grid,slot,5,'invalid');assert(strcmp(grid.Data{slot,5},'2'),'Bad edit was not rejected.');
    actual=benchSim(name,r.horizon,before.u,false,true);
    s=jsondecode(fileread(fullfile(suite,'sites.json')));idx=find(strcmp({s.id},r.sink_site));
    dst=[name '/' s(idx).destinations.path];port=str2double(get_param(dst,'Port'));
    check=benchCompare(before.baseline,actual,port,2,1,'editor_on');
    search=findall(fig,'Tag','siteSearch');search.Value=r.sink_site;
    feval(search.ValueChangedFcn,search,[]);assert(size(grid.Data,1)==1 && grid.Data{1,1}==slot);
    feval(grid.CellSelectionCallback,grid,struct('Indices',[1 3]));
    assert(isequal(sort(string(picker.Items(:))),sort(string(s(idx).faults(:)))));
    show=findall(fig,'Tag','highlightSite');feval(show.ButtonPushedFcn,show,[]);
    assert(strcmp(status.Text,grid.Data{1,10}),'Highlight failed for %s: %s',id,status.Text);
    search.Value='no matching site!';feval(search.ValueChangedFcn,search,[]);assert(isempty(grid.Data));
    search.Value='';feval(search.ValueChangedFcn,search,[]);
    paired=fimwb.experiment(name,fullfile(scratch,id,'comparison'));
    normal=checkCsv(paired.baseline,before.baseline);
    faulty=checkCsv(fullfile(paired.folder,'case_0001.csv'),actual);
    button=findall(fig,'Tag','saveModel');feval(button.ButtonPushedFcn,button,[]);
    stages=find_system(name,'SearchUnderMasks','all','Tag',sprintf('fimwb.fault.%d',grid.Data{slot,1}));path=stages{1};
    close_system(name,0);load_system(file);metadata=get_param(path,'UserData');
    assert(metadata.fault.enabled&&metadata.fault.value==2&&strcmp(metadata.fault.type,'bias'),'Edit was not persisted.');
    row(end+1)=struct('model',id,'editable_slots',size(grid.Data,1),'saved_slot',slot,'max_error',check.max_abs_error, ...
        'paired_values',normal(1)+faulty(1),'paired_max_error',max(normal(2),faulty(2))); %#ok<AGROW>
    fprintf('EDITOR_PASS %s %d controls\n',id,size(grid.Data,1));clear closeBoth
end
writetable(struct2table(row),outputCsv);
end
function editCell(grid,row,column,v)
d=grid.Data;d{row,column}=v;grid.Data=d;feval(grid.CellEditCallback,grid,struct('Indices',[row column]));
end
function closeUI(fig,name)
if isvalid(fig),delete(fig);end
if bdIsLoaded(name),close_system(name,0);end
end

function counts=checkCsv(file,expected)
rows=readtable(file,'TextType','string');
count=0;worst=0;
for port=1:numel(expected)
    trace=expected{port};
    data=rows(startsWith(rows.signal,string(port)+"/"),:);
    for component=1:size(trace.values,2)
        part=data(data.component==component,:);
        assert(numel(part.time_s)==numel(trace.time) && all(abs(part.time_s-trace.time)<=1e-12*max(1,abs(trace.time))));
        error=abs(part.value-trace.values(:,component));
        assert(all(error<=1e-11*max(1,abs(trace.values(:,component)))) && all(part.imaginary==0));
        count=count+height(part);worst=max(worst,max(error));
    end
end
assert(count==height(rows));counts=[count,worst];
end
