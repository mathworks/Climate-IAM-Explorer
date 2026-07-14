classdef MockIAMConnection < iam.data.Connection

    properties (Dependent)
        Environment
    end

    properties
        EnvironmentValue (1,1) string = "mock"
        Refs struct = struct()
        Runs table = table()
        MetadataCategories table = table()
        BulkDataRequest struct = struct()
        BulkDataResponse = []
    end

    properties (SetAccess = private)
        ConnectionProperties = struct()
    end

    methods
        function obj = MockIAMConnection(varargin)
            if nargin > 0
                set(obj, varargin{:});
            end
        end

        function set.Environment(obj, value)
            obj.EnvironmentValue = string(value);
        end

        function value = get.Environment(obj)
            value = obj.EnvironmentValue;
        end

        function ts = getBulkData(obj, varargin)
            p = inputParser();
            addParameter(p, 'runs', [])
            addParameter(p, 'variables', [])
            addParameter(p, 'regions', [])
            addParameter(p, 'years', [])
            addParameter(p, 'units', [])
            addParameter(p, 'timeslices', [])
            parse(p, varargin{:});

            obj.BulkDataRequest = p.Results;
            if isempty(obj.BulkDataResponse)
                ts = obj.BulkDataRequest;
            else
                ts = obj.BulkDataResponse;
            end
        end

        function params = getRunDetails(~, ~)
            params = string.empty(0,1);
        end

        function refs = getRefs(obj)
            refs = obj.Refs;
        end

        function runs = getRunsList(obj)
            runs = obj.Runs;
        end

        function value = getDocumentation(~, ~, ~)
            value = struct('description', "Mock documentation");
        end

        function response = getAllModels(obj)
            if isfield(obj.Refs, 'models')
                response = obj.Refs.models;
            else
                response = table();
            end
        end

        function response = getAllScenarios(obj)
            if isfield(obj.Refs, 'scenarios')
                response = obj.Refs.scenarios;
            else
                response = table();
            end
        end

        function value = getMetadataCategories(obj)
            value = obj.MetadataCategories;
        end

        function value = getMetadataDetails(obj, category)
            idx = matches(obj.MetadataCategories.name, string(category), 'IgnoreCase', true);
            value = struct('type', obj.MetadataCategories.type(find(idx, 1)));
        end
    end
end
