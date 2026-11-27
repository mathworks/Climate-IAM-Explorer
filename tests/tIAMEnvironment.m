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

            policyField = genvarname('Policy Status');
            metadata = struct();
            metadata.(policyField) = "Implemented";
            runIds = env.filterRuns('metadata', metadata);
            tc.verifyEqual(runIds, 1001)

            normalizedName = genvarname('Temperature Target');
            normalizedMetadata = struct();
            normalizedMetadata.(normalizedName) = 1.5;
            runIds = env.filterRuns('strict', true, 'metadata', normalizedMetadata);
            tc.verifyEqual(runIds, 1001)

            tc.verifyEqual(env.Metadata.(policyField).OriginalName, "Policy Status")
            tc.verifyTrue(isfield(env.RunList.metadata(2), normalizedName))
            tc.verifyTrue(isnan(env.RunList.metadata(2).(normalizedName)))
        end

        function testEmptyDiscoverySkipsDefaultTimeseriesRequest(tc)
            conn = MockIAMConnection('BulkDataResponse', buildMockTimeseries());
            env = iam.IAMEnvironment(conn);

            ts = env.getTimeSeries();

            tc.verifyClass(ts, "iam.IAMTimeseries")
            tc.verifyEmpty(ts)
            tc.verifyEmpty(fieldnames(conn.BulkDataRequest))
        end

        function testEmptyDiscoverySkipsDefaultFrameRequest(tc)
            conn = MockIAMConnection('BulkDataResponse', buildMockTimeseries());
            env = iam.IAMEnvironment(conn);

            frame = env.getFrame();

            tc.verifyClass(frame, "iam.IAMFrame")
            tc.verifyEmpty(frame.toTable())
            tc.verifyEmpty(frame.RunInfo)
            tc.verifyEmpty(fieldnames(conn.BulkDataRequest))
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

        function testGetTimeSeriesAcceptsNumericAndOmittedYears(tc)
            conn = buildMockConnection();
            env = iam.IAMEnvironment(conn);

            env.getTimeSeries('models', "Model A", 'years', [2020 2030]);
            tc.verifyEqual(conn.BulkDataRequest.years, [2020 2030])

            env.getTimeSeries('models', "Model A");
            tc.verifyEmpty(conn.BulkDataRequest.years)
        end

        function testGetFrameCollectsRunIDsAcrossMultipleSeries(tc)
            conn = buildMockConnection();
            conn.BulkDataResponse = [buildMockTimeseries(), buildMockTimeseries("Emissions")];
            env = iam.IAMEnvironment(conn);

            frame = env.getFrame('models', "Model A");

            tc.verifyEqual(height(frame.summary()), 2)
            tc.verifyEqual(frame.RunIds, 1001)
            tc.verifyEqual(frame.RunInfo.run_id, 1001)
        end

        function testGetFrameAcceptsConfiguredTypedEmptyResponse(tc)
            conn = buildMockConnection();
            conn.BulkDataResponse = iam.IAMTimeseries(struct.empty());
            conn.ReturnConfiguredBulkDataResponse = true;
            env = iam.IAMEnvironment(conn);

            frame = env.getFrame('models', "Model A");

            tc.verifyEmpty(frame.toTable())
            tc.verifyEmpty(frame.RunInfo)
        end

        function testNoMatchSkipsBulkDataRequest(tc)
            conn = buildMockConnection();
            env = iam.IAMEnvironment(conn);

            ts = env.getTimeSeries('models', "Missing Model");

            tc.verifyEmpty(ts)
            tc.verifyEmpty(fieldnames(conn.BulkDataRequest))
        end

        function testFilterRunsUsesNamedStrict(tc)
            conn = buildMockConnection();
            env = iam.IAMEnvironment(conn);
            filters = struct('PolicyStatus', "Implemented");

            runIds = env.filterRuns('metadata', filters, 'strict', true);
            appStyleRunIds = env.filterRuns('models', "Model A", 'strict', true);

            tc.verifyEqual(runIds, 1001)
            tc.verifyEqual(appStyleRunIds, 1001)
        end

        function testFilterRunsConvertsDropdownValues(tc)
            conn = buildMockConnection();
            env = iam.IAMEnvironment(conn);

            categoricalRunIds = env.filterRuns('models', categorical("Model A"), 'strict', true);
            cellRunIds = env.filterRuns('models', {'Model A'}, 'strict', true);

            tc.verifyEqual(categoricalRunIds, 1001)
            tc.verifyEqual(cellRunIds, 1001)
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
            tc.verifyFalse(ismember('PolicyStatus', frame.RunInfo.Properties.VariableNames))
        end

        function testGetFrameRestoresDamagedUnicodeScenario(tc)
            conn = buildMockConnection();
            conn.Runs.scenario(1) = "Below 2°C";
            conn.BulkDataResponse = buildMockTimeseries("Primary Energy", "Below 2?C");
            env = iam.IAMEnvironment(conn);

            frame = env.getFrame(models="Model A", strict=true);

            tc.verifyEqual(frame.Scenarios, "Below 2°C")
            tc.verifyEqual(frame.RunInfo.scenario, "Below 2°C")
        end

        function testGetFrameRejectsWrongScenarioIdentity(tc)
            conn = buildMockConnection();
            conn.BulkDataResponse = buildMockTimeseries("Primary Energy", "Different scenario");
            env = iam.IAMEnvironment(conn);

            tc.verifyError(@() env.getFrame(models="Model A", strict=true), ...
                "iam:IAMFrame:RunInfoIdentityMismatch")
        end

        function testIndexReturnsRunIdentity(tc)
            conn = buildMockConnection();
            env = iam.IAMEnvironment(conn);

            tb = env.index('models', "Model A");

            tc.verifyEqual(tb.model, "Model A")
            tc.verifyEqual(tb.scenario, "Scenario A")
            tc.verifyEqual(tb.version, 1)
        end

        function testMetaProjectsMetadataColumns(tc)
            conn = buildMockConnection();
            env = iam.IAMEnvironment(conn);

            tb = env.meta('fields', "Policy Status", 'run_id', true);

            tc.verifyTrue(ismember('PolicyStatus', tb.Properties.VariableNames))
            tc.verifyTrue(ismember('run_id', tb.Properties.VariableNames))
            tc.verifyEqual(tb.PolicyStatus, ["Implemented"; "Planned"])
        end

        function testMetaWithoutFieldsDoesNotProjectMetadata(tc)
            conn = buildMockConnection();
            env = iam.IAMEnvironment(conn);

            tb = env.meta();

            tc.verifyEqual(string(tb.Properties.VariableNames), ["model", "scenario", "version"])
        end

        function testMetaAllProjectsAllMetadataColumns(tc)
            conn = buildMockConnection();
            env = iam.IAMEnvironment(conn);

            tb = env.meta('fields', "all");

            tc.verifyTrue(all(ismember(["PolicyStatus", "TemperatureTarget"], string(tb.Properties.VariableNames))))
        end

        function testRunPropertiesReturnsAuditColumns(tc)
            conn = buildMockConnection();
            env = iam.IAMEnvironment(conn);

            tb = env.runProperties('models', "Model A");

            tc.verifyTrue(all(ismember({'cre_user', 'cre_date', 'upd_user', 'upd_date'}, ...
                tb.Properties.VariableNames)))
            tc.verifyEqual(tb.run_id, 1001)
        end

        function testGetFrameCanProjectMetadata(tc)
            conn = buildMockConnection();
            conn.BulkDataResponse = buildMockTimeseries();
            env = iam.IAMEnvironment(conn);

            frame = env.getFrame('models', "Model A", 'meta', "Temperature Target");

            tc.verifyTrue(ismember('TemperatureTarget', frame.RunInfo.Properties.VariableNames))
            tc.verifyEqual(frame.RunInfo.TemperatureTarget, 1.5)
        end

        function testGetFrameMetaAllProjectsAllMetadata(tc)
            conn = buildMockConnection();
            conn.BulkDataResponse = buildMockTimeseries();
            env = iam.IAMEnvironment(conn);

            frame = env.getFrame('models', "Model A", 'meta', "all");

            tc.verifyTrue(all(ismember(["PolicyStatus", "TemperatureTarget"], string(frame.RunInfo.Properties.VariableNames))))
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

function ts = buildMockTimeseries(variableName, scenarioName)
if nargin < 1
    variableName = "Primary Energy";
end
if nargin < 2
    scenarioName = "Scenario A";
end
years = [2020; 2030];
values = [1; 2];
tt = timetable(datetime(years, 1, 1, 'Format', 'yyyy'), values, ...
    'DimensionNames', {'Year', 'VariableUnits'}, 'VariableNames', {'Values'});

ts = iam.IAMTimeseries(struct( ...
    'model', "Model A", ...
    'scenario', scenarioName, ...
    'variable', variableName, ...
    'region', "World", ...
    'unit', "EJ/yr", ...
    'runId', 1001, ...
    'version', 1, ...
    'years', years, ...
    'values', tt));
end
