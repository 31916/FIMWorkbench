function writeConfiguration(file,data)
[folder,~,~]=fileparts(file);
if isempty(folder),folder=pwd;end
temporary=tempname(folder);cleanup=onCleanup(@()discard(temporary));
[fid,msg]=fopen(temporary,'w','n','UTF-8');assert(fid>=0,'%s',msg);
closeFile=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(data,'PrettyPrint',true));
clear closeFile
[ok,msg]=movefile(temporary,file,'f');assert(ok,'%s',msg);
end

function discard(file)
if isfile(file),delete(file);end
end
