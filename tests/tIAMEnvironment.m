classdef tIAMEnvironment < matlab.unittest.TestCase

    methods (Test, TestTags = {'Unit'})

        function testEmptyEnvironmentSetup(tc)
            conn = MockIAMConnection( ...
                'Refs', struct(), ...
                'Runs', table(), ...
                'MetadataCategories', table());

            env = iam.IAMEnvironment(conn);

            tc.verifyEmpty(env.Models)
            tc.verifyEmpty(env.Scenarios)
            tc.verifyEmpty(env.Variables)
            tc.verifyEmpty(env.Regions)
            tc.verifyEmpty(env.RunList)
            tc.verifyTrue(isstruct(env.Metadata))
            tc.verifyEmpty(fieldnames(env.Metadata))
        end

        function testMetadataFilteringSupportsNormalizedNames(tc)
            conn = buildMockConnection();
            env = iam.IAMEnvironment(conn);

            policyField = matlab.lang.makeValidName('Policy Status');
            metadata = struct();
            metadata.(policyField) = "Implemented";
            runIds = env.filterRuns('metadata', metadata);
            tc.verifyEqual(runIds, 1001)

            normalizedName = matlab.lang.makeValidName('Temperature Target');
            normalizedMetadata = struct();
            normalizedMetadata.(normalizedName) = 1.5;
            runIds = env.filterRuns('metadata', normalizedMetadata, 'strict', true);
            tc.verifyEqual(runIds, 1001)

            tc.verifyEqual(env.Metadata.(policyField).OriginalName, "Policy Status")
            tc.verifyTrue(isfield(env.RunList.metadata(2), normalizedName))
            tc.verifyTrue(isnan(env.RunList.metadata(2).(normalizedName)))
        end

        function testGetTimeSeriesForwardsAdditionalFilters(tc)
            conn = buildMockConnection();
            env = iam.IAMEnvironment(conn);

            env.getTimeSeries( ...
                'models', "Model A", ...
                'scenarios', "Scenario A", ...
                'variables', "Primary Energy", ...
                'regions', "World", ...
                'years', ["2020", "2030"], ...
                'units', "EJ/yr", ...
                'timeslices', "Year");

            tc.verifyEqual(conn.BulkDataRequest.runs, 1001)
            tc.verifyEqual(conn.BulkDataRequest.variables, "Primary Energy")
            tc.verifyEqual(conn.BulkDataRequest.regions, "World")
            tc.verifyEqual(conn.BulkDataRequest.years, ["2020", "2030"])
            tc.verifyEqual(conn.BulkDataRequest.units, "EJ/yr")
            tc.verifyEqual(conn.BulkDataRequest.timeslices, "Year")
        end

        function testGetFrameReturnsIAMFrame(tc)
            conn = buildMockConnection();
            conn.BulkDataResponse = buildMockTimeseries();
            env = iam.IAMEnvironment(conn);

            frame = env.getFrame('models', "Model A", 'variables', "Primary Energy");

            tc.verifyClass(frame, 'iam.IAMFrame')
            tc.verifyEqual(height(frame.summary()), 1)
            tc.verifyEqual(frame.RunIds, 1001)
            tc.verifyEqual(height(frame.RunInfo), 1)
        end

        function testFilterRegionsSupportsMultipleSelections(tc)
            conn = buildMockConnection();
            env = iam.IAMEnvironment(conn);

            regions = env.filterRegions(["World", "Europe"], true);

            tc.verifyEqual(regions, ["World"; "Europe"])
        end

        function testFilterRegionsSupportsMultipleWildcardSelections(tc)
            conn = buildMockConnection();
            env = iam.IAMEnvironment(conn);

            regions = sort(env.filterRegions(["Wor*", "Eur*"], true));

            tc.verifyEqual(regions, ["Europe"; "World"])
        end
    end
end

function conn = buildMockConnection()
refs = struct();
refs.models = table([1; 2], ["Model A"; "Model B"], 'VariableNames', {'ID', 'Name'});
refs.scenarios = table([11; 12], ["Scenario A"; "Scenario B"], 'VariableNames', {'ID', 'Name'});
refs.variables = table([21; 22], ["Primary Energy"; "Emissions"], [31; 32], ["EJ/yr"; "Mt CO2"], ...
    'VariableNames', {'ID', 'Name', 'Unit ID', 'Unit'});
refs.regions = table([41; 42], ["World"; "Europe"], ["common"; "common"], ["World"; "World"], ["";
    ""], 'VariableNames', {'ID', 'Name', 'Hyerarchy', 'Parent', 'Synonyms'});

metadata = { ...
    struct('PolicyStatus', "Implemented", 'TemperatureTarget', 1.5); ...
    struct('PolicyStatus', "Planned")};

runs = table( ...
    ["Model A"; "Model B"], ...
    ["Scenario A"; "Scenario B"], ...
    [1; 1], ...
    ["a"; "b"], ...
    metadata, ...
    [1001; 1002], ...
    [1; 2], ...
    [11; 12], ...
    [true; true], ...
    [false; false], ...
    ["user"; "user"], ...
    ["2024-01-01"; "2024-01-02"], ...
    [0; 0], ...
    [0; 0], ...
    [0; 0], ...
    [0; 0], ...
    [1; 1], ...
    'VariableNames', {'model', 'scenario', 'scheme', 'annotation', 'metadata', 'run_id', 'model_id', 'scen_id', 'is_default', 'is_locked', 'cre_user', 'cre_date', 'upd_user', 'upd_date', 'lock_user', 'lock_date', 'version'});

metadataCategories = table( ...
    ["Policy Status"; "Temperature Target"], ...
    ["string value"; "numeric value"], ...
    'VariableNames', {'name', 'type'});

conn = MockIAMConnection( ...
    'Refs', refs, ...
    'Runs', runs, ...
    'MetadataCategories', metadataCategories);
end

function ts = buildMockTimeseries()
years = [2020; 2030];
values = [1; 2];
tt = timetable(datetime(years, 1, 1, 'Format', 'yyyy'), values, ...
    'DimensionNames', {'Year', 'VariableUnits'}, 'VariableNames', {'Values'});

ts = iam.IAMTimeseries(struct( ...
    'model', "Model A", ...
    'scenario', "Scenario A", ...
    'variable', "Primary Energy", ...
    'region', "World", ...
    'unit', "EJ/yr", ...
    'runId', 1001, ...
    'version', 1, ...
    'years', years, ...
    'values', tt));
end
