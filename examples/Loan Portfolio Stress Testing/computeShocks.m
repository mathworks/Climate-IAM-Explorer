function shocks = computeShocks(data, scenarioBase, scenarioTarget, totalVar, suBar)
base = synchronize(data([data.Variable] == totalVar).Values);
sector = synchronize(data([data.Variable] == suBar).Values);
% vars = data.Properties.VariableNames;
ms = sector{:,:}./base{:,:}*100;
% ms = data{data.Sector == suBar,4:6}./data{data.Sector == totalVar,4:6}*100;
ms = array2table(ms,'VariableNames', unique([data.Scenario]));
shocks = (ms.(scenarioTarget) - ms.(scenarioBase))./ms.(scenarioBase);
shocks = timetable(base.Year, shocks, 'VariableNames',{'Shock'});
end