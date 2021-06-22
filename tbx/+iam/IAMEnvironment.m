classdef IAMEnvironment < matlab.mixin.SetGet
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties (Hidden)
        Connection (1,1) iiasa.Connection
    end
    
    properties (Dependent, SetAccess = private)
        Environment
    end
    
    properties (SetAccess = private)
        Models    table = table('Size', [0, 2], 'VariableNames', {'ID','Name'}, 'VariableTypes', {'double','string'})
        Scenarios table = table('Size', [0, 2], 'VariableNames', {'ID','Name'}, 'VariableTypes', {'double','string'})
        Variables table = table('Size', [0, 4], 'VariableNames', {'ID','Name','Unit ID','Unit'}, 'VariableTypes', {'double','string','double','string'})
        Regions   table = table('Size', [0, 5], 'VariableNames', {'ID','Name','Hyerarchy','Parent','Synonyms'}, 'VariableTypes', {'double','string','string','string','string'})
        RunList   table = table('Size',[0, 17], ...
            'VariableNames', {'model', 'scenario', 'scheme', 'annotation', 'metadata', 'run_id', 'model_id', 'scen_id', 'is_default', 'is_locked', 'cre_user', 'cre_date', 'upd_user', 'upd_date', 'lock_user', 'lock_date', 'version'}, ...
            'VariableTypes', {'string', 'string', 'double', 'string', 'struct', 'double', 'double', 'double', 'logical', 'logical', 'string', 'string', 'double', 'double', 'double', 'double', 'double'});
        Metadata
    end
    
    methods
        
        function obj = IAMEnvironment(conn)
            
            if nargin > 0
                obj.Connection = conn;
                obj.setEnvironment();
            end
            
        end
        
        function value = get.Environment(obj)
            value = obj.Connection.Environment;
        end
        
        function changeEnvironment(obj, value)
            obj.Connection.Environment = value;
            obj.setEnvironment();
        end
        
        function ts = getTimeSeries(obj, varargin)
            
            p = inputParser();
            
            func = @(x) isstring(x) | ischar(x);
            
            addParameter(p, 'strict', false)
            addParameter(p, 'models','', func)
            addParameter(p, 'scenarios','', func)
            addParameter(p, 'runs', [], @isnumeric)
            addParameter(p, 'variables', '', func)
            addParameter(p, 'regions', '', func)
            addParameter(p, 'years', '', func)
            addParameter(p, 'units', '', func)
            addParameter(p, 'timeslices', '', func)
            
            parse(p, varargin{:});
            
            r = p.Results;
            
            variables = obj.filterVariables(r.variables, r.strict);
            regions = obj.filterRegions(r.regions, r.strict);
            
            runIds = obj.filterRuns(r.strict, ...
                'models',r.models, ...
                'scenarios', r.scenarios, ...
                'runs', r.runs);
            
            ts = obj.Connection.getBulkData( ...
                'runs', runIds, ...
                'variables', variables, ...
                'regions', regions);
            
        end
        
        function doc = getModelDocumentation(obj,modelID)            
            doc = obj.Connection.getDocumentation('models',modelID);
        end
        
        function doc = getScenarioDocumentation(obj,scenarioID)            
            doc = obj.Connection.getDocumentation('scenarios',scenarioID);
        end
        
        function doc = getTimeseriesDocumentation(obj,timeseriesID)            
            doc = obj.Connection.getDocumentation('timeseries',timeseriesID);
        end
        
        function doc = getRegionDocumentation(obj,regionID)            
            doc = obj.Connection.getDocumentation('regions',regionID);
        end
        
        function envs = viewEnvironments(obj)
            envs = obj.Connection.getEnvironments;
        end
        
        function vars = filterVariables(obj, varargin)
            
            vars = filterVar(obj, 'Variables', varargin{:});
        end
        
        function vars = filterRegions(obj, varargin)
            
            vars = filterVar(obj, 'Regions', varargin{:});
            
        end
        
        function runIDs = filterRuns(obj, varargin)
            % FILTERRUNS get Run IDs for runs based on model, scenario, or
            % metadata.
            p = inputParser();
            
            func = @(x) isstring(x) | ischar(x) | iscellstr(x);
            
            addOptional(p, 'strict', false)
            addParameter(p, 'models','', func)
            addParameter(p, 'scenarios','', func)
            addParameter(p, 'runs', [], @isnumeric)
            addParameter(p, 'metadata', struct.empty(), @(x) checkValidMetadata(x, obj.Metadata))
            
            parse(p, varargin{:});
            
            if p.Results.strict
                fcn = @(x,y) ismember(x, y);
            else
                fcn = @(x,y) contains(x, y, 'IgnoreCase', true);
            end
            
            idx = true(height(obj.RunList),1);
            if ~isempty(p.Results.models)
                idx = idx & fcn(obj.RunList.model, p.Results.models);
            end
            if ~isempty(p.Results.scenarios)
                idx = idx & fcn(obj.RunList.scenario, p.Results.scenarios);
            end
            if ~isempty(p.Results.runs)
                idx = idx & ismember(obj.RunList.run_id, p.Results.runs);
            end
            
            if ~isempty(p.Results.metadata)
                for f = fields(p.Results.metadata)
                    vars = fields(obj.Metadata);
                    fi = contains(vars, f{1},'IgnoreCase', true);
                    idx = idx & contains({obj.RunList.metadata.(vars{fi})}', p.Results.metadata.(f{1}));
                end
            end
            
            runIDs = obj.RunList(idx,:).run_id;
            
        end
        
        function params = getRunVariables(obj, runId)
            
            params = obj.Connection.getRunDetails(runId);
            
        end
        
    end
    
    methods (Access = private)
        
        function setEnvironment(obj)
            
            refs = obj.Connection.getRefs();
            
            if ~isempty(refs)
                
                models = [refs.models{:}]';
                obj.Models = toString(cell2table(models(2:end,:),'VariableNames',models(1,:)));
                
                scenarios = [refs.scenarios{:}]';
                obj.Scenarios = toString(cell2table(scenarios(2:end,:),'VariableNames',scenarios(1,:)));
                
                variables = [refs.variables{:}]';
                obj.Variables = toString(cell2table(variables(2:end,:),'VariableNames',variables(1,:)));
                
                regions = [refs.regions{:}]';
                obj.Regions = toString(cell2table(regions(2:end,:),'VariableNames',regions(1,:)));
                
            end
            
%             metadata = obj.Connection.getMetadata();
            
%             for i = 1 : height(metadata)
%                 obj.Metadata.(genvarname(metadata.name{i})) = obj.Connection.getMetadataDetails(metadata.name{i});
%             end
            
            runs = obj.Connection.getRunsList();
%             runs = parseRunsMetadata(runs, metadata);
            obj.RunList = toString(runs);
            
        end
        
        function vars = filterVar(obj, var, data, strict)
            if nargin < 4
                strict = false;
            end
            
            if strict
                fcn = @(x,y) ismember(lower(x), lower(y));
            else
                fcn = @(x,y) contains(x, y, 'IgnoreCase', true);
            end
            
            idx = true(height(obj.(var)),1);
            if ~isempty(data)
                idx = fcn(obj.(var).Name, data);
            end
            
            vars = obj.(var).Name(idx);
        end
        
    end
end

function tb = toString(tb)
% Transform cell arrays to string arrays for conveinence.
vars = tb.Properties.VariableNames;
for i = vars
    field = i{1};
    if iscellstr(tb.(field)) %#ok<ISCLSTR>
        tb.(field) = string(tb.(field));
    end
end

end

function runs = parseRunsMetadata(runs, metadata)
for i = 1 : height(runs)
    md = runs{i,'metadata'}{1};
    for j = 1 : height(metadata)
        name = metadata.name{j};
        type = metadata.type{j};
        if ~isfield(md,name)
            switch type
                case 'string value'
                    md.(genvarname(name)) = "";
                    runs{i,'metadata'}{1} = md;
                case 'numeric value'
                    md.(genvarname(name)) = [];
                    runs{i,'metadata'}{1} = md;
                case 'boolean value'
                    md.(genvarname(name)) = logical.empty();
                    runs{i,'metadata'}{1} = md;
                otherwise
                    error('Unsupported')
            end
        end
        
    end
    
end

runs.metadata = [runs.metadata{:}]';

end

function checkValidMetadata(input, meta)

if ~isstruct(input)
    error('IIASAEnvironment:checkValidMetadata:InvalidMetadataType','Metadata must be a struct')
end

if ~all(ismember(lower(fields(input)), lower(fields(meta))))
    error('IIASAEnvironment:checkValidMetadata:InvalidMetadataFields',...
        "Metadata fields must be in: " + strjoin(fields(meta),', '));
end

end
