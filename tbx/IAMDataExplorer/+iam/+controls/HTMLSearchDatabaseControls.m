classdef HTMLSearchDatabaseControls < matlab.mixin.SetGet
    %HTMLSearchDatabaseControls - Search IAM environments with the HTML view
    %   VIEW = iam.controls.HTMLSearchDatabaseControls(Parent=PARENT)
    %   creates the search criteria, results, and preview components.
    %
    %   See also iam.controls.SearchDatabaseControls, iam.views.IAMHTMLChart

    properties
        Environment = [] % Environment queried by the search view.
        WorkbookRequestedFcn = [] % Callback accepting an IAMFrame.
        WorkspaceExportRequestedFcn = @iam.utils.exportToWorspace % Workspace/file export callback.
    end

    properties (SetAccess = private)
        MainGridLayout matlab.ui.container.GridLayout % Search container.
        HTML matlab.ui.control.HTML % Search HTML surface.
        SearchAxes iam.views.IAMHTMLChart % Selected series preview.
        Records table = table() % Result identities, including opaque IDs.
        SelectedIds (:,1) string = strings(0,1) % Current selected identities.
    end

    properties (Dependent, SetAccess = private)
        TableData % All result series.
        SelectedFrameData % Explicitly selected result observations.
    end

    properties (Access = private)
        FrameData = iam.IAMFrame()
        SeriesData = iam.IAMTimeseries.empty()
        Generation (1,1) double = 0
    end

    methods
        function obj = HTMLSearchDatabaseControls(varargin)
            obj.MainGridLayout = uigridlayout(varargin{:});
            obj.MainGridLayout.ColumnWidth = {"1x", "1.3x"};
            obj.MainGridLayout.RowHeight = {"1x"};
            obj.MainGridLayout.Padding = [10,10,10,10];
            obj.HTML = uihtml(obj.MainGridLayout, Tag="IAMHTMLSearch");
            obj.HTML.Layout.Column = 1;
            obj.HTML.HTMLEventReceivedFcn = @(~,event) obj.handleEvent(event);
            obj.HTML.Data = struct("Source", "Select an environment");
            obj.HTML.HTMLSource = fullfile(fileparts(which("iam.views.IAMHTMLChart")), ...
                "web", "search-page-v6.html");
            obj.SearchAxes = iam.views.IAMHTMLChart(Parent=obj.MainGridLayout);
            obj.SearchAxes.hideHeader();
            obj.SearchAxes.GridLayout.Layout.Column = 2;
            obj.replaceData(iam.IAMFrame());
        end

        function set.Environment(obj, value)
            if ~isempty(value) && ~isa(value, "iam.IAMEnvironment")
                error("iam:HTMLSearch:InvalidEnvironment", "Use an IAMEnvironment.")
            end
            obj.Environment = value;
            obj.resetEnvironment(value);
        end

        function response = search(obj, criteria)
            %search - Fetch matching observations from the current environment
            %   RESPONSE = search(OBJ,CRITERIA) applies independent exact-match
            %   flags to the model, scenario, variable, and region criteria.
            if isempty(obj.Environment)
                error("iam:HTMLSearch:NoEnvironment", "Select an environment first.")
            end
            criteria = obj.validateCriteria(criteria);
            progress = uiprogressdlg(ancestor(obj.MainGridLayout,"figure"), ...
                Title="Fetching data", Message="Finding matching runs...", ...
                Indeterminate="on", Cancelable="on");
            monitor = iam.views.RequestProgressMonitor(progress);
            progressCleanup = onCleanup(@() obj.finishSearch(progress, monitor));
            drawnow;
            obj.replaceData(iam.IAMFrame());
            try
                drawnow;
                if progress.CancelRequested
                    response = obj.resultPayload();
                    return
                end
                variables = obj.Environment.filterVariables( ...
                    criteria.variable, criteria.variableStrict);
                regions = obj.Environment.filterRegions( ...
                    criteria.region, criteria.regionStrict);
                models = obj.Environment.filterRuns(models=criteria.model, ...
                    strict=criteria.modelStrict);
                scenarios = obj.Environment.filterRuns(scenarios=criteria.scenario, ...
                    strict=criteria.scenarioStrict);
                runs = intersect(models, scenarios);
                if ~isempty(variables) && ~isempty(regions) && ~isempty(runs)
                    progress.Message = "Fetching time series...";
                    drawnow;
                    if progress.CancelRequested
                        response = obj.resultPayload();
                        return
                    end
                    monitorFcn = @() monitor;
                    data = obj.Environment.getFrame(runs=runs, variables=variables, ...
                        regions=regions, strict=true, progressMonitorFcn=monitorFcn);
                else
                    data = iam.IAMFrame();
                end
                progress.ShowPercentage = "off";
                progress.Indeterminate = "on";
                progress.Message = "Preparing results...";
                drawnow;
                if progress.CancelRequested
                    response = obj.resultPayload();
                    return
                end
                progress.Cancelable = "off";
                obj.replaceData(data);
                response = obj.resultPayload();
                sendEventToHTMLSource(obj.HTML, "searchResults", response);
            catch exception
                if obj.wasSearchCancelled(progress, monitor)
                    response = obj.resultPayload();
                    return
                end
                rethrow(exception)
            end
        end

        function loadData(obj, data)
            %loadData - Replace results and clear the current selection
            %   loadData(OBJ,DATA) accepts an IAMFrame or IAMTimeseries array.
            obj.replaceData(data);
            sendEventToHTMLSource(obj.HTML, "searchResults", obj.resultPayload());
        end

        function select(obj, ids)
            %select - Preview an explicit set of current result IDs
            %   select(OBJ,IDS) rejects identities from earlier searches.
            if ~(isempty(ids) || isstring(ids) || ischar(ids) || iscellstr(ids))
                error("iam:HTMLSearch:InvalidSelection", "Selection IDs must be text.")
            end
            ids = unique(string(ids), "stable");
            ids = ids(:);
            if any(ismissing(ids)) || any(~ismember(ids, obj.Records.ID))
                error("iam:HTMLSearch:UnknownSelection", "Selection contains an unknown result ID.")
            end
            obj.SelectedIds = ids;
            rows = ismember(obj.Records.ID, ids);
            obj.SearchAxes.changeData(obj.SeriesData(rows));
            sendEventToHTMLSource(obj.HTML, "selectionStatus", ...
                struct("Message", numel(ids) + " selected · " + ...
                numel(obj.SearchAxes.HTML.Data.Series) + " plotted"));
        end

        function loadSelected(obj)
            %loadSelected - Send the explicit selection to the workbook
            %   loadSelected(OBJ) calls WorkbookRequestedFcn with an IAMFrame.
            if ~isempty(obj.SelectedIds)
                obj.exportFrame(obj.SelectedFrameData);
            end
        end

        function exported = exportToWorkspace(obj)
            %exportToWorkspace - Export selected series or all search results
            %   EXPORTED = exportToWorkspace(OBJ) uses the workbook export dialog.
            data = obj.SeriesData;
            if ~isempty(obj.SelectedIds)
                data = data(ismember(obj.Records.ID,obj.SelectedIds));
            end
            exported = false;
            if isempty(data)
                return
            end
            exported = obj.WorkspaceExportRequestedFcn(data);
            if isdeployed()
                message = "Export dialog closed";
            elseif exported
                message = numel(data) + " series exported to workspace";
            else
                message = "Export cancelled";
            end
            sendEventToHTMLSource(obj.HTML,"selectionStatus",struct("Message",message));
        end

        function value = get.TableData(obj)
            value = obj.SeriesData;
        end

        function value = get.SelectedFrameData(obj)
            rows = ismember(obj.Records.ID, obj.SelectedIds);
            if any(rows)
                value = iam.IAMFrame(obj.SeriesData(rows));
            else
                value = iam.IAMFrame();
            end
        end
    end

    methods (Access = private)
        function resetEnvironment(obj, value)
            obj.replaceData(iam.IAMFrame());
            if isempty(value)
                source = "Select an environment";
            else
                source = value.Environment;
            end
            obj.HTML.Data = struct("Source", source);
        end

        function replaceData(obj, data)
            if isa(data, "iam.IAMTimeseries")
                data = data.toFrame();
            elseif ~isa(data, "iam.IAMFrame")
                error("iam:HTMLSearch:InvalidData", "Use an IAMFrame or IAMTimeseries array.")
            end
            obj.FrameData = data;
            obj.SeriesData = data.toTimeseries();
            obj.Generation = obj.Generation + 1;
            obj.Records = data.summary();
            obj.Records.ID = "g" + obj.Generation + "r" + (1:height(obj.Records))';
            obj.SelectedIds = strings(0,1);
            obj.SearchAxes.changeData(iam.IAMTimeseries.empty());
        end

        function handleEvent(obj, event)
            try
                payload = event.HTMLEventData;
                switch string(event.HTMLEventName)
                    case "searchRequested"
                        obj.search(payload);
                    case "requestFacet"
                        facet = string(payload.facet);
                        if ~isscalar(facet) || ~ismember(facet, ["model","scenario","variable","region"])
                            error("iam:HTMLSearch:InvalidFacet", "Unknown search facet.")
                        end
                        if isempty(obj.Environment)
                            error("iam:HTMLSearch:NoEnvironment", "Select an environment first.")
                        end
                        names = ["Models", "Scenarios", "Variables", "Regions"];
                        field = names(["model","scenario","variable","region"] == facet);
                        options = unique(obj.Environment.(field).Name, "stable");
                        sendEventToHTMLSource(obj.HTML, "facetOptions", ...
                            struct("Facet", facet, "Options", {cellstr(options)}));
                    case "selectionChanged"
                        obj.select(payload.ids);
                    case "criteriaCleared"
                        obj.replaceData(iam.IAMFrame());
                    case "loadSelected"
                        obj.select(payload.ids);
                        obj.loadSelected();
                    case "loadAll"
                        if ~isempty(obj.SeriesData)
                            obj.exportFrame(obj.FrameData);
                        end
                    case "exportRequested"
                        obj.select(payload.ids);
                        obj.exportToWorkspace();
                    case "viewReady"
                        if ~isempty(obj.Records)
                            sendEventToHTMLSource(obj.HTML, "searchResults", obj.resultPayload());
                        end
                    otherwise
                        error("iam:HTMLSearch:UnknownEvent", "Unknown search event.")
                end
            catch exception
                sendEventToHTMLSource(obj.HTML, "error", ...
                    struct("Message", string(exception.message)));
            end
        end

        function payload = resultPayload(obj)
            payload = struct("Records", table2struct(obj.Records), ...
                "TotalCount", height(obj.Records));
        end

        function notifySearchCancelled(obj)
            sendEventToHTMLSource(obj.HTML, "searchCancelled", ...
                struct("Message", "Search canceled"));
        end

        function finishSearch(obj, progress, monitor)
            wasCancelled = obj.wasSearchCancelled(progress, monitor);
            if isvalid(progress)
                close(progress);
            end
            if wasCancelled
                obj.notifySearchCancelled();
            end
        end

        function value = wasSearchCancelled(~, progress, monitor)
            value = monitor.CancelRequestedByUser;
            if isvalid(progress)
                value = value || progress.CancelRequested;
            end
        end

        function exportFrame(obj, frame)
            try
                if ~isempty(obj.WorkbookRequestedFcn)
                    obj.WorkbookRequestedFcn(frame);
                    sendEventToHTMLSource(obj.HTML, "selectionStatus", ...
                        struct("Message", "Data added to workbook"));
                end
            catch exception
                sendEventToHTMLSource(obj.HTML, "error", ...
                    struct("Message", string(exception.message)));
            end
        end
    end

    methods (Static, Access = private)
        function criteria = validateCriteria(criteria)
            if ~isstruct(criteria) || ~isscalar(criteria)
                error("iam:HTMLSearch:InvalidCriteria", "Criteria must be a scalar structure.")
            end
            for facet = ["model", "scenario", "variable", "region"]
                if ~isfield(criteria, facet)
                    criteria.(facet) = "";
                end
                raw = criteria.(facet);
                if ~((isstring(raw) && isscalar(raw)) || (ischar(raw) && isrow(raw)) || isempty(raw))
                    error("iam:HTMLSearch:InvalidCriteria", "Criteria must be scalar text.")
                end
                tokens = strtrim(split(string(raw), ";;"));
                if any(ismissing(tokens))
                    error("iam:HTMLSearch:InvalidCriteria", "Criteria must not be missing.")
                end
                criteria.(facet) = tokens(tokens ~= "")';
                flag = facet + "Strict";
                if ~isfield(criteria, flag)
                    criteria.(flag) = true;
                end
                if ~islogical(criteria.(flag)) || ~isscalar(criteria.(flag))
                    error("iam:HTMLSearch:InvalidCriteria", "Exact-match flags must be logical scalars.")
                end
            end
        end
    end
end
