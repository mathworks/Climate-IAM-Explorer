classdef IAMTimeseries
% IAMTimeseries Timeseries container for Integrated Assessment Model data
%
% IAMTimeseries stores time series data from Integrated Assessment Models
% (IAMs) along with metadata such as model, scenario, variable, region,
% unit, run id and version. Each element of an IAMTimeseries array
% contains a timetable in the `Values` property with a Year time vector.
%
% Construction
%   obj = IAMTimeseries(Data)
%     Construct an array of IAMTimeseries objects from a struct or object
%     array `Data` that contains fields: model, scenario, variable,
%     region, unit, runId, version, years (datetime vector), values
%     (numeric vector or timetable).
%     Optional RunInfo, Metadata, and Provenance tables are retained when
%     converting between frames and timeseries.
%
% Conversion and Display
%   tt = toTable(obj)     - Convert synchronized Values to a timetable
%   frame = toFrame(obj)  - Convert to an iam.IAMFrame object
%   out = convertUnit(obj,source,target) - Convert declared units
%   out = calculate(obj,left,op,right,name,Unit=unit) - Named calculation
%   out = share(obj,numerator,denominator,name) - Calculate a share
%   out = compareBaseline(obj,target,baseline,var,name) - Compare scenarios
%   [h,l] = plot(obj, ...) - Plot the series; returns plot handles and legend
%   [h,l] = bar(obj, ...)  - Bar chart of the series
%
% Metadata and Utilities
%   tb = summary(obj)      - Return a table summarizing the array
%   lst = getRunList(obj)  - Return a table listing model/run metadata
%   uniqueRegions(obj), uniqueVariables(obj), uniqueModels(obj),
%   uniqueScenarios(obj)  - Return unique values for those fields
%
% Arithmetic
%   r = plus(obj1,obj2)    - Add series with matching identities
%   r = minus(obj1,obj2)   - Subtract series with matching identities
%   r = times(obj1,obj2)   - Multiply series with matching identities
%   r = rdivide(obj1,obj2) - Divide series with matching identities
%   Operators synchronize annual dates and preserve scenario labels. Use
%   calculate for named operations between different variables.
%
% See also TIMETABLE, SYNCHRONIZE

% Copyright 2020-2026 The MathWorks, Inc.

    properties (SetAccess = private)
        Model    (1,1) string % Model name.
        Scenario (1,1) string % Scenario name.
        Variable (1,1) string % Variable name.
        Region   (1,1) string % Region name.
        Unit     (1,1) string % Unit label.
        RunId    (1,1) double % Source run ID.
        Version  (:,1) double % Scenario version.
        Years    (:,1) double % Annual years.
        Values   (:,:) timetable % Observation values and dates.
        RunInfo table = table() % Original provider records.
        Metadata table = table() % Local scenario annotations.
        Provenance table = table() % Result-to-original-observation links.
    end

    methods
        idx = ismember(obj, ts)
    end

    methods

        function obj = IAMTimeseries(Data)

            arguments
                Data struct
            end

            if isempty(Data)
                obj = obj([]);
                return
            end

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
                obj(i).RunId = data.runId;
                obj(i).Version = data.version;
                obj(i).Years = data.years;
                obj(i).Values = data.values;
                for name = ["RunInfo","Metadata","Provenance"]
                    if isfield(data,name)
                        obj(i).(name) = data.(name);
                    end
                end
            end

        end

        function tt = toTable(obj)
            tt = synchronize(obj.Values);
        end

        function frame = toFrame(obj)
            frame = iam.IAMFrame(obj);
        end

        function out = convertUnit(obj, sourceUnit, targetUnit, opts)
            %convertUnit - Convert timeseries values between declared units
            %   OUT = convertUnit(OBJ,SOURCEUNIT,TARGETUNIT) uses a
            %   documented common conversion when available.
            %
            %   OUT = convertUnit(...,Factor=FACTOR) supplies an explicit
            %   positive conversion factor.
            %
            %   See also iam.IAMFrame/convertUnit
            arguments
                obj
                sourceUnit {mustBeTextScalar}
                targetUnit {mustBeTextScalar}
                opts.Factor = []
            end
            frame = obj.toFrame();
            converted = frame.convertUnit(sourceUnit,targetUnit,Factor=opts.Factor);
            out = converted.toTimeseries();
        end

        function [out, report] = calculate(obj, leftVariable, operation, ...
                rightVariable, outputVariable, opts)
            %calculate - Calculate a named result from timeseries variables
            %   [OUT,REPORT] = calculate(OBJ,LEFT,OP,RIGHT,OUTPUT,Unit=UNIT)
            %   aligns observations by their scenario and annual identity.
            %
            %   REPORT describes missing operands and zero denominators.
            %
            %   See also iam.IAMFrame/calculate
            arguments
                obj
                leftVariable {mustBeTextScalar}
                operation {mustBeTextScalar}
                rightVariable {mustBeTextScalar}
                outputVariable {mustBeTextScalar}
                opts.Unit {mustBeTextScalar} = ""
            end
            frame = obj.toFrame();
            [calculated,report] = frame.calculate(leftVariable,operation, ...
                rightVariable,outputVariable,Unit=opts.Unit);
            out = calculated.toTimeseries();
        end

        function [out, report] = share(obj, numeratorVariable, ...
                denominatorVariable, outputVariable, opts)
            %share - Calculate a fraction or percentage timeseries
            %   [OUT,REPORT] = share(OBJ,NUMERATOR,DENOMINATOR,OUTPUT,...)
            %   returns fractions or Convention="percent" values.
            %
            %   See also iam.IAMFrame/share
            arguments
                obj
                numeratorVariable {mustBeTextScalar}
                denominatorVariable {mustBeTextScalar}
                outputVariable {mustBeTextScalar}
                opts.Convention {mustBeTextScalar} = "fraction"
            end
            frame = obj.toFrame();
            [calculated,report] = frame.share(numeratorVariable, ...
                denominatorVariable,outputVariable,Convention=opts.Convention);
            out = calculated.toTimeseries();
        end

        function [out, report] = compareBaseline(obj, targetScenario, ...
                baselineScenario, variable, outputVariable, opts)
            %compareBaseline - Compare scenario timeseries with a baseline
            %   [OUT,REPORT] = compareBaseline(OBJ,TARGET,BASELINE,VARIABLE,OUTPUT)
            %   aligns by model, version, region, and year.
            %
            %   See also iam.IAMFrame/compareBaseline
            arguments
                obj
                targetScenario {mustBeTextScalar}
                baselineScenario {mustBeTextScalar}
                variable {mustBeTextScalar}
                outputVariable {mustBeTextScalar}
                opts.Operation {mustBeTextScalar} = "difference"
            end
            frame = obj.toFrame();
            [calculated,report] = frame.compareBaseline(targetScenario, ...
                baselineScenario,variable,outputVariable,Operation=opts.Operation);
            out = calculated.toTimeseries();
        end

        function tb = summary(obj)
            tb = table((1:numel(obj))',[obj.Model]', [obj.Scenario]', [obj.Region]', [obj.Variable]', [obj.Unit]', ...
                'VariableNames', {'ts','Model','Scenario','Region','Variable','Unit'});
        end

        function r = plus(obj1, obj2)
            r = applySeriesOperation(obj1,obj2,"+");
        end

        function r = minus(obj1, obj2)
            r = applySeriesOperation(obj1,obj2,"-");
        end

        function r = times(obj1, obj2)
            r = applySeriesOperation(obj1,obj2,".*");
        end

        function r = rdivide(obj1, obj2)
            r = applySeriesOperation(obj1,obj2,"./");
        end

        function [h,l] = plot(obj, varargin)

            if ~isempty(obj)
                allVars = synchronize(obj.Values);
                h = plot(allVars.Year, allVars{:,:}, varargin{:});

                axis(h(1).Parent,'tight');
                xlabel(h(1).Parent,'Years');

                units = unique([obj.Unit]);
                if isscalar(units)
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
                if isscalar(units)
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
                'VariableNames',{'Model','Scenario','Variable','Region','RunId','Version'}...
                );
        end

    end

end

function result = applySeriesOperation(left,right,operation)
arguments
    left {mustBeA(left,"iam.IAMTimeseries"),mustBeNonempty}
    right {mustBeA(right,"iam.IAMTimeseries"),mustBeNonempty,mustHaveSameNumel(right,left)}
    operation (1,1) string {mustBeMember(operation,["+","-",".*","./"])}
end
leftFrame = left.toFrame();
rightFrame = right.toFrame();
leftKeys = seriesIdentity(left);
rightKeys = seriesIdentity(right);
if height(unique(leftKeys,"rows")) ~= height(leftKeys) || ...
        height(unique(rightKeys,"rows")) ~= height(rightKeys)
    error("iam:IAMTimeseries:AmbiguousIdentity", ...
        "Arithmetic arrays must contain unique series identities.")
end
[matched,rightLocation] = ismember(leftKeys,rightKeys,"rows");
if ~all(matched)
    error("iam:IAMTimeseries:IncompatibleOperands", ...
        "Arithmetic operands must contain the same model, scenario, version, variable, and region identities.")
end
leftUnits = [left.Unit]';
rightUnits = [right.Unit]';
if any(ismissing(leftUnits) | strlength(leftUnits) == 0) || ...
        any(ismissing(rightUnits) | strlength(rightUnits) == 0)
    error("iam:IAMTimeseries:UnknownUnit","Arithmetic requires known units.")
end
if ismember(operation,["+","-"]) && any(leftUnits ~= rightUnits(rightLocation))
    error("iam:IAMTimeseries:IncompatibleUnits", ...
        "Addition and subtraction require identical units.")
end
leftData = leftFrame.toTable();
rightData = rightFrame.toTable();
[~, leftGroup] = ismember(seriesIdentity(leftData),leftKeys,"rows");
[~, rightGroup] = ismember(seriesIdentity(rightData),rightKeys,"rows");
data(numel(left),1) = struct("model","","scenario","","variable","", ...
    "region","","unit","","runId",NaN,"version",NaN, ...
    "years",zeros(0,1),"values",timetable(), ...
    "RunInfo",table(),"Metadata",table(),"Provenance",table());
for i = 1:numel(left)
    j = rightLocation(i);
    synchronized = synchronize(left(i).Values,right(j).Values);
    leftValues = synchronized{:,1};
    rightValues = synchronized{:,2};
    switch operation
        case "+"
            values = leftValues + rightValues;
            unit = left(i).Unit;
        case "-"
            values = leftValues - rightValues;
            unit = left(i).Unit;
        case ".*"
            values = leftValues.*rightValues;
            unit = "(" + left(i).Unit + ")*(" + right(j).Unit + ")";
        case "./"
            values = leftValues./rightValues;
            values(rightValues == 0) = NaN;
            unit = "(" + left(i).Unit + ")/(" + right(j).Unit + ")";
    end
    if any(isinf(values))
        error("iam:IAMTimeseries:CalculationOverflow", ...
            "Arithmetic produced an infinite value.")
    end
    runId = NaN;
    if left(i).RunId == right(j).RunId
        runId = left(i).RunId;
    end
    variable = left(i).Variable + " " + operation + " " + right(j).Variable;
    dates = synchronized.Properties.RowTimes;
    entry = struct("model",left(i).Model,"scenario",left(i).Scenario, ...
        "variable",variable,"region",left(i).Region,"unit",unit, ...
        "runId",runId,"version",left(i).Version,"years",year(dates), ...
        "values",timetable(dates,values,DimensionNames=["Year","VariableUnits"], ...
        VariableNames="Values"));
    output = iam.IAMFrame(iam.IAMTimeseries(entry)).toTable();
    derived = iam.IAMFrame.fromCalculation({leftFrame,rightFrame},output, ...
        {leftData(leftGroup == i,:),rightData(rightGroup == j,:)},{},["left","right"]);
    entry.RunInfo = derived.RunInfo;
    entry.Metadata = derived.meta();
    entry.Provenance = derived.Provenance;
    data(i) = entry;
end
result = iam.IAMTimeseries(data);
end

function mustHaveSameNumel(right,left)
if numel(left) ~= numel(right)
    error("iam:IAMTimeseries:IncompatibleOperands", ...
        "Arithmetic operands must have the same number of series.")
end
end

function keys = seriesIdentity(series)
if istable(series)
    keys = series(:,{'Model','Scenario','Version','Variable','Region'});
else
    keys = table([series.Model]',[series.Scenario]',[series.Version]', ...
        [series.Variable]',[series.Region]', ...
        VariableNames=["Model","Scenario","Version","Variable","Region"]);
end
keys.Version(isnan(keys.Version)) = -Inf;
end

function str = igetLegend(dt)

str = "";
str = iaddVarToLegend(str,'Model',[dt.Model]);
str = iaddVarToLegend(str,'Scenario',[dt.Scenario]);
str = iaddVarToLegend(str,'Variable',[dt.Variable]);
str = iaddVarToLegend(str,'Region',[dt.Region]);
str = iaddVarToLegend(str,'Id',[dt.RunId]);

if isscalar(str)
    str = "Region = " + dt(1).Region;
end

end

function str = iaddVarToLegend(str,var,data)

if isnumeric(data)
    format = '%s = %d';
else
    format = '%s = %s';
end

if length(unique(data)) ~= 1
    if isscalar(str)
        str = str + arrayfun(@(x) string(sprintf('%s = %s',var(1),x)) , data);
    else
        str = str + arrayfun(@(x) string(sprintf(", " + format,var(1),x)) , data);
    end
end

end
