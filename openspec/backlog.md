# Backlog

Future enhancements to consider for the dependency update automation.

## Major-version update reporting

The nightly dependency update workflow currently only applies patch/minor bumps. It does not
detect or report when a major version is available for a library. A future enhancement could
run `versions:display-property-updates -DallowMajorUpdates=true -DallowMinorUpdates=false`
and include the results in the PR body under a "manual review required" section.

## Plugin update reporting in PR body

The workflow already runs `versions:display-plugin-updates` to detect available plugin version
bumps, but the results are only visible in the workflow logs. A future enhancement could add
a section to the PR body template showing available plugin updates (not applied, informational
only).

## Excluded library version visibility

The PR body currently lists excluded libraries by name only (from `automation-exclusions.txt`).
A future enhancement could run `versions:display-property-updates` scoped to only the excluded
libraries and show their current vs latest available version in the PR, so reviewers can see
at a glance whether a manual bump is worth investigating.
