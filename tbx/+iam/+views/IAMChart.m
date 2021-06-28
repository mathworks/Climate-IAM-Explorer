classdef createAxesWithLegend < matlab.mixin.SetGet
    
    properties
        UIAxes
        CheckBox
        GridLayout
        LegendDropDown
        ChartTypeDropDown
    end
    
    events
      PlotChanged
    end
    
    methods
        
        function obj = createAxesWithLegend(varargin)
            
            addlistener(obj,'PlotChanged', @(s,e) obj.HandlePlotChanged() );
            
            obj.GridLayout = uigridlayout(varargin{:});
            obj.GridLayout.ColumnWidth = {'1x','1x',160,'1x'};
            obj.GridLayout.RowHeight = {'1x', '20x'};
            obj.GridLayout.Padding = [0 0 0 0];
            
            obj.UIAxes = uiaxes(obj.GridLayout);
            title(obj.UIAxes, '')
            xlabel(obj.UIAxes, 'Year')
            ylabel(obj.UIAxes, 'Y')
            obj.UIAxes.Box = 'on';
            obj.UIAxes.XGrid = 'on';
            obj.UIAxes.YGrid = 'on';
            obj.UIAxes.Layout.Row = 2;
            obj.UIAxes.Layout.Column = [1 4];
            
            obj.CheckBox = uicheckbox(obj.GridLayout);
            obj.CheckBox.ValueChangedFcn = @(s,e) obj.DisplayLegendCheckBoxValueChanged(e);
            obj.CheckBox.Text = 'Display Legend, Location: ';
            obj.CheckBox.Layout.Row = 1;
            obj.CheckBox.Layout.Column = 3;
            obj.CheckBox.Value = true;
            
            obj.LegendDropDown = uidropdown(obj.GridLayout);
            obj.LegendDropDown.Layout.Row = 1;
            obj.LegendDropDown.Layout.Column = 4;
            obj.LegendDropDown.Items = ["best","bestoutside","north","south","east","west","northeast","northwest","southeast","southwest", ...
                "northoutside","southoutside","eastoutside","westoutside","northeastoutside","northwestoutside","southeastoutside","southwestoutside"];
            obj.LegendDropDown.ValueChangedFcn = @(s,e) obj.ChangeLegendLocation(e);
            
            obj.ChartTypeDropDown = uidropdown(obj.GridLayout);
            obj.ChartTypeDropDown.Layout.Row = 1;
            obj.ChartTypeDropDown.Layout.Column = 2;
            obj.ChartTypeDropDown.Items = ["line", "bar"];
%             obj.ChartTypeDropDown.ValueChangedFcn = @(s,e) obj.ChangeLegendLocation(e);

            lb = uilabel(obj.GridLayout);
            lb.Layout.Row = 1;
            lb.Layout.Column = 1;
            lb.Text = 'Chart type';
            lb.HorizontalAlignment = 'right';
        end
                
    end
    
    methods (Access = private)
        
        function DisplayLegendCheckBoxValueChanged(obj, e)
            value = e.Value;
            if ~isempty(obj.UIAxes.Legend)
                obj.UIAxes.Legend.Visible = matlab.lang.OnOffSwitchState(value);
            end
        end
        
        function ChangeLegendLocation(obj, e)
            value = e.Value;
            if ~isempty(obj.UIAxes.Legend)
                obj.UIAxes.Legend.Location = value;
            end
        end
        
        function HandlePlotChanged(obj)
            
            if ~isempty(obj.UIAxes.Legend)
                value = obj.CheckBox.Value;
                obj.UIAxes.Legend.Visible = matlab.lang.OnOffSwitchState(value);
                
                loc = obj.LegendDropDown.Value;
                obj.UIAxes.Legend.Location = loc;
            end
            
        end
        
    end    
    
end