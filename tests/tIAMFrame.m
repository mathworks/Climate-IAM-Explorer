classdef tIAMFrame < matlab.unittest.TestCase

    properties (TestParameter)
        ExplicitFactor = struct('integer',int32(2),'single',single(2))
        SourceIdName = struct('api',"run_id",'matlab',"RunId")
        InvalidYear = struct( ...
            'missing', NaN, ...
            'infinite', Inf, ...
            'fractional', 2020.5)
        InvalidYearSelector = struct( ...
            'malformedText', "not-a-year", ...
            'infinite', Inf, ...
            'fractional', 2020.5)
        InvalidTimeseriesIdentity = struct( ...
            'emptyModel', struct('Field', "model", 'Value', ""), ...
            'missingModel', struct('Field', "model", 'Value', string(missing)), ...
            'emptyScenario', struct('Field', "scenario", 'Value', ""), ...
            'missingScenario', struct('Field', "scenario", 'Value', string(missing)), ...
            'emptyVariable', struct('Field', "variable", 'Value', ""), ...
            'missingVariable', struct('Field', "variable", 'Value', string(missing)), ...
            'emptyRegion', struct('Field', "region", 'Value', ""), ...
            'missingRegion', struct('Field', "region", 'Value', string(missing)))
        InvalidTimeseriesValue = struct( ...
            'infinite', Inf, 'complex', 1 + 1i, 'text', "invalid")
        InvalidTimeseriesProvenance = struct( ...
            'infiniteRunId', struct('Field', "runId", 'Value', Inf), ...
            'infiniteVersion', struct('Field', "version", 'Value', Inf), ...
            'multipleVersions', struct('Field', "version", 'Value', [1; 2]), ...
            'emptyVersion', struct('Field', "version", 'Value', zeros(0,1)))
        InvalidTimeseriesLayout = struct( ...
            'scalarValues', "scalarValues", ...
            'emptyYears', "emptyYears", ...
            'emptyValues', "emptyValues", ...
            'multipleColumns', "multipleColumns", ...
            'matrixColumn', "matrixColumn")
    end

    methods (Test, TestTags = {'Unit'})
        function testToTableAndSummary(tc)
            frame = iam.IAMFrame(buildSampleTimeseries());

            tc.verifyEqual(height(frame.toTable()), 6)
            tc.verifyEqual(height(frame.summary()), 2)
            tc.verifyEqual(frame.Models, ["Model A"; "Model B"])
            tc.verifyEqual(frame.Years, [2020; 2030; 2040])
        end

        function testFilterSupportsStrictAndRelaxedMatches(tc)
            frame = iam.IAMFrame(buildSampleTimeseries());

            filtered = frame.filter('models', "model a", 'strict', true);
            tc.verifyEqual(filtered.Models, "Model A")

            filtered = frame.filter('variables', "Primary", 'strict', false);
            tc.verifyEqual(filtered.Variables, "Primary Energy")

            filtered = frame.filter('regions', "Wor*", 'strict', true);
            tc.verifyEqual(filtered.Regions, "World")

            filtered = frame.filter('years', [2030 2040]);
            tc.verifyEqual(filtered.Years, [2030; 2040])
        end

        function testTimeseriesReturnsWideTable(tc)
            frame = iam.IAMFrame(buildSampleTimeseries());

            wide = frame.timeseries();

            tc.verifyEqual(height(wide), 2)
            tc.verifyTrue(all(ismember(["Y2020", "Y2030", "Y2040"], string(wide.Properties.VariableNames))))
            tc.verifyEqual(wide.Y2030(1), 2)
            tc.verifyEqual(wide.Y2040(2), 30)
        end

        function testRoundTripToTimeseries(tc)
            ts = buildSampleTimeseries();
            frame = iam.IAMFrame(ts);
            roundTrip = frame.toTimeseries();

            tc.verifyNumElements(roundTrip, 2)
            tc.verifyEqual(roundTrip(1).Model, ts(1).Model)
            tc.verifyEqual(roundTrip(2).Years, ts(2).Years)
            tc.verifyEqual(roundTrip(1).Values{:,:}, ts(1).Values{:,:})
        end

        function testConstructFromEmptyTimeseries(tc)
            frame = iam.IAMFrame(iam.IAMTimeseries([]));

            tc.verifyEmpty(frame.toTable())
            tc.verifyEmpty(frame.summary())
        end

        function testAppendRejectsDuplicateObservations(tc)
            frame = iam.IAMFrame(buildSampleTimeseries());

            tc.verifyError(@() frame.append(frame), 'iam:IAMFrame:DuplicateObservation')
        end

        function testAppendMergesDistinctFrames(tc)
            frame1 = iam.IAMFrame(buildSampleTimeseries(1));
            frame2 = iam.IAMFrame(buildSampleTimeseries(2));

            merged = frame1.append(frame2);

            tc.verifyEqual(height(merged.summary()), 2)
            tc.verifyEqual(merged.RunIds, [101; 202])
        end

        function testAppendDeduplicatesIdenticalObservationsAndUnionsRunInfo(tc)
            leftInfo = table("Model", "Baseline", 1, 11, "Source A", false, ...
                VariableNames=["model", "scenario", "version", "run_id", ...
                "Source", "is_default"]);
            rightInfo = table("Model", "Baseline", 1, 22, 1.5, ...
                VariableNames=["model", "scenario", "version", "run_id", ...
                "TemperatureTarget"]);
            left = singleObservationFrame("Baseline", 11, 5, leftInfo);
            right = singleObservationFrame("Baseline", 22, 5, rightInfo);

            merged = left.append(right, RepeatPolicy="deduplicate");
            filtered = merged.filter(scenarios="Baseline", strict=true);

            tc.verifyEqual(height(merged.toTable()), 1)
            tc.verifyTrue(isnan(merged.toTable().RunId))
            tc.verifyEqual(height(merged.RunInfo), 2)
            tc.verifyEqual(merged.RunInfo.TemperatureTarget(2), 1.5)
            tc.verifyEqual(merged.RunInfo.is_default(1), 0)
            tc.verifyTrue(isnan(merged.RunInfo.is_default(2)))
            tc.verifyEqual(merged.RunInfo.Source(1), "Source A")
            tc.verifyTrue(ismissing(merged.RunInfo.Source(2)))
            tc.verifyEqual(height(filtered.RunInfo), 2)
        end

        function testAppendRejectsChangedRepeatedValue(tc)
            left = singleObservationFrame("Baseline", 11, 5, table());
            right = singleObservationFrame("Baseline", 22, 6, table());

            tc.verifyError(@() left.append(right, ...
                RepeatPolicy="deduplicate"), ...
                "iam:IAMFrame:ConflictingObservation")
        end

        function testAppendRejectsConflictingRunInfoValues(tc)
            leftInfo = table("Model", "Baseline", 1, 11, "Policy A", ...
                VariableNames=["model", "scenario", "version", "run_id", "Policy"]);
            rightInfo = table("Model", "Baseline", 1, 11, "Policy B", ...
                VariableNames=["model", "scenario", "version", "run_id", "Policy"]);
            left = singleObservationFrame("Baseline", 11, 5, leftInfo);
            right = singleObservationFrame("Baseline", 11, 6, rightInfo, 2030);

            tc.verifyError(@() left.append(right), ...
                "iam:IAMFrame:IncompatibleRunInfo")
        end

        function testRunInfoRunIdCollisionStaysWithItsScenario(tc)
            firstInfo = table("Model", "Scenario A", 1, 7, "First", ...
                VariableNames=["model", "scenario", "version", "run_id", "Category"]);
            secondInfo = table("Model", "Scenario B", 1, 7, "Second", ...
                VariableNames=["model", "scenario", "version", "run_id", "Category"]);
            first = singleObservationFrame("Scenario A", 7, 5, firstInfo);
            second = singleObservationFrame("Scenario B", 7, 8, secondInfo);

            merged = first.append(second);
            scenarioA = merged.filter(scenarios="Scenario A", strict=true);
            scenarioB = merged.filter(scenarios="Scenario B", strict=true);

            tc.verifyEqual(height(merged.RunInfo), 2)
            tc.verifyEqual(scenarioA.RunInfo.Category, "First")
            tc.verifyEqual(scenarioB.RunInfo.Category, "Second")
        end

        function testAppendRejectsAmbiguousProviderRunIdMetadata(tc)
            runInfo = table(7, "Shared", ...
                VariableNames=["run_id", "Category"]);
            first = singleObservationFrame("Scenario A", 7, 5, runInfo);
            second = singleObservationFrame("Scenario B", 7, 8, runInfo);

            tc.verifyError(@() first.append(second), ...
                "iam:IAMFrame:AmbiguousRunInfo")
        end

        function testAppendAcceptsEnvironmentNestedMetadata(tc)
            info = table("Model", "Baseline", 1, 7, ...
                struct('Category', "A"), ...
                VariableNames=["model","scenario","version","run_id","metadata"]);
            source = singleObservationFrame("Baseline", 7, 5, info);
            conn = MockIAMConnection('Runs', info, ...
                'BulkDataResponse', source.toTimeseries(), ...
                'MetadataCategories', table("Category", "string value", ...
                VariableNames=["name","type"]));
            env = iam.IAMEnvironment(conn);
            downloaded = env.getFrame(meta="all");

            merged = iam.IAMFrame().append(downloaded);

            tc.verifyEqual(merged.toTable(), downloaded.toTable())
            tc.verifyEqual(merged.RunInfo.metadata{1}.Category, "A")
            tc.verifyEqual(merged.RunInfo.Category, "A")
        end

        function testAppendMergesNestedMetadataFields(tc)
            leftInfo = table(7, struct('Policy', struct('Category', "A")), ...
                VariableNames=["run_id","metadata"]);
            rightInfo = table(7, struct('Policy', struct('Target', 1.5)), ...
                VariableNames=["run_id","metadata"]);
            left = singleObservationFrame("Baseline", 7, 5, leftInfo);
            right = singleObservationFrame("Baseline", 7, 6, rightInfo, 2030);

            merged = left.append(right);

            tc.verifyEqual(height(merged.RunInfo), 1)
            tc.verifyEqual(merged.RunInfo.metadata{1}.Policy, ...
                struct('Category', "A", 'Target', 1.5))
        end

        function testAppendRejectsNestedMetadataConflict(tc)
            leftInfo = table(7, struct('Policy', struct('Category', "A")), ...
                VariableNames=["run_id","metadata"]);
            rightInfo = table(7, struct('Policy', struct('Category', "B")), ...
                VariableNames=["run_id","metadata"]);
            left = singleObservationFrame("Baseline", 7, 5, leftInfo);
            right = singleObservationFrame("Baseline", 7, 6, rightInfo, 2030);

            tc.verifyError(@() left.append(right), "iam:IAMFrame:IncompatibleRunInfo")
        end

        function testAppendMatchesCompatibleNestedTextTypes(tc)
            leftInfo = table(7, struct('Category', "A"), ...
                VariableNames=["run_id","metadata"]);
            rightInfo = table(7, struct('Category', char("A")), ...
                VariableNames=["run_id","metadata"]);
            left = singleObservationFrame("Baseline", 7, 5, leftInfo);
            right = singleObservationFrame("Baseline", 7, 6, rightInfo, 2030);

            merged = left.append(right);

            tc.verifyEqual(height(merged.RunInfo), 1)
            tc.verifyEqual(merged.RunInfo.metadata{1}.Category, "A")
        end

        function testAppendFillsMissingNestedMetadata(tc)
            leftInfo = table(7, {[]}, VariableNames=["run_id","metadata"]);
            rightInfo = table(7, struct('Category', "A"), ...
                VariableNames=["run_id","metadata"]);
            left = singleObservationFrame("Baseline", 7, 5, leftInfo);
            right = singleObservationFrame("Baseline", 7, 6, rightInfo, 2030);

            merged = left.append(right);

            tc.verifyEqual(merged.RunInfo.metadata{1}, struct('Category', "A"))
        end

        function testAppendRejectsConflictWithPartialRunInfoIdentity(tc)
            leftInfo = table(7, "A", VariableNames=["run_id","Category"]);
            rightInfo = table("Model", "Baseline", 1, 7, "B", ...
                VariableNames=["model","scenario","version","run_id","Category"]);
            left = singleObservationFrame("Baseline", 7, 5, leftInfo);
            right = singleObservationFrame("Baseline", 7, 6, rightInfo, 2030);

            tc.verifyError(@() left.append(right), "iam:IAMFrame:IncompatibleRunInfo")
            tc.verifyError(@() right.append(left), "iam:IAMFrame:IncompatibleRunInfo")
        end

        function testAppendCombinesCompatiblePartialRunInfoIdentity(tc)
            leftInfo = table(7, "A", VariableNames=["run_id","Category"]);
            rightInfo = table("Model", "Baseline", 1, 7, 1.5, ...
                VariableNames=["model","scenario","version","run_id","Target"]);
            left = singleObservationFrame("Baseline", 7, 5, leftInfo);
            right = singleObservationFrame("Baseline", 7, 6, rightInfo, 2030);

            merged = left.append(right);

            tc.verifyEqual(height(merged.RunInfo), 1)
            tc.verifyEqual(merged.RunInfo.Category, "A")
            tc.verifyEqual(merged.RunInfo.Target, 1.5)
            tc.verifyEqual(merged.RunInfo.model, "Model")
            tc.verifyEqual(merged.RunInfo.scenario, "Baseline")
        end

        function testAppendCombinesCaseInsensitiveIdentityColumns(tc)
            leftInfo = table("Model", "Baseline", 1, 7, "A", ...
                VariableNames=["Model","Scenario","Version","Run_ID","Category"]);
            rightInfo = table("Model", "Baseline", 1, 7, 1.5, ...
                VariableNames=["model","scenario","version","run_id","Target"]);
            left = singleObservationFrame("Baseline", 7, 5, leftInfo);
            right = singleObservationFrame("Baseline", 7, 6, rightInfo, 2030);

            merged = left.append(right);

            tc.verifyEqual(height(merged.RunInfo), 1)
            tc.verifyEqual(merged.RunInfo.model, "Model")
            tc.verifyEqual(merged.RunInfo.Category, "A")
            tc.verifyEqual(merged.RunInfo.Target, 1.5)
        end

        function testAppendKeepsMixedCaseSourceIdentitiesSeparate(tc)
            leftInfo = table("Model", "Baseline", 1, 7, "Shared", ...
                VariableNames=["model","scenario","version","run_id","Category"]);
            rightInfo = table("Other model", "Baseline", 1, 7, "Shared", ...
                VariableNames=["Model","Scenario","Version","Run_ID","Category"]);
            left = singleObservationFrame("Baseline", 7, 5, leftInfo);
            rightData = singleObservationFrame("Baseline", 7, 6, table()).toTable();
            rightData.Model = "Other model";
            right = iam.IAMFrame(rightData, RunInfo=rightInfo);

            merged = left.append(right);
            selected = merged.filter(models="Other model", strict=true);

            tc.verifyEqual(height(merged.RunInfo), 2)
            tc.verifyEqual(selected.RunInfo.model, "Other model")
            tc.verifyEqual(selected.RunInfo.Category, "Shared")
        end

        function testAppendRejectsDuplicateIdentityAliases(tc)
            info = table(7, 8, VariableNames=["run_id","Run_ID"]);
            frame = singleObservationFrame("Baseline", 7, 5, info);

            tc.verifyError(@() iam.IAMFrame().append(frame), ...
                "iam:IAMFrame:IncompatibleRunInfo")
        end

        function testAppendRejectsArrayValuedMetadataWithoutReshaping(tc)
            info = table([10 20], VariableNames="Weights");
            frame = singleObservationFrame("Baseline", 7, 5, info);

            tc.verifyError(@() iam.IAMFrame().append(frame), ...
                "iam:IAMFrame:IncompatibleRunInfo")
            tc.verifyEqual(frame.RunInfo.Weights, [10 20])
        end

        function testAppendPreservesTimezoneWhenPaddingMetadata(tc)
            info = table("Model", "Baseline", 1, 7, ...
                datetime(2026,1,1,TimeZone="UTC"), ...
                VariableNames=["model","scenario","version","run_id","Retrieved"]);
            left = singleObservationFrame("Baseline", 7, 5, info);
            right = singleObservationFrame("Other", 8, 6, ...
                table(8, VariableNames="run_id"));

            merged = left.append(right);
            reversed = right.append(left);

            tc.verifyEqual(merged.RunInfo.Retrieved.TimeZone, 'UTC')
            tc.verifyEqual(merged.RunInfo.Retrieved(1), info.Retrieved)
            tc.verifyTrue(isnat(merged.RunInfo.Retrieved(2)))
            tc.verifyEqual(reversed.RunInfo.Retrieved.TimeZone, 'UTC')
            tc.verifyTrue(isnat(reversed.RunInfo.Retrieved(1)))
        end

        function testAppendPreservesEquivalentTimezoneInstants(tc)
            leftInfo = table(7, datetime(2026,1,1,TimeZone="UTC"), ...
                VariableNames=["run_id","Retrieved"]);
            rightInfo = leftInfo;
            rightInfo.Retrieved.TimeZone = "America/New_York";
            left = singleObservationFrame("Baseline", 7, 5, leftInfo);
            right = singleObservationFrame("Baseline", 7, 6, rightInfo, 2030);

            merged = left.append(right);

            tc.verifyEqual(merged.RunInfo.Retrieved, leftInfo.Retrieved)
            tc.verifyEqual(merged.RunInfo.Retrieved.TimeZone, leftInfo.Retrieved.TimeZone)
            tc.verifyEqual(right.RunInfo.Retrieved.TimeZone, rightInfo.Retrieved.TimeZone)
        end

        function testAppendFillsMissingTimezoneMetadata(tc)
            leftInfo = table(7, datetime(2026,1,1,TimeZone="UTC"), ...
                VariableNames=["run_id","Retrieved"]);
            rightInfo = table(7, NaT, VariableNames=["run_id","Retrieved"]);
            left = singleObservationFrame("Baseline", 7, 5, leftInfo);
            right = singleObservationFrame("Baseline", 7, 6, rightInfo, 2030);

            merged = left.append(right);
            reversed = right.append(left);

            tc.verifyEqual(merged.RunInfo.Retrieved, leftInfo.Retrieved)
            tc.verifyEqual(reversed.RunInfo.Retrieved, leftInfo.Retrieved)
            tc.verifyEqual(reversed.RunInfo.Retrieved.TimeZone, leftInfo.Retrieved.TimeZone)
            tc.verifyEqual(right.RunInfo.Retrieved.TimeZone, rightInfo.Retrieved.TimeZone)
        end

        function testAppendKeepsSourceRecordsWithoutOriginalRunInfo(tc)
            left = singleObservationFrame("Baseline", 7, 5, table());
            right = singleObservationFrame("Baseline", 8, 5, table());

            merged = left.append(right, RepeatPolicy="deduplicate");
            filtered = merged.filter(scenarios="Baseline", strict=true);

            tc.verifyTrue(isnan(merged.toTable().RunId))
            tc.verifyEqual(merged.RunInfo.run_id, [7; 8])
            tc.verifyEqual(merged.RunInfo.model, ["Model"; "Model"])
            tc.verifyEqual(merged.RunInfo.scenario, ["Baseline"; "Baseline"])
            tc.verifyEqual(filtered.RunInfo, merged.RunInfo)
        end

        function testLocalLongTableWithoutSourceIdsRoundTrips(tc)
            data = localLongData();
            frame = iam.IAMFrame(data);

            normalized = frame.toTable();
            tc.verifyTrue(all(isnan(normalized.RunId)))
            tc.verifyTrue(all(isnan(normalized.Version)))
            tc.verifyEqual(normalized.Unit, strings(2,1))
            tc.verifyTrue(isnan(normalized.Value(2)))

            roundTrip = iam.IAMFrame(frame.toTimeseries()).toTable();
            tc.verifyEqual(roundTrip(:, normalized.Properties.VariableNames), normalized)
        end

        function testPipeCharactersDoNotCollideInIdentity(tc)
            data = table(["A|B"; "A"], ["C"; "B|C"], ...
                ["Variable"; "Variable"], ["World"; "World"], ...
                ["EJ/yr"; "EJ/yr"], [2020; 2020], [1; 2], ...
                'VariableNames', {'Model', 'Scenario', 'Variable', ...
                'Region', 'Unit', 'Year', 'Value'});

            frame = iam.IAMFrame(data);

            tc.verifyEqual(height(frame.summary()), 2)
            tc.verifyEqual(height(frame.toTable()), 2)
        end

        function testDuplicateObservationIgnoresSourceRunId(tc)
            data = table(["Model"; "Model"], ["Scenario"; "Scenario"], ...
                ["Variable"; "Variable"], ["World"; "World"], ...
                ["EJ/yr"; "EJ/yr"], [1; 2], [1; 1], [2020; 2020], [1; 1], ...
                'VariableNames', {'Model', 'Scenario', 'Variable', 'Region', ...
                'Unit', 'RunId', 'Version', 'Year', 'Value'});

            tc.verifyError(@() iam.IAMFrame(data), ...
                'iam:IAMFrame:DuplicateObservation')
        end

        function testVersionDistinguishesObservations(tc)
            data = table(["Model"; "Model"], ["Scenario"; "Scenario"], ...
                ["Variable"; "Variable"], ["World"; "World"], ...
                ["EJ/yr"; "EJ/yr"], [1; 1], [2020; 2021], [2020; 2020], [1; 2], ...
                'VariableNames', {'Model', 'Scenario', 'Variable', 'Region', ...
                'Unit', 'RunId', 'Version', 'Year', 'Value'});

            frame = iam.IAMFrame(data);

            tc.verifyEqual(height(frame.summary()), 2)
        end

        function testRejectsInvalidAnnualYear(tc, InvalidYear)
            data = localLongData();
            data.Year(1) = InvalidYear;

            tc.verifyError(@() iam.IAMFrame(data), 'iam:IAMFrame:InvalidYear')
        end

        function testRejectsInvalidAnnualYearFromTimeseries(tc, InvalidYear)
            date = datetime(2020, 1, 1, 'Format', 'yyyy');
            series = struct( ...
                'model', "Model", 'scenario', "Scenario", ...
                'variable', "Variable", 'region', "World", ...
                'unit', "EJ/yr", 'runId', NaN, 'version', NaN, ...
                'years', InvalidYear, ...
                'values', timetable(date, 1, ...
                    'DimensionNames', {'Year', 'VariableUnits'}, ...
                    'VariableNames', {'Values'}));

            tc.verifyError(@() iam.IAMFrame(iam.IAMTimeseries(series)), ...
                'iam:IAMFrame:InvalidYear')
        end

        function testRejectsInvalidTimeseriesIdentity(tc, InvalidTimeseriesIdentity)
            [~, input] = buildSampleTimeseries(1);
            input.(InvalidTimeseriesIdentity.Field) = InvalidTimeseriesIdentity.Value;

            tc.verifyError(@() iam.IAMFrame(iam.IAMTimeseries(input)), ...
                "iam:IAMFrame:MissingIdentity")
        end

        function testRejectsInvalidTimeseriesValues(tc, InvalidTimeseriesValue)
            [~, input] = buildSampleTimeseries(1);
            input.values = timetable(input.values.Year, ...
                repmat(InvalidTimeseriesValue, 3, 1), ...
                VariableNames="Values", DimensionNames=["Year", "VariableUnits"]);

            tc.verifyError(@() iam.IAMFrame(iam.IAMTimeseries(input)), ...
                "iam:IAMFrame:InvalidNumericColumn")
        end

        function testRejectsInvalidTimeseriesProvenance(tc, InvalidTimeseriesProvenance)
            [~, input] = buildSampleTimeseries(1);
            input.(InvalidTimeseriesProvenance.Field) = InvalidTimeseriesProvenance.Value;

            tc.verifyError(@() iam.IAMFrame(iam.IAMTimeseries(input)), ...
                "iam:IAMFrame:InvalidNumericColumn")
        end

        function testRejectsInconsistentTimeseriesLayout(tc, InvalidTimeseriesLayout)
            [~, input] = buildSampleTimeseries(1);
            expectedError = "iam:IAMFrame:InvalidTimeseriesLength";
            switch InvalidTimeseriesLayout
                case "scalarValues"
                    input.values = input.values(1,:);
                case "emptyYears"
                    input.years = zeros(0,1);
                case "emptyValues"
                    input.values = input.values([],:);
                case "multipleColumns"
                    input.values.Extra = [10; 20; 30];
                    expectedError = "iam:IAMFrame:InvalidTimeseriesValues";
                case "matrixColumn"
                    input.values.Values = [1 10; 2 20; 3 30];
                    expectedError = "iam:IAMFrame:InvalidNumericColumn";
            end

            tc.verifyError(@() iam.IAMFrame(iam.IAMTimeseries(input)), expectedError)
        end

        function testRejectsInconsistentTimeseriesDates(tc)
            [~, input] = buildSampleTimeseries(1);
            input.values.Year = input.values.Year + calyears(1);

            tc.verifyError(@() iam.IAMFrame(iam.IAMTimeseries(input)), ...
                "iam:IAMFrame:InvalidTimeseriesTime")
        end

        function testRejectsSubannualTimeseriesDates(tc)
            [~, input] = buildSampleTimeseries(1);
            input.values.Year(1) = input.values.Year(1) + calmonths(1);

            tc.verifyError(@() iam.IAMFrame(iam.IAMTimeseries(input)), ...
                "iam:IAMFrame:InvalidTimeseriesTime")
        end

        function testRejectsDurationTimeseriesDates(tc)
            [~, input] = buildSampleTimeseries(1);
            input.values = timetable(days([0; 10; 20]), [1; 2; 3], ...
                VariableNames="Values", DimensionNames=["Year", "VariableUnits"]);

            tc.verifyError(@() iam.IAMFrame(iam.IAMTimeseries(input)), ...
                "iam:IAMFrame:InvalidTimeseriesTime")
        end

        function testTimeseriesInputUsesTheTableNormalization(tc)
            [~, input] = buildSampleTimeseries(1);
            input.unit = string(missing);
            input.years = [2040; 2020; 2030];
            input.values = timetable(datetime(input.years, 1, 1), [NaN; 1; 2], ...
                VariableNames="Values", DimensionNames=["Year", "VariableUnits"]);
            frame = iam.IAMFrame(iam.IAMTimeseries(input));
            expected = table(repmat("Model A",3,1), repmat("Scenario A",3,1), ...
                repmat("Primary Energy",3,1), repmat("World",3,1), strings(3,1), ...
                [2020; 2030; 2040], [1; 2; NaN], repmat(101,3,1), ones(3,1), ...
                VariableNames=["Model","Scenario","Variable","Region","Unit", ...
                "Year","Value","RunId","Version"]);

            tc.verifyEqual(frame.toTable(), expected)
            tc.verifyEqual(iam.IAMFrame(frame.toTimeseries()).toTable(), expected)
        end

        function testRejectsMalformedYearSelector(tc, InvalidYearSelector)
            frame = iam.IAMFrame(localLongData());

            tc.verifyError(@() frame.filter(years=InvalidYearSelector), ...
                'iam:IAMFrame:InvalidYears')
        end

        function testRejectsUnsupportedColumns(tc)
            data = localLongData();
            data.Subannual = repmat("Year", height(data), 1);

            tc.verifyError(@() iam.IAMFrame(data), ...
                'iam:IAMFrame:UnsupportedColumns')
        end

        function testTextYearSelectorMatchesAnnualYears(tc)
            frame = iam.IAMFrame(localLongData());

            filtered = frame.filter(years="2030");

            tc.verifyEqual(filtered.Years, 2030)
        end

        function testConvertUnitUsesKnownAndExplicitFactors(tc)
            frame = iam.IAMFrame(buildSampleTimeseries(1));

            converted = frame.convertUnit("EJ/yr","PJ/yr");
            explicit = converted.convertUnit("PJ/yr","custom energy",Factor=2);
            twhSource = singleObservationFrame("Energy",303,1,table());
            twhData = twhSource.toTable();
            twhData.Unit = "TWh/yr";
            twhFrame = iam.IAMFrame(twhData);
            twh = twhFrame.convertUnit("TWh/yr","PJ/yr");

            tc.verifyEqual(converted.toTable().Value,[1000;2000;3000],AbsTol=1e-12)
            tc.verifyEqual(converted.Units,"PJ/yr")
            tc.verifyEqual(explicit.toTable().Value,[2000;4000;6000],AbsTol=1e-12)
            tc.verifyEqual(twh.toTable().Value,3.6,AbsTol=1e-12)
            tc.verifyEqual(frame.toTable().Value,[1;2;3],AbsTol=1e-12)
            tc.verifyError(@() frame.convertUnit("EJ/yr","unknown unit"), ...
                "iam:IAMFrame:UnknownConversion")
        end

        function testExplicitFactorPreservesDoubleObservations(tc, ExplicitFactor)
            frame = singleObservationFrame("Factor",7,1.234567890123,table());
            converted = frame.convertUnit("EJ/yr","scaled",Factor=ExplicitFactor);
            tc.verifyEqual(converted.toTable().Value,2.469135780246,AbsTol=1e-14)
        end

        function testDerivedResultPreservesSourcesWithoutRunInfo(tc)
            data = calculationData();
            data = data(1:2,:);
            data.RunId = [7;8];
            frame = iam.IAMFrame(data).setMeta(table("Model A","Scenario One",1,"Reviewed", ...
                VariableNames=["Model","Scenario","Version","Review"]));
            result = frame.share("A","B","Share");
            tc.verifyTrue(isnan(result.RunIds))
            tc.verifyEqual(sort(result.RunInfo.run_id),[7;8])
            tc.verifyEqual(sort(result.Provenance.SourceRunId),[7;8])
            tc.verifyEqual(result.meta().Review,"Reviewed")
        end

        function testDerivedResultEnrichesIdOnlySourceRecords(tc, SourceIdName)
            data = calculationData();
            data = data(1:2,:);
            data.RunId = [7;8];
            info = table([7;8],["A source";"B source"],VariableNames=[SourceIdName,"Source"]);
            result = iam.IAMFrame(data,RunInfo=info).share("A","B","Share");
            tc.verifyEqual(sort(result.RunInfo.run_id),[7;8])
            tc.verifyEqual(result.RunInfo.scenario,repmat("Scenario One",2,1))
            tc.verifyEqual(result.RunInfo.Source,["A source";"B source"])
        end

        function testBaselineResultKeepsOriginalParentScenarios(tc)
            info = table(["Model A";"Model A"],["Policy";"Baseline"], ...
                [1;1],[201;101],["Policy release";"Baseline release"], ...
                VariableNames=["model","scenario","version","run_id","Source"]);
            frame = iam.IAMFrame(baselineData(),RunInfo=info);
            result = frame.compareBaseline("Policy","Baseline","Emissions","Difference");
            selected = result.filter(years=2020,regions="World",strict=true);
            unsupported = result.filter(years=2040,regions="World",strict=true);
            tc.verifyEqual(sort(result.RunInfo.run_id),[101;201])
            tc.verifyEqual(result.RunInfo.scenario,["Policy";"Baseline"])
            tc.verifyTrue(all(isnan(result.RunIds)))
            tc.verifyEqual(sort(selected.RunInfo.run_id),[101;201])
            tc.verifyEqual(unique(selected.Provenance.SourceScenario),["Baseline";"Policy"])
            tc.verifyEqual(unsupported.RunInfo.run_id,201)
            tc.verifyEqual(unsupported.Provenance.SourceScenario,"Policy")
        end

        function testDerivedProvenanceSurvivesConversionAndRoundTrip(tc)
            info = table(["Model A";"Model A"],["Policy";"Baseline"], ...
                [1;1],[201;101],VariableNames=["model","scenario","version","run_id"]);
            frame = iam.IAMFrame(baselineData(),RunInfo=info).setMeta(table( ...
                "Model A","Policy",1,"Reviewed", ...
                VariableNames=["Model","Scenario","Version","Review"]));
            result = frame.compareBaseline("Policy","Baseline","Emissions","Difference");
            converted = result.convertUnit("Mt CO2/yr","kt CO2/yr");
            roundTrip = converted.toTimeseries().toFrame();
            tc.verifyEqual(roundTrip.toTable(),converted.toTable())
            tc.verifyEqual(roundTrip.RunInfo,converted.RunInfo)
            tc.verifyEqual(roundTrip.meta(),converted.meta())
            tc.verifyEqual(roundTrip.Provenance,converted.Provenance)
            tc.verifyEqual(unique(converted.Provenance.Unit),"kt CO2/yr")
            tc.verifyEqual(unique(converted.Provenance.SourceUnit),"Mt CO2/yr")
        end

        function testMissingTargetKeepsOnlyItsActualBaselineParent(tc)
            data = baselineData();
            extra = data(5,:);
            extra.Year = 2050;
            data = [data;extra];
            info = table(["Model A";"Model A"],["Policy";"Baseline"], ...
                [1;1],[201;101],VariableNames=["model","scenario","version","run_id"]);
            result = iam.IAMFrame(data,RunInfo=info).compareBaseline( ...
                "Policy","Baseline","Emissions","Difference");
            selected = result.filter(years=2050,regions="World",strict=true);
            tc.verifyEqual(selected.RunInfo.run_id,101)
            tc.verifyEqual(selected.RunInfo.scenario,"Baseline")
            tc.verifyEqual(selected.Provenance.SourceScenario,"Baseline")
            tc.verifyTrue(isnan(selected.toTable().Value))
            tc.verifyTrue(isnan(selected.RunIds))
            tc.verifyEqual(selected.Units,"Mt CO2/yr")
        end

        function testChainedCalculationsRetainOriginalSources(tc)
            data = calculationData();
            data = data(1:2,:);
            data.RunId = [7;8];
            share = iam.IAMFrame(data).share("A","B","Share");
            result = share.calculate("Share","add","Share","Double share",Unit="fraction");
            tc.verifyEqual(result.toTable().Value,1,AbsTol=1e-12)
            tc.verifyEqual(sort(result.RunInfo.run_id),[7;8])
            tc.verifyEqual(unique(result.Provenance.SourceVariable),["A";"B"])
            tc.verifyEqual(unique(result.Provenance.Variable),"Double share")
        end

        function testAppendingFilteredResultsRetainsProvenance(tc)
            result = iam.IAMFrame(baselineData()).compareBaseline( ...
                "Policy","Baseline","Emissions","Difference");
            merged = result.filter(years=2020).append(result.filter(years=[2030 2040]));
            tc.verifyEqual(merged.toTable(),result.toTable())
            tc.verifyEqual(height(merged.Provenance),height(result.Provenance))
            tc.verifyEqual(sort(merged.RunInfo.run_id),[101;201])
        end

        function testCalculateAlignsNamedOperandsByScenarioRegionAndYear(tc)
            runInfo = table(["Model A";"Model A"], ...
                ["Scenario One";"Scenario Two"],ones(2,1),[101;202], ...
                ["Source One";"Source Two"], ...
                VariableNames=["Model","Scenario","Version","RunId","Source"]);
            frame = iam.IAMFrame(calculationData(),RunInfo=runInfo);
            annotated = frame.setMeta(table(["Model A";"Model A"], ...
                ["Scenario One";"Scenario Two"], [1;1], ["Reviewed";"New"], ...
                VariableNames=["Model","Scenario","Version","Review"]));

            [result,report] = annotated.calculate("A","subtract","B", ...
                "A minus B",Unit="EJ/yr");
            [reversed,~] = annotated.calculate("B","subtract","A", ...
                "B minus A",Unit="EJ/yr");
            [sumResult,~] = annotated.calculate("A","add","B", ...
                "A plus B",Unit="EJ/yr");
            [sumReversed,~] = annotated.calculate("B","add","A", ...
                "B plus A",Unit="EJ/yr");
            product = annotated.calculate("A","multiply","B", ...
                "A times B",Unit="(EJ/yr)^2");
            values = result.toTable();
            reversedValues = reversed.toTable();
            world = values.Scenario == "Scenario One" & values.Region == "World";
            europe = values.Scenario == "Scenario One" & values.Region == "Europe";
            missingRight = values.Scenario == "Scenario Two" & values.Region == "World";
            missingLeft = values.Scenario == "Scenario Two" & values.Region == "Europe";

            tc.verifyEqual(values.Value(world),-2,AbsTol=1e-12)
            tc.verifyEqual(values.Value(europe),-3,AbsTol=1e-12)
            tc.verifyTrue(isnan(values.Value(missingRight)))
            tc.verifyTrue(isnan(values.Value(missingLeft)))
            tc.verifyEqual(reversedValues.Value(world),2,AbsTol=1e-12)
            tc.verifyEqual(sumResult.toTable().Value(world),6,AbsTol=1e-12)
            tc.verifyEqual(sumReversed.toTable().Value(world),6,AbsTol=1e-12)
            tc.verifyEqual(product.toTable().Value(world),8,AbsTol=1e-12)
            tc.verifyEqual(report.ComputedCount,2)
            tc.verifyEqual(height(report.MissingOperands),2)
            tc.verifyEqual(height(result.meta()),2)
            tc.verifyEqual(annotated.meta().Review,["Reviewed";"New"])
            tc.verifyEqual(height(result.RunInfo),2)
            tc.verifyEqual(result.toTable().RunId(world),101)
            tc.verifyEqual(frame.Variables,["A";"B"])
        end

        function testCalculateReportsZeroDenominatorsAndChecksUnits(tc)
            frame = iam.IAMFrame(calculationData());

            [result,report] = frame.calculate("A","divide","B", ...
                "A over B",Unit="fraction");
            values = result.toTable();
            zero = values.Scenario == "Scenario Two" & values.Region == "Europe";

            tc.verifyTrue(isnan(values.Value(zero)))
            tc.verifyEqual(height(report.ZeroDenominators),1)
            tc.verifyError(@() frame.calculate("A","add","B","Total",Unit="PJ/yr"), ...
                "iam:IAMFrame:IncompatibleUnits")
            tc.verifyError(@() frame.calculate("A","divide","B","Ratio"), ...
                "iam:IAMFrame:InvalidDerivedLabel")

            incompatible = calculationData();
            incompatible.Unit(incompatible.Variable == "B") = "PJ/yr";
            incompatibleFrame = iam.IAMFrame(incompatible);
            tc.verifyError(@() incompatibleFrame.calculate("A","add","B", ...
                "Total",Unit="EJ/yr"),"iam:IAMFrame:IncompatibleUnits")
            tc.verifyError(@() incompatibleFrame.share("A","B","Share"), ...
                "iam:IAMFrame:IncompatibleUnits")

            unknown = calculationData();
            unknown.Unit(unknown.Variable == "A") = "";
            unknownFrame = iam.IAMFrame(unknown);
            tc.verifyError(@() unknownFrame.calculate("A","divide","B", ...
                "Ratio",Unit="fraction"),"iam:IAMFrame:UnknownUnit")
        end

        function testShareUsesDeclaredFractionAndPercentConventions(tc)
            frame = iam.IAMFrame(calculationData());

            [fraction,report] = frame.share("A","B","Share");
            percent = frame.share("A","B","Share",Convention="percent");
            first = fraction.toTable().Scenario == "Scenario One" & ...
                fraction.toTable().Region == "World";
            firstPercent = percent.toTable().Scenario == "Scenario One" & ...
                percent.toTable().Region == "World";

            tc.verifyEqual(fraction.toTable().Value(first),0.5,AbsTol=1e-12)
            tc.verifyEqual(percent.toTable().Value(firstPercent),50,AbsTol=1e-12)
            tc.verifyEqual(fraction.Units,"fraction")
            tc.verifyEqual(percent.Units,"%")
            tc.verifyEqual(height(report.ZeroDenominators),1)
        end

        function testCompareBaselineAlignsCoordinatesAndReportsMissingData(tc)
            frame = iam.IAMFrame(baselineData());

            [difference,report] = frame.compareBaseline("Policy","Baseline", ...
                "Emissions","Emissions difference");
            [percent,percentReport] = frame.compareBaseline("Policy","Baseline", ...
                "Emissions","Percent change",Operation="percentChange");
            data = difference.toTable();
            world2020 = data.Region == "World" & data.Year == 2020;
            europe2020 = data.Region == "Europe" & data.Year == 2020;
            world2030 = data.Region == "World" & data.Year == 2030;
            world2040 = data.Region == "World" & data.Year == 2040;
            percentData = percent.toTable();
            percent2020 = percentData.Region == "World" & percentData.Year == 2020;
            percent2030 = percentData.Region == "World" & percentData.Year == 2030;

            tc.verifyEqual(data.Value(world2020),2,AbsTol=1e-12)
            tc.verifyEqual(data.Value(europe2020),3,AbsTol=1e-12)
            tc.verifyEqual(data.Value(world2030),15,AbsTol=1e-12)
            tc.verifyTrue(isnan(data.Value(world2040)))
            tc.verifyEqual(percentData.Value(percent2020),20,AbsTol=1e-12)
            tc.verifyTrue(isnan(percentData.Value(percent2030)))
            tc.verifyEqual(height(report.MissingOperands),1)
            tc.verifyEqual(height(percentReport.ZeroDenominators),1)
            tc.verifyEqual(difference.Scenarios,"Policy")

            incompatible = baselineData();
            incompatible.Unit(incompatible.Scenario == "Baseline") = "kt CO2/yr";
            incompatibleFrame = iam.IAMFrame(incompatible);
            tc.verifyError(@() incompatibleFrame.compareBaseline("Policy", ...
                "Baseline","Emissions","Difference"), ...
                "iam:IAMFrame:IncompatibleUnits")
        end

        function testLoanStressExampleUsesFrameShareAndBaselineMethods(tc)
            frame = iam.IAMFrame(marketShareData());

            shocks = computeShocks(frame,"Baseline","Policy","Total","Sector");

            tc.verifyEqual(shocks.Shock,[0.5;0.5],AbsTol=1e-12)
            tc.verifyEqual(year(shocks.Time),[2020;2030])
        end

        function testHeadAndTail(tc)
            frame = iam.IAMFrame(buildSampleTimeseries());

            tc.verifyEqual(height(frame.head(2)), 2)
            tc.verifyEqual(height(frame.tail(2)), 2)
        end
    end
end

function [ts, data] = buildSampleTimeseries(selection)
if nargin < 1
    selection = [1 2];
end

dates = datetime([2020; 2030; 2040], 1, 1, 'Format', 'yyyy');

data(1).model = "Model A";
data(1).scenario = "Scenario A";
data(1).variable = "Primary Energy";
data(1).region = "World";
data(1).unit = "EJ/yr";
data(1).runId = 101;
data(1).version = 1;
data(1).years = year(dates);
data(1).values = timetable(dates, [1; 2; 3], ...
    'DimensionNames', {'Year', 'VariableUnits'}, 'VariableNames', {'Values'});

data(2).model = "Model B";
data(2).scenario = "Scenario B";
data(2).variable = "Emissions|CO2";
data(2).region = "Europe";
data(2).unit = "Mt CO2";
data(2).runId = 202;
data(2).version = 2;
data(2).years = year(dates);
data(2).values = timetable(dates, [10; 20; 30], ...
    'DimensionNames', {'Year', 'VariableUnits'}, 'VariableNames', {'Values'});

data = data(selection);
ts = iam.IAMTimeseries(data);
end

function data = localLongData()
data = table(["Local model"; "Local model"], ...
    ["Baseline"; "Baseline"], ["Energy"; "Energy"], ...
    ["World"; "World"], strings(2,1), [2020; 2030], [1; NaN], ...
    'VariableNames', {'Model', 'Scenario', 'Variable', 'Region', ...
    'Unit', 'Year', 'Value'});
end

function data = calculationData()
data = table( ...
    repmat("Model A",6,1), ...
    ["Scenario One";"Scenario One";"Scenario One";"Scenario One"; ...
    "Scenario Two";"Scenario Two"], ...
    ["A";"B";"A";"B";"A";"B"], ...
    ["World";"World";"Europe";"Europe";"World";"Europe"], ...
    repmat("EJ/yr",6,1),[101;101;101;101;202;202],ones(6,1), ...
    repmat(2020,6,1),[2;4;3;6;5;0], ...
    VariableNames=["Model","Scenario","Variable","Region","Unit", ...
    "RunId","Version","Year","Value"]);
end

function data = baselineData()
data = table(repmat("Model A",7,1), ...
    ["Policy";"Policy";"Policy";"Policy";"Baseline";"Baseline";"Baseline"], ...
    repmat("Emissions",7,1), ...
    ["World";"World";"World";"Europe";"World";"World";"Europe"], ...
    repmat("Mt CO2/yr",7,1),[201;201;201;201;101;101;101],ones(7,1), ...
    [2020;2030;2040;2020;2020;2030;2020],[12;15;20;6;10;0;3], ...
    VariableNames=["Model","Scenario","Variable","Region","Unit", ...
    "RunId","Version","Year","Value"]);
end

function data = marketShareData()
data = table(repmat("Model A",8,1), ...
    ["Baseline";"Baseline";"Baseline";"Baseline"; ...
    "Policy";"Policy";"Policy";"Policy"], ...
    ["Total";"Sector";"Total";"Sector"; ...
    "Total";"Sector";"Total";"Sector"], ...
    repmat("World",8,1),repmat("TWh/yr",8,1), ...
    ones(8,1),repmat(2020,8,1), ...
    [10;2;12;2.4;10;3;12;3.6], ...
    VariableNames=["Model","Scenario","Variable","Region","Unit", ...
    "Version","Year","Value"]);
data.Year([3 4 7 8]) = 2030;
end

function frame = singleObservationFrame(scenario, runId, value, runInfo, year)
if nargin < 5
    year = 2020;
end
data = table("Model", scenario, "Energy", "World", "EJ/yr", ...
    runId, 1, year, value, ...
    VariableNames=["Model", "Scenario", "Variable", "Region", ...
    "Unit", "RunId", "Version", "Year", "Value"]);
frame = iam.IAMFrame(data, RunInfo=runInfo);
end
