classdef OECMconnection < iam.data.Connection

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
            'name', "OECM", 'env', "boc",'productName', "OECM", ...
            'database', "OECM", "welcome", "Welcome to the One Earth Climate Model");

        ConnectionProperties
    end

    properties (Constant, Access = private)
        ENVIRONMENT = "OECM";
    end

    properties
        AllEnvironments
    end

    methods

        function obj = OECMconnection(url)

            arguments
                url (1,1) string = "https://www.uts.edu.au/sites/default/files/2022-05/"
            end

            obj.Url = url;

            try
                globalR = obj.Url + "/OECM_Global_2022_04_22_Results_All_CSV.xlsx";
                opts = detectImportOptions(globalR, Range = 'A2', ReadVariableNames = true, TextType = 'string', VariableNamingRule='preserve');
                opts = opts.setvaropts("Remarks", "Type","string");
                data_raw = readtable(globalR,opts);
                data_raw.REGION = repmat("GLOBAL", height(data_raw),1);

                data_rawEurope = readtable(obj.Url + "OECM_OECD_Europe_2022_04_22_Results_All_CSV.xlsx", opts);
                data_rawEurope.REGION = repmat("EUROPE", height(data_rawEurope),1);

                data_rawNA = readtable(obj.Url + "OECM_OECD_North_America_2022_04_22_Results_All_CSV.xlsx", opts);
                data_rawNA.REGION = repmat("North America", height(data_rawNA),1);

                data_raw = [data_raw; data_rawEurope; data_rawNA];
            catch e
                error('iam:data:OECMconnection:UnableToGetData', "Unable to get the raw data." + e.message)
            end

            data_raw.MODEL = repmat("OECM", height(data_raw),1);
            idx = ismissing(data_raw.Sector);
            data_raw.Sector(idx) = data_raw.Sector(find(idx)-1);
            data_raw.VARIABLE = data_raw.Sector + "|" + data_raw.Subsector + "|" + data_raw.Description;
            data_raw.SCENARIO = data_raw.Label;
            idx = data_raw.SCENARIO == "IEA WEO 21";
            data_raw.MODEL(idx) = "IEA";
            idx = ismissing(data_raw.SCENARIO);
            data_raw.SCENARIO(idx) = "TOTAL";
            data_raw.Description = strtrim(data_raw.Description) + " " + strtrim(data_raw.Remarks);
            data_raw.UNIT = data_raw.Unit;
            data_raw.Unit = [];
            data_raw.Sector = [];
            data_raw.Subsector = [];
            data_raw.Index = [];
            data_raw.Label = [];
            data_raw.run_id = ones(height(data_raw),1);
            myRuns = configureDictionary('string','double');
            current = 0;
            for i = 1 : height(data_raw)
                if isKey(myRuns, data_raw.MODEL(i) + data_raw.SCENARIO(i))
                    data_raw.run_id(i) = myRuns(data_raw.MODEL(i) + data_raw.SCENARIO(i));
                else
                    current = current + 1;
                    myRuns(data_raw.MODEL(i) + data_raw.SCENARIO(i)) = current;
                    data_raw.run_id(i) = current;
                end
            end
            
            obj.RawData = data_raw;

            data_raw = data_raw(:, ["MODEL", "SCENARIO", "REGION", "VARIABLE", "run_id", "UNIT"]);

            [data_raw,ia,ic] = unique(data_raw(:,["MODEL", "SCENARIO", "REGION", "VARIABLE", 'run_id', 'UNIT' ]), 'stable', 'rows');

            obj.IC = ic;
            obj.IA = ia;
            
            obj.TimeseriesList = data_raw;
            obj.TimeseriesList.Properties.VariableNames = {'model', 'scenario', 'region', 'variable', 'run_id', 'unit'};
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

                valuesIdx =  startsWith(rawdata.Properties.VariableNames, '2');

                data(num).model    = tlist.model(num);
                data(num).scenario = tlist.scenario(num);
                data(num).variable = tlist.variable(num);
                data(num).region   = tlist.region(num);
                data(num).runId    = tlist.run_id(num);
                data(num).version  = [];
                data(num).unit     = tlist.unit(num);
                data(num).years    = str2double(rawdata.Properties.VariableNames(valuesIdx));
                data(num).values   = timetable( datetime(data(num).years', 1,1), rawdata{:,valuesIdx}', DimensionNames = {'Year', 'Variables'});

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

            value = struct('description','Please visit "https://oneearth.uts.edu.au/" official One Earth Climate Model Website for details ');

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
