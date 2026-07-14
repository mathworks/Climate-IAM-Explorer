classdef IAMEnvironment < matlab.mixin.SetGet
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties (Hidden)
        Connection
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
        Metadata struct = struct()
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

        function reloadEnvironment(obj)
            obj.setEnvironment();
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
                'regions', regions, ...
                'years', r.years, ...
                'units', r.units, ...
                'timeslices', r.timeslices);
            
        end

        function frame = getFrame(obj, varargin)
            ts = obj.getTimeSeries(varargin{:});
            if ~isa(ts, 'iam.IAMTimeseries')
                error('IAMEnvironment:getFrame:InvalidResponse', ...
                    'getFrame requires the connection to return IAMTimeseries data.')
            end

            frame = ts.toFrame();
            frame = iam.IAMFrame(frame.toTable(), ...
                'RunInfo', obj.RunList(ismember(obj.RunList.run_id, frame.RunIds), :));
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

            idx = true(height(obj.RunList),1);
            if ~isempty(p.Results.models)
                idx = idx & matchStringValues(obj.RunList.model, p.Results.models, p.Results.strict);
            end
            if ~isempty(p.Results.scenarios)
                idx = idx & matchStringValues(obj.RunList.scenario, p.Results.scenarios, p.Results.strict);
            end
            if ~isempty(p.Results.runs)
                idx = idx & ismember(obj.RunList.run_id, p.Results.runs);
            end
            
            if ~isempty(p.Results.metadata)
                for f = fields(p.Results.metadata)
                    fieldName = resolveMetadataFieldName(obj.Metadata, f{1});
                    values = metadataValuesAsString(obj.RunList.metadata, fieldName);
                    idx = idx & matchStringValues(values, p.Results.metadata.(f{1}), p.Results.strict);
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
            obj.Models = getRefTable(refs, 'models', obj.Models);
            obj.Scenarios = getRefTable(refs, 'scenarios', obj.Scenarios);
            obj.Variables = getRefTable(refs, 'variables', obj.Variables);
            obj.Regions = getRefTable(refs, 'regions', obj.Regions);

            obj.Metadata = loadMetadataDefinitions(obj.Connection);
            
            runs = obj.Connection.getRunsList();
            runs = normalizeRunsMetadata(runs, obj.Metadata, obj.RunList([],:));
            obj.RunList = toString(runs);
            
        end
        
        function vars = filterVar(obj, var, data, strict)
            if nargin < 4
                strict = false;
            end
            
            if strict
                fcn = @(x,y) matchStringValues(x, y, true);
            else
                fcn = @(x,y) matchStringValues(x, y, false);
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

function value = getRefTable(refs, fieldName, template)
if isstruct(refs) && isfield(refs, fieldName) && istable(refs.(fieldName))
    value = refs.(fieldName);
else
    value = template([],:);
end
end

function metadata = loadMetadataDefinitions(connection)
metadata = struct();

if ~ismethod(connection, 'getMetadataCategories')
    return
end

try
    categories = connection.getMetadataCategories();
catch
    return
end

if isempty(categories) || ~ismember("name", categories.Properties.VariableNames)
    return
end

names = string(categories.name);
types = strings(size(names));
if ismember("type", categories.Properties.VariableNames)
    types = string(categories.type);
end

fieldNames = matlab.lang.makeUniqueStrings(matlab.lang.makeValidName(cellstr(names)));
for i = 1 : numel(names)
    if strlength(types(i)) == 0 && ismethod(connection, 'getMetadataDetails')
        try
            details = connection.getMetadataDetails(names(i));
            types(i) = extractMetadataType(details);
        catch
            types(i) = "";
        end
    end

    metadata.(fieldNames{i}) = struct( ...
        'OriginalName', names(i), ...
        'Type', types(i), ...
        'DefaultValue', metadataDefaultValue(types(i)));
end
end

function runs = normalizeRunsMetadata(runs, metadata, runTemplate)
if isempty(runs)
    runs = runTemplate;
    return
end

if ~ismember("metadata", runs.Properties.VariableNames)
    return
end

metadataFields = fields(metadata);
if isempty(metadataFields)
    return
end

defaultValues = cell(size(metadataFields));
for i = 1 : numel(metadataFields)
    defaultValues{i} = metadata.(metadataFields{i}).DefaultValue;
end
template = cell2struct(defaultValues, metadataFields, 1);

normalized(height(runs),1) = template;
for i = 1 : height(runs)
    current = getRunMetadataStruct(runs.metadata(i));
    normalized(i) = template;

    for name = string(fields(current))'
        fieldName = resolveMetadataFieldName(metadata, name);
        normalized(i).(fieldName) = current.(name);
    end
end

runs.metadata = normalized;
end

function metadata = getRunMetadataStruct(value)
if iscell(value)
    value = value{1};
end

if isempty(value) || ~isstruct(value)
    metadata = struct();
else
    metadata = value(1);
end
end

function fieldName = resolveMetadataFieldName(metadata, inputName)
fieldNames = string(fields(metadata));
if isempty(fieldNames)
    error('IIASAEnvironment:resolveMetadataFieldName:UnknownMetadataField', ...
        "Metadata field '" + string(inputName) + "' is not available.")
end

matchesField = matches(fieldNames, string(inputName), 'IgnoreCase', true);
matchesOriginal = false(size(fieldNames));
for i = 1 : numel(fieldNames)
    matchesOriginal(i) = isfield(metadata.(fieldNames(i)), 'OriginalName') && ...
        matches(string(metadata.(fieldNames(i)).OriginalName), string(inputName), 'IgnoreCase', true);
end

idx = matchesField | matchesOriginal;
if ~any(idx)
    error('IIASAEnvironment:resolveMetadataFieldName:UnknownMetadataField', ...
        "Metadata field '" + string(inputName) + "' is not available.")
end

fieldName = fieldNames(find(idx, 1));
end

function values = metadataValuesAsString(metadataValues, fieldName)
values = strings(numel(metadataValues), 1);
for i = 1 : numel(metadataValues)
    current = getRunMetadataStruct(metadataValues(i));
    if isfield(current, fieldName)
        values(i) = scalarToString(current.(fieldName));
    else
        values(i) = "";
    end
end
end

function idx = matchStringValues(values, patterns, strict)
values = string(values);
values(ismissing(values)) = "";

patterns = string(patterns);
patterns = patterns(strlength(patterns) > 0);
if isempty(patterns)
    idx = true(size(values));
    return
end

idx = false(size(values));
for i = 1 : numel(patterns)
    idx = idx | matchSinglePattern(values, patterns(i), strict);
end
end

function idx = matchSinglePattern(values, pattern, strict)
if contains(pattern, "*") || contains(pattern, "?")
    expr = "^" + string(regexptranslate('wildcard', char(pattern))) + "$";
    idx = ~cellfun('isempty', regexpi(cellstr(values), char(expr), 'once'));
elseif strict
    idx = matches(values, pattern, 'IgnoreCase', true);
else
    idx = contains(values, pattern, 'IgnoreCase', true);
end
end

function value = scalarToString(inputValue)
if isstring(inputValue)
    value = inputValue;
elseif ischar(inputValue)
    value = string(inputValue);
elseif islogical(inputValue) || isnumeric(inputValue)
    if isempty(inputValue)
        value = "";
    else
        value = string(inputValue);
    end
elseif isempty(inputValue)
    value = "";
else
    value = string(inputValue);
end

if numel(value) > 1
    value = strjoin(value, ", ");
end
end

function value = metadataDefaultValue(type)
type = lower(string(type));
switch type
    case "numeric value"
        value = NaN;
    case "boolean value"
        value = false;
    otherwise
        value = "";
end
end

function type = extractMetadataType(details)
type = "";
if isstruct(details) && isfield(details, 'type')
    type = string(details.type);
elseif istable(details) && ismember("type", details.Properties.VariableNames) && ~isempty(details)
    type = string(details.type(1));
end
end

function checkValidMetadata(input, meta)

if ~isstruct(input)
    error('IIASAEnvironment:checkValidMetadata:InvalidMetadataType','Metadata must be a struct')
end

validNames = lower(getMetadataFieldNames(meta));
if ~all(ismember(lower(fields(input)), validNames))
    error('IIASAEnvironment:checkValidMetadata:InvalidMetadataFields',...
        "Metadata fields must be in: " + strjoin(getMetadataFieldNames(meta),', '));
end

end

function names = getMetadataFieldNames(meta)
names = string(fields(meta));
for fieldName = string(fields(meta))'
    if isfield(meta.(fieldName), 'OriginalName')
        names(end+1) = string(meta.(fieldName).OriginalName); %#ok<AGROW>
    end
end

names = unique(names(strlength(names) > 0));
end
