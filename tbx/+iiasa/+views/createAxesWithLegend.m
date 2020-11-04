classdef createAxesWithLegend < matlab.mixin.SetGet
    
    properties
        UIAxes
        CheckBox
        GridLayout
    end
    
    methods
        
        function obj = createAxesWithLegend(varargin)
            
            obj.GridLayout = uigridlayout(varargin{:});
            obj.GridLayout.ColumnWidth = {'1x'};
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
            obj.UIAxes.Layout.Column = 1;
            
            obj.CheckBox = uicheckbox(obj.GridLayout);
            obj.CheckBox.ValueChangedFcn = @(s,e) obj.DisplayLegendCheckBoxValueChanged(e);
            obj.CheckBox.Text = 'Display Legend';
            obj.CheckBox.Layout.Row = 1;
            obj.CheckBox.Layout.Column = 1;
            obj.CheckBox.Value = true;
        end
                
    end
    
    methods (Access = private)
        
        function DisplayLegendCheckBoxValueChanged(obj, e)
            value = e.Value;
            if ~isempty(obj.UIAxes.Legend)
                obj.UIAxes.Legend.Visible = matlab.lang.OnOffSwitchState(value);
            end
        end
        
    end    
    
end