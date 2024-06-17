classdef IAMChart < matlab.mixin.SetGet
    
    properties
        UIAxes
        CheckBox
        GridLayout
        LegendDropDown
        ChartTypeDropDown
        Label
    end
    
    properties (Access = private)
        Data (:,1) iam.IAMTimeseries
        BarProps cell = {};
        LineProps cell = {'LineWidth',2};
    end
    
    events
        PlotChanged
    end
    
    methods
        
        function obj = IAMChart(varargin)
            
            addlistener(obj,'PlotChanged', @(s,e) obj.HandlePlotChanged() );
            
            obj.GridLayout = uigridlayout(varargin{:});
            obj.GridLayout.ColumnWidth = {'1x','1x',160,'1x'};
            obj.GridLayout.RowHeight = {30, '20x'};
            obj.GridLayout.Padding = [0 0 5 5];
            
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
            obj.LegendDropDown.ValueChangedFcn = @(s,e) obj.ChangeLegendLocation(s, e);
            
            obj.ChartTypeDropDown = uidropdown(obj.GridLayout);
            obj.ChartTypeDropDown.Layout.Row = 1;
            obj.ChartTypeDropDown.Layout.Column = 2;
            obj.ChartTypeDropDown.Items = ["line", "bar stacked", "bar grouped"];
            obj.ChartTypeDropDown.ValueChangedFcn = @(s,e) obj.ChangePlotType();
            
            lb = uilabel(obj.GridLayout);
            lb.Layout.Row = 1;
            lb.Layout.Column = 1;
            lb.Text = 'Chart type';
            lb.HorizontalAlignment = 'right';
            obj.Label = lb;
            
        end
        
        function changeData(obj, data, varargin)
            if nargin > 2
                if obj.ChartTypeDropDown.Value == "line"
                    obj.LineProps = varargin;
                elseif obj.ChartTypeDropDown.Value == "bar"
                    obj.BarProps = varargin;
                end
            end
            obj.Data = data;
            obj.update()
        end
        
        function changeProps(obj, varargin)
            if obj.ChartTypeDropDown == "line"
                obj.LineProps = varargin;
            elseif obj.ChartTypeDropDown == "bar"
                obj.BarProps = varargin;
            end
            obj.update()
        end
        
    end
    
    methods (Access = private)
        
        function DisplayLegendCheckBoxValueChanged(obj, e)
            value = e.Value;
            if ~isempty(obj.UIAxes.Legend)
                obj.UIAxes.Legend.Visible = matlab.lang.OnOffSwitchState(value);
            end
        end
        
        function ChangeLegendLocation(obj, ~, e)
            value = e.Value;
            if ~isempty(obj.UIAxes.Legend)
                obj.UIAxes.Legend.Location = value;
            end
        end
        
        function ChangePlotType(obj)
            obj.update();
        end
        
        function HandlePlotChanged(obj)
            
            if ~isempty(obj.UIAxes.Legend)
                value = obj.CheckBox.Value;
                obj.UIAxes.Legend.Visible = matlab.lang.OnOffSwitchState(value);
                
                loc = obj.LegendDropDown.Value;
                obj.UIAxes.Legend.Location = loc;
            end
            
        end
        
        function update(obj)
            if ~isempty(obj.Data)
                switch obj.ChartTypeDropDown.Value
                    case 'line'
                        plot(obj.Data, 'Parent', obj.UIAxes, obj.LineProps{:});
                    case 'bar stacked'
                        bar(obj.Data, 'stacked', 'Parent', obj.UIAxes, obj.BarProps{:});
                    case 'bar grouped'
                        bar(obj.Data, 'grouped', 'Parent', obj.UIAxes, obj.BarProps{:});
                end
            else
                cla(obj.UIAxes);
            end
            notify(obj, 'PlotChanged')
        end
        
    end
    
end
