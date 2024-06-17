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
            load testData.mat myData
            tc.app.loadData(myData)
            d.SyncSelection("Consumption, United states");
            tc.verifyEqual(d.Selected, "Consumption")
        end
    end

end