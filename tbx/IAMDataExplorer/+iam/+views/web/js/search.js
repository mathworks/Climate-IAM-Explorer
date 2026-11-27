(function () {
  "use strict";

  let htmlComponent;
  let resultRecords = [];
  let selectedIds = new Set();
  let selectionAnchor = null;
  let totalCount = 0;
  let hasSearched = false;
  let activeFacet = "";
  let facetOptions = [];
  let selectedFacetValues = new Set();

  function setup(component) {
    htmlComponent = component;
    component.addEventListener("searchResults", onSearchResults);
    component.addEventListener("facetOptions", onFacetOptions);
    component.addEventListener("selectionStatus", function (event) {
      const data = event.Data || {};
      showSelectionStatus(data.Message || "Selection updated");
    });
    component.addEventListener("error", onError);
    component.addEventListener("DataChanged", clearCriteria);

    document.getElementById("search-button").addEventListener("click", startSearch);
    document.getElementById("clear-criteria").addEventListener("click", clearCriteria);
    document.getElementById("selected-to-workbook").addEventListener("click", loadSelected);
    document.getElementById("all-to-workbook").addEventListener("click", function () {
      if (resultRecords.length === 0) return;
      htmlComponent.sendEventToMATLAB("loadAll", {});
      showSelectionStatus("Sending all results to MATLAB…");
    });
    document.getElementById("export-to-workspace").addEventListener("click", function () {
      if (resultRecords.length === 0) return;
      htmlComponent.sendEventToMATLAB("exportRequested", { ids: Array.from(selectedIds) });
      showSelectionStatus(selectedIds.size ? "Exporting selected series…" : "Exporting all results…");
    });
    document.getElementById("close-browse").addEventListener("click", closeBrowse);
    document.getElementById("browse-modal").addEventListener("click", function (event) {
      if (event.target.id === "browse-modal") closeBrowse();
    });
    document.getElementById("browse-search").addEventListener("input", renderFacetOptions);

    document.querySelectorAll("[data-browse]").forEach(function (button) {
      button.addEventListener("click", function () { requestFacet(button.dataset.browse); });
    });
    document.querySelectorAll(".criterion input").forEach(function (input) {
      input.addEventListener("input", markCriteriaChanged);
      input.addEventListener("change", markCriteriaChanged);
    });
    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape") closeBrowse();
    });
    component.sendEventToMATLAB("viewReady", {});
  }

  function readCriteria() {
    const criteria = {};
    ["model", "region", "scenario", "variable"].forEach(function (facet) {
      criteria[facet] = document.getElementById(facet + "-input").value.trim();
      criteria[facet + "Strict"] = document.getElementById(facet + "-strict").checked;
    });
    return criteria;
  }

  function startSearch() {
    if (!htmlComponent || !htmlComponent.sendEventToMATLAB) return;
    const criteria = readCriteria();
    hasSearched = false;
    totalCount = 0;
    resultRecords = [];
    selectedIds.clear();
    selectionAnchor = null;
    showResultsLoading();
    showSelectionStatus("Searching the selected sources");
    document.getElementById("criteria-feedback").textContent = "Searching…";
    document.getElementById("search-button").disabled = true;
    document.getElementById("search-button").querySelector("span").textContent = "Searching…";
    setCriteriaDisabled(true);
    updateWorkbookButtons();
    htmlComponent.sendEventToMATLAB("searchRequested", criteria);
  }

  function onSearchResults(event) {
    const data = event.Data || {};
    resultRecords = asArray(data.Records);
    selectedIds.clear();
    selectionAnchor = null;
    totalCount = Number(data.TotalCount || 0);
    hasSearched = true;
    document.getElementById("search-button").disabled = false;
    document.getElementById("search-button").querySelector("span").textContent = "Search database";
    setCriteriaDisabled(false);
    document.getElementById("criteria-feedback").textContent = "Search complete";
    renderResults();
  }

  function renderResults() {
    const table = document.getElementById("results-table");
    const initial = document.getElementById("initial-state");
    const noResults = document.getElementById("no-results");
    const tbody = document.getElementById("result-rows");
    tbody.replaceChildren();

    initial.hidden = true;
    noResults.hidden = totalCount !== 0;
    table.hidden = totalCount === 0;
    resultRecords.forEach(function (record) { tbody.append(createResultRow(record)); });

    document.getElementById("result-count").textContent = String(totalCount);
    updateWorkbookButtons();
    if (selectedIds.size === 0) showSelectionStatus(totalCount === 0
      ? "No runs matched these criteria" : "Select rows to preview them");
  }

  function createResultRow(record) {
    const row = document.createElement("tr");
    const id = String(record.ID);
    const isSelected = selectedIds.has(id);
    if (isSelected) row.classList.add("is-selected");

    row.dataset.recordId = id;
    row.tabIndex = 0;
    row.setAttribute("aria-selected", isSelected ? "true" : "false");
    row.addEventListener("click", function (event) { selectRow(id, event); });
    row.addEventListener("keydown", function (event) {
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
        selectRow(id, event);
      }
    });

    const variableCell = document.createElement("td");
    variableCell.className = "variable-cell";
    const variable = document.createElement("span");
    variable.className = "variable-name";
    variable.textContent = String(record.Variable || "").split("|").join(" · ");
    variableCell.append(variable);

    const unitCell = textCell(record.Unit, "unit-cell");
    const modelCell = textCell(record.Model, "model-cell");
    const scenarioCell = textCell(record.Scenario, "scenario-cell");
    const regionCell = textCell(record.Region, "region-cell");
    const runCell = textCell(record.RunId, "run-cell");
    const versionCell = textCell(record.Version, "version-cell");
    row.append(variableCell, unitCell, modelCell, scenarioCell, regionCell, runCell, versionCell);
    return row;
  }

  function textCell(value, className) {
    const cell = document.createElement("td");
    cell.className = className;
    cell.textContent = String(value == null ? "" : value);
    cell.title = cell.textContent;
    return cell;
  }

  function selectRow(id, event) {
    const index = resultRecords.findIndex(function (record) { return String(record.ID) === id; });
    const anchor = resultRecords.findIndex(function (record) { return String(record.ID) === selectionAnchor; });
    if (event.shiftKey && anchor >= 0) {
      if (!event.ctrlKey && !event.metaKey) selectedIds.clear();
      resultRecords.slice(Math.min(anchor, index), Math.max(anchor, index) + 1).forEach(function (record) {
        selectedIds.add(String(record.ID));
      });
    } else {
      if (event.ctrlKey || event.metaKey) {
        if (selectedIds.has(id)) selectedIds.delete(id);
        else selectedIds.add(id);
      } else {
        selectedIds.clear();
        selectedIds.add(id);
      }
      selectionAnchor = id;
    }
    document.querySelectorAll("#result-rows tr").forEach(function (row) {
      const selected = selectedIds.has(row.dataset.recordId);
      row.classList.toggle("is-selected", selected);
      row.setAttribute("aria-selected", selected ? "true" : "false");
    });
    updateWorkbookButtons();
    showSelectionStatus(selectedIds.size + " selected · updating preview…");
    htmlComponent.sendEventToMATLAB("selectionChanged", { ids: Array.from(selectedIds) });
  }

  function updateWorkbookButtons() {
    document.getElementById("selected-to-workbook").disabled = selectedIds.size === 0;
    document.getElementById("all-to-workbook").disabled = resultRecords.length === 0;
    const exportButton = document.getElementById("export-to-workspace");
    exportButton.disabled = resultRecords.length === 0;
    exportButton.title = selectedIds.size ? "Export selected series to workspace" : "Export all results to workspace";
  }

  function setCriteriaDisabled(isDisabled) {
    document.querySelectorAll(".criterion input, [data-browse], #clear-criteria").forEach(function (control) {
      control.disabled = isDisabled;
    });
  }

  function loadSelected() {
    if (selectedIds.size === 0) return;
    htmlComponent.sendEventToMATLAB("loadSelected", { ids: Array.from(selectedIds) });
    showSelectionStatus("Sending selection to MATLAB…");
  }

  function clearCriteria() {
    document.querySelectorAll(".criterion input[type=text]").forEach(function (input) { input.value = ""; });
    document.querySelectorAll(".criterion input[type=checkbox]").forEach(function (input) { input.checked = true; });
    resultRecords = [];
    selectedIds.clear();
    selectionAnchor = null;
    totalCount = 0;
    hasSearched = false;
    document.getElementById("initial-state").hidden = false;
    document.getElementById("no-results").hidden = true;
    document.getElementById("results-table").hidden = true;
    document.getElementById("result-rows").replaceChildren();
    document.getElementById("result-count").textContent = "—";
    document.getElementById("criteria-feedback").textContent = "Criteria cleared · press Search database to run";
    showSelectionStatus("Select rows to preview them");
    updateWorkbookButtons();
    htmlComponent.sendEventToMATLAB("criteriaCleared", {});
  }

  function markCriteriaChanged() {
    if (hasSearched || resultRecords.length > 0) {
      document.getElementById("criteria-feedback").textContent = "Criteria changed · press Search database to refresh";
    }
  }

  function showResultsLoading() {
    document.getElementById("initial-state").hidden = true;
    document.getElementById("no-results").hidden = true;
    document.getElementById("results-table").hidden = true;
    document.getElementById("result-count").textContent = "…";
  }

  function requestFacet(facet) {
    activeFacet = facet;
    selectedFacetValues = new Set();
    facetOptions = [];
    document.getElementById("browse-title").textContent = "Browse " + capitalize(facet);
    document.getElementById("browse-search").value = "";
    document.getElementById("browse-options").innerHTML = "<div class=\"browse-loading\">Loading matching metadata values…</div>";
    updateBrowseSelectionCount();
    document.getElementById("browse-modal").hidden = false;
    htmlComponent.sendEventToMATLAB("requestFacet", { facet: facet });
  }

  function onFacetOptions(event) {
    const data = event.Data || {};
    if (String(data.Facet || "").toLowerCase() !== activeFacet) return;
    facetOptions = asArray(data.Options).map(String);
    const current = parseTokens(document.getElementById(activeFacet + "-input").value);
    selectedFacetValues = new Set(current);
    renderFacetOptions();
    updateBrowseSelectionCount();
  }

  function renderFacetOptions() {
    const host = document.getElementById("browse-options");
    if (!facetOptions.length) {
      host.innerHTML = "<div class=\"browse-loading\">No values available for this field.</div>";
      return;
    }
    const query = document.getElementById("browse-search").value.trim().toLocaleLowerCase();
    const filtered = facetOptions.filter(function (value) { return value.toLocaleLowerCase().includes(query); });
    host.replaceChildren();
    if (filtered.length === 0) {
      const empty = document.createElement("div");
      empty.className = "browse-loading";
      empty.textContent = "No values match this text.";
      host.append(empty);
      return;
    }

    if (activeFacet === "variable") {
      renderVariableTree(host, filtered);
    } else {
      filtered.forEach(function (value) { host.append(createBrowseOption(value, value)); });
    }
  }

  function renderVariableTree(host, values) {
    const groups = new Map();
    values.forEach(function (value) {
      const parts = value.split("|");
      const parent = parts.length > 1 ? parts[0] : "Other variables";
      if (!groups.has(parent)) groups.set(parent, []);
      groups.get(parent).push({ value: value, label: parts.slice(1).join(" · ") || parts[0] });
    });
    groups.forEach(function (children, parent) {
      const details = document.createElement("details");
      details.className = "browse-group";
      details.open = false;
      const summary = document.createElement("summary");
      summary.textContent = parent;
      details.append(summary);
      children.forEach(function (child) { details.append(createBrowseOption(child.value, child.label)); });
      host.append(details);
    });
  }

  function createBrowseOption(value, labelText) {
    const label = document.createElement("label");
    label.className = "browse-option";
    const input = document.createElement("input");
    input.type = "checkbox";
    input.value = value;
    input.checked = Array.from(selectedFacetValues).some(function (token) {
      return token.toLocaleLowerCase() === value.toLocaleLowerCase();
    });
    const text = document.createElement("span");
    text.textContent = labelText;
    label.append(input, text);
    input.addEventListener("change", function () {
      if (input.checked) selectedFacetValues.add(value);
      else selectedFacetValues.forEach(function (token) {
        if (token.toLocaleLowerCase() === value.toLocaleLowerCase()) selectedFacetValues.delete(token);
      });
      document.getElementById(activeFacet + "-input").value = Array.from(selectedFacetValues).join(";;");
      markCriteriaChanged();
      updateBrowseSelectionCount();
    });
    return label;
  }

  function updateBrowseSelectionCount() {
    const count = selectedFacetValues.size;
    document.getElementById("browse-selection-count").textContent = count
      ? count + " value" + (count === 1 ? "" : "s") + " selected"
      : "No values selected";
  }

  function closeBrowse() {
    document.getElementById("browse-modal").hidden = true;
  }

  function parseTokens(value) {
    return String(value).split(";;").map(function (token) { return token.trim(); }).filter(Boolean);
  }

  function asArray(value) {
    if (value == null) return [];
    return Array.isArray(value) ? value : [value];
  }

  function capitalize(value) {
    return value.charAt(0).toUpperCase() + value.slice(1);
  }

  function showSelectionStatus(message, isError) {
    const status = document.getElementById("selection-status");
    status.textContent = String(message);
    status.title = String(message);
    status.classList.toggle("is-error", Boolean(isError));
  }

  function onError(event) {
    const data = event.Data || {};
    const message = String(data.Message || data.message || "MATLAB reported an error");
    document.getElementById("search-button").disabled = false;
    document.getElementById("search-button").querySelector("span").textContent = "Search database";
    document.getElementById("criteria-feedback").textContent = "Search failed";
    setCriteriaDisabled(false);
    showSelectionStatus(message, true);
  }

  window.setup = setup;
}());
