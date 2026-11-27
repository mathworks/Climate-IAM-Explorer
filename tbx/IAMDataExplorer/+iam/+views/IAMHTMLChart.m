classdef IAMHTMLChart < matlab.mixin.SetGet
    %IAMHTMLChart - Display annual IAM series in the HTML preview
    %   VIEW = iam.views.IAMHTMLChart(Parent=PARENT) creates a chart.
    %
    %   See also iam.views.IAMChart, iam.IAMFrame

    properties (SetAccess = private)
        GridLayout matlab.ui.container.GridLayout % Chart container.
        HTML matlab.ui.control.HTML % HTML chart surface.
    end

    events
        PlotChanged
    end

    properties (Access = private)
        HeaderVisible (1,1) logical = false
    end

    methods
        function obj = IAMHTMLChart(varargin)
            obj.GridLayout = uigridlayout(varargin{:});
            obj.GridLayout.RowHeight = {"1x"};
            obj.GridLayout.ColumnWidth = {"1x"};
            obj.GridLayout.Padding = [0 0 0 0];
            obj.HTML = uihtml(obj.GridLayout, Tag="IAMHTMLChart");
            obj.HTML.Data = struct("Title", "Select a result", ...
                "Unit", "", "Note", "", "Series", struct([]), ...
                "HeaderVisible", obj.HeaderVisible);
            obj.HTML.HTMLSource = fullfile(fileparts(mfilename("fullpath")), ...
                "web", "plot-page-v10.html");
        end

        function hideHeader(obj)
            %hideHeader - Remove the redundant preview heading
            %   hideHeader(OBJ) gives the chart card the full available height.
            obj.HeaderVisible = false;
            payload = obj.HTML.Data;
            payload.HeaderVisible = false;
            obj.HTML.Data = payload;
        end

        function changeData(obj, data)
            %changeData - Preview every selected series on a shared axis
            %   changeData(OBJ,DATA) accepts an IAMFrame or IAMTimeseries array.
            if isa(data, "iam.IAMFrame")
                data = data.toTimeseries();
            elseif ~isa(data, "iam.IAMTimeseries")
                error("iam:IAMHTMLChart:InvalidData", ...
                    "Use an IAMFrame or IAMTimeseries array.")
            end
            payload = struct("Title", "Select a result", ...
                "Unit", "", "Note", "", "Series", struct([]), ...
                "HeaderVisible", obj.HeaderVisible);
            if ~isempty(data)
                variables = unique([data.Variable]);
                units = unique([data.Unit]);
                versions = unique([data.Version]);
                labels = data.legendLabels();
                if isscalar(labels)
                    labels = repmat(labels, 1, numel(data));
                end
                if ~isscalar(units)
                    labels = labels + ", U = " + [data.Unit];
                end
                if ~isscalar(versions)
                    labels = labels + ", Version = " + [data.Version];
                end
                years = unique(vertcat(data.Years))';
                series = repmat(struct("Label", "", "FullLabel", "", "Variable", "", ...
                    "Unit", "", "Years", [], "Values", []), numel(data), 1);
                for i = 1:numel(data)
                    values = NaN(size(years));
                    [~, location] = ismember(data(i).Years, years);
                    values(location) = data(i).Values{:,1};
                    series(i) = struct( ...
                        "Label", labels(i), ...
                        "FullLabel", "Model: " + data(i).Model + newline + ...
                            "Scenario: " + data(i).Scenario + newline + ...
                            "Variable: " + data(i).Variable + newline + ...
                            "Region: " + data(i).Region + newline + ...
                            "Unit: " + data(i).Unit + newline + ...
                            "Run ID: " + data(i).RunId + newline + ...
                            "Version: " + data(i).Version, ...
                        "Variable", data(i).Variable, "Unit", data(i).Unit, ...
                        "Years", years, "Values", values);
                end
                if isscalar(variables)
                    payload.Title = variables;
                else
                    payload.Title = "Selected series";
                end
                payload.Series = series;
                if isscalar(units)
                    payload.Unit = units;
                else
                    payload.Unit = "Multiple units";
                    payload.Note = "Series use different units; values share one axis.";
                end
            end
            obj.HTML.Data = payload;
            notify(obj, "PlotChanged");
        end
    end
end
