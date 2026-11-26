# Climate IAM Explorer

Explore integrated assessment model (IAM) scenario data in MATLAB. Browse
scenario databases, select models, scenarios, variables, and regions, and
work with annual observations as tables or time series.

## Getting started

Launch the graphical explorer by entering `IAMDataExplorer` in MATLAB.
Use the app to browse data, select series, and compare line or bar plots.

For a guided walkthrough, open the
[Getting Started live script](mfiles/GettingStarted.m) in MATLAB.

## Explore scenario databases

[IAMEnvironment](IAMEnvironment.md) describes how to discover available runs,
filter selections, retrieve data, and inspect scenario metadata. Retrieve
individual series with `getTimeSeries()` or an annual dataset with `getFrame()`.

## Work with annual data

[IAMFrame](IAMFrame.md) describes the annual data format, observation identity,
units, missing values, and validation rules. Construct a frame from downloaded
series or a local long-format MATLAB table.

Use `filter()` to select observations, `toTable()` for a long table,
`timeseries()` for a wide table, and `toTimeseries()` to obtain series for
plotting. `RunInfo` carries attached source metadata.

## Documentation topics

- [Explore databases and retrieve scenario data](IAMEnvironment.md)
- [Annual observations and the IAMFrame data contract](IAMFrame.md)
- [Getting Started live script](mfiles/GettingStarted.m)
