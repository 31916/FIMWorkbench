function s=benchTrace(ts)
t=double(ts.Time(:));v=ts.Data;
if ~ts.IsTimeFirst && ndims(v)>1,v=permute(v,[ndims(v) 1:ndims(v)-1]);end
values=reshape(double(v),numel(t),[]);
assert(~isempty(t)&&all(isfinite(t))&&all(isfinite(values),'all'),'Invalid or empty trace.');
s=struct('time',t,'values',values,'type',class(ts.Data));
end
