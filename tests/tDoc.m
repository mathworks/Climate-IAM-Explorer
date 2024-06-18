classdef tDoc < matlab.uitest.TestCase

    properties
        App
        Info
    end

    methods (TestClassSetup)
        
        function setFigure(tc)
            tc.App = uifigure();
            tc.Info = iam.controls.IAMDocumentation(tc.App);            
        end

    end

    methods (TestClassTeardown)

        function closeFigure(tc)
            delete(tc.App)
        end

    end

    methods (Test, TestTags = {'GUI'})
        % Test methods

        function tLoadData(tc)
            c = iam.data.IIASAconnection('ngfs_phase_3');
            e = iam.IAMEnvironment(c);
            tc.Info.fillDropdowns(e);
            tc.verifyNotEmpty(tc.Info.ModelInfoDropDown.ItemsData)
        end

        function tModel(tc)
            tc.choose(tc.Info.ModelInfoDropDown, 3)
            tc.verifyNotEmpty(tc.Info.InfoHTML.HTMLSource)
        end

        function tScenario(tc)
            tc.choose(tc.Info.ScenarioInfoDropDown, 3)
            tc.verifyEqual(tc.Info.ModelInfoDropDown.Value, 0)
        end

        function tRegion(tc)
            tc.choose(tc.Info.RegionInfoDropDown, 3)
            tc.verifyEqual(tc.Info.ScenarioInfoDropDown.Value, 0)
        end

        function tTimeseries(tc)
            tc.choose(tc.Info.TimeseriesInfoDropDown, "Gross Domestic Product (GDP)")
            tc.verifyEqual(tc.Info.RegionInfoDropDown.Value, 0)
        end

    end

end