function verify_fault_chains(folder)
%VERIFY_FAULT_CHAINS Preserve stem and branch routing when adding and removing.
assert(~isfolder(folder));mkdir(folder);
source=fullfile(folder,'chain_source.slx');model='chain_working';
new_system('chain_source');
add_block('built-in/Constant','chain_source/Input','Value','3');
add_block('built-in/Gain','chain_source/Scale','Gain','2');
add_block('built-in/Outport','chain_source/First');
add_block('built-in/Outport','chain_source/Second');
add_line('chain_source','Input/1','Scale/1');add_line('chain_source','Scale/1','First/1');
add_line('chain_source','Input/1','Second/1');
set_param('chain_source','Solver','FixedStepDiscrete','FixedStep','0.1','StopTime','1');
save_system('chain_source',source);close_system('chain_source',0);
file=fullfile(folder,[model '.slx']);fimwb.build(source,file);win=fimwb.editor(file,'off');
rows=findall(win,'Tag','faultTable').Data;
sites=fimwb.scan(source);
stem=sites(strcmp({sites.kind},'stem') & strcmp({sites.source},'Input'));
branch=sites(arrayfun(@(s)strcmp(s.kind,'endpoint') && strcmp(s.source,'Input') && strcmp(s.destinations.path,'Scale'),sites));
stemSlot=rows{strcmp(rows(:,2),stem.id),1};branchSlot=rows{strcmp(rows(:,2),branch.id),1};
check(model,[6 3]);
fimwb.setFault(model,stemSlot,struct('enabled',true,'value',1));
fimwb.setFault(model,branchSlot,struct('type','gain','enabled',true,'value',2));
check(model,[16 4]);
addedStem=fimwb.addFault(model,stemSlot);
fimwb.setFault(model,addedStem,struct('type','negate','enabled',true));
check(model,[-16 -4]);
addedBranch=fimwb.addFault(model,branchSlot);
fimwb.setFault(model,addedBranch,struct('type','bias','enabled',true,'value',5));
check(model,[-6 -4]);
fimwb.removeFault(model,addedStem);check(model,[26 4]);
fimwb.removeFault(model,branchSlot);check(model,[18 4]);
save_system(model);delete(win);close_system(model,0);
win=fimwb.editor(file,'off');check(model,[18 4]);delete(win);close_system(model,0);
disp('FAULT_CHAINS_PASS');
end

function check(model,expected)
out=sim(model,'SaveOutput','on','OutputSaveName','checked','SaveFormat','Dataset','ReturnWorkspaceOutputs','on');
for k=1:numel(expected),assert(all(out.checked{k}.Values.Data==expected(k),'all'));end
end
