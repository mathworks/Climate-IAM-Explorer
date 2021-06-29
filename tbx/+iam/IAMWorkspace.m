classdef IAMWorkspace < matlab.mixin.SetGet
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties
%        ViewAxes iam.views.IAMChart 
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
    
    methods
        
        function obj = IAMWorkspace(data)
            
            if nargin == 1
                obj.Data = data;
                obj.resetFilter;
            end
            
        end
        
        function addData(obj, data)
            
            if ~isa(data, 'iam.IAMTimeseries')
                error('data must be a IAMTimeseries object')
            end
            
            idx = ismember(obj.Data, data);
            
            obj.Data = [obj.Data; data(~idx,:)];
            
            obj.resetFilter();
        end
        
        function h = plot(obj, selected, varargin)
            
            if selected
                h = plot(obj.FilteredData,varargin{:});
            else
                h = plot(obj.Data,varargin{:});
            end
            
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
        
    end
    
end