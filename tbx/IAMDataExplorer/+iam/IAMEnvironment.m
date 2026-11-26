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
        
        function ts = getTimeSeries(obj, opts)
            arguments
                obj
                opts.strict (1,1) logical = false
                opts.models (1,:) string = strings(0,1)
                opts.scenarios (1,:) string = strings(0,1)
                opts.runs double = []
                opts.variables (1,:) string = strings(0,1)
                opts.regions (1,:) string = strings(0,1)
                opts.years = []
                opts.units (1,:) string = strings(0,1)
                opts.timeslices (1,:) string = strings(0,1)
            end

            variables = obj.filterVariables(opts.variables, opts.strict);
            regions = obj.filterRegions(opts.regions, opts.strict);

            runIds = obj.filterRuns('strict', opts.strict, ...
                'models', opts.models, ...
                'scenarios', opts.scenarios, ...
                'runs', opts.runs);

            if ((~isempty(opts.models) || ~isempty(opts.scenarios) || ~isempty(opts.runs)) && isempty(runIds)) || ...
                    (~isempty(opts.variables) && isempty(variables)) || ...
                    (~isempty(opts.regions) && isempty(regions))
                ts = iam.IAMTimeseries(struct.empty());
                return
            end

            ts = obj.Connection.getBulkData( ...
                'runs', runIds, ...
                'variables', variables, ...
                'regions', regions, ...
                'years', opts.years, ...
                'units', opts.units, ...
                'timeslices', opts.timeslices);
        end

        function frame = getFrame(obj, opts)
            arguments
                obj
                opts.strict (1,1) logical = false
                opts.models (1,:) string = strings(0,1)
                opts.scenarios (1,:) string = strings(0,1)
                opts.runs double = []
                opts.variables (1,:) string = strings(0,1)
                opts.regions (1,:) string = strings(0,1)
                opts.years = []
                opts.units (1,:) string = strings(0,1)
                opts.timeslices (1,:) string = strings(0,1)
                opts.meta (1,:) string = strings(0,1)
            end

            ts = obj.getTimeSeries( ...
                'strict', opts.strict, ...
                'models', opts.models, ...
                'scenarios', opts.scenarios, ...
                'runs', opts.runs, ...
                'variables', opts.variables, ...
                'regions', opts.regions, ...
                'years', opts.years, ...
                'units', opts.units, ...
                'timeslices', opts.timeslices);
            if ~isa(ts, 'iam.IAMTimeseries')
                error('IAMEnvironment:getFrame:InvalidResponse', ...
                    'getFrame requires the connection to return IAMTimeseries data.')
            end

            frame = ts.toFrame();
            runInfo = obj.RunList(ismember(obj.RunList.run_id, frame.RunIds), :);
            runInfo = projectRunMetadata(runInfo, obj.Metadata, opts.meta);

            frame = iam.IAMFrame(frame.toTable(), ...
                'RunInfo', runInfo);
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
        
        function vars = filterVariables(obj, data, strict)
            arguments
                obj
                data (1,:) string = strings(0,1)
                strict (1,1) logical = false
            end

            vars = filterVar(obj, 'Variables', data, strict);
        end
        
        function vars = filterRegions(obj, data, strict)
            arguments
                obj
                data (1,:) string = strings(0,1)
                strict (1,1) logical = false
            end

            vars = filterVar(obj, 'Regions', data, strict);
        end
        
        function runIDs = filterRuns(obj, opts)
            % FILTERRUNS get Run IDs for runs based on model, scenario, or
            % metadata. Use name-value arguments for every filter.
            arguments
                obj
                opts.strict (1,1) logical = false
                opts.models (1,:) string = strings(0,1)
                opts.scenarios (1,:) string = strings(0,1)
                opts.runs (1,:) double = []
                opts.metadata struct = struct.empty()
            end
            
            checkValidMetadata(opts.metadata, obj.Metadata)

            idx = true(height(obj.RunList),1);
            if ~isempty(opts.models)
                idx = idx & matchStringValues(obj.RunList.model, opts.models, opts.strict);
            end
            if ~isempty(opts.scenarios)
                idx = idx & matchStringValues(obj.RunList.scenario, opts.scenarios, opts.strict);
            end
            if ~isempty(opts.runs)
                idx = idx & ismember(obj.RunList.run_id, opts.runs);
            end
            
            if ~isempty(opts.metadata)
                for f = fields(opts.metadata)
                    fieldName = resolveMetadataFieldName(obj.Metadata, f{1});
                    values = metadataValuesAsString(obj.RunList.metadata, fieldName);
                    idx = idx & matchStringValues(values, string(opts.metadata.(f{1})), opts.strict);
                end
            end
            
            runIDs = obj.RunList(idx,:).run_id;
            
        end
        
        function params = getRunVariables(obj, runId)
            
            params = obj.Connection.getRunDetails(runId);
            
        end

        function tb = index(obj, opts)
            arguments
                obj
                opts.strict (1,1) logical = false
                opts.models (1,:) string = strings(0,1)
                opts.scenarios (1,:) string = strings(0,1)
                opts.runs double = []
                opts.metadata struct = struct.empty()
            end

            checkValidMetadata(opts.metadata, obj.Metadata)

            runs = selectRunsTable(obj, opts.strict, opts.models, opts.scenarios, opts.runs, opts.metadata);
            cols = intersect(["model", "scenario", "version"], string(runs.Properties.VariableNames), 'stable');
            tb = runs(:, cellstr(cols));
        end

        function tb = meta(obj, opts)
            arguments
                obj
                opts.fields (1,:) string = strings(0,1)
                opts.run_id (1,1) logical = false
                opts.strict (1,1) logical = false
                opts.models (1,:) string = strings(0,1)
                opts.scenarios (1,:) string = strings(0,1)
                opts.runs double = []
                opts.metadata struct = struct.empty()
            end

            checkValidMetadata(opts.metadata, obj.Metadata)

            runs = selectRunsTable(obj, opts.strict, opts.models, opts.scenarios, opts.runs, opts.metadata);
            runs = projectRunMetadata(runs, obj.Metadata, opts.fields);

            cols = ["model", "scenario", "version"];
            if opts.run_id
                cols = [cols, "run_id"];
            end
            cols = [cols, getProjectedMetadataFieldNames(obj.Metadata, opts.fields)'];
            cols = intersect(cols, string(runs.Properties.VariableNames), 'stable');
            tb = runs(:, cellstr(cols));
        end

        function tb = runProperties(obj, opts)
            arguments
                obj
                opts.strict    (1,1) logical = false
                opts.models    (1,:) string = strings(0,1)
                opts.scenarios (1,:) string = strings(0,1)
                opts.runs            double = []
                opts.metadata        struct = struct.empty()
            end

            checkValidMetadata(opts.metadata, obj.Metadata)

            runs = selectRunsTable(obj, opts.strict, opts.models, opts.scenarios, opts.runs, opts.metadata);
            cols = intersect(["model", "scenario", "version", "is_default", "run_id", ...
                "cre_user", "cre_date", "upd_user", "upd_date", ...
                "lock_user", "lock_date", "is_locked"], ...
                string(runs.Properties.VariableNames), 'stable');
            tb = runs(:, cellstr(cols));
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

categories = connection.getMetadataCategories();

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

arguments
    input struct
    meta
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

function runs = selectRunsTable(obj, strict, models, scenarios, runsFilter, metadataFilter)
runIds = obj.filterRuns('strict', strict, ...
    'models', models, ...
    'scenarios', scenarios, ...
    'runs', runsFilter, ...
    'metadata', metadataFilter);
runs = obj.RunList(ismember(obj.RunList.run_id, runIds), :);
end

function runInfo = projectRunMetadata(runInfo, metadata, selection)
if isempty(runInfo) || ~ismember("metadata", runInfo.Properties.VariableNames)
    return
end

fieldsToProject = getProjectedMetadataFieldNames(metadata, selection);
if isempty(fieldsToProject)
    return
end

for i = 1 : numel(fieldsToProject)
    fieldName = fieldsToProject(i);
    values = metadataValuesAsTypedColumn(runInfo.metadata, fieldName, metadata);
    runInfo.(fieldName) = values;
end
end

function fieldNames = getProjectedMetadataFieldNames(metadata, selection)
allFields = string(fields(metadata));
if isempty(allFields)
    fieldNames = strings(0,1);
    return
end

selection = string(selection);
selection = selection(strlength(selection) > 0);
if isempty(selection)
    fieldNames = strings(0,1);
    return
end

if any(matches(selection, "all", 'IgnoreCase', true))
    fieldNames = allFields;
    return
end

fieldNames = strings(0,1);
for name = selection(:)'
    fieldNames(end+1,1) = resolveMetadataFieldName(metadata, name); %#ok<AGROW>
end
fieldNames = unique(fieldNames, 'stable');
end

function values = metadataValuesAsTypedColumn(metadataValues, fieldName, metadata)
count = numel(metadataValues);
defaultValue = metadata.(fieldName).DefaultValue;

if isstring(defaultValue)
    values = repmat("", count, 1);
elseif islogical(defaultValue)
    values = repmat(defaultValue, count, 1);
elseif isnumeric(defaultValue)
    values = repmat(double(defaultValue), count, 1);
else
    values = repmat(string(missing), count, 1);
end

for i = 1 : count
    current = getRunMetadataStruct(metadataValues(i));
    if isfield(current, fieldName)
        currentValue = current.(fieldName);
    else
        currentValue = defaultValue;
    end

    if isstring(values)
        values(i) = scalarToString(currentValue);
    elseif islogical(values)
        if isempty(currentValue)
            values(i) = defaultValue;
        else
            values(i) = logical(currentValue);
        end
    elseif isnumeric(values)
        if isempty(currentValue)
            values(i) = double(defaultValue);
        else
            values(i) = double(currentValue);
        end
    else
        values(i) = scalarToString(currentValue);
    end
end
end
