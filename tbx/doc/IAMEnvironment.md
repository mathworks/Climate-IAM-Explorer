# IAMEnvironment

`iam.IAMEnvironment` is the main exploration surface for IIASA-backed IAM
scenario data in this toolbox. It loads reference data for the active
environment, exposes run-level filters, and retrieves time-series data as
`iam.IAMTimeseries` or `iam.IAMFrame`.

## Constructing an Environment

```matlab
c = iam.data.IIASAconnection("ngfs_phase_3");
env = iam.IAMEnvironment(c);
```

The environment caches:

- `Models`
- `Scenarios`
- `Variables`
- `Regions`
- `RunList`
- `Metadata`

Use `reloadEnvironment()` to refresh this state after changing connection
settings or server-side content.

## Changing the Active Database

```matlab
env.changeEnvironment("ngfs_phase_3");
```

The `Environment` dependent property reports the current connection target.

## Querying Time-Series Data

Use `getTimeSeries()` to retrieve data as `iam.IAMTimeseries`.

If discovery contains no runs, or an explicit model/scenario/run/variable/region
selection matches nothing, the method returns an empty `iam.IAMTimeseries`
without a bulk request. `getFrame()` returns an empty frame for the same query.

```matlab
ts = env.getTimeSeries( ...
    'models', "GCAM5.3_NGFS", ...
    'regions', "World", ...
    'variables', "Primary Energy", ...
    'years', [2020 2030 2050]);
```

Supported name-value arguments:

- `strict`
- `models`
- `scenarios`
- `runs`
- `variables`
- `regions`
- `years`
- `units`
- `timeslices`

Omit `years` to request all available years. Supply years as numbers (for
example, `[2020 2030 2050]`) or as strings; both forms are converted to the
IIASA bulk filter format.

By default, string matching is relaxed and case-insensitive. Set
`strict=true` to require exact matching, while still allowing wildcard
patterns such as `"Emissions|CO2*"` and `"Wor*"`.

## Querying Frames

Use `getFrame()` to retrieve the same query as an `iam.IAMFrame`.

```matlab
frame = env.getFrame( ...
    'models', "GCAM5.3_NGFS", ...
    'regions', "World", ...
    'variables', "Primary Energy");
```

`getFrame()` accepts the same filters as `getTimeSeries()` and also supports
the `meta` argument:

```matlab
frame = env.getFrame( ...
    'models', "GCAM5.3_NGFS", ...
    'variables', "Primary Energy", ...
    'meta', ["Category", "Temperature Target"]);
```

Selector behavior:

- Omit `meta` or pass `string.empty`: project no metadata fields
- Pass `"all"`: project all metadata fields
- Pass one or more field names: project only those fields

When `meta` is supplied, selected scenario metadata fields are flattened
into `frame.RunInfo`.

## Run-Level Discovery

`IAMEnvironment` now provides a pyam-like run discovery surface.

### Index

`index()` returns the run identity columns.

```matlab
tb = env.index('models', "GCAM5.3_NGFS");
```

Returned columns:

- `model`
- `scenario`
- `version`

### Meta

`meta()` returns run identity columns plus selected metadata.

```matlab
tb = env.meta('fields', "Temperature Target", 'run_id', true);
```

Notes:

- Omit `fields` or pass `string.empty`: project no metadata fields.
- `fields="all"` projects all metadata fields.
- `fields` can use either normalized MATLAB field names or the original IIASA
  labels.
- `run_id=true` includes the `run_id` column.

### Run Properties

`runProperties()` returns audit and version columns for matching runs.

```matlab
tb = env.runProperties('models', "GCAM5.3_NGFS");
```

Typical columns include:

- `model`
- `scenario`
- `version`
- `is_default`
- `run_id`
- `cre_user`
- `cre_date`
- `upd_user`
- `upd_date`
- `lock_user`
- `lock_date`
- `is_locked`

## Filtering Helpers

Use helper methods to inspect valid selections before querying:

```matlab
env.filterVariables("Primary Energy")
env.filterRegions(["World", "Europe"], true)
runs = env.filterRuns('models', "GCAM*", 'scenarios', "Current*", 'strict', false)
```

`filterRuns()` also accepts a `metadata` struct for metadata-aware selection.
Pass `strict` as a name-value argument:

```matlab
filters = struct();
filters.TemperatureTarget = 1.5;
runs = env.filterRuns('metadata', filters, 'strict', true);
exactRuns = env.filterRuns('strict', true, 'models', "GCAM5.3_NGFS");
```

If an explicit model, scenario, run, variable, or region selection matches
nothing in the cached environment, `getTimeSeries()` returns an empty
`iam.IAMTimeseries` without sending an empty run filter to the bulk endpoint.

## Documentation Access

Use the documentation accessors for explorer-hosted descriptions:

- `getModelDocumentation(modelID)`
- `getScenarioDocumentation(scenarioID)`
- `getTimeseriesDocumentation(timeseriesID)`
- `getRegionDocumentation(regionID)`

## Typical Workflow

```matlab
c = iam.data.IIASAconnection("ngfs_phase_3");
env = iam.IAMEnvironment(c);

meta = env.meta('fields', ["Category", "Temperature Target"], 'run_id', true);

frame = env.getFrame( ...
    'models', "GCAM5.3_NGFS", ...
    'regions', "World", ...
    'variables', "Primary Energy", ...
    'meta', ["Category", "Temperature Target"]);

summary(frame)
frame.RunInfo
```
