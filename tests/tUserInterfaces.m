classdef tUserInterfaces < matlab.uitest.TestCase
    properties
        App
    end
    methods (TestClassSetup)
        function loadApp(tc)
            tc.App = IAMDataExplorer;
        end
    end

    methods (Test, TestTags = {'GUI'})
        % Test methods

        function tGuestLogin(testCase)
            testCase.press(testCase.App.GuestLoginButton)
            testCase.verifyFalse(isvalid(testCase.App))
            h = findall(0,'Type','figure', 'Name','IAM Explorer');
            testCase.verifyTrue(isvalid(h));
            delete(h);
        end
    end

end