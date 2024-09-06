classdef IAMworkbook < matlab.mixin.SetGetExactNames
    
    properties (Access = public)
        
        MainGridLayout matlab.ui.container.GridLayout

        GridLayout    matlab.ui.container.GridLayout
        RegionsListBox                  matlab.ui.control.ListBox
        RegionsListBoxLabel             matlab.ui.control.Label
        VariablesListBox                matlab.ui.control.ListBox
        VariablesListBoxLabel           matlab.ui.control.Label
        ScenariosListBox                matlab.ui.control.ListBox
        ScenariosListBoxLabel           matlab.ui.control.Label
        ModelsListBoxLabel              matlab.ui.control.Label
        ModelsListBox                   matlab.ui.control.ListBox
        ClearWorkspaceButton            matlab.ui.control.Button
        ExportAllButton                 matlab.ui.control.Button
        ExportSelectedButton            matlab.ui.control.Button
        LoadWorkspaceButton             matlab.ui.control.Button
        
        WbAxes        iam.views.IAMChart
    end
    
    properties (Dependent, SetAccess = private)
        FilteredData (:,1) struct
    end
    
    properties (SetAccess = private)
        Data (:,1) iam.IAMTimeseries
    end
    
    properties (Dependent, SetAccess = private)
        RunList
        NumDatasets
        Models
        Scenarios
        Variables
        Regions
    end
    
    properties (Access = private)
        IdxRegions   (:,1) logical
        IdxModels    (:,1) logical
        IdxScenarios (:,1) logical
        IdxVariables (:,1) logical
    end
    
    properties (Dependent, Access = private)
        IdxFilter
    end
    
    events
        DataChanged
    end
    
    methods
        
        function obj = IAMworkbook(varargin)
                        
            addlistener(obj,'DataChanged', @(s,e) obj.sendDataToPlot() );
            
            g1 = uigridlayout([1 2], varargin{:});
            g1.ColumnWidth = {'1x', '2x'};

            obj.MainGridLayout = g1;            
            obj.createComponents
            
        end
        
        function addData(obj, data)
            
            if ~isa(data, 'iam.IAMTimeseries')
                error('data must be a IAMTimeseries object')
            end
            
            if ~isempty(data)
                
                idx = ismember(obj.Data, data);
                
                obj.Data = [obj.Data; data(~idx,:)];
                
                obj.resetFilter();
                
                % set models
                obj.ModelsListBox.Items = obj.Models;
                obj.ModelsListBox.Value = obj.ModelsListBox.Items{1};
                obj.removeFilter('Model');
                obj.addFilter('Model', obj.ModelsListBox.Items{1})
                
                % set scenario
                obj.ScenariosListBox.Items = obj.Scenarios;
                obj.ScenariosListBox.Value = obj.ScenariosListBox.Items{1};
                obj.removeFilter('Scenario');
                obj.addFilter('Scenario', obj.ScenariosListBox.Items{1})
                
                % set variable (no repeated values allowed)
                currentVariable = obj.VariablesListBox.Value;
                obj.VariablesListBox.Items = obj.Variables;
                if isempty(currentVariable)
                    currentVariable = obj.VariablesListBox.Items{1};
                end
                obj.VariablesListBox.Value = currentVariable;
                obj.addFilter('Variable', currentVariable)
                
                % set region
                regions = obj.Regions;
                obj.RegionsListBox.Items = regions;
                
                try
                    obj.RegionsListBox.Value = {'World'};
                    obj.addFilter('Region', 'World')
                catch
                    obj.RegionsListBox.Value = obj.RegionsListBox.Items{1};
                    obj.addFilter('Region', obj.RegionsListBox.Items{1});
                end
                
            else
                obj.Data = data;
                
                obj.resetFilter();
                
                obj.ModelsListBox.Items = {};
                obj.ScenariosListBox.Items = {};
                obj.VariablesListBox.Items = {};
                obj.RegionsListBox.Items = {};
            end
            
            obj.WbAxes.changeData(obj.FilteredData)
            
        end
        
        function resetFilter(obj)
            
            nd = obj.NumDatasets;
            [obj.IdxModels, obj.IdxScenarios, ...
                obj.IdxVariables, obj.IdxRegions] = deal(true(nd, 1));
            
            try
                obj.IdxRegions = strcmpi(obj.RunList.Region,'World');
            catch
                obj.IdxRegions = true(nd, 1);
            end
            
        end
        
        function addFilter(obj, type, value)
            idx = ismember([obj.Data.(type)] , value);
            obj.modifyFilter(type, idx)
        end
        
        function removeFilter(obj, type)
            obj.modifyFilter(type, true(1, obj.NumDatasets))
        end
        
    end
    
    methods % Accessors
        
        function values = get.RunList(obj)
            ts = obj.Data;
            values = table([ts.Model]', [ts.Scenario]', [ts.Variable]', [ts.Region]', [ts.RunId]',[ts.Version]', ...
                'VariableNames', {'Model','Scenario','Variable','Region','RunId','Version'});
        end
        
        function value = get.IdxFilter(obj)
            value = obj.IdxModels & obj.IdxScenarios & obj.IdxRegions & obj.IdxVariables;
        end
        
        function value = get.FilteredData(obj)
            value = obj.Data(obj.IdxFilter, :);
        end
        
        function value = get.NumDatasets(obj)
            value = numel(obj.Data);
        end
        
        function value = get.Models(obj)
            value = obj.Data.uniqueModels();
        end
        
        function value = get.Scenarios(obj)
            value = obj.Data.uniqueScenarios();
        end
        
        function value = get.Variables(obj)
            value = obj.Data.uniqueVariables();
        end
        
        function value = get.Regions(obj)
            value = obj.Data.uniqueRegions();
        end
        
    end
    
    methods (Access = private)
        
        function modifyFilter(obj, type, idx)
            
            switch type
                case 'Model'
                    obj.IdxModels = idx;
                case 'Scenario'
                    obj.IdxScenarios = idx;
                case 'Variable'
                    obj.IdxVariables = idx;
                case 'Region'
                    obj.IdxRegions = idx;
            end
            
        end
        
        function createFilter(obj, type, value)
            if isempty(value)
                obj.removeFilter(type)
            else
                obj.addFilter(type, value)
            end
            notify(obj,'DataChanged')
        end
        
        % Button pushed function: LoadWorkspaceButton
        function LoadWorkspaceButtonPushed(obj)
            [file, path] = uigetfile('*.mat');
            
            if ~isnumeric(file)
                var = load(fullfile(path, file));
                namevar = fields(var);
                try
                    obj.addData(var.(namevar{1}));
                catch e
                    f = ancestor(obj.MainGridLayout, 'figure', 'toplevel');
                    uialert(f , e.message, 'Invalid Data', Icon = 'error');
                end
            end
        end
        
        % Button pushed function: ClearWorkspaceButton
        function ClearWorkspaceButtonPushed(obj)
            obj.addData(iam.IAMTimeseries.empty());
        end
        
        % Button pushed function: ExportAllButton
        function ExportAllButtonPushed(obj)
            obj.exportData(false)
        end
        
        % Button pushed function: ExportSelectedButton
        function ExportSelectedButtonPushed(obj)
            obj.exportData(true)
        end
        
        function exportData(obj, filter)
            if filter
                data = obj.FilteredData;
            else
                data = obj.Data;
            end
            
            iam.utils.exportToWorspace(data)
        end
        
        % Value changed function: ModelsListBox
        function ModelsListBoxValueChanged(obj)
            value = obj.ModelsListBox.Value;
            obj.createFilter('Model', value)
        end
        
        % Value changed function: ScenariosListBox
        function ScenariosListBoxValueChanged(obj)
            value = obj.ScenariosListBox.Value;
            obj.createFilter('Scenario', value)
        end
        
        % Value changed function: RegionsListBox
        function RegionsListBoxValueChanged(obj)
            value = obj.RegionsListBox.Value;
            obj.createFilter('Region', value)
        end
        
        % Value changed function: VariablesListBox
        function VariablesListBoxValueChanged(obj)
            value = obj.VariablesListBox.Value;
            obj.createFilter('Variable', value)
        end
        
        function sendDataToPlot(obj)

            obj.WbAxes.changeData(obj.FilteredData)
            
        end
        
    end
    
    % Component initialization
    methods (Access = private)
        
        % Create UIFigure and components
        function createComponents(obj)                     

            % Create GridLayout
            obj.GridLayout = uigridlayout(obj.MainGridLayout);
            obj.GridLayout.ColumnWidth = {'1x', '1x'};
            obj.GridLayout.RowHeight = {40, '12x'};
            obj.GridLayout.ColumnSpacing = 0;
            obj.GridLayout.RowSpacing = 0;
            obj.GridLayout.Padding = [0 0 0 0];
            obj.GridLayout.Layout.Row = 1;
            obj.GridLayout.Layout.Column = 1;  
            
            
            % Set Figure 
            obj.WbAxes = iam.views.IAMChart('Parent',obj.MainGridLayout);
            obj.WbAxes.GridLayout.BackgroundColor = [0.23,0.29,0.22];
            obj.WbAxes.UIAxes.XColor = 'w';
            obj.WbAxes.UIAxes.YColor = 'w';
            obj.WbAxes.UIAxes.GridColor = 'k';
            obj.WbAxes.CheckBox.FontColor = 'w';
            obj.WbAxes.Label.FontColor = 'w';

            % Create GridLayout2
            g2 = uigridlayout(obj.MainGridLayout, [5 4]);
            g2.Layout.Row = 1;
            g2.Layout.Column = 1;
            g2.RowHeight = {20, '10x', 20, '10x', 30};
            g2.Padding = [5 5 5 5];
            g2.BackgroundColor = [0.61,0.81,0.57];
            
            % Create ModelsListBox
            obj.ModelsListBox = uilistbox(g2);
            obj.ModelsListBox.Items = {};
            obj.ModelsListBox.Multiselect = 'on';
            obj.ModelsListBox.ValueChangedFcn = @(s,e) obj.ModelsListBoxValueChanged();
            obj.ModelsListBox.Layout.Row = 2;
            obj.ModelsListBox.Layout.Column = [1 2];
            obj.ModelsListBox.Value = {};
            
            % Create ModelsListBoxLabel
            obj.ModelsListBoxLabel = uilabel(g2);
            obj.ModelsListBoxLabel.Layout.Row = 1;
            obj.ModelsListBoxLabel.Layout.Column = [1 2];
            obj.ModelsListBoxLabel.Text = 'MODELS';
            obj.ModelsListBoxLabel.FontWeight = "bold";
            obj.ModelsListBoxLabel.HorizontalAlignment = "center";
            
            % Create ScenariosListBoxLabel
            obj.ScenariosListBoxLabel = uilabel(g2);
            obj.ScenariosListBoxLabel.Layout.Row = 1;
            obj.ScenariosListBoxLabel.Layout.Column = [3 4];
            obj.ScenariosListBoxLabel.Text = 'SCENARIOS';
            obj.ScenariosListBoxLabel.FontWeight = "bold";
            obj.ScenariosListBoxLabel.HorizontalAlignment = "center";
            
            % Create ScenariosListBox
            obj.ScenariosListBox = uilistbox(g2);
            obj.ScenariosListBox.Items = {};
            obj.ScenariosListBox.Multiselect = 'on';
            obj.ScenariosListBox.ValueChangedFcn = @(s,e) obj.ScenariosListBoxValueChanged();
            obj.ScenariosListBox.Layout.Row = 2;
            obj.ScenariosListBox.Layout.Column = [3 4];
            obj.ScenariosListBox.Value = {};
            
            % Create VariablesListBoxLabel
            obj.VariablesListBoxLabel = uilabel(g2);
            obj.VariablesListBoxLabel.Layout.Row = 3;
            obj.VariablesListBoxLabel.Layout.Column = [1 2];
            obj.VariablesListBoxLabel.Text = 'VARIABLES';
            obj.VariablesListBoxLabel.FontWeight = "bold";
            obj.VariablesListBoxLabel.HorizontalAlignment = "center";
            
            % Create VariablesListBox
            obj.VariablesListBox = uilistbox(g2);
            obj.VariablesListBox.Items = {};
            obj.VariablesListBox.Multiselect = 'on';
            obj.VariablesListBox.ValueChangedFcn = @(s,e) obj.VariablesListBoxValueChanged();
            obj.VariablesListBox.Layout.Row = 4;
            obj.VariablesListBox.Layout.Column = [1 2];
            obj.VariablesListBox.Value = {};
            
            % Create RegionsListBoxLabel
            obj.RegionsListBoxLabel = uilabel(g2);
            obj.RegionsListBoxLabel.Layout.Row = 3;
            obj.RegionsListBoxLabel.Layout.Column = [3 4];
            obj.RegionsListBoxLabel.Text = 'REGIONS';
            obj.RegionsListBoxLabel.FontWeight = "bold";
            obj.RegionsListBoxLabel.HorizontalAlignment = "center";
            
            % Create RegionsListBox
            obj.RegionsListBox = uilistbox(g2);
            obj.RegionsListBox.Items = {};
            obj.RegionsListBox.Multiselect = 'on';
            obj.RegionsListBox.ValueChangedFcn = @(s,e) obj.RegionsListBoxValueChanged();
            obj.RegionsListBox.Layout.Row = 4;
            obj.RegionsListBox.Layout.Column = [3 4];
            obj.RegionsListBox.Value = {};
            
            % Create LoadWorkspaceButton
            obj.LoadWorkspaceButton = uibutton(g2, 'push');
            obj.LoadWorkspaceButton.ButtonPushedFcn = @(s,e) obj.LoadWorkspaceButtonPushed();
            obj.LoadWorkspaceButton.Layout.Row = 5;
            obj.LoadWorkspaceButton.Layout.Column = 1;
            obj.LoadWorkspaceButton.Text = 'Load';
            
            % Create ExportSelectedButton
            obj.ExportSelectedButton = uibutton(g2, 'push');
            obj.ExportSelectedButton.ButtonPushedFcn =  @(s,e) obj.ExportSelectedButtonPushed;
            obj.ExportSelectedButton.Layout.Row = 5;
            obj.ExportSelectedButton.Layout.Column = 2;
            obj.ExportSelectedButton.Text = 'Export';
            
            % Create ExportAllButton
            obj.ExportAllButton = uibutton(g2, 'push');
            obj.ExportAllButton.ButtonPushedFcn = @(s,e) obj.ExportAllButtonPushed;
            obj.ExportAllButton.Layout.Row = 5;
            obj.ExportAllButton.Layout.Column = 3;
            obj.ExportAllButton.Text = 'Export All';
            
            % Create ClearWorkspaceButton
            obj.ClearWorkspaceButton = uibutton(g2, 'push');
            obj.ClearWorkspaceButton.ButtonPushedFcn = @(s,e) obj.ClearWorkspaceButtonPushed;
            obj.ClearWorkspaceButton.Layout.Row = 5;
            obj.ClearWorkspaceButton.Layout.Column = 4;
            obj.ClearWorkspaceButton.Text = 'Clear';
            
            % Show the figure after all components are created
            obj.MainGridLayout.Visible = 'on';
        end
    end
    
end
