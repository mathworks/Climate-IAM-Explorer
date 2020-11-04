classdef SearchDatabaseControls < matlab.mixin.SetGet
    
    properties
        MainGridLayout matlab.ui.container.GridLayout
        
        UITable matlab.ui.control.Table
        
        SearchAxes matlab.ui.control.UIAxes
        
        LoadDataButton             matlab.ui.control.Button
        SelectedtoWorkspaceButton  matlab.ui.control.Button
        AlltoWorkspaceButton       matlab.ui.control.Button
        
        GenericEditField      matlab.ui.control.EditField
        GenericStrictCheckbox matlab.ui.control.CheckBox
        GenericHTML           iiasa.views.HTMLTree
        
        TreeTab iiasa.views.MetaDataTabs
    end
    
    properties (SetAccess = private)
        
        TableData (:,1) iiasa.IIASATimeseries
        OpenTreeButton matlab.ui.control.Button
        
    end
    
    properties (Dependent, SetAccess = private)
        SelectedTableData
    end
    
    properties (Access = private)
        InputsGrid matlab.ui.container.GridLayout
        TableIdx (:,2) double
        TreeFields (:,1) string
    end
    
    methods
        
        function obj = SearchDatabaseControls(varargin)
            
            g1 = uigridlayout([1 2], varargin{:},'ColumnWidth',{'1x', '0x', '1x'});
            obj.MainGridLayout = g1;
            
            % Set Search Database Tab axis
            SDAx = iiasa.views.createAxesWithLegend('Parent',g1);
            SDAx.GridLayout.Layout.Row = 1;
            SDAx.GridLayout.Layout.Column = 3;
            
            obj.SearchAxes = SDAx.UIAxes;
            
            g2 = uigridlayout(g1);
            g2.ColumnWidth = {'1x'};
            g2.RowHeight = {'1x', '2x', '0.2x'};
            g2.Padding = [0 0 0 0];
            g2.Layout.Row = 1;
            g2.Layout.Column = 1;
            
            obj.UITable = uitable(g2);
            obj.UITable.ColumnName = {'Model'; 'Scenario'; 'Variable'; 'Region'; 'RunId'; 'Version'};
            obj.UITable.RowName = {};
            obj.UITable.Layout.Row = 2;
            obj.UITable.Layout.Column = 1;
            obj.UITable.CellSelectionCallback = @(s,e) obj.plotSelected(e);
            
            g3 = uigridlayout(g2);
            g3.ColumnWidth = {'1x', '1x', '1x'};
            g3.RowHeight = {'1x'};
            g3.Padding = [0 0 0 0];
            g3.Layout.Row = 3;
            g3.Layout.Column = 1;
            
            % Create LoadDataButton
            obj.LoadDataButton = uibutton(g3, 'push');
            obj.LoadDataButton.Layout.Row = 1;
            obj.LoadDataButton.Layout.Column = 1;
            obj.LoadDataButton.Text = 'Load Data';
            
            % Create SelectedtoWorkspaceButton
            obj.SelectedtoWorkspaceButton = uibutton(g3, 'push');
            obj.SelectedtoWorkspaceButton.Layout.Row = 1;
            obj.SelectedtoWorkspaceButton.Layout.Column = 2;
            obj.SelectedtoWorkspaceButton.Text = 'Selected to Workspace';
            
            % Create AlltoWorkspaceButton
            obj.AlltoWorkspaceButton = uibutton(g3, 'push');
            obj.AlltoWorkspaceButton.Layout.Row = 1;
            obj.AlltoWorkspaceButton.Layout.Column = 3;
            obj.AlltoWorkspaceButton.Text = 'All to Workspace';
            
            % Create InputvaluesseparatedbysemicolonsPanel
            p1 = uipanel(g2);
            p1.Title = 'Input values separated by semicolons';
            p1.Layout.Row = 1;
            p1.Layout.Column = 1;
            
            % Create GridLayout26
            g4 = uigridlayout(p1);
            g4.ColumnWidth = {'15x', '1x'};
            g4.RowHeight = {'1x'};
            g4.Padding = [0 0 0 0];
            
            % Create GridLayout18
            g5 = uigridlayout(g4);
            g5.ColumnWidth = {'1x', '5x', '1x'};
            g5.RowHeight = {'1x', '1x', '1x', '1x'};
            g5.Layout.Row = 1;
            g5.Layout.Column = 1;
            obj.InputsGrid = g5;
            
            % Create Button
            obj.OpenTreeButton = uibutton(g4, 'push');
            obj.OpenTreeButton.ButtonPushedFcn = @(s,e) obj.ButtonPushed(e);
            obj.OpenTreeButton.FontSize = 20;
            obj.OpenTreeButton.Layout.Row = 1;
            obj.OpenTreeButton.Layout.Column = 2;
            obj.OpenTreeButton.Text = '<<';
            
            obj.TreeTab = iiasa.views.MetaDataTabs('Parent',g1);
            obj.TreeTab.Layout.Row = 1;
            obj.TreeTab.Layout.Column = 2;
            
        end
        
        function [data, strict] = getCallDetails(obj, name)
            
            [~, idx] = ismember(name, obj.TreeFields);
            editField = obj.GenericEditField(idx);
            checkBox = obj.GenericStrictCheckbox(idx);
            
            data = strsplit(editField.Value,';');
            strict = checkBox.Value;
            
        end
        
        function addMetadataTree(obj, field, name)
            
            [exists, idx] = ismember(name, obj.TreeFields);
            if ~exists
                obj.addEditField(1, name);
                obj.addCheckBox(3, 'Strict');
                obj.TreeFields = [obj.TreeFields; name];
                obj.TreeTab.addTab('Title', name);
                
                idx = numel(obj.GenericHTML) + 1;
            else
                delete(obj.GenericHTML(idx))
            end
            
            obj.GenericHTML(idx) = iiasa.views.HTMLTree('Parent',obj.TreeTab.Grids(idx),'DataChangedFcn', @(s,e) appendEditField(s,e));
            obj.GenericHTML(idx).fillTree(field);
            obj.GenericHTML(idx).HTML.DataChangedFcn = @(s,e) appendEditField(e);
            
            function appendEditField(e)
                
                editField = obj.GenericEditField(idx);
                info = jsondecode(e.Data);
                if info.VALUE
                    newVar = field(str2double(info.ID));
                    if isempty(editField.Value)
                        editField.Value = newVar;
                    else
                        editField.Value = strjoin([editField.Value;newVar],";");
                    end
                else
                    newVar = field(str2double(info.ID));
                    editField.Value = strjoin(setdiff(split(editField.Value,';'),newVar),';');
                end
                
            end
        end
        
        function loadData(obj, ts)
            
            if ~isa(ts, 'iiasa.IIASATimeseries')
                error('SearchDatabaseControls:InvalidDataType','Data must be a iiasa.IIASATimeseries object')
            end
            
            obj.TableData = ts;
            obj.UITable.Data = ts.getRunList;
            
        end
        
        function value = get.SelectedTableData(obj)
            if isempty(obj.TableIdx)
                value = obj.UITable.Data;
            else
                value = obj.UITable.Data(obj.TableIdx(:,1),:);
            end
        end
        
    end
    
    methods (Access = private)
        
        function addEditField(obj, col, text)
            row = numel(obj.GenericEditField) + 1;
            
            % Create VariableEditFieldLabel
            label = uilabel(obj.InputsGrid);
            label.HorizontalAlignment = 'right';
            label.Layout.Row = row;
            label.Layout.Column = col;
            label.Text = text;
            
            % Create VariableEditField
            ef = uieditfield(obj.InputsGrid, 'text');
            ef.Layout.Row = row;
            ef.Layout.Column = col + 1;
            
            obj.GenericEditField(row) = ef;
        end
        
        function addCheckBox(obj, col, text)
            
            row = numel(obj.GenericStrictCheckbox) + 1;
            
            % Create StrictCheckBox_2
            cb = uicheckbox(obj.InputsGrid);
            cb.Text = text;
            cb.Layout.Row = row;
            cb.Layout.Column = col;
            
            obj.GenericStrictCheckbox(row) = cb;
        end
        
        function ButtonPushed(obj,event)
            if strcmp(event.Source.Text,"<<")
                obj.MainGridLayout.ColumnWidth = {'1x','1x'};
                event.Source.Text = ">";
            else
                obj.MainGridLayout.ColumnWidth = {'1x','0x'};
                event.Source.Text = "<<";
            end
        end
        
        function appendEditField(~,e,editField)
            editField.Value = e.Data;
        end
        
        function plotSelected(obj,event)
            
            indices = event.Indices;
            obj.TableIdx = indices;
            [~,b] = intersect(obj.TableData.getRunList, obj.UITable.Data(indices(:,1),:));
            plot(obj.TableData(b),'Parent',obj.SearchAxes,'LineWidth',2);
            
        end
        
    end
end