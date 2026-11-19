function output = build_fimworkbench_toolbox(outputFolder)
%BUILD_FIMWORKBENCH_TOOLBOX Build the redistributable add-on from the verified sources.
root=fileparts(fileparts(mfilename('fullpath')));
if nargin<1,outputFolder=fullfile(fileparts(root),'outputs');end
if ~isfolder(outputFolder),mkdir(outputFolder);end
[ok,info]=fileattrib(outputFolder);assert(ok);outputFolder=info.Name;
release="2.1.0";
output=fullfile(outputFolder,"FIMWorkbench-"+release+".mltbx");
stage=tempname;
mkdir(fullfile(stage,'verification'));
cleanup=onCleanup(@()rmdir(stage,'s')); %#ok<NASGU>
% Only copy release inputs. Never package a recipient's models or new runs.
for item=["FIMWorkbench.m","README.md","+fimwb","benchmarks","examples", ...
        "verification/all_sites","verification/arch2026","verification/fault_types", ...
        "verification/sources","verification/results.csv","verification/editor.csv","verification/lor.csv"]
    [ok,msg]=copyfile(fullfile(root,item),fullfile(stage,item));assert(ok,'%s',msg);
end
% MLTBX text parts use UTF-8. Transcode legacy upstream text before packaging
% so that the author's name survives the native writer's UTF-8 conversion.
lock=jsondecode(fileread(fullfile(root,'benchmarks','source-lock.json')));
for entry=reshape(lock.legacy_text,1,[])
    file=fullfile(stage,'verification','sources',entry.path);
    content=fileread(file,'Encoding',entry.encoding);
    [fid,msg]=fopen(file,'w','n','UTF-8');assert(fid~=-1,'%s',msg);
    writer=onCleanup(@()fclose(fid));
    fprintf(fid,'%s',content);clear writer
end
entries=dir(fullfile(stage,'**','*'));entries=entries(~[entries.isdir]);
files=fullfile(string({entries.folder}'),string({entries.name}'));
launcher=fullfile(stage,'FIMWorkbench.m');
% Keep the identifier across releases so MATLAB recognizes updates.
opts=matlab.addons.toolbox.ToolboxOptions(stage,"f8182e0c-2ba3-4033-89d4-2c82c5d7ed84", ...
    ToolboxFiles=files,ToolboxMatlabPath=string(stage),AppGalleryFiles=string(launcher));
opts.ToolboxName="FIM Workbench";
opts.ToolboxVersion=release;
opts.AuthorName="31916";
opts.Summary="FIMの全15種類の信号故障・演算子置換をSimulinkモデルに注入し、故障ごとにON/OFF・値・適用時間を設定できます。";
opts.Description="インストール後に「アプリ」タブで FIMWorkbench を開くか、同名のコマンドを実行してください。"+ ...
    "ARCH-COMP 2026の12モデルを同梱。MATLABとSimulinkが必要です。モデルによってはStateflow、Deep Learning Toolboxなども使用します。";
opts.MinimumMatlabRelease="R2026a";
opts.OutputFile=output;
matlab.addons.toolbox.packageToolbox(opts);
end
