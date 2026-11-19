function output = build_fimworkbench_toolbox(outputFolder)
%BUILD_FIMWORKBENCH_TOOLBOX Build the redistributable add-on from the verified sources.
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<1,outputFolder=fullfile(fileparts(root),'outputs');end
if ~isfolder(outputFolder),mkdir(outputFolder);end
[ok,info]=fileattrib(outputFolder);assert(ok);outputFolder=info.Name;
release="2.2.0";
output=fullfile(outputFolder,"FIMWorkbench-"+release+".mltbx");
stage=tempname;
mkdir(fullfile(stage,'verification'));
cleanup=onCleanup(@()rmdir(stage,'s')); %#ok<NASGU>
% Only copy release inputs. Never package a recipient's models or new runs.
for item=["FIMWorkbench.m","README.md","LICENSE","THIRD_PARTY.md","+fimwb","benchmarks","examples","study", ...
        "verification/all_sites/PM","verification/arch2026/PM","verification/sources/PM", ...
        "verification/results.csv","verification/editor.csv","verification/lor.csv","verification/campaign.csv","verification/arch_campaign.csv","verification/fim_comparison.csv"]
    dest=fullfile(stage,item);
    if ~isfolder(fileparts(dest)),mkdir(fileparts(dest));end
    [ok,msg]=copyfile(fullfile(root,item),dest);assert(ok,'%s',msg);
end
entries=dir(fullfile(stage,'**','*'));entries=entries(~[entries.isdir]);
files=fullfile(string({entries.folder}'),string({entries.name}'));
launcher=fullfile(stage,'FIMWorkbench.m');
% Keep the identifier across releases so MATLAB recognizes updates.
opts=matlab.addons.toolbox.ToolboxOptions(stage,"f8182e0c-2ba3-4033-89d4-2c82c5d7ed84", ...
    ToolboxFiles=files,ToolboxMatlabPath=[string(stage);fullfile(string(stage),"study")],AppGalleryFiles=string(launcher));
opts.ToolboxName="FIM Workbench";
opts.ToolboxVersion=release;
opts.AuthorName="31916";
opts.Summary="Inject all 15 FIM signal faults and operator mutations into Simulink models. Set each fault's value and active time window.";
opts.Description="Open FIMWorkbench from the MATLAB Apps tab or the Command Window. "+ ...
    "Compare baseline and fault traces and run factorial campaigns. Includes the PM example and supports all 12 ARCH-COMP Falsification models with a local benchmark checkout. Requires MATLAB and Simulink.";
opts.MinimumMatlabRelease="R2026a";
opts.OutputFile=output;
matlab.addons.toolbox.packageToolbox(opts);
end
