classdef IAMTimeseries
    
    % Copyright 2020-2021 The MathWorks, Inc.
    
    properties (SetAccess = private)
        Model    (1,1) string
        Scenario (1,1) string
        Variable (1,1) string
        Region   (1,1) string
        Unit     (1,1) string
        RunId    (1,1) double
        Version  (1,1) double
        Years    (:,1) double
        Values   (:,:) timetable
    end
    
    methods
        idx = ismember(obj, ts)
    end
    
    methods
        
        function obj = IAMTimeseries(Data)
            
            if nargin > 0 && ~isempty(Data)
                
                m = size(Data,1);
                n = size(Data,2);
                obj = repelem(obj,n,m);
                
                for i = 1 : numel(Data)
                    data = Data(i);
                    obj(i).Model = data.model;
                    obj(i).Scenario = data.scenario;
                    obj(i).Variable = data.variable;
                    obj(i).Region = data.region;
                    obj(i).Unit = data.unit;
                    obj(i).Years = data.years;
                    obj(i).Values = data.values;
                end
                
            end
            
        end        
        
        function r = plus(obj1, obj2) 
            
            tt = synchronize(obj1.Values, obj2.Values);            
            lim = numel(obj1);
            newValues = tt{:, 1:lim} + tt{:, lim+1:end};
            
            r = iam.IAMTimeseries.getGeneric(newValues, tt.Year);
            
        end
        
        function r = minus(obj1, obj2)
                        
            tt = synchronize(obj1.Values, obj2.Values);
            lim = numel(obj1);
            newValues = tt{:, 1:lim} - tt{:, lim+1:end};
            
            r = iam.IAMTimeseries.getGeneric(newValues, tt.Year);
        end
        
        function r = times(obj1, obj2)
                        
            tt = synchronize(obj1.Values, obj2.Values);
            lim = numel(obj1);
            newValues = tt{:, 1:lim}.*tt{:, lim+1:end};
            
            r = iam.IAMTimeseries.getGeneric(newValues, tt.Year);
        end
        
        function r = rdivide(obj1, obj2)
                        
            tt = synchronize(obj1.Values, obj2.Values);
            lim = numel(obj1);
            newValues = tt{:, 1:lim}./tt{:, lim+1:end};
            
            r = iam.IAMTimeseries.getGeneric(newValues, tt.Year);
        end
        
        function [h,l] = plot(obj, varargin)
            
            if ~isempty(obj)
                allVars = synchronize(obj.Values);
                try 
                    h = plot(allVars.Year, allVars{:,:}, varargin{:});
                catch
                    
                    h = plot(obj(1).Years, obj(1).Values, varargin{:});
                    hold(h(1).Parent,'on')
                    for i = 2 : length(obj)
                        h(i) = plot(obj(i).Years, obj(i).Values, varargin{:});
                    end
                    hold(h(1).Parent,'off')
                end
                axis(h(1).Parent,'tight');
                xlabel(h(1).Parent,'Years');

                units = unique([obj.Unit]);
                if numel(units) == 1
                    ylabel(h(1).Parent, "Units:   " + units);
                else
                    ylabel(h(1).Parent, "Multiple Units ");
                end

                str = igetLegend(obj);
                l = legend(h(1).Parent,str,'Location','best','Interpreter','none');
            else
                h = [];
            end
                         
        end
        
        function [h,l] = bar(obj, varargin)
            
            if ~isempty(obj)
                allVars = synchronize(obj.Values);
                h = bar(allVars.Year, allVars{:,:}, varargin{:});
                
                axis(h(1).Parent,'tight');
                xlabel(h(1).Parent,'Years');

                units = unique([obj.Unit]);
                if numel(units) == 1
                    ylabel(h(1).Parent, "Units:   " + units);
                else
                    ylabel(h(1).Parent, "Multiple Units ");
                end

                str = igetLegend(obj);
                l = legend(h(1).Parent,str,'Location','best','Interpreter','none');
            else
                h = [];
            end
            
        end
        
        function value = uniqueRegions(obj)
           value = unique([obj.Region]); 
        end
        
        function value = uniqueVariables(obj)
           value = unique([obj.Variable]); 
        end
        
        function value = uniqueModels(obj)
           value = unique([obj.Model]); 
        end
        
        function value = uniqueScenarios(obj)
           value = unique([obj.Scenario]); 
        end
        
        function lst = getRunList(obj)
            lst = table( ...
                [obj.Model]',[obj.Scenario]',[obj.Variable]',[obj.Region]',[obj.RunId]',[obj.Version]', ...
                'VariableNames',{'Model','Scenario','Variable','Region','RunId','Verison'}...
                );
        end
        
    end
    
    methods (Static, Access = private)
        
        function r = getGeneric(newValues, date) 
            
            r = iam.IAMTimeseries();
            
            r.Model    = "Custom";
            r.Scenario = "Custom";
            r.Variable = "Custom";
            r.Region   = "Custom";
            r.Unit     = "Custom";
            r.RunId    = NaN;
            r.Version  = NaN;
            
            r = repmat(r, size(newValues, 2), 1);
            Y = year(date);
            for i = 1 : size(newValues, 2)
                r(i).Years = Y;
                r(i).Values = timetable(date, newValues(:,i), ...
                    'DimensionNames', {'Year','VariableUnits'}, 'VariableNames',{'Values'});
            end
            
        end
    end
    
end

function str = igetLegend(dt)

str = "";
str = iaddVarToLegend(str,'Model',[dt.Model]);
str = iaddVarToLegend(str,'Scenario',[dt.Scenario]);
str = iaddVarToLegend(str,'Variable',[dt.Variable]);
str = iaddVarToLegend(str,'Region',[dt.Region]);
str = iaddVarToLegend(str,'Id',[dt.RunId]);

if numel(str) == 1
    str = "Region = " + unique(dt.Region);
end

end

function str = iaddVarToLegend(str,var,data)

if isnumeric(data)
    format = '%s = %d';
else
    format = '%s = %s';
end

if length(unique(data)) ~= 1
    if numel(str) == 1
        str = str + arrayfun(@(x) string(sprintf('%s = %s',var(1),x)) , data);
    else
        str = str + arrayfun(@(x) string(sprintf(", " + format,var(1),x)) , data);
    end
end

end