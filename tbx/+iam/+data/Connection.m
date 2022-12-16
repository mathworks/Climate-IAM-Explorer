classdef (Abstract) Connection < matlab.mixin.SetGetExactNames
    
    properties (Abstract, Dependent)
        Environment % Name of the database where we are connected
    end
    
    properties (Abstract, SetAccess = private)
        ConnectionProperties
    end
    
    methods (Abstract)
        ts     = getBulkData( obj, varargin );
        params = getRunDetails( obj, runId );
        refs   = getRefs( obj );
        runs   = getRunsList();
        value  = getDocumentation(obj, type, idx);
        
        response = getAllModels(obj)
        response = getAllScenarios(obj)
    end
    
    methods
        function value = getEnvironmentConfig(obj)
            value = obj.Config;
        end
        
        function value = getEnvironments(obj)
            value = obj.AllEnvironments;
        end
    end
    
end