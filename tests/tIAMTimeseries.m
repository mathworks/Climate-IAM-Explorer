classdef tIAMTimeseries < matlab.unittest.TestCase
    properties (TestParameter)
        SparseOperation = struct( ...
            'add',struct('Function',@plus,'Middle',5), ...
            'subtract',struct('Function',@minus,'Middle',-1), ...
            'multiply',struct('Function',@times,'Middle',6), ...
            'divide',struct('Function',@rdivide,'Middle',2/3))
        InvalidArithmeticMetadata = struct( ...
            'emptyModel',struct('Field',"model",'Value',"",'Error',"iam:IAMFrame:MissingIdentity"), ...
            'infiniteVersion',struct('Field',"version",'Value',Inf,'Error',"iam:IAMFrame:InvalidNumericColumn"), ...
            'infiniteRunId',struct('Field',"runId",'Value',Inf,'Error',"iam:IAMFrame:InvalidNumericColumn"))
    end

    methods (Test, TestTags = {'Unit'})
        function testNoArgConstructorReturnsScalarDefault(tc)
            tc.verifyError(@() iam.IAMTimeseries(), 'MATLAB:minrhs')
        end

        function testExplicitEmptyMatrixReturnsEmptyObject(tc)
            ts = iam.IAMTimeseries([]);

            tc.verifyClass(ts, 'iam.IAMTimeseries')
            tc.verifyEmpty(ts)
            tc.verifySize(ts, [0 0])
        end

        function testExplicitEmptyStructReturnsEmptyObject(tc)
            ts = iam.IAMTimeseries(struct.empty());

            tc.verifyClass(ts, 'iam.IAMTimeseries')
            tc.verifyEmpty(ts)
            tc.verifySize(ts, [0 0])
        end

        function testNonEmptyStructBuildsTimeseries(tc)
            dates = datetime([2020; 2030], 1, 1, 'Format', 'yyyy');
            input = struct( ...
                'model', "Model A", ...
                'scenario', "Scenario A", ...
                'variable', "Primary Energy", ...
                'region', "World", ...
                'unit', "EJ/yr", ...
                'runId', 101, ...
                'version', 1, ...
                'years', year(dates), ...
                'values', timetable(dates, [1; 2], ...
                    'DimensionNames', {'Year', 'VariableUnits'}, ...
                    'VariableNames', {'Values'}));

            ts = iam.IAMTimeseries(input);

            tc.verifySize(ts, [1 1])
            tc.verifyEqual(ts.Model, "Model A")
            tc.verifyEqual(ts.Years, [2020; 2030])
            tc.verifyEqual(ts.Values{:,:}, [1; 2])
        end

        function testArithmeticStillWorksWithInternalGenericConstruction(tc)
            dates = datetime([2020; 2030], 1, 1, 'Format', 'yyyy');
            input = struct( ...
                'model', "Model A", ...
                'scenario', "Scenario A", ...
                'variable', "Primary Energy", ...
                'region', "World", ...
                'unit', "EJ/yr", ...
                'runId', 101, ...
                'version', 1, ...
                'years', year(dates), ...
                'values', timetable(dates, [1; 2], ...
                    'DimensionNames', {'Year', 'VariableUnits'}, ...
                    'VariableNames', {'Values'}));

            ts = iam.IAMTimeseries(input);
            out = ts + ts;

            tc.verifySize(out, [1 1])
            tc.verifyEqual(out.Values{:,:}, [2; 4])
            tc.verifyEqual(out.Model, "Model A")
            tc.verifyEqual(out.Scenario, "Scenario A")
            tc.verifyEqual(out.Variable, "Primary Energy + Primary Energy")
            tc.verifyEqual(out.Unit, "EJ/yr")
        end

        function testArithmeticMatchesSeriesByIdentityWhenReordered(tc)
            left = [testSeries("Scenario A","Energy",101,[1;2]), ...
                testSeries("Scenario B","Energy",202,[10;20])];
            right = [testSeries("Scenario B","Energy",202,[1;3]), ...
                testSeries("Scenario A","Energy",101,[4;5])];

            result = left + right;

            tc.verifyEqual([result.Scenario]',["Scenario A";"Scenario B"])
            tc.verifyEqual(result(1).Values{:,:},[5;7])
            tc.verifyEqual(result(2).Values{:,:},[11;23])
        end

        function testArithmeticRejectsDifferentScenarioIdentities(tc)
            left = testSeries("Scenario A","Energy",101,[1;2]);
            right = testSeries("Scenario B","Energy",202,[4;5]);

            tc.verifyError(@() left + right, ...
                "iam:IAMTimeseries:IncompatibleOperands")
        end

        function testNamedShareWrapperDelegatesToFrameCalculation(tc)
            series = [testSeries("Scenario A","Numerator",101,[2;4]), ...
                testSeries("Scenario A","Denominator",101,[4;8])];

            [share,report] = series.share("Numerator","Denominator","Share");

            tc.verifyEqual(share.Variable,"Share")
            tc.verifyEqual(share.Unit,"fraction")
            tc.verifyEqual(share.Values{:,:},[0.5;0.5],AbsTol=1e-12)
            tc.verifyEqual(report.ComputedCount,2)
        end

        function testArithmeticRejectsInvalidMetadata(tc, InvalidArithmeticMetadata)
            [valid,input] = testSeries("Scenario A","Energy",7,[1;2]);
            input.(InvalidArithmeticMetadata.Field) = InvalidArithmeticMetadata.Value;
            invalid = iam.IAMTimeseries(input);
            tc.verifyError(@() invalid + valid,InvalidArithmeticMetadata.Error)
            tc.verifyError(@() valid + invalid,InvalidArithmeticMetadata.Error)
        end

        function testArithmeticRejectsMatrixColumns(tc)
            [valid,input] = testSeries("Scenario A","Energy",7,[1;2]);
            input.values.Values = [1 10;2 20];
            invalid = iam.IAMTimeseries(input);
            tc.verifyError(@() invalid + valid,"iam:IAMFrame:InvalidNumericColumn")
            tc.verifyError(@() valid + invalid,"iam:IAMFrame:InvalidNumericColumn")
        end

        function testArithmeticRejectsMismatchedYearLengths(tc)
            [valid,input] = testSeries("Scenario A","Energy",7,[1;2]);
            input.values = input.values(1,:);
            invalid = iam.IAMTimeseries(input);
            tc.verifyError(@() invalid + valid,"iam:IAMFrame:InvalidTimeseriesLength")
            tc.verifyError(@() valid + invalid,"iam:IAMFrame:InvalidTimeseriesLength")
        end

        function testArithmeticRejectsInconsistentDates(tc)
            [valid,input] = testSeries("Scenario A","Energy",7,[1;2]);
            input.values.Year = input.values.Year + calyears(1);
            invalid = iam.IAMTimeseries(input);
            tc.verifyError(@() invalid + valid,"iam:IAMFrame:InvalidTimeseriesTime")
            tc.verifyError(@() valid + invalid,"iam:IAMFrame:InvalidTimeseriesTime")
        end

        function testArithmeticRejectsMissingUnits(tc)
            [valid,input] = testSeries("Scenario A","Energy",7,[1;2]);
            input.unit = string(missing);
            invalid = iam.IAMTimeseries(input);
            tc.verifyError(@() invalid + valid,"iam:IAMTimeseries:UnknownUnit")
            tc.verifyError(@() valid + invalid,"iam:IAMTimeseries:UnknownUnit")
        end

        function testNamedSeriesCalculationRetainsBothSources(tc)
            series = [testSeries("Scenario A","A",7,[1;2]), ...
                testSeries("Scenario A","B",8,[2;4])];
            result = series.share("A","B","Share").toFrame();
            tc.verifyEqual(sort(result.RunInfo.run_id),[7;8])
            tc.verifyEqual(unique(result.Provenance.SourceRunId),[7;8])
        end

        function testSeriesOperatorsRetainDifferentSourceRecords(tc)
            left = testSeries("Scenario A","Energy",7,[1;2]);
            right = testSeries("Scenario A","Energy",8,[3;4]);
            combined = left + right;
            result = combined.toFrame();
            tc.verifyEqual(result.toTable().Value,[4;6])
            tc.verifyEqual(sort(result.RunInfo.run_id),[7;8])
            tc.verifyEqual(unique(result.Provenance.SourceVariable),"Energy")
        end

        function testArgumentsRejectMixedOperands(tc)
            series = testSeries("Scenario A","Energy",7,[1;2]);
            tc.verifyError(@() series + 1,"MATLAB:validators:mustBeA")
            tc.verifyError(@() 1 + series,"MATLAB:validators:mustBeA")
        end

        function testArgumentsRejectEmptyOperands(tc)
            series = testSeries("Scenario A","Energy",7,[1;2]);
            empty = series([]);
            tc.verifyError(@() empty + series,"MATLAB:validators:mustBeNonempty")
            tc.verifyError(@() series + empty,"MATLAB:validators:mustBeNonempty")
        end

        function testArgumentsRejectDifferentSeriesCounts(tc)
            series = testSeries("Scenario A","Energy",7,[1;2]);
            tc.verifyError(@() series + [series,series], ...
                "iam:IAMTimeseries:IncompatibleOperands")
        end

        function testSynchronizeAlignsSparseYears(tc,SparseOperation)
            left = testSeries("Scenario A","Energy",7,[1;2]);
            [~,input] = testSeries("Scenario A","Energy",8,[3;4]);
            input.years = [2030;2040];
            input.values.Year = datetime(input.years,1,1);
            right = iam.IAMTimeseries(input);
            result = SparseOperation.Function(left,right);
            tc.verifyEqual(result.Years,[2020;2030;2040])
            tc.verifyEqual(result.Values.Values,[NaN;SparseOperation.Middle;NaN],AbsTol=1e-12)
            tc.verifyEqual(unique(result.Provenance.SourceRunId),[7;8])
        end

        function testDivisionPropagatesMissingValuesAndMasksZero(tc)
            left = testSeries("Scenario A","Energy",7,[2;NaN]);
            right = testSeries("Scenario A","Energy",8,[0;3]);
            result = left./right;
            tc.verifyEqual(result.Values.Values,[NaN;NaN])
        end

        function testDivisionStillReportsOverflow(tc)
            left = testSeries("Scenario A","Energy",7,[realmax;1]);
            right = testSeries("Scenario A","Energy",8,[realmin;2]);
            tc.verifyError(@() left./right,"iam:IAMTimeseries:CalculationOverflow")
        end

        function testArithmeticStillChecksMatchedUnits(tc)
            left = testSeries("Scenario A","Energy",7,[1;2]);
            [~,input] = testSeries("Scenario A","Energy",8,[3;4]);
            input.unit = "PJ/yr";
            right = iam.IAMTimeseries(input);
            tc.verifyError(@() left + right,"iam:IAMTimeseries:IncompatibleUnits")
        end

        function testLegendRunIdsUseNumericText(tc)
            left = testSeries("Shared scenario","Energy",101,[1;2]);
            right = testSeries("Shared scenario","Energy",202,[3;4]);
            series = [left,right];

            tc.verifyEqual(series.legendLabels(), ["I = 101","I = 202"])
        end

        function testLegendFallbackForSingleSeries(tc)
            series = testSeries("Shared scenario","Energy",101,[1;2]);

            tc.verifyEqual(series.legendLabels(), "Region = World")
        end

        function testLegendLabelsEmptyArray(tc)
            series = iam.IAMTimeseries.empty();

            tc.verifyEmpty(series.legendLabels())
        end
    end
end

function [series,data] = testSeries(scenario,variable,runId,values)
dates = datetime([2020;2030],1,1,Format="yyyy");
data = struct("model","Model A","scenario",scenario, ...
    "variable",variable,"region","World","unit","EJ/yr", ...
    "runId",runId,"version",1,"years",year(dates), ...
    "values",timetable(dates,values, ...
    DimensionNames=["Year","VariableUnits"],VariableNames="Values"));
series = iam.IAMTimeseries(data);
end
