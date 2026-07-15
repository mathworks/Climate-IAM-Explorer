classdef tSearchControls < matlab.uitest.TestCase

    properties
        app
    end

    methods(TestClassSetup)
        % Shared setup for the entire test class
    end

    methods(TestMethodSetup)
        % Setup for each test
        function loadApp(tc)
            tc.app = iam.controls.SearchDatabaseControls;
        end
    end

    methods (TestMethodTeardown)

        function deleteApp(tc)
            delete(tc.app)
        end

    end

    methods (Test, TestTags = {'GUI'})
        % Test methods

        function tLoadApp(tc)
                        
            load testData.mat myData
            tc.app.loadData(myData)

        end

        function tTree(tc)
            load testData.mat field
            % Fill tree, and one edit field appears
            tc.app.addMetadataTree(field, "VARIABLES")
            tc.verifyNotEmpty(tc.app.GenericEditField)

            % Type info, chec synch
            tc.type(tc.app.GenericEditField, "Consumption;; United states");
            tc.press(tc.app.OpenTreeButton)
            tc.verifyEqual(tc.app.GenericHTML.Selected, "Consumption");
            tc.verifyEqual(tc.app.GenericEditField.Value, 'Consumption;; United states;;')

        end

        function tSelectedFrameDataReturnsSelectedSubset(tc)
            tc.app.loadData(buildSelectionTimeseries())

            tc.app.UITable.CellSelectionCallback(tc.app.UITable, ...
                struct('Indices', [1 1; 3 1]));

            selected = tc.app.SelectedFrameData;
            summary = selected.summary();

            tc.verifyEqual(height(summary), 2)
            tc.verifyEqual(summary.RunId, [101; 303])
            tc.verifyEqual(summary.Model, ["Model A"; "Model C"])
        end

        function tSelectedFrameDataDefaultsToFullFrame(tc)
            tc.app.loadData(buildSelectionTimeseries())

            selected = tc.app.SelectedFrameData;
            summary = selected.summary();

            tc.verifyEqual(height(summary), 3)
            tc.verifyEqual(summary.RunId, [101; 202; 303])
        end
    end

end

function ts = buildSelectionTimeseries()
dates = datetime([2020; 2030], 1, 1, 'Format', 'yyyy');

data(1).model = "Model A";
data(1).scenario = "Scenario A";
data(1).variable = "Variable A";
data(1).region = "World";
data(1).unit = "Unit A";
data(1).runId = 101;
data(1).version = 1;
data(1).years = year(dates);
data(1).values = timetable(dates, [1; 2], ...
    'DimensionNames', {'Year', 'VariableUnits'}, 'VariableNames', {'Values'});

data(2).model = "Model B";
data(2).scenario = "Scenario B";
data(2).variable = "Variable B";
data(2).region = "Europe";
data(2).unit = "Unit B";
data(2).runId = 202;
data(2).version = 1;
data(2).years = year(dates);
data(2).values = timetable(dates, [3; 4], ...
    'DimensionNames', {'Year', 'VariableUnits'}, 'VariableNames', {'Values'});

data(3).model = "Model C";
data(3).scenario = "Scenario C";
data(3).variable = "Variable C";
data(3).region = "Asia";
data(3).unit = "Unit C";
data(3).runId = 303;
data(3).version = 2;
data(3).years = year(dates);
data(3).values = timetable(dates, [5; 6], ...
    'DimensionNames', {'Year', 'VariableUnits'}, 'VariableNames', {'Values'});

ts = iam.IAMTimeseries(data);
end
