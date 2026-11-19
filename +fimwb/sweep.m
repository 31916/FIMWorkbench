function results = sweep(modelFile,profiles,outputDir,indices)
%SWEEP Publish each single-fault model together with its configuration and hash.
cases=fimwb.plan(modelFile,profiles);
if nargin<4,indices=1:numel(cases);end
assert(isnumeric(indices)&&all(ismember(indices,1:numel(cases)))&&numel(unique(indices))==numel(indices),'Invalid case selection.');
if ~isfolder(outputDir),mkdir(outputDir);end
[~,a]=fileattrib(outputDir);outputDir=a.Name;
[~,source,ext]=fileparts(modelFile);sourceHash=fimwb.fileHash(modelFile);
results=repmat(struct('index',0,'fault',[],'file','','status','','error',''),numel(indices),1);
for n=1:numel(indices)
    k=indices(n);f=cases(k);
    config=struct('sourceSha256',sourceHash,'faults',f);
    md=java.security.MessageDigest.getInstance('SHA-256');
    md.update(unicode2native(jsonencode(config),'UTF-8'));
    hash=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
    model=['fi_' source(1:min(end,34)) '_' hash(1:20)];target=fullfile(outputDir,model);
    name=[model ext];file=fullfile(target,name);
    results(n).index=k;results(n).fault=f;results(n).file=file;
    try
        if isfolder(target)
            verify(target,name,hash);result='reused';
        else
            scratch=tempname(outputDir);mkdir(scratch);
            clean=onCleanup(@() removeTemporary(scratch));
            fimwb.build(modelFile,config,fullfile(scratch,name));
            record=struct('configuration_sha256',hash,'model_sha256',fimwb.fileHash(fullfile(scratch,name)));
            write(fullfile(scratch,'configuration.json'),config);write(fullfile(scratch,'receipt.json'),record);
            try
                java.nio.file.Files.move(java.io.File(scratch).toPath(),java.io.File(target).toPath(),javaArray('java.nio.file.CopyOption',0));
                result='compiled';
            catch err
                if ~isfolder(target),rethrow(err);end
                verify(target,name,hash);result='reused';
            end
            clear clean
        end
        results(n).status=result;
    catch err
        if exist('clean','var'),clear clean;end
        results(n).status='failed';results(n).error=err.message;
    end
end
end

function verify(folder,name,expected)
r=jsondecode(fileread(fullfile(folder,'receipt.json')));
cfg=jsondecode(fileread(fullfile(folder,'configuration.json')));
md=java.security.MessageDigest.getInstance('SHA-256');md.update(unicode2native(jsonencode(cfg),'UTF-8'));
actual=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
assert(strcmp(actual,expected)&&strcmp(r.configuration_sha256,expected)&&strcmp(r.model_sha256,fimwb.fileHash(fullfile(folder,name))),...
    'Saved configuration or model differs from its receipt: %s',folder);
end
function write(file,data)
fid=fopen(file,'w','n','UTF-8');assert(fid>=0);c=onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(data));
end
function removeTemporary(folder)
if isfolder(folder),rmdir(folder,'s');end
end
