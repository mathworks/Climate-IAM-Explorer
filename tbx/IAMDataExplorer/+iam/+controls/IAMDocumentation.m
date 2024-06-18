classdef IAMDocumentation < handle
    %IAMVIEWS Summary of this class goes here
    %   Detailed explanation goes here   

    properties
        GridLayout
        InfoHTML
        ModelLabel
        ModelInfoDropDown
        ScenarioLabel
        ScenarioInfoDropDown
        RegionLabel
        RegionInfoDropDown
        VariableLabel
        TimeseriesInfoDropDown
    end

    properties (Access = private)
        Environment (1,1) iam.IAMEnvironment
        Parent
    end
    
    methods
        function obj = IAMDocumentation(Parent)
            %IAMVIEWS Construct an instance of this class
            %   Detailed explanation goes here
            % Create HTML
            arguments
                Parent = uifigure
            end

            obj.Parent = Parent;

            obj.GridLayout = uigridlayout(Parent);
            obj.GridLayout.ColumnWidth = {'1x', '1x', '1x', '1x'};
            obj.GridLayout.RowHeight = {30, 30, '1x'};


            obj.InfoHTML = uihtml(obj.GridLayout);
            obj.InfoHTML.HTMLSource = '<p></p>';
            obj.InfoHTML.Layout.Row = 3;
            obj.InfoHTML.Layout.Column = [1 4];            

            % Create ModelLabel
            obj.ModelLabel = uilabel(obj.GridLayout);
            obj.ModelLabel.HorizontalAlignment = 'center';
            obj.ModelLabel.Layout.Row = 1;
            obj.ModelLabel.Layout.Column = 1;
            obj.ModelLabel.Text = 'Model';
            obj.ModelLabel.FontWeight = "bold";

            % Create ModelInfoDropDown
            obj.ModelInfoDropDown = uidropdown(obj.GridLayout);
            obj.ModelInfoDropDown.Editable = 'on';
            obj.ModelInfoDropDown.ValueChangedFcn = @(~,e) obj.showModelInfo(e);
            obj.ModelInfoDropDown.BackgroundColor = [1 1 1];
            obj.ModelInfoDropDown.Layout.Row = 2;
            obj.ModelInfoDropDown.Layout.Column = 1;            

            % Create ScenarioLabel
            obj.ScenarioLabel = uilabel(obj.GridLayout);
            obj.ScenarioLabel.HorizontalAlignment = 'center';
            obj.ScenarioLabel.Layout.Row = 1;
            obj.ScenarioLabel.Layout.Column = 2;
            obj.ScenarioLabel.Text = 'Scenario';
            obj.ScenarioLabel.FontWeight = "bold";

            % Create ScenarioInfoDropDown
            obj.ScenarioInfoDropDown = uidropdown(obj.GridLayout);
            obj.ScenarioInfoDropDown.Editable = 'on';
            obj.ScenarioInfoDropDown.ValueChangedFcn = @(~,e) obj.showScenarioInfo(e);
            obj.ScenarioInfoDropDown.BackgroundColor = [1 1 1];
            obj.ScenarioInfoDropDown.Layout.Row = 2;
            obj.ScenarioInfoDropDown.Layout.Column = 2;

            % Create RegionLabel
            obj.RegionLabel = uilabel(obj.GridLayout);
            obj.RegionLabel.HorizontalAlignment = 'center';
            obj.RegionLabel.Layout.Row = 1;
            obj.RegionLabel.Layout.Column = 3;
            obj.RegionLabel.Text = 'Region';
            obj.RegionLabel.FontWeight = "bold";

            % Create RegionInfoDropDown
            obj.RegionInfoDropDown = uidropdown(obj.GridLayout);
            obj.RegionInfoDropDown.Editable = 'on';
            obj.RegionInfoDropDown.ValueChangedFcn = @(~,e) obj.showRegionInfo(e);
            obj.RegionInfoDropDown.BackgroundColor = [1 1 1];
            obj.RegionInfoDropDown.Layout.Row = 2;
            obj.RegionInfoDropDown.Layout.Column = 3;

            % Create VariableLabel
            obj.VariableLabel = uilabel(obj.GridLayout);
            obj.VariableLabel.HorizontalAlignment = 'center';
            obj.VariableLabel.Layout.Row = 1;
            obj.VariableLabel.Layout.Column = 4;
            obj.VariableLabel.Text = 'Variable';
            obj.VariableLabel.FontWeight = "bold";

            % Create TimeseriesInfoDropDown
            obj.TimeseriesInfoDropDown = uidropdown(obj.GridLayout);
            obj.TimeseriesInfoDropDown.Editable = 'on';
            obj.TimeseriesInfoDropDown.ValueChangedFcn = @(~,e) obj.showVariableInfo(e);
            obj.TimeseriesInfoDropDown.BackgroundColor = [1 1 1];
            obj.TimeseriesInfoDropDown.Layout.Row = 2;
            obj.TimeseriesInfoDropDown.Layout.Column = 4;

        end

        function fillDropdowns(obj, Environment)

            arguments
                obj
                Environment (1,1) iam.IAMEnvironment
            end

            obj.Environment = Environment;

            [models, idx] = sort(Environment.Models.Name);
            obj.ModelInfoDropDown.Items = ["";models];
            obj.ModelInfoDropDown.ItemsData = [0;Environment.Models.ID(idx)];

            [scenarios, idx] = sort(Environment.Scenarios.Name);
            obj.ScenarioInfoDropDown.Items = ["";scenarios];
            obj.ScenarioInfoDropDown.ItemsData = [0;Environment.Scenarios.ID(idx)];

            [regions, idx] = sort(Environment.Regions.Name);
            obj.RegionInfoDropDown.Items = ["";regions];
            obj.RegionInfoDropDown.ItemsData = [0;Environment.Regions.ID(idx)];

            obj.TimeseriesInfoDropDown.Items = ["";unique(Environment.Variables.Name)];
            
        end

        function showModelInfo(obj, event)
            
            obj.ScenarioInfoDropDown.Value = 0;
            obj.RegionInfoDropDown.Value = 0;
            obj.TimeseriesInfoDropDown.Value = "";

            value = event.Value;
            if value ~= 0
                doc = obj.Environment.getModelDocumentation(value);
                if isempty(doc)
                    obj.InfoHTML.HTMLSource = '<p>NO INFO</p>';
                else
                    obj.InfoHTML.HTMLSource = doc.description;
                end
            end

        end

        function showScenarioInfo(obj, event)

            obj.ModelInfoDropDown.Value = 0;
            obj.RegionInfoDropDown.Value = 0;
            obj.TimeseriesInfoDropDown.Value = "";

            value = event.Value;
            if value ~= 0
                doc = obj.Environment.getScenarioDocumentation(value);
                if isempty(doc)
                    obj.InfoHTML.HTMLSource = '<p>NO INFO</p>';
                else
                    obj.InfoHTML.HTMLSource = doc.description;
                end
            end

        end

        function showRegionInfo(obj, event)

            obj.ModelInfoDropDown.Value = 0;
            obj.ScenarioInfoDropDown.Value = 0;
            obj.TimeseriesInfoDropDown.Value = "";

            value = event.Value;
            if value ~= 0
                doc = obj.Environment.getRegionDocumentation(value);
                if isempty(doc)
                    obj.InfoHTML.HTMLSource = '<p>NO INFO</p>';
                else
                    obj.InfoHTML.HTMLSource = doc.description;
                end
            end
        end

        function showVariableInfo(obj, event)
            value = event.Value;

            obj.ModelInfoDropDown.Value = 0;
            obj.ScenarioInfoDropDown.Value = 0;
            obj.RegionInfoDropDown.Value = 0;

            idx = obj.Environment.Variables.Name == value;
            toSearch = obj.Environment.Variables(idx,:);

            pfigure = ancestor(obj.GridLayout, 'figure', 'toplevel');
            d = uiprogressdlg(pfigure, Message='Loading Documentation...', Title = 'Loading', Indeterminate='on' );
            cleanupObj = onCleanup(@() delete(d));

            if height(toSearch) == 1
                doc = obj.Environment.getTimeseriesDocumentation(toSearch{1,"ID"});
                allInfo = doc.description;
            else
                allInfo = "<h1>" + obj.TimeseriesInfoDropDown.Value + "</h1> <p>Multiple units might be available</p>";            

                for i = 1 : height(toSearch)
                    doc = obj.Environment.getTimeseriesDocumentation(toSearch{i,"ID"});
                    if isempty(doc)
                        allInfo = sprintf(allInfo +"<br> Unit: %s </br> ", toSearch{i,"Unit"});
                    else
                        allInfo = sprintf(allInfo + "%s", doc.description);
                    end
                end

            end

            obj.InfoHTML.HTMLSource = allInfo;

        end

    end

end