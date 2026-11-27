classdef IAMFrame
    %IAMFrame - Store annual observations and scenario annotations
    %   FRAME = iam.IAMFrame() creates an empty annual frame.
    %
    %   FRAME = iam.IAMFrame(DATA) constructs a frame from timeseries objects
    %   or a long table with Model, Scenario, Variable, Region, Unit, Year,
    %   and Value columns.
    %
    %   FRAME = iam.IAMFrame(...,RunInfo=TABLE) also attaches source metadata.
    %
    %   FRAME = iam.IAMFrame(...,Metadata=TABLE) also attaches a local table
    %   keyed by Model, Scenario, and Version.
    %
    %   FRAME = iam.IAMFrame(...,Provenance=TABLE) also attaches validated
    %   result-to-original-observation links.
    %
    %   Annual years must be finite integers. Missing observations use NaN.
    %   An empty Unit string means unknown. Unsupported columns are rejected.
    %
    %   IAMFrame functions:
    %       toTable     - Return long-format observations
    %       meta        - Return keyed local annotations
    %       setMeta     - Set annotations without changing observations
    %       filter      - Select observations by coordinates or metadata
    %       append      - Merge observations, annotations, and provenance
    %       convertUnit - Convert values with an explicit or common factor
    %       calculate   - Align and calculate named variables
    %       share       - Calculate a fraction or percentage share
    %       compareBaseline - Compare one scenario with a baseline
    %       requireData - Check required coordinate combinations
    %       validate    - Check bounds and report unchecked evidence
    %       categorize  - Label scenarios using a bounds check
    %       summary     - Summarize series identities and year counts
    %       head        - Return the first observation rows
    %       tail        - Return the last observation rows
    %       timeseries  - Return a wide table
    %       toTimeseries - Convert to plotting-compatible series
    %
    %   IAMFrame properties:
    %       RunInfo     - Provider metadata and source provenance
    %       Provenance  - Links from result rows to original inputs
    %       Models      - Model names
    %       Scenarios   - Scenario names
    %       Variables   - Variable names
    %       Regions     - Region names
    %       Units       - Unit labels
    %       RunIds      - Source run IDs
    %       Years       - Annual years
    %
    %   See also table, iam.IAMTimeseries

    properties (Access = private)
        Data table
        LocalMetadata table = table()
    end

    properties (SetAccess = private)
        RunInfo table = table() % Source metadata associated with RunId values.
        Provenance table = emptyProvenance() % Result-to-original-observation links.
    end

    properties (Dependent, SetAccess = private)
        Models (:,1) string % Model names in the frame.
        Scenarios (:,1) string % Scenario names in the frame.
        Variables (:,1) string % Variable names in the frame.
        Regions (:,1) string % Region names in the frame.
        Units (:,1) string % Units; empty denotes unknown.
        RunIds (:,1) double % Source run IDs; NaN denotes no source run.
        Years (:,1) double % Annual years in the frame.
    end

    methods
        function obj = IAMFrame(data, nvp)

            arguments
                data = defaultDataTable()
                nvp.RunInfo table = table.empty()
                nvp.Metadata table = table.empty()
                nvp.Provenance table = table.empty()
            end

            if isa(data, 'iam.IAMTimeseries')
                [data,inheritedInfo,inheritedMetadata,inheritedProvenance] = fromTimeseries(data);
                if isempty(nvp.RunInfo.Properties.VariableNames)
                    nvp.RunInfo = inheritedInfo;
                end
                if isempty(nvp.Metadata.Properties.VariableNames)
                    nvp.Metadata = inheritedMetadata;
                end
                if isempty(nvp.Provenance.Properties.VariableNames)
                    nvp.Provenance = inheritedProvenance;
                end
            elseif ~istable(data)
                error('iam:IAMFrame:InvalidInput', ...
                    'IAMFrame input must be a IAMTimeseries array or a table.')
            end

            obj.Data = normalizeDataTable(data);
            validateUniqueObservations(obj.Data);

            obj.RunInfo = nvp.RunInfo;
            validateRunInfoMapping(obj.RunInfo, obj.Data);
            obj.LocalMetadata = normalizeLocalMetadata(nvp.Metadata, obj.Data);
            obj.Provenance = normalizeProvenance(nvp.Provenance,obj.Data);
        end

        function value = get.Models(obj)
            value = uniqueOrEmpty(obj.Data, 'Model', strings(0,1));
        end

        function value = get.Scenarios(obj)
            value = uniqueOrEmpty(obj.Data, 'Scenario', strings(0,1));
        end

        function value = get.Variables(obj)
            value = uniqueOrEmpty(obj.Data, 'Variable', strings(0,1));
        end

        function value = get.Regions(obj)
            value = uniqueOrEmpty(obj.Data, 'Region', strings(0,1));
        end

        function value = get.Units(obj)
            value = uniqueOrEmpty(obj.Data, 'Unit', strings(0,1));
        end

        function value = get.RunIds(obj)
            value = uniqueOrEmpty(obj.Data, 'RunId', zeros(0,1));
        end

        function value = get.Years(obj)
            value = uniqueOrEmpty(obj.Data, 'Year', zeros(0,1));
        end

        function tb = toTable(obj)
            tb = obj.Data;
        end

        function tb = meta(obj)
            %META - Return local scenario annotations
            %   T = META(OBJ) returns annotations keyed by Model, Scenario,
            %   and Version. Provider metadata remains in OBJ.RunInfo.
            %
            %   See also setMeta, filter
            tb = obj.LocalMetadata;
            if isempty(tb.Properties.VariableNames)
                tb = normalizeLocalMetadata(tb,obj.Data);
            end
        end

        function out = setMeta(obj, metadata)
            %setMeta - Set annotations for selected scenario identities
            %   OUT = setMeta(OBJ,METADATA) assigns columns from a keyed
            %   table. Supplied missing values clear previous annotations.
            %   Other scenarios and columns remain unchanged.
            %
            %   See also meta, filter
            arguments
                obj
                metadata table
            end
            [updates, supplied] = normalizeLocalMetadata(metadata, obj.Data);
            out = obj;
            out.LocalMetadata = obj.meta();
            names = string(updates.Properties.VariableNames);
            for name = names(4:end)
                incoming = updates.(name);
                if ismember(name, string(out.LocalMetadata.Properties.VariableNames))
                    [current, incoming] = harmonizeMetadataColumns( ...
                        out.LocalMetadata.(name), incoming, name);
                else
                    current = missingMetadataColumn(incoming, height(updates), name);
                end
                current(supplied) = incoming(supplied);
                out.LocalMetadata.(name) = current;
            end
        end

        function out = convertUnit(obj, sourceUnit, targetUnit, opts)
            %convertUnit - Convert observations between declared units
            %   OUT = convertUnit(OBJ,SOURCEUNIT,TARGETUNIT) applies a
            %   documented common conversion when the unit pair is known.
            %
            %   OUT = convertUnit(...,Factor=FACTOR) multiplies matching
            %   values by an explicitly supplied positive factor.
            %
            %   The input frame is unchanged. All rows with SOURCEUNIT are
            %   converted; other rows retain their values and units.
            %
            %   See also calculate, share
            arguments
                obj
                sourceUnit {mustBeTextScalar}
                targetUnit {mustBeTextScalar}
                opts.Factor = []
            end
            sourceUnit = string(sourceUnit);
            targetUnit = string(targetUnit);
            if ismissing(sourceUnit) || strlength(sourceUnit) == 0 || ...
                    ismissing(targetUnit) || strlength(targetUnit) == 0
                error("iam:IAMFrame:InvalidUnit", ...
                    "SourceUnit and TargetUnit must be nonempty unit labels.")
            end
            if isempty(opts.Factor)
                factor = commonUnitConversionFactor(sourceUnit,targetUnit);
                if isnan(factor)
                    error("iam:IAMFrame:UnknownConversion", ...
                        "No common conversion is defined for '%s' to '%s'. Supply Factor explicitly.", ...
                        sourceUnit,targetUnit)
                end
            else
                factor = opts.Factor;
                if ~isnumeric(factor) || ~isreal(factor) || ...
                        ~isscalar(factor) || ~isfinite(factor) || factor <= 0
                    error("iam:IAMFrame:InvalidConversionFactor", ...
                        "Factor must be a finite, positive real scalar.")
                end
            end
            factor = double(factor);
            selected = obj.Data.Unit == sourceUnit;
            if ~any(selected)
                error("iam:IAMFrame:NoMatchingUnit", ...
                    "The frame contains no observations with unit '%s'.",sourceUnit)
            end
            data = obj.Data;
            data.Value(selected) = data.Value(selected).*factor;
            if any(isinf(data.Value))
                error("iam:IAMFrame:ConversionOverflow", ...
                    "Unit conversion produced an infinite value.")
            end
            data.Unit(selected) = targetUnit;
            provenance = obj.Provenance;
            provenance.Unit(provenance.Unit == sourceUnit) = targetUnit;
            out = iam.IAMFrame(data,RunInfo=obj.RunInfo,Metadata=obj.meta(), ...
                Provenance=provenance);
        end

        function [out, report] = calculate(obj, leftVariable, operation, ...
                rightVariable, outputVariable, opts)
            %calculate - Calculate a named result from two frame variables
            %   [OUT,REPORT] = calculate(OBJ,LEFT,OPERATION,RIGHT,OUTPUT,...)
            %   aligns annual observations by model, scenario, version,
            %   region, and year before applying add, subtract, multiply,
            %   or divide.
            %
            %   The Unit name-value argument is required. Addition and
            %   subtraction require known, identical operand units and the
            %   same output unit. Other operations require known operand
            %   units and use the declared output label.
            %
            %   REPORT identifies missing operands and zero denominators.
            %   Unavailable results are NaN. OUT contains only derived rows;
            %   the input frame is unchanged.
            %
            %   See also convertUnit, share, compareBaseline
            arguments
                obj
                leftVariable {mustBeTextScalar}
                operation {mustBeTextScalar}
                rightVariable {mustBeTextScalar}
                outputVariable {mustBeTextScalar}
                opts.Unit {mustBeTextScalar} = ""
            end
            leftVariable = string(leftVariable);
            rightVariable = string(rightVariable);
            outputVariable = string(outputVariable);
            outputUnit = string(opts.Unit);
            operation = lower(string(operation));
            if ~ismember(operation,["add","subtract","multiply","divide"])
                error("iam:IAMFrame:InvalidOperation", ...
                    "Operation must be add, subtract, multiply, or divide.")
            end
            validateDerivedLabels(leftVariable,rightVariable,outputVariable,outputUnit)
            left = obj.Data(obj.Data.Variable == leftVariable,:);
            right = obj.Data(obj.Data.Variable == rightVariable,:);
            if isempty(left) || isempty(right)
                error("iam:IAMFrame:MissingOperandVariable", ...
                    "Both operand variables must occur in the frame.")
            end
            if any(left.Unit == "") || any(right.Unit == "")
                error("iam:IAMFrame:UnknownUnit", ...
                    "Calculations require known units for both operands.")
            end
            if ismember(operation,["add","subtract"]) && ...
                    (any(left.Unit ~= outputUnit) || any(right.Unit ~= outputUnit))
                error("iam:IAMFrame:IncompatibleUnits", ...
                    "Addition and subtraction require operands and output to use the same unit.")
            end
            keys = ["Model","Scenario","Version","Region","Year"];
            [aligned,leftLoc,rightLoc] = alignObservationRows(left,right,keys);
            leftPresent = leftLoc > 0;
            rightPresent = rightLoc > 0;
            leftValue = NaN(height(aligned),1);
            rightValue = NaN(height(aligned),1);
            leftRun = NaN(height(aligned),1);
            rightRun = NaN(height(aligned),1);
            leftValue(leftPresent) = left.Value(leftLoc(leftPresent));
            rightValue(rightPresent) = right.Value(rightLoc(rightPresent));
            leftRun(leftPresent) = left.RunId(leftLoc(leftPresent));
            rightRun(rightPresent) = right.RunId(rightLoc(rightPresent));
            missingLeft = ~leftPresent | isnan(leftValue);
            missingRight = ~rightPresent | isnan(rightValue);
            zeroDenominator = rightPresent & ~isnan(rightValue) & rightValue == 0 & ...
                operation == "divide";
            values = NaN(height(aligned),1);
            computable = ~missingLeft & ~missingRight & ~zeroDenominator;
            switch operation
                case "add"
                    values(computable) = leftValue(computable) + rightValue(computable);
                case "subtract"
                    values(computable) = leftValue(computable) - rightValue(computable);
                case "multiply"
                    values(computable) = leftValue(computable).*rightValue(computable);
                case "divide"
                    values(computable) = leftValue(computable)./rightValue(computable);
            end
            if any(isinf(values))
                error("iam:IAMFrame:CalculationOverflow", ...
                    "The calculation produced an infinite value.")
            end
            runId = alignedRunIds(leftRun,rightRun,leftPresent,rightPresent);
            data = calculatedObservationTable(aligned,outputVariable,outputUnit,runId,values);
            out = derivedFrame({obj,obj},data,{left,right}, ...
                {leftLoc,rightLoc},["left","right"]);
            report = calculationReport(aligned,missingLeft,missingRight,zeroDenominator,nnz(computable));
        end

        function [out, report] = share(obj, numeratorVariable, ...
                denominatorVariable, outputVariable, opts)
            %share - Calculate an identity-aligned variable share
            %   [OUT,REPORT] = share(OBJ,NUMERATOR,DENOMINATOR,OUTPUT,...)
            %   returns a unitless fraction by default. Convention="percent"
            %   scales that result to the 0-to-100 percentage convention.
            %
            %   REPORT identifies missing operands and zero denominators.
            %   OUT contains only share rows. The input frame is unchanged.
            %
            %   See also calculate, convertUnit
            arguments
                obj
                numeratorVariable {mustBeTextScalar}
                denominatorVariable {mustBeTextScalar}
                outputVariable {mustBeTextScalar}
                opts.Convention {mustBeTextScalar} = "fraction"
            end
            convention = lower(string(opts.Convention));
            switch convention
                case "fraction"
                    unit = "fraction";
                    scale = 1;
                case "percent"
                    unit = "%";
                    scale = 100;
                otherwise
                    error("iam:IAMFrame:InvalidShareConvention", ...
                        "Convention must be fraction or percent.")
            end
            numeratorVariable = string(numeratorVariable);
            denominatorVariable = string(denominatorVariable);
            numerator = obj.Data(obj.Data.Variable == numeratorVariable,:);
            denominator = obj.Data(obj.Data.Variable == denominatorVariable,:);
            if ~isempty(numerator) && ~isempty(denominator)
                keys = ["Model","Scenario","Version","Region","Year"];
                [~,numeratorLoc,denominatorLoc] = ...
                    alignObservationRows(numerator,denominator,keys);
                paired = numeratorLoc > 0 & denominatorLoc > 0;
                if any(numerator.Unit(numeratorLoc(paired)) ~= ...
                        denominator.Unit(denominatorLoc(paired)))
                    error("iam:IAMFrame:IncompatibleUnits", ...
                        "Share operands must use identical units.")
                end
            end
            [out,report] = obj.calculate(numeratorVariable,"divide", ...
                denominatorVariable,outputVariable,Unit=unit);
            if scale ~= 1
                data = out.toTable();
                data.Value = data.Value.*scale;
                if any(isinf(data.Value))
                    error("iam:IAMFrame:CalculationOverflow", ...
                        "The share calculation produced an infinite value.")
                end
                provenance = out.Provenance;
                provenance.Unit(:) = unit;
                out = iam.IAMFrame(data,RunInfo=out.RunInfo,Metadata=out.meta(), ...
                    Provenance=provenance);
            end
        end

        function [out, report] = compareBaseline(obj, targetScenario, ...
                baselineScenario, variable, outputVariable, opts)
            %compareBaseline - Compare one scenario with a named baseline
            %   [OUT,REPORT] = compareBaseline(OBJ,TARGET,BASELINE,VARIABLE,OUTPUT)
            %   returns target minus baseline, aligned by model, version,
            %   region, and year.
            %
            %   Operation="percentChange" returns 100 times the difference
            %   divided by the baseline. A zero baseline is reported and
            %   yields NaN. Differences retain the source unit; percentage
            %   changes use "%".
            %
            %   REPORT identifies missing operands and zero baselines. The
            %   result contains only comparison rows. The input is unchanged.
            %
            %   See also calculate, share
            arguments
                obj
                targetScenario {mustBeTextScalar}
                baselineScenario {mustBeTextScalar}
                variable {mustBeTextScalar}
                outputVariable {mustBeTextScalar}
                opts.Operation {mustBeTextScalar} = "difference"
            end
            targetScenario = string(targetScenario);
            baselineScenario = string(baselineScenario);
            variable = string(variable);
            outputVariable = string(outputVariable);
            operation = lower(string(opts.Operation));
            if ismissing(targetScenario) || strlength(targetScenario) == 0 || ...
                    ismissing(baselineScenario) || strlength(baselineScenario) == 0 || ...
                    targetScenario == baselineScenario
                error("iam:IAMFrame:InvalidBaseline", ...
                    "Target and baseline must be distinct nonempty scenario names.")
            end
            if ~ismember(operation,["difference","percentchange"])
                error("iam:IAMFrame:InvalidBaselineOperation", ...
                    "Operation must be difference or percentChange.")
            end
            if ismissing(variable) || strlength(variable) == 0 || ...
                    ismissing(outputVariable) || strlength(outputVariable) == 0
                error("iam:IAMFrame:InvalidDerivedLabel", ...
                    "Variable and OutputVariable must be nonempty text.")
            end
            target = obj.Data(obj.Data.Scenario == targetScenario & ...
                obj.Data.Variable == variable,:);
            baseline = obj.Data(obj.Data.Scenario == baselineScenario & ...
                obj.Data.Variable == variable,:);
            if isempty(target)
                error("iam:IAMFrame:MissingTargetScenario", ...
                    "No observations match the target scenario and variable.")
            end
            if any(target.Unit == "") || any(baseline.Unit == "")
                error("iam:IAMFrame:UnknownUnit", ...
                    "Baseline comparisons require known units.")
            end
            keys = ["Model","Version","Region","Year"];
            [aligned,targetLoc,baselineLoc] = alignObservationRows(target,baseline,keys);
            targetPresent = targetLoc > 0;
            baselinePresent = baselineLoc > 0;
            targetValue = NaN(height(aligned),1);
            baselineValue = NaN(height(aligned),1);
            targetUnit = strings(height(aligned),1);
            baselineUnit = strings(height(aligned),1);
            targetValue(targetPresent) = target.Value(targetLoc(targetPresent));
            targetUnit(targetPresent) = target.Unit(targetLoc(targetPresent));
            baselineValue(baselinePresent) = baseline.Value(baselineLoc(baselinePresent));
            baselineUnit(baselinePresent) = baseline.Unit(baselineLoc(baselinePresent));
            bothPresent = targetPresent & baselinePresent;
            if any(targetUnit(bothPresent) ~= baselineUnit(bothPresent))
                error("iam:IAMFrame:IncompatibleUnits", ...
                    "Target and baseline units differ; convert them before comparison.")
            end
            missingTarget = ~targetPresent | isnan(targetValue);
            missingBaseline = ~baselinePresent | isnan(baselineValue);
            zeroBaseline = operation == "percentchange" & baselinePresent & ...
                ~isnan(baselineValue) & baselineValue == 0;
            computable = ~missingTarget & ~missingBaseline & ~zeroBaseline;
            values = NaN(height(aligned),1);
            if operation == "difference"
                values(computable) = targetValue(computable) - baselineValue(computable);
                units = targetUnit;
                units(~targetPresent) = baselineUnit(~targetPresent);
            else
                values(computable) = 100.*(targetValue(computable) - ...
                    baselineValue(computable))./baselineValue(computable);
                units = repmat("%",height(aligned),1);
            end
            if any(isinf(values))
                error("iam:IAMFrame:CalculationOverflow", ...
                    "The baseline comparison produced an infinite value.")
            end
            runId = NaN(height(aligned),1);
            aligned.Scenario = repmat(targetScenario,height(aligned),1);
            data = calculatedObservationTable(aligned,outputVariable,units,runId,values);
            out = derivedFrame({obj,obj},data,{target,baseline}, ...
                {targetLoc,baselineLoc},["target","baseline"]);
            report = calculationReport(aligned,missingTarget,missingBaseline, ...
                zeroBaseline,nnz(computable));
        end

        function [report, out] = requireData(obj, opts)
            %requireData - Check required observation combinations
            %   REPORT = requireData(OBJ,Name=Value) checks combinations of
            %   variables, regions, units, and years for every scenario.
            %   NaN observations do not satisfy a requirement.
            %
            %   [REPORT,OUT] = requireData(...,ExcludeOnFail=true) also
            %   records Excluded flags in a new frame. Filter selects the
            %   scenario scope; required coordinates are separate options.
            %
            %   See also validate, categorize, filter
            arguments
                obj
                opts.variables (1,:) string = strings(1,0)
                opts.regions (1,:) string = strings(1,0)
                opts.units (1,:) string = strings(1,0)
                opts.years = []
                opts.Filter (1,1) struct = struct()
                opts.ExcludeOnFail (1,1) {mustBeA(opts.ExcludeOnFail,"logical")} = false
            end
            coordinateNames = ["Variable","Region","Unit","Year"];
            if any(ismember(lower(string(fieldnames(opts.Filter))), ...
                    ["variables","regions","units","years"]))
                error("iam:IAMFrame:InvalidRequirements", ...
                    "Use required coordinate options; Filter selects scenarios.")
            end
            values = {opts.variables(:),opts.regions(:),opts.units(:), ...
                normalizeYears(opts.years)};
            active = ~cellfun(@isempty, values);
            if ~any(active)
                error("iam:IAMFrame:InvalidRequirements", ...
                    "Specify at least one required variable, region, unit, or year.")
            end
            for i = 1:3
                if any(ismissing(values{i}) | contains(values{i}, "*") | ...
                        contains(values{i}, "?")) || ...
                        (i < 3 && any(strlength(values{i}) == 0))
                    error("iam:IAMFrame:InvalidRequirements", ...
                        "Requirements must contain literal coordinate names.")
                end
                values{i} = unique(values{i}, "stable");
            end
            values{4} = unique(values{4}(:), "stable");
            scope = validationScope(obj, opts.Filter);
            data = scope.toTable();
            [keys, group] = scenarioIndex(data);
            coordinates = coordinateNames(active);
            tuples = combinations(values{active});
            tuples.Properties.VariableNames = cellstr(coordinates);
            requests = keys(repelem((1:height(keys))',height(tuples)),:);
            for name = coordinates
                requests.(name) = repmat(tuples.(name),height(keys),1);
            end
            names = ["Model","Scenario","Version",coordinates];
            finite = ~ismissing(data.Value);
            present = ismember(requirementKeys(requests,coordinates), ...
                requirementKeys(data(finite,names),coordinates), "rows");
            selected = ismember(requirementKeys(data(:,coordinates),coordinates), ...
                requirementKeys(tuples,coordinates), "rows");
            summary = validationSummary(keys,group,finite & selected, ...
                false(height(data),1),false(height(data),1));
            if any(~present)
                missingGroups = repelem((1:height(keys))',height(tuples));
                counts = groupcounts(table(missingGroups(~present), ...
                    VariableNames="Group"),"Group");
                summary.MissingCount(counts.Group) = counts.GroupCount;
            end
            summary.Status(summary.MissingCount > 0) = "Failed";
            % Populate wildcard coordinates explicitly instead of copying data.
            missingRows = table('Size',[nnz(~present),7], ...
                'VariableNames',{'Model','Scenario','Version','Variable','Region','Unit','Year'}, ...
                'VariableTypes',{'string','string','double','string','string','string','double'});
            missingRows.Version(:) = NaN;
            missingRows.Year(:) = NaN;
            missingRows.Variable(:) = string(missing);
            missingRows.Region(:) = string(missing);
            missingRows.Unit(:) = string(missing);
            for name = ["Model","Scenario","Version",coordinates]
                missingRows.(name) = requests.(name)(~present);
            end
            report = finishValidationReport(summary,data([],:),missingRows);
            out = obj;
            if opts.ExcludeOnFail
                out = recordExclusions(obj,summary);
            end
        end

        function [report, out] = validate(obj, opts)
            %VALIDATE - Check bounds on selected observations
            %   REPORT = VALIDATE(OBJ,Name=Value) checks inclusive LowerBound
            %   and UpperBound values. Filter selects scenarios and evidence.
            %   Missing evidence produces NotChecked rather than Passed.
            %
            %   [REPORT,OUT] = VALIDATE(...,ExcludeOnFail=true) also records
            %   Excluded as one for Failed, zero for Passed, and NaN for
            %   NotChecked. Earlier exclusions remain set until explicitly
            %   cleared. The input frame remains unchanged.
            %
            %   See also requireData, categorize, filter
            arguments
                obj
                opts.LowerBound (1,1) {mustBeNumeric,mustBeReal} = -Inf
                opts.UpperBound (1,1) {mustBeNumeric,mustBeReal} = Inf
                opts.Filter (1,1) struct = struct()
                opts.ExcludeOnFail (1,1) {mustBeA(opts.ExcludeOnFail,"logical")} = false
            end
            if isnan(opts.LowerBound) || isnan(opts.UpperBound) || ...
                    opts.LowerBound > opts.UpperBound
                error("iam:IAMFrame:InvalidBounds", ...
                    "Bounds must be ordered and cannot be NaN.")
            end
            [scope, selected] = validationScope(obj, opts.Filter);
            [keys, ~] = scenarioIndex(scope.toTable());
            data = selected.toTable();
            [~, group] = ismember(identityComparisonTable(data(:, ...
                {'Model','Scenario','Version'})),identityComparisonTable(keys),"rows");
            finite = ~ismissing(data.Value);
            failed = finite & ~isbetween(data.Value,opts.LowerBound,opts.UpperBound);
            summary = validationSummary(keys,group,finite,~finite,failed);
            report = finishValidationReport(summary,data(failed,:), ...
                data(~finite,{'Model','Scenario','Version','Variable','Region','Unit','Year'}));
            out = obj;
            if opts.ExcludeOnFail
                out = recordExclusions(obj,summary);
            end
        end

        function [out, report] = categorize(obj, name, value, opts)
            %CATEGORIZE - Label scenarios that pass a bounds check
            %   OUT = CATEGORIZE(OBJ,NAME,VALUE,Name=Value) writes a text
            %   annotation only for scenarios with complete checked evidence
            %   within LowerBound and UpperBound. Other scoped labels clear.
            %
            %   [OUT,REPORT] = CATEGORIZE(...) also returns the validation
            %   report. Scenarios outside Filter's scope remain unchanged.
            %
            %   See also validate, requireData, setMeta
            arguments
                obj
                name {mustBeTextScalar}
                value {mustBeTextScalar}
                opts.LowerBound (1,1) {mustBeNumeric,mustBeReal} = -Inf
                opts.UpperBound (1,1) {mustBeNumeric,mustBeReal} = Inf
                opts.Filter (1,1) struct = struct()
            end
            name = string(name);
            value = string(value);
            validateAnnotationName(name);
            if ismissing(value) || strlength(value) == 0
                error("iam:IAMFrame:InvalidCategory", "A category label must be nonempty.")
            end
            if strlength(resolveMetadataName(name,sourceMetadataNames(obj.RunInfo))) > 0
                error("iam:IAMFrame:ReservedMetadataName", ...
                    "Use a local category name that does not shadow provider metadata.")
            end
            report = obj.validate(LowerBound=opts.LowerBound, ...
                UpperBound=opts.UpperBound,Filter=opts.Filter);
            annotations = report.Scenarios(:,{'Model','Scenario','Version'});
            labels = repmat(string(missing),height(annotations),1);
            labels(report.Scenarios.Status == "Passed") = value;
            annotations.(name) = labels;
            out = obj.setMeta(annotations);
        end

        function tb = summary(obj)
            if isempty(obj.Data)
                tb = obj.Data(:, identityVariables());
                tb.NumYears = zeros(0,1);
                return
            end

            [tb, ~, uniqueKeys, loc] = identityGroups(obj.Data);
            tb.NumYears = accumarray(loc, 1, [height(uniqueKeys), 1]);

        end

        function value = head(obj, n)
            if nargin < 2
                n = 8;
            end
            value = head(obj.Data, n);
        end

        function value = tail(obj, n)
            if nargin < 2
                n = 8;
            end
            value = tail(obj.Data, n);
        end

        function out = filter(obj, nvp)
            %FILTER - Select frame observations by dimensions and metadata
            %   OUT = FILTER(OBJ,Name=Value) selects matching observations.
            %   Use the metadata name-value argument to filter local scenario
            %   metadata along with the observations.
            %
            %   See also meta, setMeta.
            arguments
                obj
                nvp.strict (1,1) logical = false
                nvp.models (1,:) string = string(missing)
                nvp.scenarios (1,:) string = string(missing)
                nvp.variables (1,:) string = string(missing)
                nvp.regions   (1,:) string = string(missing)
                nvp.units     (1,:) string = string(missing)
                nvp.runs double = []
                nvp.years = []
                nvp.metadata (1,1) struct = struct()
            end

            idx = true(height(obj.Data), 1);
            idx = idx & matchStringValues(obj.Data.Model, nvp.models, nvp.strict);
            idx = idx & matchStringValues(obj.Data.Scenario, nvp.scenarios, nvp.strict);
            idx = idx & matchStringValues(obj.Data.Variable, nvp.variables, nvp.strict);
            idx = idx & matchStringValues(obj.Data.Region, nvp.regions, nvp.strict);
            idx = idx & matchStringValues(obj.Data.Unit, nvp.units, nvp.strict);

            if ~isempty(nvp.runs)
                idx = idx & ismember(obj.Data.RunId, nvp.runs);
            end

            years = normalizeYears(nvp.years);
            if ~isempty(years)
                idx = idx & ismember(obj.Data.Year, years);
            end

            if ~isempty(fieldnames(nvp.metadata))
                idx = idx & matchFrameMetadata(obj.Data, obj.RunInfo, ...
                    obj.meta(), nvp.metadata, nvp.strict);
            end

            data = obj.Data(idx, :);
            provenance = subsetProvenance(obj.Provenance,data);
            runInfo = subsetRunInfo(obj.RunInfo, data,provenance);
            localMetadata = subsetLocalMetadata(obj.meta(), data);
            out = iam.IAMFrame(data, RunInfo=runInfo, Metadata=localMetadata, ...
                Provenance=provenance);
        end

        function out = append(obj, other, nvp)
            %append - Merge another frame using a shared conflict policy
            %   OUT = append(OBJ,OTHER) merges non-overlapping observations
            %   from OTHER into OBJ. Repeated observations raise an error.
            %
            %   OUT = append(OBJ,OTHER,RepeatPolicy=POLICY) selects how
            %   identical repeated observations are handled. POLICY is
            %   "error" or "deduplicate"; changed values always raise an
            %   error. Compatible RunInfo schemas are combined by column;
            %   ambiguous source IDs raise an error.
            arguments
                obj
                other
                nvp.RepeatPolicy {mustBeTextScalar} = "error"
            end

            repeatPolicy = string(nvp.RepeatPolicy);
            if ~ismember(repeatPolicy, ["error", "deduplicate"])
                error('iam:IAMFrame:InvalidRepeatPolicy', ...
                    'RepeatPolicy must be "error" or "deduplicate".')
            end

            if ~isa(other, 'iam.IAMFrame')
                other = iam.IAMFrame(other);
            end

            data = [obj.Data; other.Data];
            validateRunInfoMapping(obj.RunInfo, data);
            validateRunInfoMapping(other.RunInfo, data);
            [data, sourceRecords] = mergeObservations(data, repeatPolicy);
            runInfo = mergeRunInfo(obj.RunInfo, other.RunInfo);
            if ~isempty(sourceRecords)
                runInfo = mergeRunInfo(runInfo, sourceRecords);
            end
            localMetadata = mergeRunInfo(obj.meta(), other.meta());
            provenance = [obj.Provenance;other.Provenance];
            out = iam.IAMFrame(data, RunInfo=runInfo, Metadata=localMetadata, ...
                Provenance=provenance);
        end

        function tb = timeseries(obj)

            if isempty(obj.Data)
                tb = obj.summary();
                return
            end

            [tb, ~, uniqueKeys, loc] = identityGroups(obj.Data);
            years = sort(unique(obj.Data.Year));

            for i = 1 : numel(years)
                y = years(i);
                colName = "Y" + string(y);
                col = NaN(height(uniqueKeys), 1);
                idx = obj.Data.Year == y;
                col(loc(idx)) = obj.Data.Value(idx);
                tb.(colName) = col;
            end
        end

        function ts = toTimeseries(obj)
            if isempty(obj.Data)
                ts = iam.IAMTimeseries.empty();
                return
            end

            [~, ~, uniqueKeys, loc] = identityGroups(obj.Data);
            nGroups = height(uniqueKeys);

            % Sort once so each group is a contiguous, year-ordered block.
            [~, order] = sortrows([loc, obj.Data.Year]);

            % Pull raw arrays out of the table a single time.
            model    = obj.Data.Model(order);
            scenario = obj.Data.Scenario(order);
            variable = obj.Data.Variable(order);
            region   = obj.Data.Region(order);
            unit     = obj.Data.Unit(order);
            runId    = obj.Data.RunId(order);
            version  = obj.Data.Version(order);
            year     = obj.Data.Year(order);
            value    = obj.Data.Value(order);
            g        = loc(order);

            % Build datetimes once, not per group.
            dt = datetime(year, 1, 1, 'Format', 'yyyy');

            % Block boundaries from the sorted group index.
            starts = find([true; diff(g) ~= 0]);
            stops  = [starts(2:end) - 1; numel(g)];

            data(nGroups, 1) = struct('model', "", 'scenario', "", ...
                'variable', "", 'region', "", 'unit', "", 'runId', NaN, ...
                'version', NaN, 'years', zeros(0,1), 'values', timetable(), ...
                'RunInfo',table(),'Metadata',table(),'Provenance',emptyProvenance());

            for i = 1 : nGroups
                s = starts(i);
                rng = s:stops(i);

                data(i).model    = model(s);
                data(i).scenario = scenario(s);
                data(i).variable = variable(s);
                data(i).region   = region(s);
                data(i).unit     = unit(s);
                data(i).runId    = runId(s);
                data(i).version  = version(s);
                data(i).years    = year(rng);
                data(i).values   = timetable(dt(rng), value(rng), ...
                    'DimensionNames', {'Year', 'VariableUnits'}, ...
                    'VariableNames', {'Values'});
                rows = obj.Data(order(rng),:);
                data(i).Provenance = subsetProvenance(obj.Provenance,rows);
                data(i).RunInfo = subsetRunInfo(obj.RunInfo,rows,data(i).Provenance);
                data(i).Metadata = subsetLocalMetadata(obj.meta(),rows);
            end

            ts = iam.IAMTimeseries(data);
        end
    end
    methods (Static, Hidden)
        function out = fromCalculation(sources,data,parents,locations,operands)
            out = derivedFrame(sources,data,parents,locations,operands);
        end
    end
end

function validateDerivedLabels(leftVariable,rightVariable,outputVariable,outputUnit)
labels = [leftVariable,rightVariable,outputVariable,outputUnit];
if any(ismissing(labels) | strlength(labels) == 0)
    error("iam:IAMFrame:InvalidDerivedLabel", ...
        "Operand, output variable, and output unit labels must be nonempty text.")
end
end

function factor = commonUnitConversionFactor(sourceUnit,targetUnit)
if sourceUnit == targetUnit
    factor = 1;
    return
end
sources = ["Mt CO2/yr";"Gt CO2/yr";"Mt CO2";"Gt CO2"; ...
    "EJ/yr";"EJ";"TWh/yr";"TWh";"GWh";"MWh";"t CO2/yr";"kt CO2/yr"];
targets = ["kt CO2/yr";"Mt CO2/yr";"kt CO2";"Mt CO2"; ...
    "PJ/yr";"PJ";"PJ/yr";"PJ";"MWh";"kWh";"kt CO2/yr";"Mt CO2/yr"];
factors = [1000;1000;1000;1000;1000;1000;3.6;3.6;1000;1000; ...
    0.001;0.001];
index = find(sources == sourceUnit & targets == targetUnit,1);
if ~isempty(index)
    factor = factors(index);
    return
end
index = find(sources == targetUnit & targets == sourceUnit,1);
if isempty(index)
    factor = NaN;
else
    factor = 1/factors(index);
end
end

function [keys,leftLocation,rightLocation] = alignObservationRows(left,right,keyNames)
leftKeys = identityComparisonTable(left(:,cellstr(keyNames)));
rightKeys = identityComparisonTable(right(:,cellstr(keyNames)));
if height(unique(leftKeys,"rows")) ~= height(leftKeys) || ...
        height(unique(rightKeys,"rows")) ~= height(rightKeys)
    error("iam:IAMFrame:AmbiguousOperand", ...
        "Each operand must have at most one observation per model, scenario, version, region, and year.")
end
keys = unique([leftKeys;rightKeys],"rows","stable");
[~,leftLocation] = ismember(keys,leftKeys,"rows");
[~,rightLocation] = ismember(keys,rightKeys,"rows");
end

function runId = alignedRunIds(leftRun,rightRun,leftPresent,rightPresent)
runId = NaN(numel(leftRun),1);
leftOnly = leftPresent & ~rightPresent;
rightOnly = rightPresent & ~leftPresent;
runId(leftOnly) = leftRun(leftOnly);
runId(rightOnly) = rightRun(rightOnly);
both = leftPresent & rightPresent & ~isnan(leftRun) & leftRun == rightRun;
runId(both) = leftRun(both);
end

function data = calculatedObservationTable(keys,variable,unit,runId,value)
if isscalar(unit)
    unit = repmat(unit,height(keys),1);
end
version = keys.Version;
version(isinf(version) & version < 0) = NaN;
data = table(keys.Model,keys.Scenario,repmat(variable,height(keys),1), ...
    keys.Region,unit,runId,version,keys.Year,value, ...
    VariableNames=["Model","Scenario","Variable","Region","Unit", ...
    "RunId","Version","Year","Value"]);
end

function out = derivedFrame(sources,data,parents,locations,operands)
pieces = cell(numel(sources),1);
runInfo = table();
metadata = table();
for i = 1:numel(sources)
    parent = parents{i};
    if isempty(locations)
        keys = {'Model','Scenario','Version','Region','Year'};
        [~, location] = ismember(identityComparisonTable(data(:,keys)), ...
            identityComparisonTable(parent(:,keys)),"rows");
    else
        location = locations{i};
    end
    actual = find(location > 0);
    parent = parent(location(actual),:);
    result = data(actual,:);
    old = sources{i}.Provenance;
    inherited = false(height(parent),1);
    links = emptyProvenance();
    if ~isempty(old)
        keys = observationIdentityVariables();
        [matched, parentLocation] = ismember(identityComparisonTable(old(:,keys)), ...
            identityComparisonTable(parent(:,keys)),"rows");
        inherited(parentLocation(matched)) = true;
        links = old(matched,:);
        links(:,keys) = result(parentLocation(matched),keys);
        links.Operand(:) = operands(i);
    end
    fresh = emptyProvenance();
    if any(~inherited)
        keys = observationIdentityVariables();
        origin = renamevars(parent(~inherited,keys),string(keys),"Source" + string(keys));
        fresh = [result(~inherited,keys),origin, ...
            table(parent.RunId(~inherited),repmat(operands(i),nnz(~inherited),1), ...
            VariableNames=["SourceRunId","Operand"])];
    end
    pieces{i} = [links;fresh];
    runInfo = mergeRunInfo(runInfo,subsetRunInfo(sources{i}.RunInfo,parent,old));
    metadata = mergeRunInfo(metadata,subsetLocalMetadata(sources{i}.meta(),data));
end
provenance = vertcat(pieces{:});
known = ~isnan(provenance.SourceRunId);
records = provenance(known,{'SourceModel','SourceScenario','SourceVersion','SourceRunId'});
records.Properties.VariableNames = {'model','scenario','version','run_id'};
runInfo = mergeRunInfo(runInfo,records);
out = iam.IAMFrame(data,RunInfo=runInfo,Metadata=metadata,Provenance=provenance);
end

function provenance = emptyProvenance()
keys = string(observationIdentityVariables());
names = [keys,"Source" + keys,"SourceRunId","Operand"];
types = [repmat("string",1,5),"double","double"];
provenance = table('Size',[0,16],'VariableNames',cellstr(names), ...
    'VariableTypes',cellstr([types,types,"double","string"]));
end

function provenance = normalizeProvenance(provenance,data)
if isempty(provenance.Properties.VariableNames)
    provenance = emptyProvenance();
    return
end
names = string(emptyProvenance().Properties.VariableNames);
if ~isequal(sort(string(provenance.Properties.VariableNames)),sort(names))
    error("iam:IAMFrame:InvalidProvenance","Provenance must use the result/source observation schema.")
end
provenance = provenance(:,cellstr(names));
for name = ["Model","Scenario","Variable","Region","Unit", ...
        "SourceModel","SourceScenario","SourceVariable","SourceRegion","SourceUnit","Operand"]
    provenance.(name) = normalizeTextColumn(provenance.(name),name);
    if ~ismember(name,["Unit","SourceUnit"]) && ...
            any(ismissing(provenance.(name)) | strlength(provenance.(name)) == 0)
        error("iam:IAMFrame:InvalidProvenance","Provenance identities must be nonempty.")
    end
end
for name = ["Unit","SourceUnit"]
    provenance.(name)(ismissing(provenance.(name))) = "";
end
for name = ["Version","SourceVersion","SourceRunId"]
    provenance.(name) = normalizeNumericColumn(provenance.(name),name,true);
end
for name = ["Year","SourceYear"]
    provenance.(name) = normalizeAnnualYears(provenance.(name));
end
keys = observationIdentityVariables();
if any(~ismember(identityComparisonTable(provenance(:,keys)), ...
        identityComparisonTable(data(:,keys)),"rows"))
    error("iam:IAMFrame:InvalidProvenance","A provenance link refers to an unknown result observation.")
end
[~, first] = unique(identityComparisonTable(provenance),"rows","stable");
provenance = provenance(first,:);
provenance = sortrows(provenance,cellstr(names));
end

function provenance = subsetProvenance(provenance,data)
if isempty(provenance)
    return
end
keys = observationIdentityVariables();
keep = ismember(identityComparisonTable(provenance(:,keys)), ...
    identityComparisonTable(data(:,keys)),"rows");
provenance = provenance(keep,:);
end

function report = calculationReport(keys,missingLeft,missingRight,zeroDenominator,computedCount)
version = keys.Version;
version(isinf(version) & version < 0) = NaN;
missing = table(keys.Model,keys.Scenario,version,keys.Region,keys.Year, ...
    missingLeft,missingRight, ...
    VariableNames=["Model","Scenario","Version","Region","Year", ...
    "MissingLeft","MissingRight"]);
zero = table(keys.Model(zeroDenominator),keys.Scenario(zeroDenominator), ...
    version(zeroDenominator),keys.Region(zeroDenominator),keys.Year(zeroDenominator), ...
    VariableNames=["Model","Scenario","Version","Region","Year"]);
report = struct("ComputedCount",computedCount, ...
    "MissingOperands",missing(any([missingLeft,missingRight],2),:), ...
    "ZeroDenominators",zero);
end

function [ids, keys, uniqueKeys, loc] = identityGroups(data)
vars = identityVariables();
keys = identityComparisonTable(data(:, vars));
[uniqueKeys, ia, loc] = unique(keys, 'rows', 'stable');
ids = data(ia, vars);
end

function tb = defaultDataTable()
tb = table('Size', [0, 9], ...
    'VariableNames', {'Model', 'Scenario', 'Variable', 'Region', 'Unit', 'RunId', 'Version', 'Year', 'Value'}, ...
    'VariableTypes', {'string', 'string', 'string', 'string', 'string', 'double', 'double', 'double', 'double'});
end

function vars = identityVariables()
vars = {'Model', 'Scenario', 'Variable', 'Region', 'Unit', 'RunId', 'Version'};
end

function vars = observationIdentityVariables()
vars = {'Model', 'Scenario', 'Variable', 'Region', 'Unit', 'Version', 'Year'};
end

function value = uniqueOrEmpty(data, fieldName, emptyValue)
if isempty(data)
    value = emptyValue;
else
    value = unique(data.(fieldName));
end
end

function [data,runInfo,metadata,provenance] = fromTimeseries(ts)
data = defaultDataTable();
runInfo = table();
metadata = table();
provenance = emptyProvenance();
if isempty(ts)
    return
end

numRows = sum(arrayfun(@(x) numel(x.Years), ts(:)));
model = strings(numRows, 1);
scenario = strings(numRows, 1);
variable = strings(numRows, 1);
region = strings(numRows, 1);
unit = strings(numRows, 1);
runId = NaN(numRows, 1);
version = NaN(numRows, 1);
yearValue = NaN(numRows, 1);
value = NaN(numRows, 1);

current = 1;
pieces = cell(numel(ts),1);
for i = 1 : numel(ts)
    years = normalizeAnnualYears(ts(i).Years(:));
    tt = ts(i).Values;
    count = numel(years);
    if width(tt) ~= 1
        error("iam:IAMFrame:InvalidTimeseriesValues", ...
            "Each timeseries must contain exactly one numeric value column.")
    end
    if height(tt) ~= count
        error("iam:IAMFrame:InvalidTimeseriesLength", ...
            "Timeseries %d has %d years and %d value rows; their lengths must match.", ...
            i, count, height(tt))
    end
    values = normalizeNumericColumn(tt{:,1}, "Value", true);
    if ~isscalar(ts(i).Version)
        error("iam:IAMFrame:InvalidNumericColumn", ...
            "Version must contain one numeric value per timeseries.")
    end
    dates = tt.Properties.RowTimes;
    if ~isdatetime(dates) || any(isnat(dates)) || ...
            ~isequal(year(dates), years) || any(dates ~= dateshift(dates, "start", "year"))
        error("iam:IAMFrame:InvalidTimeseriesTime", ...
            "Timeseries row times must match Years and be January 1 at midnight.")
    end
    idx = current:(current + count - 1);

    model(idx) = ts(i).Model;
    scenario(idx) = ts(i).Scenario;
    variable(idx) = ts(i).Variable;
    region(idx) = ts(i).Region;
    unit(idx) = ts(i).Unit;
    runId(idx) = ts(i).RunId;
    version(idx) = ts(i).Version;
    yearValue(idx) = years;
    value(idx) = values;

    current = current + count;
    runInfo = mergeRunInfo(runInfo,ts(i).RunInfo);
    metadata = mergeRunInfo(metadata,ts(i).Metadata);
    pieces{i} = ts(i).Provenance;
    if isempty(pieces{i}.Properties.VariableNames)
        pieces{i} = emptyProvenance();
    end
end
provenance = vertcat(pieces{:});

data = table(model, scenario, variable, region, unit, runId, version, yearValue, value, ...
    'VariableNames', data.Properties.VariableNames);
end

function data = normalizeDataTable(data)
required = ["Model", "Scenario", "Variable", "Region", "Unit", "Year", "Value"];
optional = ["RunId", "Version"];
present = string(data.Properties.VariableNames);
if ~all(ismember(required, present))
    error('iam:IAMFrame:InvalidTable', ...
        "IAMFrame table input must contain: " + strjoin(required, ", "))
end

unsupported = setdiff(present, [required, optional], 'stable');
if ~isempty(unsupported)
    error('iam:IAMFrame:UnsupportedColumns', ...
        "Unsupported IAMFrame table columns: " + strjoin(unsupported, ", "))
end

data.Model = normalizeTextColumn(data.Model, "Model");
data.Scenario = normalizeTextColumn(data.Scenario, "Scenario");
data.Variable = normalizeTextColumn(data.Variable, "Variable");
data.Region = normalizeTextColumn(data.Region, "Region");
data.Unit = normalizeTextColumn(data.Unit, "Unit");
data.Unit(ismissing(data.Unit)) = "";
missingIdentity = ismissing(data.Model) | strlength(data.Model) == 0 | ...
    ismissing(data.Scenario) | strlength(data.Scenario) == 0 | ...
    ismissing(data.Variable) | strlength(data.Variable) == 0 | ...
    ismissing(data.Region) | strlength(data.Region) == 0;
if any(missingIdentity)
    error('iam:IAMFrame:MissingIdentity', ...
        'Model, Scenario, Variable, and Region must be nonempty text.')
end

if ~ismember("RunId", present)
    data.RunId = NaN(height(data), 1);
end
if ~ismember("Version", present)
    data.Version = NaN(height(data), 1);
end
data.RunId = normalizeNumericColumn(data.RunId, "RunId", true);
data.Version = normalizeNumericColumn(data.Version, "Version", true);
data.Year = normalizeAnnualYears(data.Year);
data.Value = normalizeNumericColumn(data.Value, "Value", true);
if any(isinf(data.Value))
    error('iam:IAMFrame:InvalidValue', ...
        'Value entries may be finite or NaN, but not infinite.')
end

data = data(:, cellstr([required, optional]));
data = sortrows(data, {'Model', 'Scenario', 'Variable', 'Region', 'Unit', 'RunId', 'Version', 'Year'});
end

function values = normalizeTextColumn(values, name)
validType = isstring(values) || ischar(values) || iscellstr(values) || iscategorical(values);
if ~validType || (~ischar(values) && size(values, 2) ~= 1)
    error('iam:IAMFrame:InvalidTextColumn', ...
        name + " must contain text values.")
end
values = string(values);
end

function values = normalizeNumericColumn(values, name, allowMissing)
if ~isnumeric(values) || ~isreal(values) || size(values, 2) ~= 1
    error('iam:IAMFrame:InvalidNumericColumn', ...
        name + " must contain a real numeric column.")
end
values = double(values);
if any(isinf(values)) || (~allowMissing && any(isnan(values)))
    error('iam:IAMFrame:InvalidNumericColumn', ...
        name + " contains invalid or nonfinite values.")
end
end

function years = normalizeAnnualYears(years)
if ~isnumeric(years) || ~isreal(years) || size(years, 2) ~= 1
    error('iam:IAMFrame:InvalidYear', ...
        'Year values must be finite integer annual years.')
end
years = double(years);
if any(~isfinite(years)) || any(years ~= fix(years))
    error('iam:IAMFrame:InvalidYear', ...
        'Year values must be finite integer annual years.')
end
end

function idx = matchStringValues(values, patterns, strict)
values = string(values);
values(ismissing(values)) = "";

patterns = string(patterns);
patterns = patterns(~ismissing(patterns));
if isempty(patterns)
    idx = true(size(values));
    return
end

idx = false(size(values));
for i = 1 : numel(patterns)
    idx = idx | matchSinglePattern(values, patterns(i), strict);
end
end

function idx = matchSinglePattern(values, pattern, strict)
if strlength(pattern) == 0
    idx = values == "";
elseif contains(pattern, "*") || contains(pattern, "?")
    expr = "^" + string(regexptranslate('wildcard', char(pattern))) + "$";
    idx = ~cellfun('isempty', regexpi(cellstr(values), char(expr), 'once'));
elseif strict
    idx = matches(values, pattern, 'IgnoreCase', true);
else
    idx = contains(values, pattern, 'IgnoreCase', true);
end
end

function years = normalizeYears(inputYears)
if isempty(inputYears)
    years = zeros(0,1);
    return
end

if isnumeric(inputYears)
    if ~isreal(inputYears)
        invalidYearSelector()
    end
    years = double(inputYears);
elseif isstring(inputYears) || ischar(inputYears) || iscellstr(inputYears)
    years = str2double(string(inputYears));
else
    invalidYearSelector()
end

if any(~isfinite(years), 'all') || any(years ~= fix(years), 'all')
    invalidYearSelector()
end
end

function invalidYearSelector()
error('iam:IAMFrame:InvalidYears', ...
    'Years must be finite integer annual years or empty.')
end

function rows = identityComparisonTable(rows)
% UNIQUE treats NaNs as distinct rows; negative infinity is reserved for
% missing optional numeric identity fields by the input contract.
names = rows.Properties.VariableNames;
for i = 1 : numel(names)
    if isnumeric(rows.(names{i}))
        values = rows.(names{i});
        values(isnan(values)) = -Inf;
        rows.(names{i}) = values;
    end
end
end

function runInfo = subsetRunInfo(runInfo, data, provenance)
if nargin < 3
    provenance = emptyProvenance();
else
    provenance = subsetProvenance(provenance,data);
end
if isempty(runInfo) || isempty(data)
    runInfo = runInfo([],:);
    return
end

runInfoNames = lower(string(runInfo.Properties.VariableNames));
runInfoNames(runInfoNames == "runid") = "run_id";
identityNames = ["run_id", "model", "scenario", "version"];
dataNames = ["RunId", "Model", "Scenario", "Version"];
available = ismember(identityNames, runInfoNames);
if ~any(available)
    return
end
directData = data;
if ~isempty(provenance)
    keys = observationIdentityVariables();
    linked = ismember(identityComparisonTable(data(:,keys)), ...
        identityComparisonTable(provenance(:,keys)),"rows");
    directData = data(~linked,:);
end

keep = false(height(runInfo), 1);
for i = 1 : height(runInfo)
    match = true(height(directData), 1);
    hasAnalyticalKey = false;
    runIdMatch = true(height(directData), 1);
    hasRunIdKey = false;
    sourceMatch = true(height(provenance),1);
    sourceNames = ["SourceRunId","SourceModel","SourceScenario","SourceVersion"];
    for j = find(available)
        name = runInfo.Properties.VariableNames{find(runInfoNames == identityNames(j), 1)};
        value = runInfo.(name)(i);
        if isMissingMetadataValue(value)
            continue
        end
        sourceMatch = sourceMatch & matchMetadataIdentity(provenance.(sourceNames(j)),value);
        if identityNames(j) == "run_id"
            hasRunIdKey = true;
            runIdMatch = matchMetadataIdentity(directData.(dataNames(j)), value);
        else
            hasAnalyticalKey = true;
            match = match & matchMetadataIdentity(directData.(dataNames(j)), value);
        end
    end
    if hasRunIdKey && hasAnalyticalKey
        keep(i) = any(match & (runIdMatch | isnan(directData.RunId)));
    elseif hasRunIdKey
        keep(i) = any(match & runIdMatch);
    else
        keep(i) = hasAnalyticalKey && any(match);
    end
    keep(i) = keep(i) || ((hasRunIdKey || hasAnalyticalKey) && any(sourceMatch));
end
runInfo = runInfo(keep, :);
end

function runInfo = mergeRunInfo(leftInfo, rightInfo)
leftInfo = normalizeRunInfoIdentityNames(leftInfo);
rightInfo = normalizeRunInfoIdentityNames(rightInfo);
leftNames = string(leftInfo.Properties.VariableNames);
rightNames = string(rightInfo.Properties.VariableNames);
names = [leftNames, rightNames(~ismember(rightNames, leftNames))];
if isempty(names)
    runInfo = table();
    return
end

leftAligned = table();
rightAligned = table();
for name = names
    hasLeft = ismember(name, leftNames);
    hasRight = ismember(name, rightNames);
    if hasLeft && hasRight
        [leftColumn, rightColumn] = harmonizeMetadataColumns( ...
            leftInfo.(name), rightInfo.(name), name);
    elseif hasLeft
        leftColumn = normalizeMetadataColumn(leftInfo.(name), name);
        rightColumn = missingMetadataColumn(leftColumn, height(rightInfo), name);
    else
        rightColumn = normalizeMetadataColumn(rightInfo.(name), name);
        leftColumn = missingMetadataColumn(rightColumn, height(leftInfo), name);
    end
    leftAligned.(name) = leftColumn;
    rightAligned.(name) = rightColumn;
end

rows = [leftAligned; rightAligned];
identityNames = lower(string(rows.Properties.VariableNames));
keyNames = intersect(["run_id", "model", "scenario", "version"], ...
    identityNames, 'stable');
runInfo = rows;
outputCount = 0;
for i = 1 : height(rows)
    match = findRunInfoMatch(runInfo(1:outputCount,:), rows(i,:), keyNames);
    if isempty(match)
        outputCount = outputCount + 1;
        runInfo(outputCount,:) = rows(i,:);
    else
        runInfo(match,:) = mergeRunInfoRow(runInfo(match,:), rows(i,:), keyNames);
    end
end
runInfo = runInfo(1:outputCount, :);
end

function runInfo = normalizeRunInfoIdentityNames(runInfo)
names = string(runInfo.Properties.VariableNames);
names(lower(names) == "runid") = "run_id";
identityColumns = ismember(lower(names), ["run_id","model","scenario","version"]);
names(identityColumns) = lower(names(identityColumns));
if numel(unique(names)) ~= numel(names)
    error('iam:IAMFrame:IncompatibleRunInfo', ...
        'RunInfo contains duplicate case-insensitive identity columns.')
end
runInfo.Properties.VariableNames = cellstr(names);
end

function validateRunInfoMapping(runInfo, data)
if isempty(runInfo) || isempty(data)
    return
end

runInfoNames = lower(string(runInfo.Properties.VariableNames));
runInfoNames(runInfoNames == "runid") = "run_id";
runIdIndex = find(runInfoNames == "run_id", 1);
if isempty(runIdIndex)
    return
end
runIdName = runInfo.Properties.VariableNames{runIdIndex};
runIds = unique(runInfo.(runIdName));
runIds = runIds(~isnan(runIds));
identityNames = ["model", "scenario", "version"];
dataNames = ["Model", "Scenario", "Version"];
available = ismember(identityNames, runInfoNames);

for runId = runIds(:)'
    dataRows = data(~isnan(data.RunId) & data.RunId == runId, :);
    if isempty(dataRows)
        continue
    end
    trajectories = unique(identityComparisonTable( ...
        dataRows(:, {'Model', 'Scenario', 'Version'})), 'rows', 'stable');
    infoRows = runInfo(runInfo.(runIdName) == runId, :);
    for i = 1 : height(infoRows)
        matchesTrajectory = true(height(trajectories), 1);
        hasIdentity = false;
        for j = find(available)
            name = runInfo.Properties.VariableNames{find( ...
                runInfoNames == identityNames(j), 1)};
            value = infoRows.(name)(i);
            if isMissingMetadataValue(value)
                continue
            end
            hasIdentity = true;
            matchesTrajectory = matchesTrajectory & ...
                matchMetadataIdentity(trajectories.(dataNames(j)), value);
        end
        matchCount = nnz(matchesTrajectory);
        if matchCount == 0
            error('iam:IAMFrame:RunInfoIdentityMismatch', ...
                'RunInfo identity does not match data for RunId %.15g.', runId)
        elseif matchCount > 1 && hasIdentity
            error('iam:IAMFrame:AmbiguousRunInfo', ...
                ['RunInfo for RunId %.15g does not identify one model, ' ...
                 'scenario, and version.'], runId)
        elseif matchCount > 1
            error('iam:IAMFrame:AmbiguousRunInfo', ...
                ['RunInfo for RunId %.15g has no analytical identity and ' ...
                 'matches multiple scenarios.'], runId)
        end
    end
end
end

function [data, provenance] = mergeObservations(data, repeatPolicy)
provenance = table();
if isempty(data)
    return
end

keys = identityComparisonTable(data(:, observationIdentityVariables()));
[uniqueKeys, ~, group] = unique(keys, 'rows', 'stable');
counts = accumarray(group, 1, [height(uniqueKeys), 1]);
duplicateGroups = find(counts > 1);
if isempty(duplicateGroups)
    return
end

keep = true(height(data), 1);
provenanceMask = false(height(data), 1);
originalRunIds = data.RunId;
for groupId = duplicateGroups'
    rows = find(group == groupId);
    observation = observationDescription(data(rows(1), :));
    values = data.Value(rows);
    if any(~arrayfun(@(value) isequaln(value, values(1)), values))
        error('iam:IAMFrame:ConflictingObservation', ...
            "Repeated observation has changed values: " + observation)
    end
    if repeatPolicy == "error"
        error('iam:IAMFrame:DuplicateObservation', ...
            "Repeated observation: " + observation + ...
            '. Set RepeatPolicy="deduplicate" to collapse identical values.')
    end

    sourceIds = data.RunId(rows);
    sourceIds = sourceIds(~isnan(sourceIds));
    if isempty(sourceIds)
        data.RunId(rows(1)) = NaN;
    elseif all(sourceIds == sourceIds(1))
        data.RunId(rows(1)) = sourceIds(1);
    else
        provenanceMask(rows(~isnan(originalRunIds(rows)))) = true;
        data.RunId(rows(1)) = NaN;
    end
    keep(rows(2:end)) = false;
end
if any(provenanceMask)
    provenance = data(provenanceMask, {'Model','Scenario','Version','RunId'});
    provenance.RunId = originalRunIds(provenanceMask);
    provenance.Properties.VariableNames = {'model','scenario','version','run_id'};
    [~, first] = unique(identityComparisonTable(provenance), 'rows', 'stable');
    provenance = provenance(first,:);
end
data = data(keep, :);
end

function [left, right] = harmonizeMetadataColumns(left, right, name)
left = normalizeMetadataColumn(left, name);
right = normalizeMetadataColumn(right, name);
if ~strcmp(class(left), class(right))
    error('iam:IAMFrame:IncompatibleRunInfo', ...
        "RunInfo column '" + name + "' has incompatible types " + ...
        class(left) + " and " + class(right) + ".")
end
if isdatetime(left) && ~strcmp(left.TimeZone, right.TimeZone)
    if isempty(left.TimeZone) && all(isnat(left))
        left.TimeZone = right.TimeZone;
    elseif isempty(right.TimeZone) && all(isnat(right))
        right.TimeZone = left.TimeZone;
    elseif isempty(left.TimeZone) || isempty(right.TimeZone)
        error('iam:IAMFrame:IncompatibleRunInfo', ...
            "RunInfo column '" + name + "' mixes zoned and unzoned timestamps.")
    end
    right.TimeZone = left.TimeZone;
end
end

function values = normalizeMetadataColumn(values, name)
if ~ischar(values) && (~ismatrix(values) || ...
        (size(values,2) ~= 1 && ~isequal(size(values), [0 0])))
    error('iam:IAMFrame:IncompatibleRunInfo', ...
        "RunInfo column '" + name + "' must contain one value per row; array columns are unsupported.")
end
if ischar(values)
    if size(values,1) == 0
        values = strings(0,1);
    else
        values = string(values);
    end
elseif iscategorical(values) || (iscellstr(values) && ~isempty(values))
    values = string(values);
elseif isstring(values)
    values = values(:);
elseif isnumeric(values) || islogical(values)
    values = double(values(:));
elseif isstruct(values)
    values = num2cell(values(:));
elseif isdatetime(values) || isduration(values) || iscell(values)
    values = values(:);
else
    error('iam:IAMFrame:IncompatibleRunInfo', ...
        "RunInfo column '" + name + "' has unsupported type " + class(values) + ".")
end
end

function values = missingMetadataColumn(template, count, name)
if isstring(template)
    values = repmat(string(missing), count, 1);
elseif isnumeric(template)
    values = NaN(count, 1);
elseif isdatetime(template)
    values = NaT(count, 1, 'TimeZone', template.TimeZone);
elseif isduration(template)
    values = seconds(NaN(count, 1));
elseif iscell(template)
    values = cell(count, 1);
else
    error('iam:IAMFrame:IncompatibleRunInfo', ...
        "RunInfo column '" + name + "' cannot represent missing values.")
end
end

function match = findRunInfoMatch(existing, candidate, keyNames)
match = [];
if isempty(existing)
    return
end

if isempty(keyNames)
    for i = 1 : height(existing)
        if metadataRowsEqual(existing(i,:), candidate)
            match = i;
            return
        end
    end
    return
end

for i = 1 : height(existing)
    sharedRunId = false;
    sameIdentity = true;
    sharedModel = false;
    sharedScenario = false;
    for name = keyNames
        columnName = existing.Properties.VariableNames{find( ...
            lower(string(existing.Properties.VariableNames)) == name, 1)};
        leftValue = existing.(columnName)(i);
        rightValue = candidate.(columnName);
        if isMissingMetadataValue(leftValue) || isMissingMetadataValue(rightValue)
            continue
        end
        if ~isequaln(leftValue, rightValue)
            sameIdentity = false;
            break
        end
        sharedRunId = sharedRunId || name == "run_id";
        sharedModel = sharedModel || name == "model";
        sharedScenario = sharedScenario || name == "scenario";
    end
    analyticalKeys = keyNames(keyNames ~= "run_id");
    if sameIdentity && (sharedRunId || (sharedModel && sharedScenario && ...
            metadataRowsEqual(existing(i,:), candidate, analyticalKeys)))
        if ~isempty(match)
            error('iam:IAMFrame:AmbiguousRunInfo', ...
                'A partial RunInfo identity matches multiple source records.')
        end
        match = i;
    end
end
end

function merged = mergeRunInfoRow(existing, candidate, keyNames)
merged = existing;
allNames = string(existing.Properties.VariableNames);
identity = metadataIdentityDescription(existing, keyNames);
for name = allNames
    merged.(name) = mergeMetadataValues(existing.(name), candidate.(name), ...
        "RunInfo for " + identity + ", column '" + name + "'");
end
end

function value = mergeMetadataValues(left, right, description)
value = left;
if isMissingMetadataValue(left)
    value = right;
elseif isMissingMetadataValue(right)
    return
elseif iscell(left) && iscell(right) && isscalar(left) && isscalar(right)
    value = {mergeMetadataValues(left{1}, right{1}, description)};
elseif isstruct(left) && isstruct(right) && isscalar(left) && isscalar(right)
    for name = string(fieldnames(right))'
        if isfield(left, name)
            value.(name) = mergeMetadataValues(left.(name), right.(name), ...
                description + "." + name);
        else
            value.(name) = right.(name);
        end
    end
elseif ~isequaln(left, right)
    if (ischar(left) || isstring(left) || iscategorical(left)) && ...
            (ischar(right) || isstring(right) || iscategorical(right)) && ...
            isequaln(string(left), string(right))
        return
    end
    error('iam:IAMFrame:IncompatibleRunInfo', ...
        "Conflicting metadata in " + description + ".")
end
end

function tf = metadataRowsEqual(left, right, names)
if nargin < 3
    names = string(left.Properties.VariableNames);
end
tf = true;
for name = names
    if ~isequaln(left.(name), right.(name))
        tf = false;
        return
    end
end
end

function tf = isMissingMetadataValue(value)
if isempty(value)
    tf = true;
elseif iscell(value)
    tf = isscalar(value) && isMissingMetadataValue(value{1});
elseif isstruct(value)
    tf = isempty(value) || (isscalar(value) && isempty(fieldnames(value)));
elseif isnumeric(value)
    tf = isscalar(value) && isnan(value);
elseif isstring(value)
    tf = isscalar(value) && ismissing(value);
elseif isdatetime(value)
    tf = isscalar(value) && isnat(value);
elseif isduration(value)
    tf = isscalar(value) && isnan(seconds(value));
elseif iscategorical(value)
    tf = isscalar(value) && isundefined(value);
else
    tf = isempty(value);
end
end

function tf = matchMetadataIdentity(dataValues, runInfoValue)
if iscell(dataValues)
    dataValues = string(dataValues);
end
if isstring(dataValues) || ischar(dataValues) || iscategorical(dataValues)
    tf = matches(string(dataValues), string(runInfoValue));
elseif isnumeric(dataValues) || islogical(dataValues)
    value = double(runInfoValue);
    values = double(dataValues);
    tf = values == value | (isnan(values) & isnan(value));
else
    tf = arrayfun(@(value) isequaln(value, runInfoValue), dataValues);
end
end

function description = observationDescription(row)
description = "Model=" + row.Model + ", Scenario=" + row.Scenario + ...
    ", Version=" + string(row.Version) + ", Variable=" + row.Variable + ...
    ", Region=" + row.Region + ", Unit=" + row.Unit + ...
    ", Year=" + string(row.Year);
end

function description = metadataIdentityDescription(row, keyNames)
parts = strings(numel(keyNames), 1);
for i = 1 : numel(keyNames)
    name = keyNames(i);
    columnName = row.Properties.VariableNames{find( ...
        lower(string(row.Properties.VariableNames)) == name, 1)};
    value = string(row.(columnName));
    value(ismissing(value)) = "missing";
    parts(i) = name + "=" + value;
end
description = strjoin(parts, ", ");
end

function validateUniqueObservations(data)
if isempty(data)
    return
end
keys = identityComparisonTable(data(:, observationIdentityVariables()));
uniqueKeys = unique(keys, 'rows', 'stable');
if height(uniqueKeys) ~= height(data)
    error('iam:IAMFrame:DuplicateObservation', ...
        ['IAMFrame data contains duplicate observations for the same ' ...
         'model, scenario, version, variable, region, unit, and year.'])
end
end


function [keys, group] = scenarioIndex(data)
identity = data(:, {'Model','Scenario','Version'});
[~, first, group] = unique(identityComparisonTable(identity), "rows", "stable");
keys = identity(first,:);
end

function [metadata, supplied] = normalizeLocalMetadata(input, data)
metadata = scenarioIndex(data);
supplied = false(height(metadata),1);
if isempty(input.Properties.VariableNames)
    return
end
input = normalizeRunInfoIdentityNames(input);
names = string(input.Properties.VariableNames);
if ~all(ismember(["model","scenario"],names))
    error("iam:IAMFrame:InvalidMetadata", "Metadata requires Model and Scenario keys.")
end
if ~ismember("version",names)
    input.version = NaN(height(input),1);
end
input.model = normalizeTextColumn(input.model,"Model");
input.scenario = normalizeTextColumn(input.scenario,"Scenario");
if any(ismissing(input.model) | strlength(input.model) == 0 | ...
        ismissing(input.scenario) | strlength(input.scenario) == 0)
    error("iam:IAMFrame:InvalidMetadataIdentity", "Metadata keys must be nonempty text.")
end
input.version = normalizeNumericColumn(input.version,"Version",true);
input = renamevars(input,["model","scenario","version"],["Model","Scenario","Version"]);
keys = input(:,{'Model','Scenario','Version'});
[known, location] = ismember(identityComparisonTable(keys), ...
    identityComparisonTable(metadata),"rows");
if any(~known)
    error("iam:IAMFrame:UnknownMetadataIdentity", "Metadata refers to an unknown scenario/version.")
end
if numel(unique(location)) ~= height(input)
    error("iam:IAMFrame:DuplicateMetadataIdentity", "Metadata keys must be unique.")
end
supplied(location) = true;
names = string(input.Properties.VariableNames);
for name = names(~ismember(names,["Model","Scenario","Version"]))
    validateAnnotationName(name);
    values = input.(name);
    if isnumeric(values) || islogical(values)
        values = normalizeNumericColumn(double(values),name,true);
    elseif isstring(values) || ischar(values) || iscellstr(values) || iscategorical(values)
        values = normalizeTextColumn(values,name);
    else
        error("iam:IAMFrame:InvalidMetadataColumn", ...
            "Annotations must contain scalar numeric, logical, or text values.")
    end
    if strcmpi(name,"Excluded") && (~isnumeric(values) || ...
            any(~isnan(values) & values ~= 0 & values ~= 1))
        error("iam:IAMFrame:InvalidMetadataColumn", "Excluded must contain zero, one, or NaN.")
    end
    metadata.(name) = missingMetadataColumn(values,height(metadata),name);
    metadata.(name)(location) = values;
end
end

function validateAnnotationName(name)
reserved = ["model","scenario","version","runid","run_id", ...
    "variable","region","unit","year","value","metadata"];
if ismissing(name) || strlength(name) == 0 || ...
        ismember(lower(string(matlab.lang.makeValidName(name))),reserved)
    error("iam:IAMFrame:ReservedMetadataName", "Use a nonempty annotation name outside the data/provenance keys.")
end
end

function metadata = subsetLocalMetadata(metadata, data)
keep = ismember(identityComparisonTable(metadata(:,{'Model','Scenario','Version'})), ...
    identityComparisonTable(scenarioIndex(data)),"rows");
metadata = metadata(keep,:);
end

function keep = matchFrameMetadata(data, runInfo, local, filters, strict)
[keys, group] = scenarioIndex(data);
selected = true(height(keys),1);
localNames = string(local.Properties.VariableNames);
sourceNames = sourceMetadataNames(runInfo);
for requested = string(fieldnames(filters))'
    selector = filters.(requested);
    if ~(isnumeric(selector) || islogical(selector) || isstring(selector) || ...
            ischar(selector) || iscellstr(selector) || iscategorical(selector)) || ...
            ((isnumeric(selector) || islogical(selector)) && ...
            (~isreal(selector) || any(isinf(selector),"all")))
        error("iam:IAMFrame:InvalidMetadataSelector", "Use real numeric, logical, or text metadata selectors.")
    end
    name = resolveMetadataName(requested,localNames(4:end));
    sourceName = resolveMetadataName(requested,sourceNames);
    override = false(height(keys),1);
    localMatch = false(height(keys),1);
    if strlength(name) > 0
        localMatch = matchMetadataColumn(local.(name),filters.(requested),strict);
        override = ~ismissing(local.(name));
        if strcmpi(name,"Excluded")
            override(:) = true;
        end
    end
    if strlength(name) == 0 && strlength(sourceName) == 0
        error("iam:IAMFrame:UnknownMetadataName", "Unknown metadata field '" + requested + "'.")
    end
    if strlength(sourceName) == 0
        selected = selected & localMatch;
        continue
    end
    matched = false(height(keys),1);
    for i = find(~override)'
        rows = subsetRunInfo(runInfo,data(group == i,:));
        value = [];
        for j = 1:height(rows)
            candidate = sourceMetadataValue(rows(j,:),sourceName);
            value = mergeMetadataValues(value,candidate,"scenario metadata '" + sourceName + "'");
        end
        if isempty(value)
            matched(i) = any(ismissing(filters.(requested)),"all");
        else
            if ischar(value) || iscategorical(value)
                value = string(value);
            end
            if ~isscalar(value)
                error("iam:IAMFrame:InvalidMetadataColumn", "Filtering requires scalar scenario metadata.")
            end
            matched(i) = matchMetadataColumn(value,filters.(requested),strict);
        end
    end
    selected = selected & ((override & localMatch) | (~override & matched));
end
keep = selected(group);
end

function names = sourceMetadataNames(runInfo)
names = string(runInfo.Properties.VariableNames);
names = names(~ismember(lower(names),["model","scenario","version","run_id","metadata"]));
if ismember("metadata",string(runInfo.Properties.VariableNames))
    fields = cell(height(runInfo),1);
    for i = 1:height(runInfo)
        payload = runInfo.metadata(i);
        if iscell(payload)
            payload = payload{1};
        end
        fields{i} = strings(0,1);
        if isstruct(payload) && isscalar(payload)
            fields{i} = string(fieldnames(payload));
        end
    end
    names = unique([names(:);vertcat(fields{:})],"stable")';
end
end

function value = sourceMetadataValue(row, name)
value = [];
flat = string(row.Properties.VariableNames);
flat = flat(~ismember(lower(flat),["model","scenario","version","run_id","metadata"]));
field = resolveMetadataName(name,flat);
if strlength(field) > 0
    value = row.(field);
    if iscell(value) && isscalar(value)
        value = value{1};
    end
end
if ismember("metadata",string(row.Properties.VariableNames))
    payload = row.metadata;
    if iscell(payload)
        payload = payload{1};
    end
    if isstruct(payload) && isscalar(payload)
        field = resolveMetadataName(name,string(fieldnames(payload)));
        if strlength(field) > 0
            value = mergeMetadataValues(value,payload.(field),"source metadata '" + name + "'");
        end
    end
end
end

function name = resolveMetadataName(requested, names)
requested = string(requested);
names = string(names);
match = strcmpi(names,requested) | ...
    strcmpi(matlab.lang.makeValidName(names),matlab.lang.makeValidName(requested)) | ...
    strcmpi(matlab.lang.makeValidName(regexprep(names,"\s+","_"),ReplacementStyle="underscore"), ...
    matlab.lang.makeValidName(regexprep(requested,"\s+","_"),ReplacementStyle="underscore"));
if nnz(match) > 1
    error("iam:IAMFrame:DuplicateMetadataName", "The metadata selector has ambiguous column aliases.")
end
name = "";
if any(match)
    name = names(match);
end
end

function keep = matchMetadataColumn(values, selector, strict)
if isnumeric(values) || islogical(values)
    if ~(isnumeric(selector) || islogical(selector)) || ~isreal(selector) || ...
            any(isinf(selector),"all")
        error("iam:IAMFrame:InvalidMetadataSelector", "Numeric metadata requires real numeric selectors.")
    end
    keep = ismember(double(values),double(selector));
    if any(isnan(selector),"all")
        keep = keep | isnan(values);
    end
elseif isstring(values)
    if ~(isstring(selector) || ischar(selector) || iscellstr(selector) || iscategorical(selector))
        error("iam:IAMFrame:InvalidMetadataSelector", "Text metadata requires text selectors.")
    end
    selector = string(selector);
    keep = false(size(values));
    if any(ismissing(selector),"all")
        keep = ismissing(values);
    end
    if any(selector == "","all")
        keep = keep | values == "";
    end
    nonempty = selector(~ismissing(selector) & strlength(selector) > 0);
    if ~isempty(nonempty)
        keep = keep | matchStringValues(values,nonempty,strict);
    end
else
    error("iam:IAMFrame:InvalidMetadataSelector", "Filtering supports numeric, logical, and text metadata.")
end
end

function [scope, selected] = validationScope(obj, filters)
names = string(fieldnames(filters));
coordinates = ismember(lower(names),["variables","regions","units","years"]);
scenarioFilters = rmfield(filters,cellstr(names(coordinates)));
args = namedargs2cell(scenarioFilters);
scope = obj.filter(args{:});
if nargout > 1
    args = namedargs2cell(filters);
    selected = scope.filter(args{:});
end
end

function keys = requirementKeys(keys, coordinates)
for name = coordinates(coordinates ~= "Year")
    keys.(name) = lower(keys.(name));
end
keys = identityComparisonTable(keys);
end

function summary = validationSummary(keys, group, checked, missing, violated)
summary = keys;
summary.CheckedCount = zeros(height(keys),1);
summary.MissingCount = zeros(height(keys),1);
summary.ViolationCount = zeros(height(keys),1);
if ~isempty(group)
    counts = groupsummary(table(group,checked,missing,violated),"group","sum", ...
        ["checked","missing","violated"]);
    summary.CheckedCount(counts.group) = counts.sum_checked;
    summary.MissingCount(counts.group) = counts.sum_missing;
    summary.ViolationCount(counts.group) = counts.sum_violated;
end
summary.Status = repmat("NotChecked",height(keys),1);
summary.Status(summary.CheckedCount > 0 & summary.MissingCount == 0) = "Passed";
summary.Status(summary.ViolationCount > 0) = "Failed";
end

function report = finishValidationReport(summary, violations, missing)
status = "NotChecked";
if any(summary.Status == "Failed")
    status = "Failed";
elseif ~isempty(summary) && all(summary.Status == "Passed")
    status = "Passed";
end
report = struct("Status",status,"CheckedCount",sum(summary.CheckedCount), ...
    "Scenarios",summary,"Violations",violations,"MissingRequirements",missing);
end

function out = recordExclusions(obj, summary)
annotations = summary(:,{'Model','Scenario','Version'});
annotations.Excluded = NaN(height(summary),1);
annotations.Excluded(summary.Status == "Passed") = 0;
annotations.Excluded(summary.Status == "Failed") = 1;
existing = obj.meta();
if ismember("Excluded",string(existing.Properties.VariableNames))
    [~, location] = ismember(identityComparisonTable(annotations(:,1:3)), ...
        identityComparisonTable(existing(:,1:3)),"rows");
    annotations.Excluded(existing.Excluded(location) == 1) = 1;
end
out = obj.setMeta(annotations);
end
