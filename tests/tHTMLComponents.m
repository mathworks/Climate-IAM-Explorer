classdef tHTMLComponents < matlab.uitest.TestCase
    properties
        Figure
        Search
        Probe
    end

    methods (TestMethodSetup)
        function createSearch(tc)
            import matlab.unittest.constraints.Eventually
            import matlab.unittest.constraints.IsTrue
            tc.Figure = uifigure(Position=[100 100 1300 800]);
            tc.Search = iam.controls.HTMLSearchDatabaseControls(Parent=tc.Figure);
            tc.Probe = HTMLProbe(tc.Search.HTML);
            tc.addTeardown(@delete, tc.Probe);
            tc.addTeardown(@delete, tc.Figure);
            tc.assertThat(@() tc.Probe.Ready, Eventually(IsTrue(), WithTimeoutOf=15));
            drawnow;
        end
    end

    methods (Test, TestTags=["GUI","HTML"])
        function selectionPreservesMetadata(tc)
            frame = HTMLTestSupport.frame();
            frame = frame.setMeta(table("Model B", "Scenario B", 1, "Selected", ...
                VariableNames=["Model","Scenario","Version","Category"]));
            tc.Search.loadData(frame);
            tc.Search.select(tc.Search.Records.ID(2));
            selected = tc.Search.SelectedFrameData;
            tc.verifyEqual(selected.RunIds, 202);
            tc.verifyEqual(selected.meta().Category, "Selected");
            tc.verifyEqual(height(selected.toTable()), 2);
        end

        function staleSelectionRejected(tc)
            tc.Search.loadData(HTMLTestSupport.frame());
            oldId = tc.Search.Records.ID(1);
            tc.Search.select(oldId);
            tc.Search.loadData(HTMLTestSupport.frame());
            tc.verifyEmpty(tc.Search.SelectedIds);
            tc.verifyError(@() tc.Search.select(oldId), "iam:HTMLSearch:UnknownSelection");
        end

        function htmlWorkbookButtonExportsSelection(tc)
            tc.Search.loadData(HTMLTestSupport.frame());
            tc.Search.WorkbookRequestedFcn = @(frame) tc.Probe.recordExport(frame);
            tc.Search.select(tc.Search.Records.ID(2));
            tc.Probe.act(tc, struct("kind","click","selector","#result-rows tr:nth-child(2)"));
            tc.Probe.act(tc, struct("kind","click","selector","#selected-to-workbook"));
            tc.verifyEqual(tc.Probe.ExportedFrame.RunIds, 202);
        end

        function htmlSelectionAndClear(tc)
            tc.Search.loadData(HTMLTestSupport.frame());
            tc.Probe.act(tc, struct("kind","click","selector","#result-rows tr"));
            state = tc.Probe.act(tc, struct("kind","snapshot"));
            tc.verifyEqual(state.selected, 1);
            tc.verifyEqual(state.rowCheckboxes, 0);
            tc.verifyEqual(state.resultSummaryCount, 0);
            tc.verifyEqual(string(state.columns), ["VARIABLE","UNITS","MODEL","SCENARIO","REGION","RUN ID","VERSION"]);
            tc.verifyEqual(string(state.units), ["Mt/yr","Mt/yr","C"]);
            tc.verifyEqual(state.loadButtonCount, 0);
            tc.verifyEqual(state.greenWorkbookButtons, 2);
            tc.verifyFalse(state.selectedWorkbookDisabled);
            tc.verifyFalse(state.allWorkbookDisabled);
            tc.verifyFalse(state.workspaceExportDisabled);
            tc.verifyEqual(string(state.resultActions), ...
                ["selected-to-workbook","all-to-workbook","export-to-workspace"]);
            tc.verifyNumElements(tc.Search.MainGridLayout.RowHeight, 1);
            tc.verifyEqual(numel(tc.Search.SelectedIds), 1);
            tc.Probe.act(tc, struct("kind","click","selector","#clear-criteria"));
            state = tc.Probe.act(tc, struct("kind","snapshot"));
            tc.verifyEqual(state.rows, 0);
            tc.verifyEmpty(tc.Search.SelectedIds);
            tc.verifyEmpty(tc.Search.SearchAxes.HTML.Data.Series);
            tc.verifyEmpty(tc.Search.TableData);
            tc.verifyTrue(state.selectedWorkbookDisabled);
            tc.verifyTrue(state.allWorkbookDisabled);
            tc.verifyTrue(state.workspaceExportDisabled);
            tc.verifyEqual(state.brandHeaderCount, 0);
            tc.verifyTrue(all(state.strictFlags));
        end

        function htmlSearchUsesRealEnvironment(tc)
            [environment, connection] = HTMLTestSupport.environment();
            tc.Search.Environment = environment;
            tc.Probe.act(tc, struct("kind","value","selector","#model-input","value","Model A;;Model B"));
            tc.Probe.act(tc, struct("kind","checked","selector","#model-strict","value",true));
            tc.Probe.act(tc, struct("kind","value","selector","#variable-input","value","Emissions"));
            tc.Probe.act(tc, struct("kind","checked","selector","#variable-strict","value",false));
            tc.Probe.act(tc, struct("kind","click","selector","#search-button"));
            state = tc.Probe.act(tc, struct("kind","snapshot"));
            tc.verifyEqual(connection.BulkDataRequest.runs, [101;202]);
            tc.verifyEqual(connection.BulkDataRequest.variables, "Emissions|CO2");
            tc.verifyEqual(state.criteriaFeedback, 'Search complete');
            tc.verifyFalse(state.searchDisabled);
            tc.verifyEqual(state.rows, height(tc.Search.Records));
            tc.verifyEqual(state.rows, 2);
        end

        function htmlSearchErrorRecovers(tc)
            tc.Probe.act(tc, struct("kind","click","selector","#search-button"));
            state = tc.Probe.act(tc, struct("kind","snapshot"));
            tc.verifyEqual(state.criteriaFeedback, 'Search failed');
            tc.verifyFalse(state.searchDisabled);
            tc.verifySubstring(state.selectionStatus, 'Select an environment');
            tc.verifyTrue(state.statusIsError);
            tc.verifyEqual(string(state.statusColor), ...
                sprintf("rgb(%d, %d, %d)", sscanf(state.errorColor,"#%2x%2x%2x")));
            state = tc.Probe.act(tc, struct("kind","click","selector","#clear-criteria"));
            tc.verifyFalse(state.statusIsError);
        end

        function noMatchesSkipProvider(tc)
            [environment, connection] = HTMLTestSupport.environment();
            tc.Search.Environment = environment;
            response = tc.Search.search(struct("variable", "Absent"));
            tc.verifyEqual(response.TotalCount, 0);
            tc.verifyEmpty(fieldnames(connection.BulkDataRequest));
        end

        function invalidExactFlagRejected(tc)
            tc.Search.Environment = HTMLTestSupport.environment();
            tc.verifyError(@() tc.Search.search(struct("modelStrict",1)), ...
                "iam:HTMLSearch:InvalidCriteria");
        end

        function exactMatchDefaultsAndPartialMatchOptOut(tc)
            [environment, connection] = HTMLTestSupport.environment();
            tc.Search.Environment = environment;
            state = tc.Probe.act(tc, struct("kind","snapshot"));
            tc.verifyTrue(all(state.strictFlags));
            tc.Probe.act(tc, struct("kind","value","selector","#variable-input","value","Emissions"));
            tc.Probe.act(tc, struct("kind","click","selector","#search-button"));
            state = tc.Probe.act(tc, struct("kind","snapshot"));
            tc.verifyEqual(state.rows, 0);
            tc.verifyEmpty(fieldnames(connection.BulkDataRequest));
            tc.Probe.act(tc, struct("kind","checked","selector","#variable-strict","value",false));
            tc.Probe.act(tc, struct("kind","click","selector","#search-button"));
            state = tc.Probe.act(tc, struct("kind","snapshot"));
            tc.verifyEqual(state.rows, 2);
            tc.verifyEqual(connection.BulkDataRequest.variables,"Emissions|CO2");
            state = tc.Probe.act(tc, struct("kind","click","selector","#clear-criteria"));
            tc.verifyTrue(all(state.strictFlags));
        end

        function htmlBrowseAddsFullVariablePath(tc)
            tc.Search.Environment = HTMLTestSupport.environment();
            tc.Probe.act(tc, struct("kind","click","selector",'[data-browse="variable"]'));
            state = tc.Probe.act(tc, struct("kind","snapshot"));
            tc.verifyTrue(state.browseOpen);
            tc.verifyEqual(state.browseOptions, 2);
            tc.verifyEqual(state.openBrowseGroups, 0);
            width = state.browseDialogWidth;
            height = state.browseDialogHeight;
            left = state.browseDialogLeft;
            top = state.browseDialogTop;
            inputWidth = state.browseSearchWidth;
            state = tc.Probe.act(tc, struct("kind","value","selector","#browse-search","value","Emissions"));
            tc.verifyEqual(state.browseOptions, 1);
            tc.verifyEqual(state.browseDialogWidth, width, AbsTol=0.5);
            tc.verifyEqual(state.browseDialogHeight, height, AbsTol=0.5);
            tc.verifyEqual(state.browseDialogLeft, left, AbsTol=0.5);
            tc.verifyEqual(state.browseDialogTop, top, AbsTol=0.5);
            tc.verifyEqual(state.browseSearchWidth, inputWidth, AbsTol=0.5);
            state = tc.Probe.act(tc, struct("kind","value","selector","#browse-search","value","No such variable"));
            tc.verifyEqual(state.browseOptions, 0);
            tc.verifyEqual(state.browseDialogWidth, width, AbsTol=0.5);
            tc.verifyEqual(state.browseDialogHeight, height, AbsTol=0.5);
            tc.verifyEqual(state.browseDialogLeft, left, AbsTol=0.5);
            tc.verifyEqual(state.browseDialogTop, top, AbsTol=0.5);
            tc.verifyEqual(state.browseSearchWidth, inputWidth, AbsTol=0.5);
            state = tc.Probe.act(tc, struct("kind","value","selector","#browse-search","value",""));
            tc.verifyEqual(state.browseOptions, 2);
            tc.verifyEqual(state.browseDialogWidth, width, AbsTol=0.5);
            tc.verifyEqual(state.browseDialogHeight, height, AbsTol=0.5);
            tc.verifyEqual(state.browseDialogLeft, left, AbsTol=0.5);
            tc.verifyEqual(state.browseDialogTop, top, AbsTol=0.5);
            tc.verifyEqual(state.browseSearchWidth, inputWidth, AbsTol=0.5);
            tc.Probe.act(tc, struct("kind","click","selector","#browse-options summary"));
            tc.Probe.act(tc, struct("kind","checked", ...
                "selector",'#browse-options input[value="Emissions|CO2"]',"value",true));
            state = tc.Probe.act(tc, struct("kind","snapshot"));
            tc.verifyTrue(state.browseOpen);
            tc.verifyEqual(state.variableInput, 'Emissions|CO2');
            state = tc.Probe.act(tc, struct("kind","checked", ...
                "selector",'#browse-options input[value="Emissions|CO2"]',"value",false));
            tc.verifyEqual(state.variableInput, '');
            tc.Probe.act(tc, struct("kind","click","selector","#close-browse"));
        end

        function htmlAllButtonExportsAllResults(tc)
            tc.Search.loadData(HTMLTestSupport.frame());
            tc.Search.WorkbookRequestedFcn = @(frame) tc.Probe.recordExport(frame);
            tc.Search.select(tc.Search.Records.ID(1));
            tc.Probe.act(tc, struct("kind","click","selector","#all-to-workbook"));
            tc.verifyEqual(tc.Probe.ExportedFrame.RunIds, [101;202;303]);
        end

        function workspaceExportWithoutSelectionExportsAll(tc)
            tc.Search.loadData(HTMLTestSupport.frame());
            tc.Search.WorkspaceExportRequestedFcn = @(series) tc.Probe.recordWorkspaceExport(series);
            tc.Probe.act(tc,struct("kind","click","selector","#export-to-workspace"));
            state = tc.Probe.act(tc,struct("kind","snapshot"));

            tc.verifyClass(tc.Probe.ExportedSeries,"iam.IAMTimeseries");
            tc.verifyEqual([tc.Probe.ExportedSeries.RunId],[101 202 303]);
            tc.verifyEqual(state.selected,0);
            tc.verifyEqual(state.workspaceExportTooltip,'Export all results to workspace');
            tc.verifySubstring(state.selectionStatus,'3 series exported to workspace');
        end

        function workspaceExportUsesOnlySelectedRows(tc)
            frame = HTMLTestSupport.frame();
            frame = frame.setMeta(table("Model B","Scenario B",1,"Selected", ...
                VariableNames=["Model","Scenario","Version","Category"]));
            tc.Search.loadData(frame);
            tc.Search.WorkspaceExportRequestedFcn = @(series) tc.Probe.recordWorkspaceExport(series);
            tc.Probe.act(tc,struct("kind","click","selector","#result-rows tr:nth-child(2)"));
            tc.Probe.act(tc,struct("kind","click","selector","#export-to-workspace"));
            state = tc.Probe.act(tc,struct("kind","snapshot"));
            exported = tc.Probe.ExportedSeries.toFrame();

            tc.verifyEqual(exported.RunIds,202);
            tc.verifyEqual(exported.meta().Category,"Selected");
            tc.verifyEqual(state.workspaceExportTooltip,'Export selected series to workspace');
            tc.verifySubstring(state.selectionStatus,'1 series exported to workspace');
        end

        function workspaceExportCancellationKeepsResults(tc)
            tc.Search.loadData(HTMLTestSupport.frame());
            tc.Search.WorkspaceExportRequestedFcn = @(~) false;
            tc.Probe.act(tc,struct("kind","click","selector","#export-to-workspace"));
            state = tc.Probe.act(tc,struct("kind","snapshot"));

            tc.verifyEqual(state.selectionStatus,'Export cancelled');
            tc.verifyFalse(state.statusIsError);
            tc.verifyEqual(height(tc.Search.Records),3);
        end

        function browseDialogKeepsSizeWithLongList(tc)
            [environment, connection] = HTMLTestSupport.environment();
            variables = "Group " + (1:40)' + "|Variable";
            variables(1) = "Emissions|CO2";
            connection.Refs.variables = table((1:40)', variables, ones(40,1), ...
                repmat("Mt/yr",40,1), VariableNames=["ID","Name","Unit ID","Unit"]);
            environment.reloadEnvironment();
            tc.Search.Environment = environment;
            tc.Probe.act(tc, struct("kind","click","selector",'[data-browse="variable"]'));
            initial = tc.Probe.act(tc, struct("kind","snapshot"));
            geometry = [initial.browseDialogWidth, initial.browseDialogHeight, ...
                initial.browseDialogLeft, initial.browseDialogTop];
            tc.verifyEqual(initial.browseOptions, 40);

            state = tc.Probe.act(tc, struct("kind","value","selector","#browse-search","value","Emissions"));
            tc.verifyEqual(state.browseOptions, 1);
            tc.verifyEqual([state.browseDialogWidth, state.browseDialogHeight, ...
                state.browseDialogLeft, state.browseDialogTop], geometry, AbsTol=0.5);

            state = tc.Probe.act(tc, struct("kind","value","selector","#browse-search","value","No such variable"));
            tc.verifyEqual(state.browseOptions, 0);
            tc.verifyEqual([state.browseDialogWidth, state.browseDialogHeight, ...
                state.browseDialogLeft, state.browseDialogTop], geometry, AbsTol=0.5);

            state = tc.Probe.act(tc, struct("kind","value","selector","#browse-search","value",""));
            tc.verifyEqual(state.browseOptions, 40);
            tc.verifyEqual([state.browseDialogWidth, state.browseDialogHeight, ...
                state.browseDialogLeft, state.browseDialogTop], geometry, AbsTol=0.5);
        end

        function shiftClickSelectsRangeAndClickReplacesIt(tc)
            import matlab.unittest.constraints.Eventually
            import matlab.unittest.constraints.IsTrue
            chartProbe = HTMLProbe(tc.Search.SearchAxes.HTML);
            tc.addTeardown(@delete, chartProbe);
            tc.assertThat(@() chartProbe.Ready, Eventually(IsTrue(), WithTimeoutOf=15));
            tc.Search.loadData(HTMLTestSupport.frame());
            tc.Probe.act(tc, struct("kind","click","selector","#result-rows tr:first-child"));
            state = tc.Probe.act(tc, struct("kind","click", ...
                "selector","#result-rows tr:nth-child(3)","shift",true));
            tc.verifyEqual(state.selected, 3);
            tc.verifyEqual(tc.Search.SelectedFrameData.RunIds, [101;202;303]);
            chartState = chartProbe.act(tc, struct("kind","snapshot"));
            tc.verifyEqual(chartState.lineCount, 3);
            tc.verifyEqual(chartState.legendCount, 3);
            tc.verifyTrue(chartState.finiteGeometry);
            state = tc.Probe.act(tc, struct("kind","click","selector","#result-rows tr:nth-child(2)"));
            tc.verifyEqual(state.selected, 1);
            tc.verifyEqual(tc.Search.SelectedFrameData.RunIds, 202);
            chartState = chartProbe.act(tc, struct("kind","snapshot"));
            tc.verifyEqual(chartState.lineCount, 1);
        end
    end
end
