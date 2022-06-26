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
            cleanupObj = onCleanup(@() delete(tc.app));
        end
    end

    methods(Test, TestTags = {'GUI'})
        % Test methods

        function tLoadApp(tc)
                        
            load testData.mat myData
            tc.app.loadData(myData)

        end
    end

end