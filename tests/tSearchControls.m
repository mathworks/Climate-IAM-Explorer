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
            load test.mat field
            % Fill tree, and one edit field appears
            tc.app.addMetadataTree(field, "VARIABLES")
            tc.verifyNotEmpty(tc.app.GenericEditField)

            % Type info, chec synch
            tc.type(tc.app.GenericEditField, "Consumption;; United states");
            tc.press(tc.app.OpenTreeButton)
            tc.verifyEqual(tc.app.GenericHTML.Selected, "Consumption");
            tc.verifyEqual(tc.app.GenericEditField.Value, 'Consumption;; United states;;')

        end
    end

end