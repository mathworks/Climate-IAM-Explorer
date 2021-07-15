classdef IAManalysis < matlab.mixin.SetGetExactNames
    
    properties (Access = public)
        
        MainGridLayout matlab.ui.container.GridLayout
                
        EqualSign     matlab.ui.control.Label
        FormulaField  matlab.ui.control.EditField
        VarNameField  matlab.ui.control.EditField
        AddButton     matlab.ui.control.Button
        CustomVars    matlab.ui.control.Table
        IAMvars       matlab.ui.control.Table
        
    end
    
    methods
        function obj = IAManalysis(varargin)
            
            % Create GridLayout2
            obj.MainGridLayout = uigridlayout([4 4], varargin{:});
            obj.MainGridLayout.ColumnWidth = {50, 20, '1x', 50};
            obj.MainGridLayout.RowHeight = {'5x', 20, '3x'};
            
            obj.createComponents
        end
    end
    
     % Component initialization
    methods (Access = private)
        
        % Create UIFigure and components
        function createComponents(obj)          
            
            % Create IAMvars
            obj.IAMvars = uitable(obj.MainGridLayout);
            obj.IAMvars.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            obj.IAMvars.RowName = {};
            obj.IAMvars.Layout.Row = 1;
            obj.IAMvars.Layout.Column = [1 4];
            
            % Create CustomVars
            obj.CustomVars = uitable(obj.MainGridLayout);
            obj.CustomVars.ColumnName = {'Column 1'; 'Column 2'; 'Column 3'; 'Column 4'};
            obj.CustomVars.RowName = {};
            obj.CustomVars.Layout.Row = 3;
            obj.CustomVars.Layout.Column = [1 4];
            
            % Create AddButton
            obj.AddButton = uibutton(obj.MainGridLayout, 'push');
            obj.AddButton.Layout.Row = 2;
            obj.AddButton.Layout.Column = 4;
            obj.AddButton.Text = 'Add';
            obj.AddButton.Enable = false;
            
            % Create VarNameField
            obj.VarNameField = uieditfield(obj.MainGridLayout, 'text');
            obj.VarNameField.Layout.Row = 2;
            obj.VarNameField.Layout.Column = 1;
            obj.VarNameField.Value = 'myVar';
            obj.VarNameField.Enable = false;
            
            % Create FormulaField
            obj.FormulaField = uieditfield(obj.MainGridLayout, 'text');
            obj.FormulaField.Layout.Row = 2;
            obj.FormulaField.Layout.Column = 3;
            obj.FormulaField.Enable = false;
            
            % Create EqualSign
            obj.EqualSign = uilabel(obj.MainGridLayout);
            obj.EqualSign.FontSize = 16;
            obj.EqualSign.Layout.Row = 2;
            obj.EqualSign.Layout.Column = 2;
            obj.EqualSign.Text = '=';
            
        end
    end
end