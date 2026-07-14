classdef tIAMFrame < matlab.unittest.TestCase

    methods (TestClassSetup)
        function addToolboxToPath(tc)
            root = fileparts(fileparts(mfilename('fullpath')));
            tc.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root, 'tbx', 'IAMDataExplorer')));
        end
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

        function testHeadAndTail(tc)
            frame = iam.IAMFrame(buildSampleTimeseries());

            tc.verifyEqual(height(frame.head(2)), 2)
            tc.verifyEqual(height(frame.tail(2)), 2)
        end
    end
end

function ts = buildSampleTimeseries(selection)
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

ts = iam.IAMTimeseries(data(selection));
end
