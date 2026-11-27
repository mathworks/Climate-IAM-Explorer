(function () {
  "use strict";

  const NS = "http://www.w3.org/2000/svg";
  const theme = getComputedStyle(document.documentElement);
  const COLORS = ["--color-accent", "--color-amber", "--color-blue", "--color-plum",
    "--color-rose", "--color-teal", "--color-olive", "--color-indigo"].map(function (token) {
    return theme.getPropertyValue(token).trim();
  });
  const MARGIN = { left: 58, right: 18, top: 14, bottom: 44 };
  let currentSeries = [];
  let chartType = "line";

  function setup(htmlComponent) {
    const selector = document.getElementById("chart-type");
    selector.addEventListener("change", function () {
      chartType = selector.value;
      safelyDrawChart();
    });
    chartType = selector.value;

    htmlComponent.addEventListener("DataChanged", function () {
      try {
        render(htmlComponent.Data || {});
      } catch (error) {
        showError(error.message);
      }
    });
    htmlComponent.addEventListener("error", function (event) {
      const data = event.Data || {};
      showError(data.message || data || "MATLAB reported an error");
    });

    const viewport = document.getElementById("chart-viewport");
    if (window.ResizeObserver) {
      const observer = new ResizeObserver(safelyDrawChart);
      observer.observe(viewport);
    } else {
      window.addEventListener("resize", safelyDrawChart);
    }

    if (htmlComponent.Data) render(htmlComponent.Data);
  }

  function render(data) {
    document.body.classList.toggle("hide-preview-header", data.HeaderVisible === false);
    currentSeries = normalizeSeries(data.Series);
    document.getElementById("chart-title").textContent = displayVariable(data.Title || "Select a result");
    document.getElementById("chart-unit").textContent = String(data.Unit || "Choose a row from the catalogue");
    document.getElementById("series-count").textContent = currentSeries.length
      ? currentSeries.length + " series"
      : "";
    document.getElementById("chart-note").textContent = String(data.Note || "");
    document.getElementById("chart-note").style.color = "";
    renderLegend(currentSeries);
    drawChart();
  }

  function normalizeSeries(value) {
    if (!value) return [];
    const values = Array.isArray(value) ? value : [value];
    return values.filter(Boolean).map(function (item) {
      const years = Array.isArray(item.Years) ? item.Years : [item.Years];
      const observations = Array.isArray(item.Values) ? item.Values : [item.Values];
      return {
        label: String(item.Label || "Series"),
        fullLabel: String(item.FullLabel || item.Label || "Series"),
        variable: String(item.Variable || ""),
        unit: String(item.Unit || ""),
        years: years.map(Number),
        values: observations.map(function (entry) { return entry == null ? NaN : Number(entry); })
      };
    }).filter(function (item) {
      return item.years.length > 0 && item.years.length === item.values.length && item.years.every(Number.isFinite);
    });
  }

  function displayVariable(value) {
    return String(value).split("|").join(" · ");
  }

  function renderLegend(series) {
    const host = document.getElementById("chart-legend");
    host.replaceChildren();
    series.forEach(function (item, index) {
      const entry = document.createElement("div");
      entry.className = "legend-item";
      entry.title = item.fullLabel;
      const swatch = document.createElement("span");
      swatch.className = "legend-swatch";
      swatch.style.backgroundColor = COLORS[index % COLORS.length];
      const label = document.createElement("span");
      label.className = "legend-label";
      label.textContent = item.label;
      label.title = item.fullLabel;
      entry.append(swatch, label);
      host.append(entry);
    });
  }

  function drawChart() {
    const selector = document.getElementById("chart-type");
    if (selector) chartType = selector.value;
    if (currentSeries.length === 0) {
      renderEmptyChart();
      return;
    }
    renderSvg(currentSeries, chartType);
  }

  function safelyDrawChart() {
    try {
      drawChart();
    } catch (error) {
      showError(error && error.message ? error.message : error);
    }
  }

  function renderEmptyChart() {
    const svg = document.getElementById("chart-svg");
    const size = getSize(svg);
    svg.setAttribute("viewBox", "0 0 " + size.width + " " + size.height);
    svg.replaceChildren();
    svg.setAttribute("aria-label", "No series selected");
    addSvgText(svg, size.width / 2, size.height / 2 - 7, "empty-chart-label", "Choose a result to preview", "middle");
    addSvgText(svg, size.width / 2, size.height / 2 + 17, "empty-chart-hint", "Selected series will appear here", "middle");
  }

  function renderSvg(series, type) {
    const svg = document.getElementById("chart-svg");
    const size = getSize(svg);
    const plot = {
      left: MARGIN.left,
      right: size.width - MARGIN.right,
      top: MARGIN.top,
      bottom: size.height - MARGIN.bottom
    };
    const years = series[0].years;
    const minYear = Math.min.apply(null, years);
    const maxYear = Math.max.apply(null, years);
    svg.setAttribute("viewBox", "0 0 " + size.width + " " + size.height);
    svg.replaceChildren();

    const domain = valueDomain(series, type);
    const yAt = function (value) {
      return plot.bottom - (value - domain.min) / (domain.max - domain.min) * (plot.bottom - plot.top);
    };
    const xAt = function (index) {
      if (type === "line") {
        const yearSpan = maxYear - minYear;
        const fraction = yearSpan === 0 ? 0.5 : (years[index] - minYear) / yearSpan;
        return plot.left + fraction * (plot.right - plot.left);
      }
      return plot.left + (index + 0.5) / years.length * (plot.right - plot.left);
    };

    drawAxes(svg, plot, size.height, years, domain, xAt, yAt);
    if (type === "line") drawLines(svg, series, years, plot, xAt, yAt);
    else drawBars(svg, series, years, type, plot, xAt, yAt);
    svg.setAttribute("aria-label", displayVariable(series[0].variable) + ", " + series.length + " plotted series");
  }

  function getSize(svg) {
    const rect = svg.getBoundingClientRect();
    return {
      width: Math.max(320, Math.round(rect.width)),
      height: Math.max(260, Math.round(rect.height))
    };
  }

  function valueDomain(series, type) {
    let min = 0;
    let max = 0;
    if (type === "bar stacked") {
      const length = series[0].values.length;
      for (let i = 0; i < length; i += 1) {
        let positive = 0;
        let negative = 0;
        series.forEach(function (line) {
          const value = Number(line.values[i]);
          if (!Number.isFinite(value)) return;
          if (value >= 0) positive += value;
          else negative += value;
        });
        max = Math.max(max, positive);
        min = Math.min(min, negative);
      }
    } else {
      const values = series.flatMap(function (line) {
        return line.values.map(Number).filter(Number.isFinite);
      });
      min = values.length ? Math.min.apply(null, values) : 0;
      max = values.length ? Math.max.apply(null, values) : 0;
      if (type !== "line") {
        min = Math.min(0, min);
        max = Math.max(0, max);
      }
    }

    let span = max - min;
    if (!Number.isFinite(span) || span === 0) span = Math.max(Math.abs(max), 1);
    const padding = type === "line" ? span * 0.1 : span * 0.05;
    min -= padding;
    max += padding;
    if (type !== "line" && min > 0) min = 0;
    if (type !== "line" && max < 0) max = 0;
    return { min: min, max: max };
  }

  function drawAxes(svg, plot, height, years, domain, xAt, yAt) {
    for (let tick = 0; tick <= 4; tick += 1) {
      const value = domain.min + (domain.max - domain.min) * tick / 4;
      const y = yAt(value);
      addSvgLine(svg, plot.left, y, plot.right, y, "chart-gridline");
      addSvgText(svg, plot.left - 9, y + 4, "chart-axis-label", formatAxis(value), "end");
    }

    const tickIndices = uniqueIndices(years.length, Math.min(5, years.length));
    tickIndices.forEach(function (index) {
      const x = xAt(index);
      addSvgLine(svg, x, plot.top, x, plot.bottom, "chart-gridline");
      addSvgText(svg, x, plot.bottom + 20, "chart-axis-label", String(years[index]), "middle");
    });
    addSvgLine(svg, plot.left, yAt(0) >= plot.top && yAt(0) <= plot.bottom ? yAt(0) : plot.bottom,
      plot.right, yAt(0) >= plot.top && yAt(0) <= plot.bottom ? yAt(0) : plot.bottom, "chart-axis-line");
    addSvgText(svg, (plot.left + plot.right) / 2, height - 5, "chart-axis-title", "Year", "middle");
  }

  function drawLines(svg, series, years, plot, xAt, yAt) {
    series.forEach(function (line, index) {
      const color = COLORS[index % COLORS.length];
      let gap = true;
      let lastIndex = -1;
      const segments = [];
      line.values.forEach(function (value, pointIndex) {
        if (!Number.isFinite(value)) { gap = true; return; }
        segments.push((gap ? "M" : "L") + xAt(pointIndex).toFixed(2) + " " + yAt(value).toFixed(2));
        gap = false;
        lastIndex = pointIndex;
      });
      if (lastIndex < 0) return;
      const pathData = segments.join(" ");
      svg.append(svgElement("path", { d: pathData, stroke: color, class: "chart-series-line" }));
      const point = svgElement("circle", { cx: xAt(lastIndex), cy: yAt(line.values[lastIndex]), r: 4.2, fill: color, class: "chart-series-point" });
      addTitle(point, line.label + ": " + formatValue(line.values[lastIndex]) + " " + line.unit);
      svg.append(point);
    });
  }

  function drawBars(svg, series, years, type, plot, xAt, yAt) {
    const slotWidth = (plot.right - plot.left) / Math.max(years.length, 1);
    const groupWidth = slotWidth * 0.72;
    const zero = yAt(0);
    for (let yearIndex = 0; yearIndex < years.length; yearIndex += 1) {
      const center = plot.left + (yearIndex + 0.5) * slotWidth;
      if (type === "bar stacked") {
        let positiveBase = 0;
        let negativeBase = 0;
        series.forEach(function (line, seriesIndex) {
          const value = Number(line.values[yearIndex]);
          if (!Number.isFinite(value)) return;
          const before = value >= 0 ? positiveBase : negativeBase;
          const after = before + value;
          const y1 = yAt(before);
          const y2 = yAt(after);
          const rect = svgElement("rect", {
            x: center - groupWidth / 2,
            y: Math.min(y1, y2),
            width: groupWidth,
            height: Math.max(1, Math.abs(y2 - y1)),
            fill: COLORS[seriesIndex % COLORS.length],
            class: "chart-bar"
          });
          addTitle(rect, line.label + " · " + years[yearIndex] + ": " + formatValue(value) + " " + line.unit);
          svg.append(rect);
          if (value >= 0) positiveBase = after;
          else negativeBase = after;
        });
      } else {
        const barWidth = groupWidth / series.length;
        series.forEach(function (line, seriesIndex) {
          const value = Number(line.values[yearIndex]);
          if (!Number.isFinite(value)) return;
          const y = yAt(value);
          const rect = svgElement("rect", {
            x: center - groupWidth / 2 + seriesIndex * barWidth + barWidth * 0.08,
            y: Math.min(y, zero),
            width: Math.max(1, barWidth * 0.84),
            height: Math.max(1, Math.abs(zero - y)),
            fill: COLORS[seriesIndex % COLORS.length],
            class: "chart-bar"
          });
          addTitle(rect, line.label + " · " + years[yearIndex] + ": " + formatValue(value) + " " + line.unit);
          svg.append(rect);
        });
      }
    }
  }

  function uniqueIndices(length, count) {
    if (length <= 1) return [0];
    const result = [];
    for (let i = 0; i < count; i += 1) {
      const index = Math.round(i * (length - 1) / Math.max(count - 1, 1));
      if (result.indexOf(index) < 0) result.push(index);
    }
    return result;
  }

  function addSvgLine(parent, x1, y1, x2, y2, className) {
    parent.append(svgElement("line", { x1: x1, y1: y1, x2: x2, y2: y2, class: className }));
  }

  function addSvgText(parent, x, y, className, value, anchor) {
    const node = svgElement("text", { x: x, y: y, class: className, "text-anchor": anchor || "start" });
    node.textContent = value;
    parent.append(node);
  }

  function addTitle(node, value) {
    const title = svgElement("title", {});
    title.textContent = value;
    node.append(title);
  }

  function svgElement(name, attributes) {
    const node = document.createElementNS(NS, name);
    Object.keys(attributes).forEach(function (key) { node.setAttribute(key, String(attributes[key])); });
    return node;
  }

  function formatValue(value) {
    if (!Number.isFinite(value)) return "—";
    return Math.abs(value) >= 100 ? value.toFixed(0) : value.toFixed(1);
  }

  function formatAxis(value) {
    if (Math.abs(value) >= 100) return Math.round(value).toLocaleString();
    return value.toFixed(1);
  }

  function showError(message) {
    document.getElementById("chart-note").textContent = String(message);
    document.getElementById("chart-note").style.color = "var(--color-danger)";
  }

  window.setup = setup;
}());
