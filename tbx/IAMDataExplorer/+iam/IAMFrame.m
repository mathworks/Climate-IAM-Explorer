%IAMFrame Store annual IAM observations in a MATLAB table.
%   FRAME = iam.IAMFrame(DATA) constructs a frame from IAMTimeseries objects
%   or a long table with Model, Scenario, Variable, Region, Unit, Year, and
%   Value columns. RunId and Version are optional. Use 'RunInfo' to attach
%   source metadata.
%
%   Annual years must be finite integers. Missing observations are represented
%   by NaN and are not replaced with zero. An empty Unit string means unknown.
%   Additional columns are rejected so data cannot be silently discarded.

classdef IAMFrame

    properties (Access = private)
        Data table
    end

    properties (SetAccess = private)
        RunInfo table = table() % Source metadata associated with RunId values.
    end

    properties (Dependent, SetAccess = private)
        Models (:,1) string % Model names in the frame.
        Scenarios (:,1) string % Scenario names in the frame.
        Variables (:,1) string % Variable names in the frame.
        Regions (:,1) string % Region names in the frame.
        Units (:,1) string % Units; empty denotes unknown.
        RunIds (:,1) double % Source run IDs; NaN denotes no source run.
        Years (:,1) double % Annual years in the frame.
    end

    methods
        function obj = IAMFrame(data, nvp)

            arguments
                data = defaultDataTable()
                nvp.RunInfo table = table.empty()
            end

            if isa(data, 'iam.IAMTimeseries')
                obj.Data = fromTimeseries(data);
            elseif istable(data)
                obj.Data = normalizeDataTable(data);
            else
                error('iam:IAMFrame:InvalidInput', ...
                    'IAMFrame input must be a IAMTimeseries array or a table.')
            end

            validateUniqueObservations(obj.Data);

            obj.RunInfo = nvp.RunInfo;
        end

        function value = get.Models(obj)
            value = uniqueOrEmpty(obj.Data, 'Model', strings(0,1));
        end

        function value = get.Scenarios(obj)
            value = uniqueOrEmpty(obj.Data, 'Scenario', strings(0,1));
        end

        function value = get.Variables(obj)
            value = uniqueOrEmpty(obj.Data, 'Variable', strings(0,1));
        end

        function value = get.Regions(obj)
            value = uniqueOrEmpty(obj.Data, 'Region', strings(0,1));
        end

        function value = get.Units(obj)
            value = uniqueOrEmpty(obj.Data, 'Unit', strings(0,1));
        end

        function value = get.RunIds(obj)
            value = uniqueOrEmpty(obj.Data, 'RunId', zeros(0,1));
        end

        function value = get.Years(obj)
            value = uniqueOrEmpty(obj.Data, 'Year', zeros(0,1));
        end

        function tb = toTable(obj)
            tb = obj.Data;
        end

        function tb = summary(obj)
            if isempty(obj.Data)
                tb = obj.Data(:, identityVariables());
                tb.NumYears = zeros(0,1);
                return
            end

            [tb, ~, uniqueKeys, loc] = identityGroups(obj.Data);
            tb.NumYears = accumarray(loc, 1, [height(uniqueKeys), 1]);

        end

        function value = head(obj, n)
            if nargin < 2
                n = 8;
            end
            value = head(obj.Data, n);
        end

        function value = tail(obj, n)
            if nargin < 2
                n = 8;
            end
            value = tail(obj.Data, n);
        end

        function out = filter(obj, nvp)

            arguments
                obj
                nvp.strict (1,1) logical = false
                nvp.models (1,:) string = string(missing)
                nvp.scenarios (1,:) string = string(missing)
                nvp.variables (1,:) string = string(missing)
                nvp.regions   (1,:) string = string(missing)
                nvp.units     (1,:) string = string(missing)
                nvp.runs double = []
                nvp.years = []
            end

            idx = true(height(obj.Data), 1);
            idx = idx & matchStringValues(obj.Data.Model, nvp.models, nvp.strict);
            idx = idx & matchStringValues(obj.Data.Scenario, nvp.scenarios, nvp.strict);
            idx = idx & matchStringValues(obj.Data.Variable, nvp.variables, nvp.strict);
            idx = idx & matchStringValues(obj.Data.Region, nvp.regions, nvp.strict);
            idx = idx & matchStringValues(obj.Data.Unit, nvp.units, nvp.strict);

            if ~isempty(nvp.runs)
                idx = idx & ismember(obj.Data.RunId, nvp.runs);
            end

            years = normalizeYears(nvp.years);
            if ~isempty(years)
                idx = idx & ismember(obj.Data.Year, years);
            end

            data = obj.Data(idx, :);
            runInfo = subsetRunInfo(obj.RunInfo, data.RunId);
            out = iam.IAMFrame(data, 'RunInfo', runInfo);
        end

        function out = append(obj, other)
            if ~isa(other, 'iam.IAMFrame')
                other = iam.IAMFrame(other);
            end

            data = [obj.Data; other.Data];
            out = iam.IAMFrame(data, 'RunInfo', mergeRunInfo(obj.RunInfo, other.RunInfo));
        end

        function tb = timeseries(obj)

            if isempty(obj.Data)
                tb = obj.summary();
                return
            end

            [tb, ~, uniqueKeys, loc] = identityGroups(obj.Data);
            years = sort(unique(obj.Data.Year));

            for i = 1 : numel(years)
                y = years(i);
                colName = "Y" + string(y);
                col = NaN(height(uniqueKeys), 1);
                idx = obj.Data.Year == y;
                col(loc(idx)) = obj.Data.Value(idx);
                tb.(colName) = col;
            end
        end

        function ts = toTimeseries(obj)
            if isempty(obj.Data)
                ts = iam.IAMTimeseries.empty();
                return
            end

            [~, ~, uniqueKeys, loc] = identityGroups(obj.Data);
            nGroups = height(uniqueKeys);

            % Sort once so each group is a contiguous, year-ordered block.
            [~, order] = sortrows([loc, obj.Data.Year]);

            % Pull raw arrays out of the table a single time.
            model    = obj.Data.Model(order);
            scenario = obj.Data.Scenario(order);
            variable = obj.Data.Variable(order);
            region   = obj.Data.Region(order);
            unit     = obj.Data.Unit(order);
            runId    = obj.Data.RunId(order);
            version  = obj.Data.Version(order);
            year     = obj.Data.Year(order);
            value    = obj.Data.Value(order);
            g        = loc(order);

            % Build datetimes once, not per group.
            dt = datetime(year, 1, 1, 'Format', 'yyyy');

            % Block boundaries from the sorted group index.
            starts = find([true; diff(g) ~= 0]);
            stops  = [starts(2:end) - 1; numel(g)];

            data(nGroups, 1) = struct('model', "", 'scenario', "", ...
                'variable', "", 'region', "", 'unit', "", 'runId', NaN, ...
                'version', NaN, 'years', zeros(0,1), 'values', timetable());

            for i = 1 : nGroups
                s = starts(i);
                rng = s:stops(i);

                data(i).model    = model(s);
                data(i).scenario = scenario(s);
                data(i).variable = variable(s);
                data(i).region   = region(s);
                data(i).unit     = unit(s);
                data(i).runId    = runId(s);
                data(i).version  = version(s);
                data(i).years    = year(rng);
                data(i).values   = timetable(dt(rng), value(rng), ...
                    'DimensionNames', {'Year', 'VariableUnits'}, ...
                    'VariableNames', {'Values'});
            end

            ts = iam.IAMTimeseries(data);
        end
    end
end

function [ids, keys, uniqueKeys, loc] = identityGroups(data)
vars = identityVariables();
keys = identityComparisonTable(data(:, vars));
[uniqueKeys, ia, loc] = unique(keys, 'rows', 'stable');
ids = data(ia, vars);
end

function tb = defaultDataTable()
tb = table('Size', [0, 9], ...
    'VariableNames', {'Model', 'Scenario', 'Variable', 'Region', 'Unit', 'RunId', 'Version', 'Year', 'Value'}, ...
    'VariableTypes', {'string', 'string', 'string', 'string', 'string', 'double', 'double', 'double', 'double'});
end

function vars = identityVariables()
vars = {'Model', 'Scenario', 'Variable', 'Region', 'Unit', 'RunId', 'Version'};
end

function vars = observationIdentityVariables()
vars = {'Model', 'Scenario', 'Variable', 'Region', 'Unit', 'Version', 'Year'};
end

function value = uniqueOrEmpty(data, fieldName, emptyValue)
if isempty(data)
    value = emptyValue;
else
    value = unique(data.(fieldName));
end
end

function data = fromTimeseries(ts)
data = defaultDataTable();
if isempty(ts)
    return
end

numRows = sum(arrayfun(@(x) numel(x.Years), ts(:)));
model = strings(numRows, 1);
scenario = strings(numRows, 1);
variable = strings(numRows, 1);
region = strings(numRows, 1);
unit = strings(numRows, 1);
runId = NaN(numRows, 1);
version = NaN(numRows, 1);
yearValue = NaN(numRows, 1);
value = NaN(numRows, 1);

current = 1;
for i = 1 : numel(ts)
    years = normalizeAnnualYears(ts(i).Years(:));
    values = ts(i).Values{:,1};
    count = numel(years);
    idx = current:(current + count - 1);

    model(idx) = ts(i).Model;
    scenario(idx) = ts(i).Scenario;
    variable(idx) = ts(i).Variable;
    region(idx) = ts(i).Region;
    unit(idx) = ts(i).Unit;
    runId(idx) = ts(i).RunId;
    version(idx) = double(ts(i).Version(1));
    yearValue(idx) = years;
    value(idx) = values;

    current = current + count;
end

data = table(model, scenario, variable, region, unit, runId, version, yearValue, value, ...
    'VariableNames', data.Properties.VariableNames);
end

function data = normalizeDataTable(data)
required = ["Model", "Scenario", "Variable", "Region", "Unit", "Year", "Value"];
optional = ["RunId", "Version"];
present = string(data.Properties.VariableNames);
if ~all(ismember(required, present))
    error('iam:IAMFrame:InvalidTable', ...
        "IAMFrame table input must contain: " + strjoin(required, ", "))
end

unsupported = setdiff(present, [required, optional], 'stable');
if ~isempty(unsupported)
    error('iam:IAMFrame:UnsupportedColumns', ...
        "Unsupported IAMFrame table columns: " + strjoin(unsupported, ", "))
end

data.Model = normalizeTextColumn(data.Model, "Model");
data.Scenario = normalizeTextColumn(data.Scenario, "Scenario");
data.Variable = normalizeTextColumn(data.Variable, "Variable");
data.Region = normalizeTextColumn(data.Region, "Region");
data.Unit = normalizeTextColumn(data.Unit, "Unit");
data.Unit(ismissing(data.Unit)) = "";
missingIdentity = ismissing(data.Model) | strlength(data.Model) == 0 | ...
    ismissing(data.Scenario) | strlength(data.Scenario) == 0 | ...
    ismissing(data.Variable) | strlength(data.Variable) == 0 | ...
    ismissing(data.Region) | strlength(data.Region) == 0;
if any(missingIdentity)
    error('iam:IAMFrame:MissingIdentity', ...
        'Model, Scenario, Variable, and Region must be nonempty text.')
end

if ~ismember("RunId", present)
    data.RunId = NaN(height(data), 1);
end
if ~ismember("Version", present)
    data.Version = NaN(height(data), 1);
end
data.RunId = normalizeNumericColumn(data.RunId, "RunId", true);
data.Version = normalizeNumericColumn(data.Version, "Version", true);
data.Year = normalizeAnnualYears(data.Year);
data.Value = normalizeNumericColumn(data.Value, "Value", true);
if any(isinf(data.Value))
    error('iam:IAMFrame:InvalidValue', ...
        'Value entries may be finite or NaN, but not infinite.')
end

data = data(:, cellstr([required, optional]));
data = sortrows(data, {'Model', 'Scenario', 'Variable', 'Region', 'Unit', 'RunId', 'Version', 'Year'});
end

function values = normalizeTextColumn(values, name)
validType = isstring(values) || ischar(values) || iscellstr(values) || iscategorical(values);
if ~validType || (~ischar(values) && size(values, 2) ~= 1)
    error('iam:IAMFrame:InvalidTextColumn', ...
        name + " must contain text values.")
end
values = string(values);
end

function values = normalizeNumericColumn(values, name, allowMissing)
if ~isnumeric(values) || ~isreal(values) || size(values, 2) ~= 1
    error('iam:IAMFrame:InvalidNumericColumn', ...
        name + " must contain a real numeric column.")
end
values = double(values);
if any(isinf(values)) || (~allowMissing && any(isnan(values)))
    error('iam:IAMFrame:InvalidNumericColumn', ...
        name + " contains invalid or nonfinite values.")
end
end

function years = normalizeAnnualYears(years)
if ~isnumeric(years) || ~isreal(years) || size(years, 2) ~= 1
    error('iam:IAMFrame:InvalidYear', ...
        'Year values must be finite integer annual years.')
end
years = double(years);
if any(~isfinite(years)) || any(years ~= fix(years))
    error('iam:IAMFrame:InvalidYear', ...
        'Year values must be finite integer annual years.')
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

function years = normalizeYears(inputYears)
if isempty(inputYears)
    years = zeros(0,1);
    return
end

if isnumeric(inputYears)
    if ~isreal(inputYears)
        invalidYearSelector()
    end
    years = double(inputYears);
elseif isstring(inputYears) || ischar(inputYears) || iscellstr(inputYears)
    years = str2double(string(inputYears));
else
    invalidYearSelector()
end

if any(~isfinite(years), 'all') || any(years ~= fix(years), 'all')
    invalidYearSelector()
end
end

function invalidYearSelector()
error('iam:IAMFrame:InvalidYears', ...
    'Years must be finite integer annual years or empty.')
end

function rows = identityComparisonTable(rows)
% UNIQUE treats NaNs as distinct rows; negative infinity is reserved for
% missing optional numeric identity fields by the input contract.
names = rows.Properties.VariableNames;
for i = 1 : numel(names)
    if isnumeric(rows.(names{i}))
        values = rows.(names{i});
        values(isnan(values)) = -Inf;
        rows.(names{i}) = values;
    end
end
end

function runInfo = subsetRunInfo(runInfo, runIds)
if isempty(runInfo) || ~ismember('run_id', runInfo.Properties.VariableNames)
    return
end

runInfo = runInfo(ismember(runInfo.run_id, unique(runIds)), :);
end

function runInfo = mergeRunInfo(leftInfo, rightInfo)
if isempty(leftInfo)
    runInfo = rightInfo;
    return
end

if isempty(rightInfo)
    runInfo = leftInfo;
    return
end

if ~isequal(leftInfo.Properties.VariableNames, rightInfo.Properties.VariableNames)
    error('iam:IAMFrame:IncompatibleRunInfo', ...
        'Cannot append frames with incompatible RunInfo schemas.')
end

runInfo = [leftInfo; rightInfo];
if ismember('run_id', runInfo.Properties.VariableNames)
    [~, ia] = unique(runInfo.run_id, 'stable');
    runInfo = runInfo(ia, :);
else
    [~, ia] = unique(runInfo, 'rows', 'stable');
    runInfo = runInfo(ia, :);
end
end

function validateUniqueObservations(data)
if isempty(data)
    return
end
keys = identityComparisonTable(data(:, observationIdentityVariables()));
uniqueKeys = unique(keys, 'rows', 'stable');
if height(uniqueKeys) ~= height(data)
    error('iam:IAMFrame:DuplicateObservation', ...
        ['IAMFrame data contains duplicate observations for the same ' ...
         'model, scenario, version, variable, region, unit, and year.'])
end
end
