function root = benchmarkFolder(id,checkout)
%BENCHMARKFOLDER Locate a benchmark, or remember a checkout containing its data.
% fimwb.benchmarkFolder('AT','/path/to/FIMWorkbench') configures the add-on.
id=upper(char(id));
assert(ismember(id,{'AT','AFC','NN','CC','SC','PM','F16','SB1','SB2','SB3','SB4','SB5'}),'Unknown benchmark.');
installed=fileparts(fileparts(mfilename('fullpath')));
if nargin==2
    [ok,a]=fileattrib(checkout);assert(ok&&a.directory,'Choose the extracted FIM Workbench folder.');
    root=a.Name;
    if ~hasModel(root,id)
        error('fimwb:BenchmarkFolder','The selected folder needs verification/all_sites/%s and verification/sources.',id);
    end
    setpref('FIMWorkbench','BenchmarkFolder',root);
    return
end
if hasModel(installed,id),root=installed;return;end
for candidate={getpref('FIMWorkbench','BenchmarkFolder',''),pwd}
    if ~isempty(candidate{1}) && hasModel(candidate{1},id),root=candidate{1};return;end
end
error('fimwb:BenchmarkFolder','Choose the extracted FIM Workbench source checkout containing verification/all_sites/%s.',id);
end

function found=hasModel(root,id)
found=isfolder(fullfile(root,'verification','all_sites',id)) && isfolder(fullfile(root,'verification','sources'));
end
