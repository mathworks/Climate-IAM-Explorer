classdef tConnection < matlab.uitest.TestCase
    

    methods (Test)
        % Test methods

        function testNGFSconnection(tc)
                        
            c = iam.data.IIASAconnection('ngfs');
            e = iam.IAMEnvironment(c);
            tc.verifyClass(e, 'iam.IAMEnvironment')

        end
        
    end

end