classdef tHTMLWorkbook < matlab.uitest.TestCase
    properties
        Figure
        Workbook
        Probe
    end

    methods (TestMethodSetup)
        function createWorkbook(tc)
            import matlab.unittest.constraints.Eventually
            import matlab.unittest.constraints.IsTrue
            tc.Figure = uifigure(Position=[100 100 1300 800]);
            tc.Workbook = iam.controls.IAMworkbook(Parent=tc.Figure);
            tc.Probe = HTMLProbe(tc.Workbook.WbAxes.HTML);
            tc.addTeardown(@delete, tc.Probe);
            tc.addTeardown(@delete, tc.Figure);
            tc.assertThat(@() tc.Probe.Ready, Eventually(IsTrue(), WithTimeoutOf=15));
            drawnow;
        end
    end

    methods (Test, TestTags=["GUI","HTML"])
        function nativeFiltersUpdateHTMLPreview(tc)
            tc.Workbook.addData(HTMLTestSupport.frame());
            tc.choose(tc.Workbook.ModelsListBox,["Model A","Model B"]);
            tc.choose(tc.Workbook.ScenariosListBox,["Scenario A","Scenario B"]);
            state = tc.Probe.act(tc,struct("kind","snapshot"));

            tc.verifyClass(tc.Workbook.WbAxes,"iam.views.IAMHTMLChart");
            tc.verifyEqual([tc.Workbook.FilteredData.RunId],[101 202]);
            tc.verifyEqual(state.lineCount,2);
            tc.verifyEqual(state.legendCount,2);
            tc.verifyEqual(state.title,'Emissions · CO2');
            tc.verifyFalse(state.previewHeaderVisible);
        end

        function mixedVariablesAndChartModes(tc)
            tc.Workbook.addData(HTMLTestSupport.frame());
            tc.choose(tc.Workbook.ModelsListBox,["Model A","Model B","Model C"]);
            tc.choose(tc.Workbook.ScenariosListBox,["Scenario A","Scenario B","Scenario C"]);
            tc.choose(tc.Workbook.VariablesListBox,["Emissions|CO2","Temperature"]);
            state = tc.Probe.act(tc,struct("kind","snapshot"));
            tc.verifyEqual(state.lineCount,3);
            tc.verifyEqual(state.legendCount,3);
            tc.verifyEqual(state.unit,'Multiple units');

            state = tc.Probe.act(tc,struct("kind","value","selector","#chart-type","value","bar grouped"));
            tc.verifyEqual(state.barCount,5);
            tc.verifyTrue(state.finiteGeometry);
            state = tc.Probe.act(tc,struct("kind","value","selector","#chart-type","value","bar stacked"));
            tc.verifyEqual(state.barCount,5);
            tc.verifyTrue(state.finiteGeometry);
        end

        function clearingWorkbookClearsChart(tc)
            tc.Workbook.addData(HTMLTestSupport.frame());
            tc.press(tc.Workbook.ClearWorkspaceButton);
            state = tc.Probe.act(tc,struct("kind","snapshot"));

            tc.verifyEqual(tc.Workbook.NumDatasets,0);
            tc.verifyEmpty(tc.Workbook.FilteredData);
            tc.verifyEqual(state.lineCount,0);
            tc.verifyEqual(state.legendCount,0);
        end

        function legacyWorkbookKeepsNativeChart(tc)
            figureHandle = uifigure(Visible="off");
            tc.addTeardown(@delete,figureHandle);
            legacy = iam.legacy.IAMworkbook(Parent=figureHandle);

            tc.verifyClass(legacy.WbAxes,"iam.views.IAMChart");
        end

        function legacyAppKeepsNativeWorkbook(tc)
            import matlab.unittest.constraints.Eventually
            import matlab.unittest.constraints.IsEqualTo
            legacy = iam.legacy.DataExplorer(HTMLTestSupport.environment());
            tc.addTeardown(@delete,legacy);
            tc.assertThat(@() legacy.Label.Text, ...
                Eventually(IsEqualTo('Mock IAM environment'),WithTimeoutOf=15));
            tc.choose(legacy.WORKBOOKTab);

            tc.verifyNotEmpty(findall(legacy.WORKBOOKTab,"-property","XLim"));
            tc.verifyEmpty(findobj(legacy.WORKBOOKTab,"Tag","IAMHTMLChart"));
        end
    end
end
