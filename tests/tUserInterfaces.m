classdef tUserInterfaces < matlab.uitest.TestCase
    properties
        App
    end
    methods (TestMethodSetup)
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
            t = timerfindall;
            wait(t)
            testCase.verifyNotEmpty(t);

            testCase.verifyTrue(isvalid(h));
            delete(h);
        end

        function tBoC(testCase)
            testCase.choose(testCase.App.BOCTab);
            testCase.press(testCase.App.LoginButton_3)
            h = findall(0,'Type','figure', 'Name','IAM Explorer');

            t = timerfindall;
            if ~isempty(t)
                wait(t)
            end

            testCase.verifyTrue(isvalid(h));
            delete(h);

        end
        
    end

end