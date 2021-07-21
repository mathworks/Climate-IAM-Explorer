function plotMarketShare(ts, scenarioIdx, mainSectorIdx)
fig = figure;
tt = synchronize(ts(scenarioIdx & ~mainSectorIdx).Values);
ms = tt{:,:}./ts(scenarioIdx & mainSectorIdx).Values{:,1}*100;
bar(ts(scenarioIdx & mainSectorIdx).Values.Year, ms,'stacked');
legend(tt.Properties.VariableNames,'Location','eastoutside');
title('GCAM secondary energy by sector in the Scenario Immediate 2C with CDR')
fig.OuterPosition(3) = fig.OuterPosition(3)*2;
ylim([0 100])
end
