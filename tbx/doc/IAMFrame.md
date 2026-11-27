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

## Merging frames

`append` combines frames using that observation identity. Distinct observations
are retained. A repeated identity with a different value raises
`iam:IAMFrame:ConflictingObservation` and reports its model, scenario, version,
variable, region, unit, and year. Identical repeats raise
`iam:IAMFrame:DuplicateObservation` by default. Pass
`RepeatPolicy="deduplicate"` to collapse identical values explicitly.

When identical observations came from different nonmissing `RunId` values,
the merged observation gets `RunId=NaN`; source-specific records remain in
`RunInfo`. If no source records were supplied, the merge creates minimal
records containing model, scenario, version, and run ID before removing those
IDs from the observation. Filtering retains these source records.

Compatible `RunInfo` tables are joined by their available
`run_id`, `model`, `scenario`, and `version` columns. Their schemas are
unioned, and missing metadata stays missing. Conflicting values for the same
source record raise `iam:IAMFrame:IncompatibleRunInfo`. Numeric and logical
metadata use doubles in merged tables so missing logical values can be `NaN`;
text metadata uses strings. Filtering keeps source metadata aligned by run and
scenario identity, including provider-local run-ID collisions. If the available
RunInfo identifiers cannot map a colliding run ID to one analytical trajectory,
the frame rejects it with `iam:IAMFrame:AmbiguousRunInfo`.

Reserved identity column names are normalized to lowercase when merging.
Partial identities can match a shared nonmissing run ID only when known
identifiers agree and the source mapping is unambiguous. Duplicate aliases,
such as `run_id` and `Run_ID` in one table, are rejected.

Struct-valued metadata is stored in scalar cells so records with different
field sets can coexist. Nested fields are merged recursively; incompatible
values report the field path. Empty cells and missing values can be filled
from a compatible record. Array-valued table columns are rejected rather than
reshaped into additional metadata rows; array payloads can be retained inside
a structured record or scalar cell.

Missing datetime metadata retains the column's timezone. An unspecified
timezone on an all-`NaT` column can adopt the known timezone without inventing
timestamps. Compatible zoned
columns are expressed in the left column's timezone without changing their
instants. Mixing known zoned and unzoned timestamps raises an explicit error.

`iam.controls.IAMworkbook.addData` accepts the same `RepeatPolicy` name-value
argument and delegates to `append`, so scripted and workbook merges apply the
same duplicate and metadata rules.

The frame sorts rows by model, scenario, variable, region, unit, run ID,
version, and year. Series conversions retain all supported observations,
including rows whose value is missing.

Table and timeseries inputs use the same validation, unit normalization, and
row ordering. Each timeseries must contain exactly one real numeric value
column with one value per annual year, and a scalar `Version` (which may be
`NaN`). Multiple timetable variables, matrix-valued columns, and mismatched
year/value lengths are rejected. Timetable row times must be January 1 at
midnight and agree with `Years`; duration coordinates, missing dates, and
subannual timestamps are rejected rather than silently relabeled.

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
