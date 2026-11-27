classdef tIAMMetadataValidation < matlab.unittest.TestCase
    methods (Test, TestTags="Unit")
        function testFilterReadsDownloadedMetadata(tc)
            frame = sourceFrame();
            selected = frame.filter(metadata=struct(Category="Low"),strict=true);
            tc.verifyEqual(selected.Scenarios,"A")
            tc.verifyEqual(height(selected.toTable()),2)
            tc.verifyEqual(selected.RunInfo.scenario,"A")
        end

        function testFilterReadsNumericSourceMetadata(tc)
            selected = sourceFrame().filter(metadata=struct(Target=1.5));
            tc.verifyEqual(selected.Scenarios,"A")
        end

        function testFilterReadsMissingSourceMetadata(tc)
            selected = sourceFrame().filter(metadata=struct(Category=string(missing)));
            tc.verifyEqual(selected.Scenarios,["C";"D"])
        end

        function testProviderMissingBooleanIsNotFalse(tc)
            data = exampleData();
            data = data(1:2,:);
            data.Scenario = ["A";"B"];
            data.RunId = [7;8];
            info = table(["M";"M"],["A";"B"],[NaN;NaN],[7;8], ...
                {struct('Reviewed',false,'Policy',"Known");struct()}, ...
                VariableNames=["model","scenario","version","run_id","metadata"]);
            conn = MockIAMConnection('Runs',info, ...
                'BulkDataResponse',iam.IAMFrame(data).toTimeseries(), ...
                'MetadataCategories',table(["Reviewed";"Policy"],["boolean value";"string value"], ...
                VariableNames=["name","type"]));
            env = iam.IAMEnvironment(conn);
            frame = env.getFrame(meta="all");
            reviewed = frame.filter(metadata=struct(Reviewed=false));
            unknown = frame.filter(metadata=struct(Reviewed=NaN));
            unknownPolicy = frame.filter(metadata=struct(Policy=string(missing)));
            tc.verifyEqual(frame.RunInfo.Reviewed,[0;NaN])
            tc.verifyEqual(reviewed.Scenarios,"A")
            tc.verifyEqual(unknown.Scenarios,"B")
            tc.verifyEqual(frame.RunInfo.Policy,["Known";string(missing)])
            tc.verifyEqual(unknownPolicy.Scenarios,"B")
            tc.verifyEqual(env.filterRuns(metadata=struct(Reviewed=false),strict=true),7)
            tc.verifyEqual(env.filterRuns(metadata=struct(Policy=string(missing)),strict=true),8)
        end

        function testLocalOverridesDoNotHideOtherSourceRows(tc)
            frame = sourceFrame().setMeta(table("M","A",NaN,"Custom", ...
                VariableNames=["Model","Scenario","Version","Category"]));
            local = frame.filter(metadata=struct(Category="Custom"),strict=true);
            original = frame.filter(metadata=struct(Category="High"),strict=true);
            tc.verifyEqual(local.Scenarios,"A")
            tc.verifyEqual(original.Scenarios,"B")
            tc.verifyEqual(frame.RunInfo.metadata{1}.Category,"Low")
        end

        function testLocalLabelsAndUnknownFlagsStayNative(tc)
            frame = iam.IAMFrame(exampleData());
            annotations = table(["M";"M"],["A";"B"],[0;NaN],["Low";"High"], ...
                VariableNames=["Model","Scenario","Excluded","Policy category"]);
            tagged = frame.setMeta(annotations);
            selected = tagged.filter(metadata=struct(Policy_category="Low"),strict=true);
            allowed = tagged.filter(metadata=struct(Excluded=false));
            unknown = tagged.filter(metadata=struct(Excluded=NaN));
            tc.verifyEqual(tagged.meta().("Policy category")(1),"Low")
            tc.verifyEqual(selected.Scenarios,"A")
            tc.verifyEqual(allowed.Scenarios,"A")
            tc.verifyEqual(unknown.Scenarios,["B";"C";"D"])
            tc.verifyEqual(tagged.toTable(),frame.toTable())
            tc.verifyFalse(isprop(tagged,"MetadataNames"))
        end

        function testExplicitMissingClearsOnlySuppliedAnnotations(tc)
            frame = iam.IAMFrame(exampleData()).setMeta(table( ...
                ["M";"M"],["A";"B"],[1;0], ...
                VariableNames=["Model","Scenario","Reviewed"]));
            changed = frame.setMeta(table("M","A",NaN, ...
                VariableNames=["Model","Scenario","Reviewed"]));
            tc.verifyTrue(isnan(changed.meta().Reviewed(1)))
            tc.verifyEqual(changed.meta().Reviewed(2),0)
            tc.verifyEqual(frame.meta().Reviewed(1),1)
        end

        function testAnnotationsStayWithTheirVersion(tc)
            data = exampleData();
            data = data(1:2,:);
            data.Year(:) = 2020;
            data.Version = [1;2];
            frame = iam.IAMFrame(data).setMeta(table("M","A",1,"Chosen", ...
                VariableNames=["Model","Scenario","Version","Tag"]));
            selected = frame.filter(metadata=struct(Tag="Chosen"),strict=true);
            tc.verifyEqual(selected.toTable().Version,1)
            tc.verifyEqual(selected.meta().Version,1)
        end

        function testRejectsUnknownAnnotationIdentity(tc)
            frame = iam.IAMFrame(exampleData());
            tc.verifyError(@() frame.setMeta(table("M","Unknown",true, ...
                VariableNames=["Model","Scenario","Tag"])), ...
                "iam:IAMFrame:UnknownMetadataIdentity")
        end

        function testRejectsAnnotationArrayWithoutReshaping(tc)
            frame = iam.IAMFrame(exampleData());
            tc.verifyError(@() frame.setMeta(table("M","A",[1 2], ...
                VariableNames=["Model","Scenario","Score"])), ...
                "iam:IAMFrame:InvalidNumericColumn")
        end

        function testAppendKeepsAnnotations(tc)
            frame = iam.IAMFrame(exampleData());
            left = frame.filter(scenarios="A",strict=true).setMeta(table( ...
                "M","A","One",VariableNames=["Model","Scenario","Tag"]));
            right = frame.filter(scenarios="B",strict=true).setMeta(table( ...
                "M","B",2,VariableNames=["Model","Scenario","Score"]));
            merged = left.append(right);
            tc.verifyEqual(merged.meta().Tag(1),"One")
            tc.verifyEqual(merged.meta().Score(2),2)
            tc.verifyTrue(ismissing(merged.meta().Tag(2)))
            tc.verifyTrue(isnan(merged.meta().Score(1)))
        end

        function testAppendRejectsConflictingAnnotations(tc)
            frame = iam.IAMFrame(exampleData()).filter(scenarios="A",strict=true);
            left = frame.filter(years=2010).setMeta(table("M","A","One", ...
                VariableNames=["Model","Scenario","Tag"]));
            right = frame.filter(years=2020).setMeta(table("M","A","Two", ...
                VariableNames=["Model","Scenario","Tag"]));
            tc.verifyError(@() left.append(right),"iam:IAMFrame:IncompatibleRunInfo")
        end

        function testSourceConflictsRequireAnExplicitOverride(tc)
            info = table(["M";"M"],["A";"A"],[NaN;NaN],[7;8], ...
                {struct('Category',"Low");struct('Category',"High")}, ...
                VariableNames=["model","scenario","version","run_id","metadata"]);
            frame = iam.IAMFrame(exampleData(),RunInfo=info);
            tc.verifyError(@() frame.filter(metadata=struct(Category="Low")), ...
                "iam:IAMFrame:IncompatibleRunInfo")
            overridden = frame.setMeta(table("M","A","Chosen", ...
                VariableNames=["Model","Scenario","Category"]));
            selected = overridden.filter(metadata=struct(Category="Chosen"),strict=true);
            tc.verifyEqual(selected.Scenarios,"A")
            tc.verifyEqual(height(selected.RunInfo),2)
        end

        function testMultipleFiltersPreserveLocalOverrides(tc)
            info = table(["M";"M"],["A";"A"],[NaN;NaN],[7;8], ...
                {struct(Category="Low",Target=1.5);struct(Category="High",Target=1.5)}, ...
                VariableNames=["model","scenario","version","run_id","metadata"]);
            frame = iam.IAMFrame(exampleData(),RunInfo=info).setMeta( ...
                table("M","A","Chosen",VariableNames=["Model","Scenario","Category"]));

            selected = frame.filter(metadata=struct(Category="Chosen",Target=1.5),strict=true);
            reversed = frame.filter(metadata=struct(Target=1.5,Category="Chosen"),strict=true);

            tc.verifyEqual(selected.Scenarios,"A")
            tc.verifyEqual(reversed.toTable(),selected.toTable())
            tc.verifyEqual(height(selected.RunInfo),2)
        end

        function testExcludedAnnotationsMustBeFlags(tc)
            frame = iam.IAMFrame(exampleData());
            tc.verifyError(@() frame.setMeta(table("M","A",2, ...
                VariableNames=["Model","Scenario","Excluded"])), ...
                "iam:IAMFrame:InvalidMetadataColumn")
        end

        function testUnknownSourceRowsStillRejectMalformedSelectors(tc)
            frame = sourceFrame().filter(scenarios="C",strict=true);
            tc.verifyError(@() frame.filter(metadata=struct(Target=Inf)), ...
                "iam:IAMFrame:InvalidMetadataSelector")
        end

        function testCompletenessReportsMissingValuesAndYears(tc)
            report = iam.IAMFrame(exampleData()).requireData( ...
                variables="Energy",years=[2010 2020]);
            tc.verifyEqual(report.Status,"Failed")
            tc.verifyEqual(report.CheckedCount,6)
            tc.verifyEqual(report.Scenarios.Status,["Passed";"Passed";"Failed";"Failed"])
            tc.verifyEqual(report.Scenarios.MissingCount,[0;0;1;1])
            tc.verifyEqual(report.MissingRequirements.Scenario,["C";"D"])
            tc.verifyEqual(report.MissingRequirements.Year,[2020;2020])
            tc.verifyTrue(all(ismissing(report.MissingRequirements.Unit)))
        end

        function testCompletenessChecksCartesianCombinations(tc)
            report = iam.IAMFrame(exampleData()).requireData( ...
                variables=["Energy","Other"],regions="World",years=[2010 2020]);
            tc.verifyEqual(report.Scenarios.MissingCount,[2;2;3;3])
            tc.verifyEqual(height(report.MissingRequirements),10)
        end

        function testCompletenessCanBeScopedByMetadata(tc)
            report = sourceFrame().requireData(variables="Energy",years=[2010 2020], ...
                Filter=struct(metadata=struct(Category="Low"),strict=true));
            tc.verifyEqual(report.Status,"Passed")
            tc.verifyEqual(report.Scenarios.Scenario,"A")
            tc.verifyEmpty(report.MissingRequirements)
        end

        function testCompletenessRejectsEmptyRequirements(tc)
            frame = iam.IAMFrame(exampleData());
            tc.verifyError(@() frame.requireData(),"iam:IAMFrame:InvalidRequirements")
        end

        function testCompletenessRejectsWildcardRequirements(tc)
            frame = iam.IAMFrame(exampleData());
            tc.verifyError(@() frame.requireData(variables="Energy*"), ...
                "iam:IAMFrame:InvalidRequirements")
        end

        function testCompletenessCanRequireUnknownUnits(tc)
            data = exampleData();
            data = data(1,:);
            data.Unit = "";
            report = iam.IAMFrame(data).requireData(units="",years=2010);
            tc.verifyEqual(report.Status,"Passed")
            tc.verifyEqual(report.CheckedCount,1)
        end

        function testBoundsDistinguishFailuresAndMissingEvidence(tc)
            report = iam.IAMFrame(exampleData()).validate(LowerBound=0,UpperBound=10);
            tc.verifyEqual(report.Status,"Failed")
            tc.verifyEqual(report.CheckedCount,6)
            tc.verifyEqual(report.Scenarios.Status,["Passed";"Failed";"NotChecked";"Passed"])
            tc.verifyEqual(report.Violations.Scenario,"B")
            tc.verifyEqual(report.Violations.Value,12)
            tc.verifyEqual(report.MissingRequirements.Scenario,"C")
        end

        function testBoundsAreInclusiveAndZeroIsObserved(tc)
            report = iam.IAMFrame(exampleData()).validate(LowerBound=0,UpperBound=5, ...
                Filter=struct(scenarios="A",strict=true));
            tc.verifyEqual(report.Status,"Passed")
            tc.verifyEqual(report.CheckedCount,2)
            tc.verifyEmpty(report.Violations)
        end

        function testCoordinateFilterRetainsUncheckedScenarios(tc)
            report = iam.IAMFrame(exampleData()).validate(UpperBound=10, ...
                Filter=struct(years=2020));
            tc.verifyEqual(report.Status,"NotChecked")
            tc.verifyEqual(report.Scenarios.Status,["Passed";"Passed";"NotChecked";"NotChecked"])
            tc.verifyEqual(report.CheckedCount,2)
        end

        function testMetadataScopeRetainsUncheckedCoordinates(tc)
            frame = sourceFrame();

            report = frame.validate(Filter=struct(metadata= ...
                struct(Category="Low",Target=1.5),years=1970,strict=true));

            tc.verifyEqual(report.Status,"NotChecked")
            tc.verifyEqual(report.Scenarios.Scenario,"A")
            tc.verifyEqual(report.Scenarios.Status,"NotChecked")
            tc.verifyEqual(report.CheckedCount,0)
        end

        function testUnmatchedEvidenceNeverPasses(tc)
            report = iam.IAMFrame(exampleData()).validate( ...
                Filter=struct(variables="Absent",strict=true));
            tc.verifyEqual(report.Status,"NotChecked")
            tc.verifyEqual(report.CheckedCount,0)
            tc.verifyEqual(report.Scenarios.Status,repmat("NotChecked",4,1))
        end

        function testEmptyScopeHasStableReportSchema(tc)
            frame = iam.IAMFrame(exampleData());
            bounds = frame.validate(Filter=struct(models="Absent",strict=true));
            required = frame.requireData(years=2020,Filter=struct(models="Absent",strict=true));
            tc.verifyEqual(bounds.Status,"NotChecked")
            tc.verifyEqual(required.Status,"NotChecked")
            tc.verifyEmpty(bounds.Scenarios)
            tc.verifyEmpty(required.Scenarios)
            tc.verifyEqual(bounds.MissingRequirements.Properties.VariableNames, ...
                required.MissingRequirements.Properties.VariableNames)
        end

        function testEmptyFrameNeverPasses(tc)
            frame = iam.IAMFrame();
            bounds = frame.validate();
            required = frame.requireData(years=2020);
            [tagged, classification] = frame.categorize("Quality","Accepted");
            tc.verifyEqual(bounds.Status,"NotChecked")
            tc.verifyEqual(required.Status,"NotChecked")
            tc.verifyEqual(classification.Status,"NotChecked")
            tc.verifyEmpty(tagged.meta())
        end

        function testAllMissingEvidenceIsNotZero(tc)
            frame = iam.IAMFrame(exampleData());
            report = frame.validate(Filter=struct(scenarios="C",years=2020,strict=true));
            tc.verifyEqual(report.Status,"NotChecked")
            tc.verifyEqual(report.CheckedCount,0)
            tc.verifyEqual(report.Scenarios.MissingCount,1)
        end

        function testBoundsRejectMalformedIntervals(tc)
            frame = iam.IAMFrame(exampleData());
            tc.verifyError(@() frame.validate(LowerBound=NaN),"iam:IAMFrame:InvalidBounds")
            tc.verifyError(@() frame.validate(LowerBound=10,UpperBound=0), ...
                "iam:IAMFrame:InvalidBounds")
        end

        function testExplicitExclusionsPreserveInputAndUnknownState(tc)
            frame = iam.IAMFrame(exampleData());
            [report, changed] = frame.validate(LowerBound=0,UpperBound=10,ExcludeOnFail=true);
            tc.verifyEqual(report.Status,"Failed")
            tc.verifyEqual(changed.meta().Excluded,[0;1;NaN;0])
            tc.verifyEqual(changed.toTable(),frame.toTable())
            tc.verifyFalse(ismember("Excluded",string(frame.meta().Properties.VariableNames)))
        end

        function testCompletenessCanMarkFailuresWithoutDeletingData(tc)
            frame = iam.IAMFrame(exampleData());
            [~, changed] = frame.requireData(years=[2010 2020],ExcludeOnFail=true);
            tc.verifyEqual(changed.meta().Excluded,[0;0;1;1])
            tc.verifyEqual(changed.toTable(),frame.toTable())
        end

        function testLaterChecksDoNotClearEarlierExclusions(tc)
            frame = iam.IAMFrame(exampleData());
            [~, coverage] = frame.requireData(years=[2010 2020],ExcludeOnFail=true);
            [~, bounded] = coverage.validate(LowerBound=0,UpperBound=10,ExcludeOnFail=true);
            tc.verifyEqual(bounded.meta().Excluded,[0;1;1;1])
            tc.verifyEqual(coverage.meta().Excluded,[0;0;1;1])
        end

        function testCategorizationRequiresCompleteCheckedEvidence(tc)
            frame = iam.IAMFrame(exampleData());
            [tagged, report] = frame.categorize("Quality","Accepted",LowerBound=0,UpperBound=10);
            tc.verifyEqual(report.Status,"Failed")
            tc.verifyEqual(tagged.meta().Quality([1;4]),["Accepted";"Accepted"])
            tc.verifyTrue(all(ismissing(tagged.meta().Quality([2;3]))))
            tc.verifyEqual(tagged.toTable(),frame.toTable())
        end

        function testUnmatchedCategorizationDoesNotLabelEveryScenario(tc)
            frame = iam.IAMFrame(exampleData());
            [tagged, report] = frame.categorize("Quality","Accepted", ...
                Filter=struct(variables="Absent",strict=true));
            tc.verifyEqual(report.Status,"NotChecked")
            tc.verifyTrue(all(ismissing(tagged.meta().Quality)))
        end

        function testRecategorizationClearsStaleScopedLabels(tc)
            frame = iam.IAMFrame(exampleData()).setMeta(table("M","B","Accepted", ...
                VariableNames=["Model","Scenario","Quality"]));
            tagged = frame.categorize("Quality","Accepted",UpperBound=10);
            tc.verifyTrue(ismissing(tagged.meta().Quality(2)))
            tc.verifyEqual(frame.meta().Quality(2),"Accepted")
        end

        function testCategorizationCannotShadowProviderLabels(tc)
            frame = sourceFrame();
            tc.verifyError(@() frame.categorize("Category","Accepted",UpperBound=10), ...
                "iam:IAMFrame:ReservedMetadataName")
        end

        function testCategorizationPreservesOutOfScopeLabels(tc)
            frame = iam.IAMFrame(exampleData()).setMeta(table("M","B","Keep", ...
                VariableNames=["Model","Scenario","Quality"]));
            tagged = frame.categorize("Quality","Accepted",UpperBound=10, ...
                Filter=struct(scenarios="A",strict=true));
            tc.verifyEqual(tagged.meta().Quality(1),"Accepted")
            tc.verifyEqual(tagged.meta().Quality(2),"Keep")
        end

        function testUnknownUnitFilterIsNotAnUnrestrictedQuery(tc)
            data = exampleData();
            data = data(1:2,:);
            data.Unit = ["";"EJ/yr"];
            data.Value = [0;100];
            report = iam.IAMFrame(data).validate(UpperBound=10,Filter=struct(units=""));
            tc.verifyEqual(report.Status,"Passed")
            tc.verifyEqual(report.CheckedCount,1)
        end
    end
end

function data = exampleData()
data = table(repmat("M",7,1),["A";"A";"B";"B";"C";"C";"D"], ...
    repmat("Energy",7,1),repmat("World",7,1),repmat("EJ/yr",7,1), ...
    [2010;2020;2010;2020;2010;2020;2010],[0;5;12;6;1;NaN;2], ...
    VariableNames=["Model","Scenario","Variable","Region","Unit","Year","Value"]);
end

function frame = sourceFrame()
info = table(["M";"M"],["A";"B"],[NaN;NaN],[7;8], ...
    {struct('Category',"Low",'Target',1.5);struct('Category',"High",'Target',2)}, ...
    VariableNames=["model","scenario","version","run_id","metadata"]);
frame = iam.IAMFrame(exampleData(),RunInfo=info);
end
