function idx = ismember(obj, ts)

% Copyright 2020-2021 The MathWorks, Inc.

if ~isa(ts, 'iiasa.IIASATimeseries')
    error('ts must be a IIASATimeseries object')
end

idx = false(numel(ts), 1);

numNew = numel(ts);
numOld = numel(obj);

for i = 1 : numNew
    
    for j = 1 : numOld
        
        if isequal(ts(i), obj(j))
            
            idx(i) = true;
            break
            
        end
        
    end
    
end


end