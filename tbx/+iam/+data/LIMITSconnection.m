classdef LIMITSconnection < matlab.mixin.SetGet
    
    % Copyright 2021-2022 The MathWorks, Inc.
    
    properties (SetAccess = private)
        ExcelFile (1,1) string
    end
    
    properties (Constant)
        Environment = "LIMITS"
    end
    
    properties
        TimeseriesList (:,6) table
    end
    
    properties (Constant)
        Config struct = struct( ...
            'name', "LIMITS", 'env', "limits",'productName', "LIMITS", ...
            'database', "LIMITS", "welcome", "Welcome to the LIMITS Database");
    end
    
    properties
        AllEnvironments
    end
    
    methods
        
        function obj = LIMITSconnection(excelFile)
            
            if isfile(excelFile)
                obj.ExcelFile = excelFile;
                opts = detectImportOptions(obj.ExcelFile, 'TextType', 'string', 'ReadVariableNames', true, 'Range', 'A:E');
                
                rl = readtable(excelFile, opts);
                rl.run_id = ones(height(rl), 1);
                count = 1;
                model = rl.MODEL;
                scenario = rl.SCENARIO;
                for i = 2 : height(rl)
                    if ~(model(i) == model(i-1) && scenario(i) == scenario(i-1))
                        count = count + 1;
                    end
                    rl.run_id(i) = count;
                end
                obj.TimeseriesList = rl;
                obj.TimeseriesList.Properties.VariableNames = {'model','scenario','region','variable','unit','run_id'};
                obj.getAllEnvironments();
            else
                error('iam:data:LIMITSconnection:ExcelDoesNotExist', ...
                    'Unable to find a valid Excel file')
            end
            
        end
        
    end
    
    methods %(Access = ?iam.IAMEnvironment)
        
        function value = getEnvironmentConfig(obj)
            value = obj.Config;
        end
        
        function params = getRunDetails(obj, runId)
            
            params = obj.getAllVariables();
            
        end
        
        function value = getEnvironments(obj)
            value = obj.AllEnvironments;
        end
        
        function getAllEnvironments(obj)
            
            productName = obj.Config.productName;
            env = obj.Config.env;
            uiUrl = obj.ExcelFile;
            name = obj.Config.name;
            scheme = "";
            
            tb = table(productName, env, uiUrl, name, scheme);
            
            obj.AllEnvironments = tb;
            
        end
        
        function data = getCurrentData(obj, varargin)
            data = obj.getBulkData('models',obj.Model, 'scenarios', obj.Scenario, varargin{:});
        end
        
        function ref = getRefs(obj)
            
            refsID = cell(2,1);
            refsID{1,1} = 'ID';
            refsID{2,1} = 'Name';
            refsID = {refsID};
            ref.models = [refsID; arrayfun(@(a,b) {a;b}, 1:length(obj.getAllModels), obj.getAllModels', 'UniformOutput', false)'];
            
            ref.scenarios = [refsID; arrayfun(@(a,b) {a;b}, 1:length(obj.getAllScenarios), obj.getAllScenarios', 'UniformOutput', false)'];
            vars = unique(obj.TimeseriesList.variable);
            ref.variables = [refsID; arrayfun(@(a,b) {a;b}, 1:length(vars), vars', 'UniformOutput', false)'];
            reg = unique(obj.TimeseriesList.region);
            ref.regions = [refsID; arrayfun(@(a,b) {a;b}, 1:length(reg), reg', 'UniformOutput', false)'];
        end
        
        function data = getBulkData(obj, varargin)
            
            p = inputParser();
            
            func = @(x) isstring(x) | ischar(x);
            addParameter(p, 'runs', [], @isnumeric)
            addParameter(p, 'models', '', func)
            addParameter(p, 'scenarios', '', func)
            addParameter(p, 'variables', '', func)
            addParameter(p, 'regions', '', func)
            addParameter(p, 'years', '', func)
            addParameter(p, 'units', '', func)
            addParameter(p, 'timeslices', '', func)
            
            parse(p, varargin{:});
            
            idx = true(height(obj.TimeseriesList), 1);
            if ~isempty(p.Results.models)
                idx = idx & ismember(obj.TimeseriesList.model, p.Results.models);
            end
            
            if ~isempty(p.Results.scenarios)
                idx = idx & ismember(obj.TimeseriesList.scenario, p.Results.scenarios);
            end
            
            if ~isempty(p.Results.runs)
                idx = idx & ismember(obj.TimeseriesList.run_id, p.Results.runs);
            end
            
            if ~isempty(p.Results.variables)
                idx = idx & ismember(obj.TimeseriesList.variable, p.Results.variables);
            end
            
            if ~isempty(p.Results.regions)
                idx = idx & ismember(obj.TimeseriesList.region, p.Results.regions);
            end
            
            if nnz(idx) ~= 0
                
                years = readmatrix('LIMITSPUBLIC_2014-10-13.csv', 'Range', 'F1:AB1');
                
                AllValues = readmatrix(obj.ExcelFile, 'Range', 'F2');
                tb = obj.TimeseriesList(idx, :);
                data = struct.empty();
                if ~isempty(tb)
                    
                    num = 1;
                    data = struct([]);
                    
                    models    = tb.model;
                    scenarios = tb.scenario;
                    regions   = tb.region;
                    unit      = tb.unit;
                    variables = tb.variable;
                    
                    for i = 1 : height(tb)
                        
                        values = AllValues(i,6:end);
                        values = values(~isnan(values));
                        nonEmpty = numel(values);
                        varName = variables(i);
                        
                        data(num).model    = models(i);
                        data(num).scenario = scenarios(i);
                        data(num).variable = varName;
                        data(num).region   = regions(i);
                        data(num).runID    = [];
                        data(num).version  = [];
                        data(num).unit     = unit(i);
                        data(num).years    = years(1:nonEmpty);
                        
                        if strlength(varName) >= 60
                            varName = extractBetween(varName,1, 59);
                        end
                        
                        data(num).values = timetable( ...
                            datetime(years(1:nonEmpty),1,1,'Format', 'yyyy')', ...
                            values(1:nonEmpty)', ...
                            'DimensionNames', {'Year', 'VariableUnits'}, ...
                            'VariableNames', varName);
                        
                        num = num + 1;
                        
                    end
                end
                
                data = iam.IAMTimeseries(data);
                
            else
                data = iam.IAMTimeseries.empty();
            end
            
            
        end
        
        function response = getAllModels(obj)
            
            response = unique(obj.TimeseriesList.model);
            
        end
        
        function response = getAllScenarios(obj)
            
            response = unique(obj.TimeseriesList.scenario);
            
        end
        
        function response = getAllVariables(obj)
            
            response = unique(obj.TimeseriesList.variable);
            
        end
        
        function runs = getRunsList(obj)
            
            runs = obj.TimeseriesList;
            
        end
        
    end
    
    methods (Access = private)
        
        function getEnvConfig(obj, env)
            
            url = strjoin([obj.Auth_Url, "config/user", env.name], "/");
            
            env_config = obj.getRequest(url);
            env_config = env_config.records;
            
            p = {env_config.path};
            sel = @(x) strcmp(x, p);
            obj.Config = struct(...
                'name', env.name, ...
                'scheme', env.scheme, ...
                'env', env.env, ...
                'productName', env.productName, ...
                'uiUrl', env.uiUrl, ...
                'authUrl', env_config(sel('authUrl')).value, ...
                'baseUrl', env_config(sel('baseUrl')).value, ...
                'database', env_config(sel('database')).value);
            try
                obj.Config.welcome = env_config(sel('welcomeMessage')).value;
            catch
                obj.Config.welcome = '';
            end
            
        end
        
    end
    
end