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
                data = fromTimeseries(data);
            elseif ~istable(data)
                error('iam:IAMFrame:InvalidInput', ...
                    'IAMFrame input must be a IAMTimeseries array or a table.')
            end

            obj.Data = normalizeDataTable(data);
            validateUniqueObservations(obj.Data);

            obj.RunInfo = nvp.RunInfo;
            validateRunInfoMapping(obj.RunInfo, obj.Data);
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
            runInfo = subsetRunInfo(obj.RunInfo, data);
            out = iam.IAMFrame(data, 'RunInfo', runInfo);
        end

        function out = append(obj, other, nvp)
            %append - Merge another frame using a shared conflict policy
            %   OUT = append(OBJ,OTHER) merges non-overlapping observations
            %   from OTHER into OBJ. Repeated observations raise an error.
            %
            %   OUT = append(OBJ,OTHER,RepeatPolicy=POLICY) selects how
            %   identical repeated observations are handled. POLICY is
            %   "error" or "deduplicate"; changed values always raise an
            %   error. Compatible RunInfo schemas are combined by column;
            %   ambiguous source IDs raise an error.
            arguments
                obj
                other
                nvp.RepeatPolicy {mustBeTextScalar} = "error"
            end

            repeatPolicy = string(nvp.RepeatPolicy);
            if ~ismember(repeatPolicy, ["error", "deduplicate"])
                error('iam:IAMFrame:InvalidRepeatPolicy', ...
                    'RepeatPolicy must be "error" or "deduplicate".')
            end

            if ~isa(other, 'iam.IAMFrame')
                other = iam.IAMFrame(other);
            end

            data = [obj.Data; other.Data];
            validateRunInfoMapping(obj.RunInfo, data);
            validateRunInfoMapping(other.RunInfo, data);
            [data, provenance] = mergeObservations(data, repeatPolicy);
            runInfo = mergeRunInfo(obj.RunInfo, other.RunInfo);
            if ~isempty(provenance)
                runInfo = mergeRunInfo(runInfo, provenance);
            end
            out = iam.IAMFrame(data, 'RunInfo', runInfo);
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
    tt = ts(i).Values;
    count = numel(years);
    if width(tt) ~= 1
        error("iam:IAMFrame:InvalidTimeseriesValues", ...
            "Each timeseries must contain exactly one numeric value column.")
    end
    if height(tt) ~= count
        error("iam:IAMFrame:InvalidTimeseriesLength", ...
            "Timeseries %d has %d years and %d value rows; their lengths must match.", ...
            i, count, height(tt))
    end
    values = normalizeNumericColumn(tt{:,1}, "Value", true);
    if ~isscalar(ts(i).Version)
        error("iam:IAMFrame:InvalidNumericColumn", ...
            "Version must contain one numeric value per timeseries.")
    end
    dates = tt.Properties.RowTimes;
    if ~isdatetime(dates) || any(isnat(dates)) || ...
            ~isequal(year(dates), years) || any(dates ~= dateshift(dates, "start", "year"))
        error("iam:IAMFrame:InvalidTimeseriesTime", ...
            "Timeseries row times must match Years and be January 1 at midnight.")
    end
    idx = current:(current + count - 1);

    model(idx) = ts(i).Model;
    scenario(idx) = ts(i).Scenario;
    variable(idx) = ts(i).Variable;
    region(idx) = ts(i).Region;
    unit(idx) = ts(i).Unit;
    runId(idx) = ts(i).RunId;
    version(idx) = ts(i).Version;
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

function runInfo = subsetRunInfo(runInfo, data)
if isempty(runInfo) || isempty(data)
    runInfo = runInfo([],:);
    return
end

runInfoNames = lower(string(runInfo.Properties.VariableNames));
identityNames = ["run_id", "model", "scenario", "version"];
dataNames = ["RunId", "Model", "Scenario", "Version"];
available = ismember(identityNames, runInfoNames);
if ~any(available)
    return
end

keep = false(height(runInfo), 1);
for i = 1 : height(runInfo)
    match = true(height(data), 1);
    hasAnalyticalKey = false;
    runIdMatch = true(height(data), 1);
    hasRunIdKey = false;
    for j = find(available)
        name = runInfo.Properties.VariableNames{find(runInfoNames == identityNames(j), 1)};
        value = runInfo.(name)(i);
        if isMissingMetadataValue(value)
            continue
        end
        if identityNames(j) == "run_id"
            hasRunIdKey = true;
            runIdMatch = matchMetadataIdentity(data.(dataNames(j)), value);
        else
            hasAnalyticalKey = true;
            match = match & matchMetadataIdentity(data.(dataNames(j)), value);
        end
    end
    if hasRunIdKey && hasAnalyticalKey
        keep(i) = any(match & (runIdMatch | isnan(data.RunId)));
    elseif hasRunIdKey
        keep(i) = any(match & runIdMatch);
    else
        keep(i) = hasAnalyticalKey && any(match);
    end
end
runInfo = runInfo(keep, :);
end

function runInfo = mergeRunInfo(leftInfo, rightInfo)
leftInfo = normalizeRunInfoIdentityNames(leftInfo);
rightInfo = normalizeRunInfoIdentityNames(rightInfo);
leftNames = string(leftInfo.Properties.VariableNames);
rightNames = string(rightInfo.Properties.VariableNames);
names = [leftNames, rightNames(~ismember(rightNames, leftNames))];
if isempty(names)
    runInfo = table();
    return
end

leftAligned = table();
rightAligned = table();
for name = names
    hasLeft = ismember(name, leftNames);
    hasRight = ismember(name, rightNames);
    if hasLeft && hasRight
        [leftColumn, rightColumn] = harmonizeMetadataColumns( ...
            leftInfo.(name), rightInfo.(name), name);
    elseif hasLeft
        leftColumn = normalizeMetadataColumn(leftInfo.(name), name);
        rightColumn = missingMetadataColumn(leftColumn, height(rightInfo), name);
    else
        rightColumn = normalizeMetadataColumn(rightInfo.(name), name);
        leftColumn = missingMetadataColumn(rightColumn, height(leftInfo), name);
    end
    leftAligned.(name) = leftColumn;
    rightAligned.(name) = rightColumn;
end

rows = [leftAligned; rightAligned];
identityNames = lower(string(rows.Properties.VariableNames));
keyNames = intersect(["run_id", "model", "scenario", "version"], ...
    identityNames, 'stable');
runInfo = rows;
outputCount = 0;
for i = 1 : height(rows)
    match = findRunInfoMatch(runInfo(1:outputCount,:), rows(i,:), keyNames);
    if isempty(match)
        outputCount = outputCount + 1;
        runInfo(outputCount,:) = rows(i,:);
    else
        runInfo(match,:) = mergeRunInfoRow(runInfo(match,:), rows(i,:), keyNames);
    end
end
runInfo = runInfo(1:outputCount, :);
end

function runInfo = normalizeRunInfoIdentityNames(runInfo)
names = string(runInfo.Properties.VariableNames);
identityColumns = ismember(lower(names), ["run_id","model","scenario","version"]);
names(identityColumns) = lower(names(identityColumns));
if numel(unique(names)) ~= numel(names)
    error('iam:IAMFrame:IncompatibleRunInfo', ...
        'RunInfo contains duplicate case-insensitive identity columns.')
end
runInfo.Properties.VariableNames = cellstr(names);
end

function validateRunInfoMapping(runInfo, data)
if isempty(runInfo) || isempty(data)
    return
end

runInfoNames = lower(string(runInfo.Properties.VariableNames));
runIdIndex = find(runInfoNames == "run_id", 1);
if isempty(runIdIndex)
    return
end
runIdName = runInfo.Properties.VariableNames{runIdIndex};
runIds = unique(runInfo.(runIdName));
runIds = runIds(~isnan(runIds));
identityNames = ["model", "scenario", "version"];
dataNames = ["Model", "Scenario", "Version"];
available = ismember(identityNames, runInfoNames);

for runId = runIds(:)'
    dataRows = data(~isnan(data.RunId) & data.RunId == runId, :);
    if isempty(dataRows)
        continue
    end
    trajectories = unique(identityComparisonTable( ...
        dataRows(:, {'Model', 'Scenario', 'Version'})), 'rows', 'stable');
    infoRows = runInfo(runInfo.(runIdName) == runId, :);
    for i = 1 : height(infoRows)
        matchesTrajectory = true(height(trajectories), 1);
        hasIdentity = false;
        for j = find(available)
            name = runInfo.Properties.VariableNames{find( ...
                runInfoNames == identityNames(j), 1)};
            value = infoRows.(name)(i);
            if isMissingMetadataValue(value)
                continue
            end
            hasIdentity = true;
            matchesTrajectory = matchesTrajectory & ...
                matchMetadataIdentity(trajectories.(dataNames(j)), value);
        end
        matchCount = nnz(matchesTrajectory);
        if matchCount == 0
            error('iam:IAMFrame:RunInfoIdentityMismatch', ...
                'RunInfo identity does not match data for RunId %.15g.', runId)
        elseif matchCount > 1 && hasIdentity
            error('iam:IAMFrame:AmbiguousRunInfo', ...
                ['RunInfo for RunId %.15g does not identify one model, ' ...
                 'scenario, and version.'], runId)
        elseif matchCount > 1
            error('iam:IAMFrame:AmbiguousRunInfo', ...
                ['RunInfo for RunId %.15g has no analytical identity and ' ...
                 'matches multiple scenarios.'], runId)
        end
    end
end
end

function [data, provenance] = mergeObservations(data, repeatPolicy)
provenance = table();
if isempty(data)
    return
end

keys = identityComparisonTable(data(:, observationIdentityVariables()));
[uniqueKeys, ~, group] = unique(keys, 'rows', 'stable');
counts = accumarray(group, 1, [height(uniqueKeys), 1]);
duplicateGroups = find(counts > 1);
if isempty(duplicateGroups)
    return
end

keep = true(height(data), 1);
provenanceMask = false(height(data), 1);
originalRunIds = data.RunId;
for groupId = duplicateGroups'
    rows = find(group == groupId);
    observation = observationDescription(data(rows(1), :));
    values = data.Value(rows);
    if any(~arrayfun(@(value) isequaln(value, values(1)), values))
        error('iam:IAMFrame:ConflictingObservation', ...
            "Repeated observation has changed values: " + observation)
    end
    if repeatPolicy == "error"
        error('iam:IAMFrame:DuplicateObservation', ...
            "Repeated observation: " + observation + ...
            '. Set RepeatPolicy="deduplicate" to collapse identical values.')
    end

    sourceIds = data.RunId(rows);
    sourceIds = sourceIds(~isnan(sourceIds));
    if isempty(sourceIds)
        data.RunId(rows(1)) = NaN;
    elseif all(sourceIds == sourceIds(1))
        data.RunId(rows(1)) = sourceIds(1);
    else
        provenanceMask(rows(~isnan(originalRunIds(rows)))) = true;
        data.RunId(rows(1)) = NaN;
    end
    keep(rows(2:end)) = false;
end
if any(provenanceMask)
    provenance = data(provenanceMask, {'Model','Scenario','Version','RunId'});
    provenance.RunId = originalRunIds(provenanceMask);
    provenance.Properties.VariableNames = {'model','scenario','version','run_id'};
    [~, first] = unique(identityComparisonTable(provenance), 'rows', 'stable');
    provenance = provenance(first,:);
end
data = data(keep, :);
end

function [left, right] = harmonizeMetadataColumns(left, right, name)
left = normalizeMetadataColumn(left, name);
right = normalizeMetadataColumn(right, name);
if ~strcmp(class(left), class(right))
    error('iam:IAMFrame:IncompatibleRunInfo', ...
        "RunInfo column '" + name + "' has incompatible types " + ...
        class(left) + " and " + class(right) + ".")
end
if isdatetime(left) && ~strcmp(left.TimeZone, right.TimeZone)
    if isempty(left.TimeZone) && all(isnat(left))
        left.TimeZone = right.TimeZone;
    elseif isempty(right.TimeZone) && all(isnat(right))
        right.TimeZone = left.TimeZone;
    elseif isempty(left.TimeZone) || isempty(right.TimeZone)
        error('iam:IAMFrame:IncompatibleRunInfo', ...
            "RunInfo column '" + name + "' mixes zoned and unzoned timestamps.")
    end
    right.TimeZone = left.TimeZone;
end
end

function values = normalizeMetadataColumn(values, name)
if ~ischar(values) && (~ismatrix(values) || ...
        (size(values,2) ~= 1 && ~isequal(size(values), [0 0])))
    error('iam:IAMFrame:IncompatibleRunInfo', ...
        "RunInfo column '" + name + "' must contain one value per row; array columns are unsupported.")
end
if ischar(values)
    if size(values,1) == 0
        values = strings(0,1);
    else
        values = string(values);
    end
elseif iscategorical(values) || (iscellstr(values) && ~isempty(values))
    values = string(values);
elseif isstring(values)
    values = values(:);
elseif isnumeric(values) || islogical(values)
    values = double(values(:));
elseif isstruct(values)
    values = num2cell(values(:));
elseif isdatetime(values) || isduration(values) || iscell(values)
    values = values(:);
else
    error('iam:IAMFrame:IncompatibleRunInfo', ...
        "RunInfo column '" + name + "' has unsupported type " + class(values) + ".")
end
end

function values = missingMetadataColumn(template, count, name)
if isstring(template)
    values = repmat(string(missing), count, 1);
elseif isnumeric(template)
    values = NaN(count, 1);
elseif isdatetime(template)
    values = NaT(count, 1, 'TimeZone', template.TimeZone);
elseif isduration(template)
    values = seconds(NaN(count, 1));
elseif iscell(template)
    values = cell(count, 1);
else
    error('iam:IAMFrame:IncompatibleRunInfo', ...
        "RunInfo column '" + name + "' cannot represent missing values.")
end
end

function match = findRunInfoMatch(existing, candidate, keyNames)
match = [];
if isempty(existing)
    return
end

if isempty(keyNames)
    for i = 1 : height(existing)
        if metadataRowsEqual(existing(i,:), candidate)
            match = i;
            return
        end
    end
    return
end

for i = 1 : height(existing)
    sharedRunId = false;
    sameIdentity = true;
    sharedModel = false;
    sharedScenario = false;
    for name = keyNames
        columnName = existing.Properties.VariableNames{find( ...
            lower(string(existing.Properties.VariableNames)) == name, 1)};
        leftValue = existing.(columnName)(i);
        rightValue = candidate.(columnName);
        if isMissingMetadataValue(leftValue) || isMissingMetadataValue(rightValue)
            continue
        end
        if ~isequaln(leftValue, rightValue)
            sameIdentity = false;
            break
        end
        sharedRunId = sharedRunId || name == "run_id";
        sharedModel = sharedModel || name == "model";
        sharedScenario = sharedScenario || name == "scenario";
    end
    analyticalKeys = keyNames(keyNames ~= "run_id");
    if sameIdentity && (sharedRunId || (sharedModel && sharedScenario && ...
            metadataRowsEqual(existing(i,:), candidate, analyticalKeys)))
        if ~isempty(match)
            error('iam:IAMFrame:AmbiguousRunInfo', ...
                'A partial RunInfo identity matches multiple source records.')
        end
        match = i;
    end
end
end

function merged = mergeRunInfoRow(existing, candidate, keyNames)
merged = existing;
allNames = string(existing.Properties.VariableNames);
identity = metadataIdentityDescription(existing, keyNames);
for name = allNames
    merged.(name) = mergeMetadataValues(existing.(name), candidate.(name), ...
        "RunInfo for " + identity + ", column '" + name + "'");
end
end

function value = mergeMetadataValues(left, right, description)
value = left;
if isMissingMetadataValue(left)
    value = right;
elseif isMissingMetadataValue(right)
    return
elseif iscell(left) && iscell(right) && isscalar(left) && isscalar(right)
    value = {mergeMetadataValues(left{1}, right{1}, description)};
elseif isstruct(left) && isstruct(right) && isscalar(left) && isscalar(right)
    for name = string(fieldnames(right))'
        if isfield(left, name)
            value.(name) = mergeMetadataValues(left.(name), right.(name), ...
                description + "." + name);
        else
            value.(name) = right.(name);
        end
    end
elseif ~isequaln(left, right)
    if (ischar(left) || isstring(left) || iscategorical(left)) && ...
            (ischar(right) || isstring(right) || iscategorical(right)) && ...
            isequaln(string(left), string(right))
        return
    end
    error('iam:IAMFrame:IncompatibleRunInfo', ...
        "Conflicting metadata in " + description + ".")
end
end

function tf = metadataRowsEqual(left, right, names)
if nargin < 3
    names = string(left.Properties.VariableNames);
end
tf = true;
for name = names
    if ~isequaln(left.(name), right.(name))
        tf = false;
        return
    end
end
end

function tf = isMissingMetadataValue(value)
if isempty(value)
    tf = true;
elseif iscell(value)
    tf = isscalar(value) && isMissingMetadataValue(value{1});
elseif isstruct(value)
    tf = isempty(value) || (isscalar(value) && isempty(fieldnames(value)));
elseif isnumeric(value)
    tf = isscalar(value) && isnan(value);
elseif isstring(value)
    tf = isscalar(value) && ismissing(value);
elseif isdatetime(value)
    tf = isscalar(value) && isnat(value);
elseif isduration(value)
    tf = isscalar(value) && isnan(seconds(value));
elseif iscategorical(value)
    tf = isscalar(value) && isundefined(value);
else
    tf = isempty(value);
end
end

function tf = matchMetadataIdentity(dataValues, runInfoValue)
if iscell(dataValues)
    dataValues = string(dataValues);
end
if isstring(dataValues) || ischar(dataValues) || iscategorical(dataValues)
    tf = matches(string(dataValues), string(runInfoValue));
elseif isnumeric(dataValues) || islogical(dataValues)
    value = double(runInfoValue);
    values = double(dataValues);
    tf = values == value | (isnan(values) & isnan(value));
else
    tf = arrayfun(@(value) isequaln(value, runInfoValue), dataValues);
end
end

function description = observationDescription(row)
description = "Model=" + row.Model + ", Scenario=" + row.Scenario + ...
    ", Version=" + string(row.Version) + ", Variable=" + row.Variable + ...
    ", Region=" + row.Region + ", Unit=" + row.Unit + ...
    ", Year=" + string(row.Year);
end

function description = metadataIdentityDescription(row, keyNames)
parts = strings(numel(keyNames), 1);
for i = 1 : numel(keyNames)
    name = keyNames(i);
    columnName = row.Properties.VariableNames{find( ...
        lower(string(row.Properties.VariableNames)) == name, 1)};
    value = string(row.(columnName));
    value(ismissing(value)) = "missing";
    parts(i) = name + "=" + value;
end
description = strjoin(parts, ", ");
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
