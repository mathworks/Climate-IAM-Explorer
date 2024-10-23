classdef BANKOFCANADAconnection < iam.data.Connection
    
    % Copyright 2021-2022 The MathWorks, Inc.
    
    properties (Dependent)
        Environment
    end
    
    properties (SetAccess = private)
        Url (1,1) string
        TimeseriesList
    end

    properties (Access = private)
        RawData
        IA
        IC
        YEARS
    end
    
    properties (SetAccess = private)
        Config struct = struct( ...
            'name', "BANKOFCANADA", 'env', "boc",'productName', "BANKOFCANADA", ...
            'database', "BANKOFCANADA", "welcome", "Welcome to the BANKOFCANADA IAM Database");
        
        ConnectionProperties
    end
    
    properties (Constant, Access = private)
       ENVIRONMENT = "BANKOFCANADA";
    end
    
    properties
        AllEnvironments
    end
    
    methods
        
        function obj = BANKOFCANADAconnection(url)

            arguments
                url (1,1) string = "https://www.bankofcanada.ca/climate-transition-scenario-data-3/";
            end

            obj.Url = url;

            try
                data_raw = webread(url);
            catch
                error('iam:data:BANKOFCANADAconnection', 'UnableToGetData')
            end

            data_raw.VARIABLE = string(data_raw.CL_VARIABLE ) + "|" + string(data_raw.CL_SECTOR );
            data_raw.CL_GEOGRAPHY = string(data_raw.CL_GEOGRAPHY);
            data_raw.CL_SCENARIO = string(data_raw.CL_SCENARIO);
            data_raw.CL_UNIT = string(data_raw.CL_UNIT);
            data_raw.CL_SECTOR = string(data_raw.CL_SECTOR);

            obj.RawData = data_raw;

            [rl,ia,ic] = unique(data_raw(:,["CL_SCENARIO", "CL_GEOGRAPHY", "VARIABLE" ]), 'stable', 'rows');

            obj.IC = ic;
            obj.IA = ia;

            rl.run_id = ones(height(rl),1);
            myRuns = configureDictionary('string','double');            
            current = 0;
            for i = 1 : height(rl)
                if isKey(myRuns, rl.CL_SCENARIO(i))
                    rl.run_id(i) = myRuns(rl.CL_SCENARIO(i));
                else
                    current = current + 1;
                    myRuns(rl.CL_SCENARIO(i)) = current;
                    rl.run_id(i) = current;
                end
            end

            rl.unit = data_raw{ia, "CL_UNIT"};
            
            rl.model = repmat("CL", height(rl), 1);

            obj.TimeseriesList = rl;
            obj.TimeseriesList.Properties.VariableNames = {'scenario', 'region', 'variable', 'run_id', 'unit', 'model'};
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

            idxA = find(idx);
            tlist = obj.TimeseriesList(idx, :);

            data = struct([]);
            for num = 1 : numel(idxA)

                idxC = ismember(obj.IC, idxA(num));
                rawdata = obj.RawData(idxC, :);

                data(num).model    = tlist.model(num);
                data(num).scenario = tlist.scenario(num);
                data(num).variable = tlist.variable(num);
                data(num).region   = tlist.region(num);
                data(num).runId    = tlist.run_id(num);
                data(num).version  = [];
                data(num).unit     = tlist.unit(num);
                data(num).years    = rawdata.CL_YEAR;
                data(num).values   = timetable( datetime([rawdata.CL_YEAR], 1,1), rawdata.CL_VALUE, DimensionNames = {'Year', 'Variables'});

            end

            ts = iam.IAMTimeseries(data);

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
            runs = unique(obj.TimeseriesList(:,{'scenario', 'model','run_id'}), 'stable', 'rows');            
        end
        
         function value = getDocumentation(~, ~, ~)
            
             value = struct('description','Please visit the <a href="https://www.bankofcanada.ca/2022/01/climate-transition-scenario-data/" target="_blank">official Bank of Canada Website</a> for details ');
            
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
            uiUrl = obj.Url;
            name = obj.Config.name;
            scheme = "";
            
            value = table(productName, env, uiUrl, name, scheme);
        end
        
    end
         
end
