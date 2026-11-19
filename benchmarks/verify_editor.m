function verify_editor(outputCsv)
%VERIFY_EDITOR Exercise the real desktop controls on each verified all-sites copy.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
ids={'AT','AFC','NN','CC','SC','PM','SB1','SB2','SB3','SB4','SB5','F16'};
scratch=tempname;mkdir(scratch);guard=onCleanup(@()rmdir(scratch,'s')); %#ok<NASGU>
old=pwd;loc=onCleanup(@()cd(old));cd(scratch); %#ok<NASGU>
row=struct('model',{},'editable_slots',{},'saved_slot',{},'max_error',{});
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
    editCell(grid,slot,3,'gain');editCell(grid,slot,3,'bias');
    editCell(grid,slot,4,true);editCell(grid,slot,5,'2');
    status=findall(fig,'Type','uilabel');
    assert(grid.Data{slot,4}&&strcmp(grid.Data{slot,5},'2'),'Cannot activate %s: %s',id,status.Text);
    editCell(grid,slot,5,'invalid');assert(strcmp(grid.Data{slot,5},'2'),'Bad edit was not rejected.');
    actual=benchSim(name,r.horizon,before.u,false,true);
    s=jsondecode(fileread(fullfile(suite,'sites.json')));idx=find(strcmp({s.id},r.sink_site));
    dst=[name '/' s(idx).destinations.path];port=str2double(get_param(dst,'Port'));
    check=benchCompare(before.baseline,actual,port,2,1,'editor_on');
    button=findall(fig,'Type','uibutton');feval(button.ButtonPushedFcn,button,[]);
    stages=find_system(name,'SearchUnderMasks','all','Tag',sprintf('fimwb.fault.%d',grid.Data{slot,1}));path=stages{1};
    close_system(name,0);load_system(file);metadata=get_param(path,'UserData');
    assert(metadata.fault.enabled&&metadata.fault.value==2&&strcmp(metadata.fault.type,'bias'),'Edit was not persisted.');
    row(end+1)=struct('model',id,'editable_slots',size(grid.Data,1),'saved_slot',slot,'max_error',check.max_abs_error); %#ok<AGROW>
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
