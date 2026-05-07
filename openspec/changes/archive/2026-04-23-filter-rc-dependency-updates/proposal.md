## Why

The automated dependency update workflow (`dependency-updates.yml`) uses the Maven Versions Plugin to bump dependency versions nightly. Currently, it accepts any non-major version update — including release candidates (e.g., `4.35.0-RC1`), alphas, betas, and milestones. This has caused the workflow to propose updates to unstable pre-release versions (e.g., `protobuf-java` `4.34.1` → `4.35.0-RC1`), which are not suitable for production use and should never be merged automatically.

## What Changes

- Add a Maven Versions Plugin **rules configuration file** that defines version qualifier exclusion patterns (e.g., `-RC*`, `-alpha*`, `-beta*`, `-M*`, `-SNAPSHOT`).
- Update all `mvn versions:*` invocations in `dependency-updates.yml` to reference the rules file via `-DrulesUri`, ensuring pre-release versions are ignored during both detection and update phases.
- The existing `automation-exclusions.txt` mechanism (which excludes entire artifacts) remains unchanged and continues to work alongside this new version-qualifier filtering.

## Capabilities

### New Capabilities
- `version-qualifier-filtering`: Defines the rules for excluding pre-release version qualifiers (RC, alpha, beta, milestone, snapshot) from the automated dependency update process via a Maven Versions Plugin rules XML configuration.

### Modified Capabilities
_None — no existing spec-level requirements are changing. The exclusion-list mechanism is unaffected._

## Impact

- **Files changed**: `.github/workflows/dependency-updates.yml`, plus a new Maven Versions rules XML file (e.g., `.github/versions-rules.xml`)
- **Behavior change**: The workflow will no longer propose updates to versions containing pre-release qualifiers. Only stable releases will be considered.
- **Risk**: Low — this is an additive filter. If the rules file is misconfigured, the worst case is that some valid updates are skipped, which would be caught in review.
- **No breaking changes** to the BOM itself, downstream consumers, or the existing exclusion-list mechanism.
