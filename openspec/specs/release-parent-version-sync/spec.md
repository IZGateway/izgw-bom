### Requirement: Release-version step synchronizes validation pom parent

After the release-version preparation step in either the standard or hotfix release workflow, `validation/pom.xml`'s `<parent><version>` SHALL equal the release version passed to the workflow, and the resulting commit SHALL include both `pom.xml` and `validation/pom.xml` in its diff.

#### Scenario: Standard release version preparation
- **WHEN** the standard release workflow runs with release version `X.Y.Z` and the develop branch's `validation/pom.xml` `<parent><version>` was previously a different value (e.g. `X.Y.Z-SNAPSHOT`)
- **THEN** the workflow's "prepare release" commit SHALL set `validation/pom.xml`'s `<parent><version>` to `X.Y.Z`
- **AND** the commit SHALL list both `pom.xml` and `validation/pom.xml` as modified files

#### Scenario: Hotfix release version preparation
- **WHEN** the hotfix release workflow runs with release version `X.Y.Z` from a `hotfix/*` branch
- **THEN** the workflow's "prepare release" commit SHALL set `validation/pom.xml`'s `<parent><version>` to `X.Y.Z`
- **AND** the commit SHALL list both `pom.xml` and `validation/pom.xml` as modified files

### Requirement: Next-snapshot bump synchronizes validation pom parent

After the next-snapshot bump step on the develop branch in a standard release, `validation/pom.xml`'s `<parent><version>` SHALL equal the next-snapshot version, and the resulting commit SHALL include both `pom.xml` and `validation/pom.xml` in its diff.

#### Scenario: Auto-calculated next snapshot
- **WHEN** the standard release workflow completes a release of `X.Y.Z` with no explicit `next-snapshot-version` input
- **THEN** the workflow's "bump version" commit SHALL set `validation/pom.xml`'s `<parent><version>` to `X.(Y+1).0-SNAPSHOT`
- **AND** the commit SHALL list both `pom.xml` and `validation/pom.xml` as modified files

#### Scenario: Explicit next snapshot
- **WHEN** the standard release workflow completes a release of `X.Y.Z` with explicit `next-snapshot-version` input `A.B.C` (with or without a `-SNAPSHOT` suffix)
- **THEN** the workflow's "bump version" commit SHALL set `validation/pom.xml`'s `<parent><version>` to `A.B.C-SNAPSHOT`
- **AND** the commit SHALL list both `pom.xml` and `validation/pom.xml` as modified files

#### Scenario: Hotfix release skips snapshot bump
- **WHEN** the hotfix release workflow completes
- **THEN** no "bump version" commit SHALL be produced on develop
- **AND** the requirement SHALL NOT apply to hotfix releases

### Requirement: Sync mechanism does not depend on remote metadata

The mechanism that sets `validation/pom.xml`'s `<parent><version>` SHALL succeed regardless of whether the target version is published to Maven Central, GitHub Packages, or any other remote repository at the moment of execution.

#### Scenario: Target version exists only in local repository
- **WHEN** the sync mechanism is invoked with a target version that has been installed to the runner's `~/.m2` repository but has not been deployed to any remote repository (typical for the just-set next-snapshot)
- **THEN** the sync SHALL update `validation/pom.xml`'s `<parent><version>` to the target version

#### Scenario: Target version not present anywhere
- **WHEN** the sync mechanism is invoked with a target version that exists nowhere yet (neither local nor remote)
- **THEN** the sync SHALL still update `validation/pom.xml`'s `<parent><version>` to the target version, because the mechanism operates as a literal text edit and does not query any repository

### Requirement: Sync step verifies post-edit state and fails loudly on mismatch

After each sync invocation, the workflow SHALL read back `validation/pom.xml`'s `<parent><version>` and compare it to the intended target. If the value does not match, the workflow SHALL exit with a non-zero status code and emit an error message identifying the expected and actual versions, before any subsequent step (commit, push, deploy) executes.

#### Scenario: Sync took effect
- **WHEN** the sync step has run and `validation/pom.xml`'s `<parent><version>` now equals the intended target `T`
- **THEN** the workflow SHALL log a confirmation that the value matches `T`
- **AND** the workflow SHALL proceed to the next step

#### Scenario: Sync silently failed
- **WHEN** the sync step has run but `validation/pom.xml`'s `<parent><version>` does not equal the intended target `T`
- **THEN** the workflow SHALL exit with a non-zero status code
- **AND** the error output SHALL include both the expected value `T` and the actual value found in the file
- **AND** no subsequent step (commit, push, merge, deploy, tag, release) SHALL execute
