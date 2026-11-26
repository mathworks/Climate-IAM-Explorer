# IAMFrame annual data contract

`iam.IAMFrame` stores annual IAM observations in a MATLAB table. Construct it
from `iam.IAMTimeseries` objects or a long table:

```matlab
data = table("Model A", "Scenario A", "Emissions|CO2", "World", ...
    "Mt CO2/yr", 2020, 120, ...
    'VariableNames', {'Model', 'Scenario', 'Variable', 'Region', ...
    'Unit', 'Year', 'Value'});
frame = iam.IAMFrame(data);
```

## Columns and identity

`Model`, `Scenario`, `Variable`, `Region`, `Unit`, `Year`, and `Value` are
required. `RunId` and `Version` are optional numeric columns; when omitted,
their values are `NaN`. Additional columns are rejected. This keeps dimensions
and annotations from disappearing during construction; convert unsupported
dimensions explicitly before making a frame.

An observation is identified by model, scenario, version, variable, region,
unit, and year. Version distinguishes scenario variants. `RunId` and attached
`RunInfo` describe source provenance and are not part of observation identity;
duplicate observations are rejected even if their source run IDs differ. Run
IDs are not globally unique across providers. Local or derived data can use
`NaN` when no unchanged source run can be claimed.

The frame sorts rows by model, scenario, variable, region, unit, run ID,
version, and year. Series conversions retain all supported observations,
including rows whose value is missing.

## Values and annual years

Years must be real, finite integer numbers. Year selectors passed to `filter`
must also be finite integers; text selectors are accepted only when every
entry represents an integer year. Invalid entries raise an error instead of
being ignored.

`Value` must be real numeric data. `NaN` represents an unavailable observation
and is preserved; it is never converted to zero. Infinite values are rejected.
An empty `Unit` string represents an unknown unit. Unknown units are retained
as-is and are not assumed compatible with other units.

## MATLAB behavior

Tables provide row selection, sorting, and structured identity comparison.
Frames do not silently discard extra columns or fill missing observations.
Datetime observations and subannual dimensions are not part of this annual
contract.
