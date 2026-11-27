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

## Local scenario metadata

Provider metadata remains in `RunInfo`. `filter(metadata=...)` reads scalar
numeric, boolean, or text fields from those records, including nested
`metadata` payloads. No local copy or extra download is required. Conflicting
provider values for one scenario must be resolved explicitly rather than
selecting whichever record comes first.

`meta()` returns local annotations keyed by `Model`, `Scenario`, and `Version`.
Use `setMeta` with a keyed table to add or change annotations. The keys must
exist in the frame; omitted `Version` means the unversioned identity (`NaN`).
Supply the version explicitly for versioned scenarios.

```matlab
annotations = table("Model A", "Scenario A", "Reviewed", false, ...
    VariableNames=["Model","Scenario","Policy category","Excluded"]);
frame = frame.setMeta(annotations);
selected = frame.filter(metadata=struct(Policy_category="Reviewed"),strict=true);
```

Table labels are preserved, including spaces. Filters can use an unambiguous
valid-name alias such as `Policy_category`. There is no separate name registry.
Data/provenance column names are reserved. Annotations support scalar numeric,
logical, and text columns; unsupported arrays or objects are rejected.

Only supplied rows and columns change. Missing values clear a previous local
annotation; other scenarios remain unchanged. A nonmissing local annotation
overrides the provider field for that scenario. Clearing it restores the
provider value when one exists. Original `RunInfo` remains unchanged.

Logical annotations use `0`, `1`, and `NaN`; missing never becomes false.
`Excluded` is an analyst-owned flag and does not fall back to provider values.
Numeric selectors match exact values, including `NaN` for unknown flags. Text
selectors follow `strict`/wildcard behavior; a missing string selects unknown
text and `""` selects blank text. Appending and filtering retain annotations
with their scenario/version, and conflicting appended values raise an error.

General derivation callbacks and a `setMetaFromData` API are deferred. Compute
an indicator with native MATLAB table functions, then attach the resulting
keyed table with `setMeta` when a workflow needs it. MAT save/load already
provides persistence; these methods add selection and annotation behavior.

## Unit conversion and named calculations

`convertUnit(sourceUnit,targetUnit)` converts every observation carrying the
exact source label. It supports the following common mappings; reverse
conversions use the reciprocal factor.

| Source unit | Target unit | Factor |
|---|---|---:|
| `Mt CO2/yr` | `kt CO2/yr` | 1,000 |
| `Gt CO2/yr` | `Mt CO2/yr` | 1,000 |
| `Mt CO2` | `kt CO2` | 1,000 |
| `Gt CO2` | `Mt CO2` | 1,000 |
| `EJ/yr` | `PJ/yr` | 1,000 |
| `EJ` | `PJ` | 1,000 |
| `TWh/yr` | `PJ/yr` | 3.6 |
| `TWh` | `PJ` | 3.6 |
| `GWh` | `MWh` | 1,000 |
| `MWh` | `kWh` | 1,000 |
| `t CO2/yr` | `kt CO2/yr` | 0.001 |
| `kt CO2/yr` | `Mt CO2/yr` | 0.001 |

Other labels require an explicit positive `Factor`; the method does not parse
arbitrary unit expressions or infer dimensional compatibility. The source
frame is unchanged. Accepted numeric factors are converted to double before
multiplication, so integer factors do not round or saturate observations and
single-precision factors do not reduce the observation arithmetic precision.

```matlab
converted = frame.convertUnit("EJ/yr", "PJ/yr");
custom = frame.convertUnit("index", "scaled index", Factor=100);
```

`calculate` selects two named variables from one frame and aligns by Model,
Scenario, Version, Region, and Year. It emits a frame containing the named
derived variable. Addition and subtraction require both variables and the
output to have the same known unit label; convert units first when needed.
Multiplication and division require known operand units and an explicit output
unit label. The method does not guess a compound unit. Missing rows and NaN
values produce NaN derived values and appear in `report.MissingOperands`;
division by zero produces NaN and appears in `report.ZeroDenominators`.
The returned frame contains only the derived observations; append it explicitly
when a combined source-and-result frame is needed. Rows are never paired by
position, and a duplicate operand identity is an error.

```matlab
[difference, report] = frame.calculate("Emissions|CO2", "subtract", ...
    "Emissions|CO2 baseline", "Emissions difference", Unit="Mt CO2/yr");
[intensity, report] = frame.calculate("Emissions|CO2", "divide", ...
    "GDP", "Emissions intensity", Unit="Mt CO2 per billion USD");
```

`share` is the named division convenience for operands with identical units.
Its default `Convention="fraction"` returns a unitless ratio on the natural
scale; use `Convention="percent"` for that ratio multiplied by 100 and unit
`%`. `compareBaseline(target,baseline,variable,output)` returns target minus
baseline for matching Model, Version, Region, and Year keys. Use
`Operation="percentChange"` for 100 times `(target-baseline)/baseline`; zero
baselines are reported and yield NaN. Unit mismatches must be converted before
comparison.

Derived frames retain local annotations and all contributing provider records.
`Provenance` links each result observation to its original source observations:
the ordinary observation keys identify the result; `SourceModel`,
`SourceScenario`, `SourceVariable`, `SourceRegion`, `SourceUnit`, `SourceVersion`,
`SourceYear`, and `SourceRunId` identify the original input. `Operand` records
left/right or target/baseline participation. Missing operands do not create
invented input links. Chained calculations retain original input dependencies.

`RunInfo` keeps original source identities, including baseline scenario names.
Minimal records are synthesized when inputs carry run IDs without attached
metadata. Filtering subsets links and source records by actual contribution;
unit conversion changes result units while retaining original source units.
Baseline comparisons use `RunId=NaN` for result observations, rather than
claiming that a baseline run belongs to the target. Other operations may retain
a shared source ID as a reference, with explicit links identifying derivation.

`iam.IAMTimeseries` wrappers and arithmetic operators reuse the annual input
contract before calculating. Non-numeric/matrix columns, inconsistent years or
dates, invalid identities/provenance, and unknown units are rejected. Arrays
align by series identity and annual dates. Frames and timeseries retain
`RunInfo`, local `Metadata`, and `Provenance` during round-trips; source values
and metadata remain unchanged.

Series arithmetic validates operand types, nonemptiness, and equal element
counts in an `arguments` block. C02 validation runs once per operand array;
the validated frames are reused for provenance. `synchronize` supplies the
common time vector and missing observations, and ordinary arithmetic propagates
NaN values. Division explicitly converts zero-denominator results to NaN;
genuine overflow still raises an error. Identity and unit checks remain
separate because time synchronization cannot validate those relationships.

## Completeness and bounds checks

`requireData` checks every combination of the literal coordinates you supply.
Other coordinates are unrestricted. A row whose `Value` is `NaN` does not
satisfy a requirement. Requirements do not accept wildcard names.

```matlab
coverage = frame.requireData(variables="Emissions|CO2", ...
    regions="World", years=2020);
coverage.Scenarios
coverage.MissingRequirements
```

`validate` checks inclusive numeric bounds on selected observations. Put frame
selectors in `Filter`. Model/scenario/run/metadata selectors choose the scenario
scope; variable/region/unit/year selectors choose the evidence within that
scope. An absent variable does not remove the scenario from the report.

```matlab
bounds = frame.validate(LowerBound=0, UpperBound=150, ...
    Filter=struct(variables="Emissions|CO2", units="Mt CO2/yr", strict=true));
bounds.Scenarios
bounds.Violations
```

Both methods return the same report fields:

| Field | Meaning |
|---|---|
| `Status` | Overall `Passed`, `Failed`, or `NotChecked`; a failure takes precedence. |
| `CheckedCount` | Number of nonmissing observations checked. |
| `Scenarios` | Model/scenario/version keys, per-scenario status, and checked/missing/violation counts. |
| `Violations` | Observations outside the bounds, retaining the long-table schema. |
| `MissingRequirements` | Absent or missing-valued required coordinates; unspecified coordinates remain missing. For bounds checks, explicit missing-valued observations. |

Completeness fails when a required combination is missing. Bounds produce
`NotChecked` when evidence is absent or partly missing, unless an observed
value already violates the bounds. Zero is a valid observation. Empty frames
and empty scenario selections are `NotChecked`, never a vacuous pass. Empty
report tables retain their schemas.

Bounds do not implicitly require every unobserved year or coordinate. Use
`requireData` for coverage, and inspect both reports when both completeness
and acceptable values are needed.

## Categorization and exclusions

`categorize` reuses the bounds check and writes a text annotation only for
scenarios that pass with complete checked evidence. Failed or unchecked labels
are cleared within the selected scope; other scenarios remain unchanged. Choose
a local category name that does not shadow provider metadata.

```matlab
[reviewed, report] = frame.categorize("Review category", "Accepted", ...
    UpperBound=150, ...
    Filter=struct(variables="Emissions|CO2", units="Mt CO2/yr", strict=true));
reviewed.meta()
```

Exclusion recording is opt-in and returns a new frame without deleting data:

```matlab
[report, checked] = frame.validate(UpperBound=150, ExcludeOnFail=true, ...
    Filter=struct(variables="Emissions|CO2", units="Mt CO2/yr", strict=true));
checked.meta()
```

New flags are `1` for failed scenarios, `0` for passed ones, and `NaN` for
unchecked ones. An earlier exclusion remains set when subsequent checks run;
clear it explicitly with `setMeta` when appropriate. The reports still describe
each individual check, and the original frame and provider metadata are unchanged.
No classification changes global chart styles. GUI integration remains separate
from these programmatic operations.

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
