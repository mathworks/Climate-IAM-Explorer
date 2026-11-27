classdef tHTMLDataExplorer < matlab.uitest.TestCase
    properties
        App
    end

    methods (TestMethodSetup)
        function createApp(tc)
            import matlab.unittest.constraints.Eventually
            import matlab.unittest.constraints.IsEqualTo
            tc.App = iam.DataExplorer(HTMLTestSupport.environment());
            tc.addTeardown(@delete, tc.App);
            tc.assertThat(@() tc.App.Label.Text, ...
                Eventually(IsEqualTo('Mock IAM environment'), WithTimeoutOf=15));
            drawnow;
        end
    end

    methods (Test, TestTags=["GUI","HTML"])
        function searchAndFilterUseHTMLChart(tc)
            tc.verifyNumElements(findobj(tc.App.DATABASEEXPLORER, ...
                "Tag", "IAMHTMLSearch"), 1);
            tc.verifyNumElements(findobj(tc.App.DATABASEEXPLORER, ...
                "Tag", "IAMHTMLChart"), 1);
            searchChart = findobj(tc.App.DATABASEEXPLORER, "Tag", "IAMHTMLChart");
            tc.verifyFalse(searchChart.Data.HeaderVisible);
            tc.choose(tc.App.FILTER);
            chart = findobj(tc.App.FILTER, "Tag", "IAMHTMLChart");
            tc.verifyNumElements(chart, 1);
            tc.verifyFalse(chart.Data.HeaderVisible);
            tc.press(tc.App.LoadandPreviewDataButton);
            tc.verifyEqual(chart.Data.Title, "Emissions|CO2");
            tc.verifyNumElements(chart.Data.Series, 1);
        end

        function filterExportCreatesWorkbook(tc)
            tc.choose(tc.App.FILTER);
            tc.press(tc.App.LoadandPreviewDataButton);
            tc.press(tc.App.SelectedtoWorkbookButton);
            tc.verifyNotEmpty(tc.App.WORKBOOKTab.Children);
            tc.verifyNumElements(findobj(tc.App.WORKBOOKTab,"Tag","IAMHTMLChart"),1);
        end

        function htmlSearchExportCreatesWorkbook(tc)
            import matlab.unittest.constraints.Eventually
            import matlab.unittest.constraints.IsTrue
            html = findobj(tc.App.DATABASEEXPLORER, "Tag", "IAMHTMLSearch");
            probe = HTMLProbe(html);
            tc.addTeardown(@delete, probe);
            tc.assertThat(@() probe.Ready, Eventually(IsTrue(), WithTimeoutOf=15));
            probe.act(tc, struct("kind","click","selector","#search-button"));
            probe.act(tc, struct("kind","click","selector","#result-rows tr"));
            probe.act(tc, struct("kind","click","selector","#selected-to-workbook"));
            tc.verifyNotEmpty(tc.App.WORKBOOKTab.Children);
            tc.verifyNumElements(findobj(tc.App.WORKBOOKTab,"Tag","IAMHTMLChart"),1);
        end
    end
end
