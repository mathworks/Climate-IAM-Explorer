(function () {
  "use strict";
  const productionSetup = window.setup;
  window.setup = function (component) {
    window.addEventListener("error", function (event) {
      component.sendEventToMATLAB("testError", { message: event.message });
    });
    productionSetup(component);
    component.addEventListener("testAction", function (event) {
      const action = event.Data || {};
      try {
        const kind = String(action.kind || "snapshot");
        const element = action.selector ? document.querySelector(action.selector) : null;
        if (action.selector && !element) throw new Error("Missing element: " + action.selector);
        if (kind === "click") element.dispatchEvent(new MouseEvent("click", {
          bubbles: true, shiftKey: action.shift === true,
          ctrlKey: action.control === true, metaKey: action.meta === true
        }));
        if (kind === "value") {
          element.value = action.value;
          element.dispatchEvent(new Event("input", { bubbles: true }));
          element.dispatchEvent(new Event("change", { bubbles: true }));
        }
        if (kind === "checked") {
          element.checked = action.value;
          element.dispatchEvent(new Event("change", { bubbles: true }));
        }
        component.sendEventToMATLAB("testResponse", { id: action.id, snapshot: snapshot() });
      } catch (error) {
        component.sendEventToMATLAB("testError", { message: error.message });
        component.sendEventToMATLAB("testResponse", { id: action.id, snapshot: {} });
      }
    });
    component.sendEventToMATLAB("testReady", {});
  };

  function snapshot() {
    const text = function (id) { const element = document.getElementById(id); return element ? element.textContent : ""; };
    const paths = Array.from(document.querySelectorAll(".chart-series-line"), function (node) { return node.getAttribute("d"); });
    const bars = Array.from(document.querySelectorAll(".chart-bar"), function (node) {
      return ["x", "y", "width", "height"].map(function (name) { return Number(node.getAttribute(name)); });
    });
    const search = document.getElementById("search-button");
    const modal = document.getElementById("browse-modal");
    return {
      resultCount: text("result-count"),
      resultSummaryCount: document.querySelectorAll("#result-summary").length,
      selectionStatus: text("selection-status"),
      statusIsError: document.getElementById("selection-status") ? document.getElementById("selection-status").classList.contains("is-error") : false,
      statusColor: document.getElementById("selection-status") ? getComputedStyle(document.getElementById("selection-status")).color : "",
      errorColor: getComputedStyle(document.body).getPropertyValue("--color-danger").trim(),
      columns: Array.from(document.querySelectorAll("#results-table th"), function (node) { return node.textContent; }),
      units: Array.from(document.querySelectorAll("#result-rows .unit-cell"), function (node) { return node.textContent; }),
      rowCheckboxes: document.querySelectorAll("#result-rows input[type=checkbox], #result-rows .row-check").length,
      rows: document.querySelectorAll("#result-rows tr").length,
      selected: document.querySelectorAll("#result-rows tr[aria-selected='true']").length,
      loadButtonCount: document.querySelectorAll("#load-selected").length,
      selectedWorkbookDisabled: document.getElementById("selected-to-workbook") ? document.getElementById("selected-to-workbook").disabled : true,
      allWorkbookDisabled: document.getElementById("all-to-workbook") ? document.getElementById("all-to-workbook").disabled : true,
      workspaceExportDisabled: document.getElementById("export-to-workspace") ? document.getElementById("export-to-workspace").disabled : true,
      workspaceExportTooltip: document.getElementById("export-to-workspace") ? document.getElementById("export-to-workspace").title : "",
      resultActions: Array.from(document.querySelectorAll(".result-actions button"), function (node) { return node.id; }),
      greenWorkbookButtons: document.querySelectorAll("#selected-to-workbook.button-primary, #all-to-workbook.button-primary").length,
      brandHeaderCount: document.querySelectorAll(".app-header").length,
      previewHeaderVisible: document.querySelector(".plot-header") ? getComputedStyle(document.querySelector(".plot-header")).display !== "none" : false,
      searchDisabled: search ? search.disabled : false,
      criteriaFeedback: text("criteria-feedback"),
      strictFlags: Array.from(document.querySelectorAll(".criterion input[type=checkbox]"), function (node) { return node.checked; }),
      browseOpen: modal ? !modal.hidden : false,
      browseOptions: document.querySelectorAll("#browse-options input").length,
      openBrowseGroups: document.querySelectorAll("#browse-options details[open]").length,
      browseDialogWidth: document.querySelector(".browse-dialog") ? document.querySelector(".browse-dialog").getBoundingClientRect().width : 0,
      browseDialogHeight: document.querySelector(".browse-dialog") ? document.querySelector(".browse-dialog").getBoundingClientRect().height : 0,
      browseDialogLeft: document.querySelector(".browse-dialog") ? document.querySelector(".browse-dialog").getBoundingClientRect().left : 0,
      browseDialogTop: document.querySelector(".browse-dialog") ? document.querySelector(".browse-dialog").getBoundingClientRect().top : 0,
      browseSearchWidth: document.getElementById("browse-search") ? document.getElementById("browse-search").getBoundingClientRect().width : 0,
      variableInput: document.getElementById("variable-input") ? document.getElementById("variable-input").value : "",
      title: text("chart-title"),
      unit: text("chart-unit"),
      legendCount: document.querySelectorAll(".legend-item").length,
      legendLabels: Array.from(document.querySelectorAll(".legend-label"), function (node) { return node.textContent; }),
      legendTooltips: Array.from(document.querySelectorAll(".legend-label"), function (node) { return node.title; }),
      legendItemWidths: Array.from(document.querySelectorAll(".legend-item"), function (node) { return node.getBoundingClientRect().width; }),
      legendLabelLefts: Array.from(document.querySelectorAll(".legend-label"), function (node) { return node.getBoundingClientRect().left; }),
      legendRowTops: Array.from(document.querySelectorAll(".legend-item"), function (node) { return node.getBoundingClientRect().top; }),
      clippedLegendLabels: document.querySelectorAll(".legend-label").length ? Array.from(document.querySelectorAll(".legend-label"), function (node) { return node.scrollWidth > node.clientWidth; }) : [],
      lineCount: paths.length,
      paths: paths,
      barCount: bars.length,
      finiteGeometry: paths.every(function (value) { return !/NaN|Infinity/.test(value); }) &&
        bars.every(function (bar) { return bar.every(Number.isFinite); }),
      note: text("chart-note")
    };
  }
}());
