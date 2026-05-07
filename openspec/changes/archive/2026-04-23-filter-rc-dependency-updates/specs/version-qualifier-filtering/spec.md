## ADDED Requirements

### Requirement: Pre-release version exclusion rules file
The project SHALL include a Maven Versions Plugin rules XML file at `versions-rules.xml` (project root, co-located with `automation-exclusions.txt`) that defines global `ignoreVersion` patterns for pre-release version qualifiers. The rules file SHALL use the Maven Versions Plugin `ruleset` XML schema and contain regex-based ignore patterns covering at minimum the following qualifier families: RC, alpha, beta, milestone (M), SNAPSHOT, and CR (candidate release). All patterns SHALL be case-insensitive.

#### Scenario: Rules file excludes RC versions
- **WHEN** the Maven Versions Plugin evaluates version `4.35.0-RC1` against the rules file
- **THEN** the version SHALL be ignored and not proposed as an update candidate

#### Scenario: Rules file excludes alpha versions
- **WHEN** the Maven Versions Plugin evaluates version `2.0.0-alpha1` against the rules file
- **THEN** the version SHALL be ignored and not proposed as an update candidate

#### Scenario: Rules file excludes beta versions
- **WHEN** the Maven Versions Plugin evaluates version `3.1.0-beta2` against the rules file
- **THEN** the version SHALL be ignored and not proposed as an update candidate

#### Scenario: Rules file excludes milestone versions
- **WHEN** the Maven Versions Plugin evaluates version `5.0.0-M3` against the rules file
- **THEN** the version SHALL be ignored and not proposed as an update candidate

#### Scenario: Rules file excludes SNAPSHOT versions
- **WHEN** the Maven Versions Plugin evaluates version `1.2.3-SNAPSHOT` against the rules file
- **THEN** the version SHALL be ignored and not proposed as an update candidate

#### Scenario: Rules file excludes CR versions
- **WHEN** the Maven Versions Plugin evaluates version `6.0.0.cr1` against the rules file
- **THEN** the version SHALL be ignored and not proposed as an update candidate

#### Scenario: Rules file allows stable releases
- **WHEN** the Maven Versions Plugin evaluates version `4.34.1` against the rules file
- **THEN** the version SHALL NOT be ignored and SHALL be considered as a valid update candidate

#### Scenario: Rules file allows Final-qualified releases
- **WHEN** the Maven Versions Plugin evaluates version `5.6.15.Final` against the rules file
- **THEN** the version SHALL NOT be ignored and SHALL be considered as a valid update candidate

#### Scenario: Case-insensitive qualifier matching
- **WHEN** the Maven Versions Plugin evaluates versions `4.35.0-RC1`, `4.35.0-rc1`, and `4.35.0-Rc1` against the rules file
- **THEN** all three versions SHALL be ignored regardless of qualifier casing

### Requirement: Plugin configuration of rules file
The `versions-maven-plugin` configuration in `pom.xml` and `validation/pom.xml` SHALL include a `<rulesUri>` element referencing `versions-rules.xml` at the project root. This ensures all `mvn versions:*` goals — including `versions:display-property-updates`, `versions:display-plugin-updates`, `versions:display-dependency-updates`, and `versions:update-properties` — apply the rules file automatically without requiring `-DrulesUri` CLI flags in the workflow.

#### Scenario: Property update detection excludes pre-release versions
- **WHEN** the `versions:display-property-updates` goal runs
- **THEN** it SHALL apply the rules from `versions-rules.xml` via the pom.xml plugin configuration
- **AND** pre-release versions SHALL not appear in the reported available updates

#### Scenario: Plugin update detection excludes pre-release versions
- **WHEN** the `versions:display-plugin-updates` goal runs
- **THEN** it SHALL apply the rules from `versions-rules.xml` via the pom.xml plugin configuration
- **AND** pre-release versions SHALL not appear in the reported available updates

#### Scenario: Dependency update detection excludes pre-release versions
- **WHEN** the `versions:display-dependency-updates` goal runs
- **THEN** it SHALL apply the rules from `versions-rules.xml` via the pom.xml plugin configuration
- **AND** pre-release versions SHALL not appear in the reported available updates

#### Scenario: Property update application excludes pre-release versions
- **WHEN** the `versions:update-properties` goal runs
- **THEN** it SHALL apply the rules from `versions-rules.xml` via the pom.xml plugin configuration
- **AND** no pre-release versions SHALL be written into `pom.xml` properties

### Requirement: Coexistence with artifact-level exclusions
The version qualifier filtering mechanism SHALL operate independently of and alongside the existing `automation-exclusions.txt` artifact-level exclusion mechanism. The `-Dexcludes` parameter SHALL continue to be passed where it is currently used. Both filtering mechanisms SHALL be applied simultaneously — an artifact excluded by `automation-exclusions.txt` remains excluded, and a pre-release version filtered by the rules file remains filtered, regardless of the other mechanism.

#### Scenario: Excluded artifact with RC version available
- **WHEN** an artifact is listed in `automation-exclusions.txt` AND a new RC version exists for it
- **THEN** the artifact SHALL be excluded by `-Dexcludes` (artifact-level) AND the RC version SHALL also be ignored by the rules file (qualifier-level)
- **AND** neither mechanism SHALL interfere with the other

#### Scenario: Non-excluded artifact with only RC version available
- **WHEN** an artifact is NOT in `automation-exclusions.txt` AND the only newer version available is an RC
- **THEN** the rules file SHALL filter out the RC version
- **AND** no update SHALL be proposed for that artifact
