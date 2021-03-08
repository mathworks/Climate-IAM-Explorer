classdef MetaDataTabs < matlab.mixin.SetGet
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties
        TabGroup matlab.ui.container.TabGroup
        Tabs matlab.ui.container.Tab
        Grids matlab.ui.container.GridLayout
    end
    
    properties (Dependent)
        Layout
    end
    
    methods
        
        function obj = MetaDataTabs(varargin)
            
            obj.TabGroup = uitabgroup(varargin{:});
            
        end
        
        function gl = addTab(obj, varargin)
            
            t = uitab(obj.TabGroup, varargin{:});            
            gl = uigridlayout(t, [1 1]);
            obj.Tabs = [obj.Tabs; t];
            obj.Grids = [obj.Grids; gl];
            
        end
        
        function changeTab(obj, id)
            
            idx = obj.getTabIdx(id);
            obj.TabGroup.SelectedTab = obj.Tabs(idx);
            
        end
        
        function bool = tabExists(obj, name)
            bool = ismember({obj.Tabs.Title}, name);
            if isempty(bool)
                bool = false;
            end
        end
        
        function cleanTabs(obj)
           if ~isempty(obj.Tabs)
               delete(obj.Tabs);
               obj.Tabs(1:end) = [];
           end               
        end
        
        function value = get.Layout(obj)
            value = obj.TabGroup.Layout;
        end
        
        function set.Layout(obj, value)
            obj.TabGroup.Layout = value;
        end
        
    end
    
    methods (Access = protected)
        
        function idx = getTabIdx(obj, value)
            if isnumeric(value)
                idx = value;
            elseif isstring(value) || ischar(value)
                idx = strcmp(value,{obj.Tabs.Title});
            end
        end
        
    end
end