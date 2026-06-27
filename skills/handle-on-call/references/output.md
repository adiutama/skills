# Triage output format

Write the full report to `report_path` from session JSON.

## Header

```text
# On-call triage — <one-line summary>
Incident: <incident_id>
Source: <slack_url or "pasted alert">
```

## Sections

```text
## What happened
<facts from alert + investigation — no speculation yet>

## Likely cause
<best current hypothesis>

## Proposed action
<fix in code | runbook step | config change | need more info>

## Risk / blast radius
<who is affected, rollback plan if fix goes wrong>

## Recommendation
fix | skip | need-info

## If fix — plan
1. …
2. …

## If skip — reason
<why not acting + what to tell reporter>
```

Present this to the user and ask once:

```text
Proceed?
- fix
- skip
- need-info (what's missing?)
```

Record choice in tracker **Decision** and timeline **confirm** row.
