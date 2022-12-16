classdef setConnectionProperties
    
    properties
        FIG
        TB
    end
    
    properties (Access = private)
        Conn
    end
    
    methods 
        function obj = setConnectionProperties(c)
            obj.Conn = c;
            
            obj.FIG = uifigure;
            gl = uigridlayout([1,1], 'Parent', obj.FIG);
            obj.TB = uitable(gl, ...
                'ColumnName', "Property Value",  ...
                "RowName", c.ConnectionProperties', ...
                "ColumnEditable", true);
            obj.TB.Data = c.ConnectionValues';
            obj.TB.CellEditCallback = @(s,e) changeProperty(obj, e);
        end
    end
    
    methods (Access = private)
        function changeProperty(obj, e)
            prop = obj.TB.RowName(e.Indices(1));
            obj.Conn.ConnectionProperties.(prop{1}) = e.NewData;        
        end
    end
    
end
