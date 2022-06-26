function [h, varNames] = plotMarketShare(ax, ts, scenarioIdx, mainSectorIdx)

tt = synchronize(ts(scenarioIdx & ~mainSectorIdx).Values);
ms = tt{:,:}./ts(scenarioIdx & mainSectorIdx).Values{:,1}*100;
h = bar(ts(scenarioIdx & mainSectorIdx).Values.Year, ms,'stacked', Parent = ax);
ylim([0 100])
varNames = tt.Properties.VariableNames;

end
