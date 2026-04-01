## Automated Dependency Updates

This PR was created automatically by the `Automated Dependency Updates` workflow.

### Version Changes (property-backed)

$CHANGES_TABLE

### Transitive Dependencies Auto-fixed

$AUTO_FIXED_TRANSITIVES

> These transitives had no existing property override. A new `<properties>` entry and
> `<dependencyManagement>` entry were added automatically for each.

### Transitives Requiring Manual Action

$MANUAL_TRANSITIVES

> These could not be patched automatically. Each requires a manual `<properties>` entry
> and `<dependencyManagement>` entry in the BOM.

### Dependency Tree Changes

$TREE_DIFF_SUMMARY

### Excluded Libraries (not updated automatically)

$EXCLUDED_REPORT

> These libraries require manual review before upgrading. Check for major version bumps or certification requirements.

### CVE Scan Results

| Phase | Result |
|-------|--------|
| Pre-update | $CVE_SUMMARY_PRE |
| Post-update | $CVE_SUMMARY_POST |

> See the `dependency-check-report-pre-update` and `dependency-check-report-post-update` artifacts for full details.

### Notes
- Only patch and minor version bumps are applied automatically (`allowMajorUpdates=false`).
- All updated versions have been verified to resolve via `mvn dependency:resolve` on the validation project.
- Transitives that could not be auto-fixed are flagged above and require a manual BOM entry.
