function upgradeMeasurement(model)
% The published F16 observation source in 1.0.0 calls a renamed helper.
block=getSimulinkBlockHandle([model '/Measurement']);
if block~=-1 && strcmp(get_param(block,'BlockType'),'FromWorkspace') && ...
        strcmp(get_param(block,'VariableName'),'grfi_f16_measurement()')
    root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
    addpath(fullfile(root,'benchmarks'));
    set_param(block,'VariableName','fimwb_f16_measurement()');
end
end
