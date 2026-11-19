function digest = fileHash(file)
%FILEHASH SHA-256 of the source bytes for matching a configuration to a model.
fid=fopen(file,'rb');assert(fid>=0,'Cannot open %s',file);
closeFile=onCleanup(@() fclose(fid)); %#ok<NASGU>
md=java.security.MessageDigest.getInstance('SHA-256');
while ~feof(fid),md.update(fread(fid,65536,'*uint8'));end
digest=lower(reshape(dec2hex(typecast(md.digest(),'uint8'),2).',1,[]));
end
