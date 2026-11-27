classdef tHTMLChart < matlab.unittest.TestCase
    properties
        Figure
        Chart
        Probe
    end

    properties (TestParameter)
        ChartWidth = struct("Narrow",580,"Wide",800)
    end

    methods (TestMethodSetup)
        function createChart(tc)
            import matlab.unittest.constraints.Eventually
            import matlab.unittest.constraints.IsTrue
            tc.Figure = uifigure(Position=[100 100 800 600]);
            tc.Chart = iam.views.IAMHTMLChart(Parent=tc.Figure);
            tc.Probe = HTMLProbe(tc.Chart.HTML);
            tc.addTeardown(@delete, tc.Probe);
            tc.addTeardown(@delete, tc.Figure);
            tc.assertThat(@() tc.Probe.Ready, Eventually(IsTrue(), WithTimeoutOf=15));
        end
    end

    methods (Test, TestTags=["GUI","HTML"])
        function lineHasRealMissingValueGap(tc)
            tc.Chart.changeData(HTMLTestSupport.frame());
            state = tc.Probe.act(tc, struct("kind","snapshot"));
            tc.verifyEqual(state.title, 'Selected series');
            tc.verifyEqual(state.unit, 'Multiple units');
            tc.verifyEqual(state.legendCount, 3);
            tc.verifyFalse(state.previewHeaderVisible);
            tc.verifyEqual(state.lineCount, 3);
            tc.verifyTrue(state.finiteGeometry);
            tc.verifyEqual(count(string(state.paths), "M"), [2 2 1]);
            tc.verifySubstring(state.note, 'different units');
            tc.verifySubstring(state.legendLabels{3}, 'V = Temperature');
            tc.verifySubstring(state.legendLabels{3}, 'U = C');
            tc.verifySubstring(state.legendTooltips{3}, 'Variable: Temperature');
            tc.verifySubstring(state.legendTooltips{3}, 'Unit: C');
        end

        function groupedBarsSkipMissingValues(tc)
            tc.Chart.changeData(HTMLTestSupport.frame());
            state = tc.Probe.act(tc, struct("kind","value","selector","#chart-type","value","bar grouped"));
            tc.verifyEqual(state.lineCount, 0);
            tc.verifyEqual(state.barCount, 5);
            tc.verifyTrue(state.finiteGeometry);
        end

        function stackedBarsHaveFiniteGeometry(tc)
            tc.Chart.changeData(HTMLTestSupport.frame());
            state = tc.Probe.act(tc, struct("kind","value","selector","#chart-type","value","bar stacked"));
            tc.verifyEqual(state.barCount, 5);
            tc.verifyTrue(state.finiteGeometry);
        end

        function singlePointRenders(tc)
            frame = HTMLTestSupport.frame();
            tc.Chart.hideHeader();
            tc.Chart.changeData(frame.filter(models="Model C", strict=true));
            state = tc.Probe.act(tc, struct("kind","snapshot"));
            tc.verifyFalse(state.previewHeaderVisible);
            tc.verifyEqual(state.lineCount, 1);
            tc.verifyEqual(state.legendCount, 1);
            tc.verifyTrue(state.finiteGeometry);
        end

        function emptyChartClearsGeometry(tc)
            tc.Chart.changeData(HTMLTestSupport.frame());
            tc.Chart.changeData(iam.IAMFrame());
            state = tc.Probe.act(tc, struct("kind","snapshot"));
            tc.verifyEqual(state.lineCount, 0);
            tc.verifyEqual(state.barCount, 0);
            tc.verifyEqual(state.legendCount, 0);
        end

        function legendOmitsSharedCoordinates(tc)
            frame = HTMLTestSupport.frame();
            data = frame.toTable();
            data.Model(:) = "Shared model";
            data.Scenario(:) = "Shared scenario";
            data.Variable(:) = "Shared variable";
            data.Unit(:) = "EJ/yr";
            data.RunId(:) = 101;
            data.Region = ["World";"World";"World";"Europe";"Europe";"Asia"];
            tc.Chart.changeData(iam.IAMFrame(data));

            state = tc.Probe.act(tc, struct("kind","snapshot"));

            tc.verifyEqual(sort(string(state.legendLabels)), ...
                ["R = Asia", "R = Europe", "R = World"]);
            tc.verifySubstring(state.legendTooltips{1}, 'Model: Shared model');
            tc.verifySubstring(state.legendTooltips{1}, 'Scenario: Shared scenario');
            tc.verifySubstring(state.legendTooltips{1}, 'Variable: Shared variable');
            tc.verifySubstring(state.legendTooltips{1}, 'Unit: EJ/yr');
        end

        function longLegendHasFullHoverDetails(tc)
            frame = HTMLTestSupport.frame();
            data = frame.toTable();
            data.Model(data.Model == "Model A") = join(repmat("Long model name",1,30)," ");
            tc.Chart.changeData(iam.IAMFrame(data));

            state = tc.Probe.act(tc, struct("kind","snapshot"));

            tc.verifyTrue(state.clippedLegendLabels(1));
            tc.verifySubstring(state.legendTooltips{1}, data.Model(1));
            tc.verifySubstring(state.legendTooltips{1}, 'Region: World');
            tc.verifySubstring(state.legendTooltips{1}, 'Run ID: 101');
            tc.verifySubstring(state.legendTooltips{1}, 'Version: 1');
        end

        function legendDistinguishesVersions(tc)
            frame = HTMLTestSupport.frame();
            data = frame.toTable();
            data.Model(:) = "Shared model";
            data.Scenario(:) = "Shared scenario";
            data.Variable(:) = "Shared variable";
            data.Unit(:) = "EJ/yr";
            data.RunId(:) = 101;
            data.Version = [1;1;1;2;2;3];
            tc.Chart.changeData(iam.IAMFrame(data));

            state = tc.Probe.act(tc, struct("kind","snapshot"));

            tc.verifyEqual(numel(unique(string(state.legendLabels))), 3);
            tc.verifyTrue(all(contains(string(state.legendLabels),"Version = ")));
            tc.verifyFalse(any(contains(string(state.legendLabels),"Shared model")));
        end

        function wrappedLegendColumnsStayAligned(tc, ChartWidth)
            tc.Figure.Position(3) = ChartWidth;
            drawnow;
            data = table(repelem(["Model A";"Model B";"Model C";"Model D";"Model E"],2), ...
                repmat("Scenario",10,1), repmat("Energy",10,1), ...
                repmat("World",10,1), repmat("EJ/yr",10,1), ...
                repelem((101:105)',2), ones(10,1), ...
                repmat([2020;2030],5,1), (1:10)', ...
                VariableNames=["Model","Scenario","Variable","Region","Unit","RunId","Version","Year","Value"]);
            tc.Chart.changeData(iam.IAMFrame(data));

            state = tc.Probe.act(tc, struct("kind","snapshot"));

            tc.verifyEqual(state.legendCount, 5);
            tc.verifyLessThanOrEqual(max(state.legendItemWidths)-min(state.legendItemWidths),0.5);
            firstRow = abs(state.legendRowTops-min(state.legendRowTops)) < 0.5;
            offsets = abs(state.legendLabelLefts(:)-state.legendLabelLefts(firstRow));
            tc.verifyLessThanOrEqual(min(offsets,[],2),0.5);
        end
    end
end
