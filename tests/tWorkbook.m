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

    methods (Test)
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
    end

end