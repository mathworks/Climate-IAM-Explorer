classdef tIAMFrame < matlab.unittest.TestCase

    properties (TestParameter)
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
