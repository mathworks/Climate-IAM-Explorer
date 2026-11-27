function shocks = computeShocks(data, scenarioBase, scenarioTarget, totalVar, suBar)
if isa(data,"iam.IAMFrame")
    frame = data;
else
    frame = iam.IAMFrame(data);
end
shares = frame.share(suBar,totalVar,"Market Share");
change = shares.compareBaseline(scenarioTarget,scenarioBase, ...
    "Market Share","Market Share Shock",Operation="percentChange");
observations = change.toTable();
if isempty(observations)
    shocks = timetable(datetime.empty(0,1),zeros(0,1), ...
        DimensionNames=["Time","VariableUnits"],VariableNames="Shock");
    return
end
version = observations.Version;
version(isnan(version)) = -Inf;
trajectory = table(observations.Model,version,observations.Region, ...
    VariableNames=["Model","Version","Region"]);
if height(unique(trajectory,"rows")) ~= 1
    error("computeShocks:AmbiguousSelection", ...
        "Select one model, version, and region before calculating shocks.")
end
% The helper historically returns proportional changes rather than percent.
time = datetime(observations.Year,1,1,Format="yyyy");
shocks = timetable(time,observations.Value./100, ...
    DimensionNames=["Time","VariableUnits"],VariableNames="Shock");
end
