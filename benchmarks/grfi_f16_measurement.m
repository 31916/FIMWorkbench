function data=grfi_f16_measurement()
% Evaluate the official ODE with the project's release compatibility adapter.
% Only its published scalar measurement is exposed as a Simulink signal.
root=fileparts(fileparts(mfilename('fullpath')));
assets=fullfile(root,'verification','sources');
compat=fullfile(assets,'compat_f16');
if ~isfolder(compat),compat=fullfile(fileparts(root),'Falsify','arch2025_compat','f16');end
flags=warning;oldPath=path;
reset=onCleanup(@() restore(flags,oldPath)); %#ok<NASGU>
warning('off','all');addpath(compat);
[t,y]=run_arch2025_f16_compat(fullfile(assets,'ARCH','f16-gcas'),4040,540,.24*pi,-.375*pi,-.25*pi,15);
data=[double(t(:)),double(y(:))];
assert(size(data,1)>1 && all(isfinite(data),'all') && abs(data(end,1)-15)<1e-10);
end

function restore(flags,p)
warning(flags);path(p);
end
