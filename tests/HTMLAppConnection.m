classdef HTMLAppConnection < MockIAMConnection
    properties
        Config = struct("welcome", "Mock IAM environment")
        AllEnvironments = table("mock", "mock", ...
            VariableNames=["env","productName"])
    end

    methods
        function obj = HTMLAppConnection(varargin)
            obj@MockIAMConnection(varargin{:});
        end

        function data = getBulkData(obj, varargin)
            data = getBulkData@MockIAMConnection(obj, varargin{:});
            frame = iam.IAMFrame(data);
            request = obj.BulkDataRequest;
            frame = frame.filter(runs=request.runs, variables=request.variables, ...
                regions=request.regions, strict=true);
            data = frame.toTimeseries();
        end

        function names = getRunDetails(obj, ~)
            names = obj.Refs.variables.Name;
        end
    end
end
