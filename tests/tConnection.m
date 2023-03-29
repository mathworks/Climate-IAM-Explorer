classdef tConnection < matlab.uitest.TestCase
    

    methods (Test, TestTags = {'Unit'})

        % Test methods

        function testNGFSconnection(tc)
                        
            c = iam.data.IIASAconnection('ngfs_phase_2');
            e = iam.IAMEnvironment(c);
            tc.verifyClass(e, 'iam.IAMEnvironment')

        end

        function testNGFSconnectionPhase3(tc)

            c = iam.data.IIASAconnection('ngfs_phase_3');
            e = iam.IAMEnvironment(c);
            tc.verifyClass(e, 'iam.IAMEnvironment')

        end
        
    end

end