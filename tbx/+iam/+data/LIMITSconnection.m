classdef LIMITSconnection < iam.data.Connection
    
    % Copyright 2021-2022 The MathWorks, Inc.
    
    properties (Dependent)
        Environment
    end
    
    properties (SetAccess = private)
        File (1,1) string
        TimeseriesList
    end
    
    properties (SetAccess = private)
        Config struct = struct( ...
            'name', "LIMITS", 'env', "limits",'productName', "LIMITS", ...
            'database', "LIMITS", "welcome", "Welcome to the LIMITS Database");
        
        ConnectionProperties
    end
    
    properties (Constant, Access = private)
       YEARS = [2005:5:2050,2060:10:2100]; 
       ENVIRONMENT = "LIMITS";
    end
    
    properties
        AllEnvironments
    end
    
    methods
        
        function obj = LIMITSconnection(excelFile)
            
            if isfile(excelFile)
                obj.File = iam.utils.GetFullPath(excelFile);
                
%                 obj.ImportOptions = delimitedTextImportOptions("NumVariables", 20);
                
                opts = detectImportOptions(obj.File, 'TextType', 'string', 'ReadVariableNames', true, 'Range', 'A:E');
                
                rl = readtable(excelFile, opts);
                runId = ones(height(rl), 1);
                count = 1;
                model = rl.MODEL;
                scenario = rl.SCENARIO;
                for i = 2 : height(rl)
                    if ~(model(i) == model(i-1) && scenario(i) == scenario(i-1))
                        count = count + 1;
                    end
                    runId(i) = count;
                end
                rl.run_id = runId;
                obj.TimeseriesList = rl;
                obj.TimeseriesList.Properties.VariableNames = {'model','scenario','region','variable','unit','run_id'};
                % I probably want a caching option here.
            else
                error('iam:data:LIMITSconnection:ExcelDoesNotExist', ...
                    'Unable to find a valid Excel file')
            end
            
        end
        
        function ts = getBulkData(obj, varargin)
            
            p = inputParser();
            
            func = @(x) isstring(x) | ischar(x);
            addParameter(p, 'models', '', func)
            addParameter(p, 'scenarios', '', func)            
            addParameter(p, 'runs', [], @isnumeric)
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
                % Set up the Import Options and import the data
                opts = delimitedTextImportOptions("NumVariables", 20);
                
                % Specify range and delimiter
                DataLines = find(idx)+1;
                opts.DataLines = [DataLines, DataLines];
                opts.Delimiter = ",";
                
                % Specify column names and types
                opts.VariableNames = ["model", "scenario", "region", "variable", "unit", "VarName6", "VarName7", "VarName8", "VarName9", "VarName10", "VarName11", "VarName12", "VarName13", "VarName14", "VarName15", "VarName16", "VarName17", "VarName18", "VarName19", "VarName20"];
                opts.VariableTypes = ["categorical", "categorical", "categorical", "categorical", "categorical", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double", "double"];
                
                % Specify file level properties
                opts.ExtraColumnsRule = "ignore";
                opts.EmptyLineRule = "read";
                
                % Specify variable properties
                opts = setvaropts(opts, ["model","scenario", "region", "variable", "unit"], "EmptyFieldRule", "auto");
                
                % Import the data
                AllValues = readtable("C:\Users\ebenetce\OneDrive - MathWorks\AEProjects\Climate\iam-explorer\examples\LIMITSPUBLIC_2014-10-13.csv", opts);
                
                years = obj.YEARS;
                
                tb = AllValues(:,1:5);
                AllValues = AllValues{:,6:end};
                
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
                        
                        values = AllValues(i,:);
                        values = values(~isnan(values));
                        nonEmpty = numel(values);
                        varName = string(variables(i));
                        
                        data(num).model    = models(i);
                        data(num).scenario = scenarios(i);
                        data(num).variable = varName;
                        data(num).region   = regions(i);
                        data(num).runID    = obj.TimeseriesList{i,'run_id'};
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
                
                ts = iam.IAMTimeseries(data);
                
            else
                ts = iam.IAMTimeseries.empty();
            end
        end
        
        function params = getRunDetails(obj, runId)
            idx = obj.TimeseriesList.run_id == runId;
            params = obj.TimeseriesList.variable(idx);            
        end
        
        function refs = getRefs(obj)
            
            models = obj.getAllModels;
            ID = (1 : numel(models))';
            Name = models;
            refs.models = table(ID,Name);
            
            scenarios = obj.getAllScenarios;
            ID = (1 : numel(scenarios))';
            Name = scenarios;
            refs.scenarios = table(ID,Name); 
            
            vars = unique(obj.TimeseriesList.variable);
            ID = (1 : numel(vars))';
            Name = vars;
            refs.variables = table(ID,Name);
            
            reg = unique(obj.TimeseriesList.region);
            ID = (1 : numel(reg))';
            Name = reg;
            refs.regions = table(ID,Name);
            
        end
        
        function runs = getRunsList(obj)
            [~, filteredList, ~] = unique(obj.TimeseriesList.run_id);
            runs = obj.TimeseriesList(filteredList, :);            
        end
        
         function value = getDocumentation(obj, type, idx)
            
             value = struct('description','Please visit the <a href="https://tntcat.iiasa.ac.at/LIMITSDB/dsd?Action=htmlpage&page=about#cpy" target="_blank">official LIMITS Website</a> for details ');
            
         end
        
    end
    
    methods
        function value = get.Environment(obj)
            value = obj.ENVIRONMENT;
        end
        
        function response = getAllModels(obj)            
            response = unique(obj.TimeseriesList.model);            
        end
        
        function response = getAllScenarios(obj)            
            response = unique(obj.TimeseriesList.scenario);            
        end 
        
        function value = getEnvironments(obj)
            productName = obj.Config.productName;
            env = obj.Config.env;
            uiUrl = obj.File;
            name = obj.Config.name;
            scheme = "";
            
            value = table(productName, env, uiUrl, name, scheme);
        end
        
    end
         
end