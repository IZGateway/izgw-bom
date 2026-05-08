## Why

The release workflow leaves `validation/pom.xml` out of sync with the root `pom.xml` after every standard release: the snapshot-bump step on `develop` updates only the root pom, leaving the validation pom's `<parent><version>` pointing at the just-cut release version. The next `dependency-updates.yml` run then fails with `Non-resolvable parent POM ... gov.cdc.izgw:izgw-bom:pom:<release>`, because the workflow's local Maven repo holds only the new SNAPSHOT and Maven Central does not host this private artifact. The 1.7.0 release reproduced this on 2026-05-07 and broke the 2026-05-08 nightly run.

The root cause is `mvn versions:update-parent`: the plugin treats `-DparentVersion` as a version range and queries remote repositories for satisfying candidates. The just-installed local snapshot is not advertised remotely, so the plugin silently reports "nothing to update" and exits 0. The follow-up `git commit` captures only the root pom change. The release-version invocation succeeds for unrelated reasons (release-handling code path), masking the bug until the snapshot step.

## What Changes

- Replace the SNAPSHOT-bump invocation of `mvn versions:update-parent` in `.github/workflows/_release_common.yml` with a direct XML edit of `validation/pom.xml`'s `<parent><version>`, using a tool that does not depend on remote metadata (xmlstarlet, already available on the GitHub-hosted runner).
- Apply the same direct-edit approach to the release-version invocation, for consistency and to remove the asymmetry between the two steps.
- Add a post-edit verification step that reads back `validation/pom.xml`'s parent version and fails the workflow if it does not match the expected target, so any future regression surfaces during the release run rather than days later in the nightly job.
- No change to the `dependency-updates.yml` workflow itself — once the release workflow stops emitting a stale validation pom, the nightly job will resolve correctly.

## Capabilities

### New Capabilities

- `release-parent-version-sync`: Behavior of the standard and hotfix release workflows for keeping `validation/pom.xml`'s `<parent><version>` synchronized with the root `pom.xml` `<version>` across both the release-version and next-snapshot bump steps, including verification that each bump actually took effect.

### Modified Capabilities

_None — no existing spec covers this behavior._

## Impact

- **Workflow**: `.github/workflows/_release_common.yml` is modified. Used by both `release.yml` (standard) and `hotfix.yml` (hotfix) — both paths inherit the fix.
- **Files at runtime**: After a release, `validation/pom.xml`'s `<parent><version>` reliably tracks the root pom version (release version on the release branch and main; next SNAPSHOT on develop).
- **Downstream**: `dependency-updates.yml` resumes successfully on the first nightly run after a release, with no changes required to that workflow.
- **Consumers of the BOM**: No effect on the published BOM artifact. The validation pom is never published.
