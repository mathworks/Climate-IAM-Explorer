classdef tWorkbook < matlab.uitest.TestCase

    properties
        App
    end

    methods (TestClassSetup)
        function loadWorkbook(tc)
            tc.App = iam.controls.IAMworkbook();
        end
    end

    methods (TestClassTeardown)
        function deleteWorkbook(tc)
            delete(ancestor(tc.App.MainGridLayout, 'figure', 'toplevel'));
        end
    end

    methods (Test, TestTags={'GUI'})
        % Test methods

        function tWorkflows(testCase)
            dates = datetime(2020,1,1):calyears(1):datetime(2030,1,1);
            values = 1:11;
            t = timetable(dates',values', 'VariableNames', {'variable'}, 'DimensionNames', {'Year','Values'});

            ts = iam.IAMTimeseries(struct(model="model", scenario = "scenario", variable = "variable", region = "region", unit = "unit", runId = 1, version = "1", years = year(t.Year), values = t));
            ts2 = iam.IAMTimeseries(struct(model="model2", scenario = "scenario2", variable = "variable2", region = "region2", unit = "unit", runId = 1, version = "1", years = year(t.Year), values = t));


            testCase.App.addData(ts)
            testCase.App.addData(ts2)
        end

        function tAppendUsesIAMFrameRepeatPolicy(testCase)
            first = workbookObservation("C03 Workbook", 31, 5);
            identical = workbookObservation("C03 Workbook", 32, 5);
            changed = workbookObservation("C03 Workbook", 33, 6);

            testCase.App.addData(first);
            testCase.verifyError(@() testCase.App.addData(changed), ...
                "iam:IAMFrame:ConflictingObservation")
            testCase.App.addData(identical, RepeatPolicy="deduplicate");
            merged = testCase.App.Data.filter( ...
                scenarios="C03 Workbook", strict=true);

            testCase.verifyEqual(height(merged.toTable()), 1)
            testCase.verifyEqual(merged.toTable().Value, 5)
            testCase.verifyTrue(isnan(merged.toTable().RunId))
            testCase.verifyEqual(merged.RunInfo.run_id, [31; 32])
        end

        function tAppendAcceptsNestedMetadata(testCase)
            first = workbookObservation("Nested metadata", 41, 5);
            info = table("C03 Model", "Nested metadata", 1, 41, ...
                struct('Category', "A"), ...
                VariableNames=["model","scenario","version","run_id","metadata"]);
            source = iam.IAMFrame(first.toTable(), RunInfo=info);

            testCase.App.addData(source);
            loaded = testCase.App.Data.filter(scenarios="Nested metadata", strict=true);

            testCase.verifyEqual(loaded.toTable(), source.toTable())
            testCase.verifyEqual(loaded.RunInfo.metadata{1}.Category, "A")
        end
    end

end

function frame = workbookObservation(scenario, runId, value)
data = table("C03 Model", scenario, "Energy", "World", "EJ/yr", ...
    runId, 1, 2020, value, ...
    VariableNames=["Model", "Scenario", "Variable", "Region", ...
    "Unit", "RunId", "Version", "Year", "Value"]);
frame = iam.IAMFrame(data);
end
