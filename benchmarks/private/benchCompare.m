function check=benchCompare(reference,actual,index,bias,gain,tag)
assert(numel(reference)==numel(actual),'Output count changed.');
err=0;delta=0;points=0;
for j=1:numel(reference)
    a=reference{j};b=actual{j};
    assert(isequal(a.time,b.time)&&isequal(size(a.values),size(b.values)),...
        'Different sampling grid or output shape (%s, output %d).',tag,j);
    expected=a.values;
    if j==index
        first=cast(expected+bias,a.type);
        expected=double(cast(double(first)*gain,a.type));
        delta=max(abs(expected-a.values),[],'all');
    end
    e=abs(b.values-expected);err=max(err,max(e,[],'all'));points=points+numel(e);
    tol=2e-10;if strcmp(a.type,'single'),tol=4e-6;end
    assert(all(e<=tol.*(1+abs(expected)),'all'),...
        'Wrong fault response (%s, output %d, maximum absolute error %.9g).',tag,j,max(e,[],'all'));
end
if bias~=0 || gain~=1,assert(delta>1e-6,'Test did not excite the selected fault (%s).',tag);end
check=struct('name',tag,'samples_compared',points,'max_abs_error',err,'fault_change',delta);
end

