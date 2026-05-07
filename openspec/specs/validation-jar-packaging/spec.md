# Spec: Validation JAR Packaging

## Purpose

Defines how the `validation` Maven module is packaged so that the CI workflow can
resolve and copy all runtime transitive dependencies for OWASP Dependency-Check scanning,
without publishing any artifacts to GitHub Packages.

## Requirements

### Requirement: JAR packaging for validation module
`validation/pom.xml` MUST declare `<packaging>jar</packaging>` so that Maven resolves and
copies runtime-scoped transitive dependencies during the CI publish workflow.

#### Scenario: dependency:copy-dependencies resolves JARs
- **WHEN** `mvn dependency:copy-dependencies -DincludeScope=runtime` is run against the
  validation module
- **THEN** all runtime-scoped transitive dependencies are copied to
  `validation/target/dependency/`
- **AND** the directory is non-empty

#### Scenario: Validation module is never deployed
- **WHEN** `mvn deploy` is run (either standalone or as part of the parent build)
- **THEN** the `maven-deploy-plugin` skips the validation module (`<skip>true</skip>`)
- **AND** no artifact is published to GitHub Packages

---

### Requirement: Marker class for JAR compilation
A minimal Java source file MUST exist at
`validation/src/main/java/gov/cdc/izgw/validation/BomValidation.java` to satisfy the
Maven compiler for `jar` packaging.

#### Scenario: BomValidation compiles without errors
- **WHEN** `mvn clean package -f validation/pom.xml` is run
- **THEN** the build succeeds with no compilation errors
- **AND** `validation/target/izgw-bom-validation-*.jar` is produced

#### Scenario: BomValidation carries explanatory Javadoc
- **WHEN** a developer opens `BomValidation.java`
- **THEN** the class Javadoc clearly states that the module exists for CI validation only
  and is never published or deployed

---

### Requirement: Runtime-only dependency scope for CVE scan
The `dependency:copy-dependencies` invocation in `publish.yml` MUST pass
`-DincludeScope=runtime` to exclude test-scoped dependencies from the scan path.

#### Scenario: Test JARs are excluded from scan
- **WHEN** the CI workflow runs `dependency:copy-dependencies`
- **THEN** JARs with scope `test` (e.g., JUnit, Mockito) are not copied to
  `target/dependency/`
- **AND** the OWASP scan does not report findings against test-only artifacts

---

### Requirement: Clean build in CI workflow
The Maven invocation that builds the validation module in `publish.yml` MUST include the
`clean` lifecycle phase.

#### Scenario: Stale build artefacts are removed
- **WHEN** the CI workflow runs the build step
- **THEN** any previously compiled class files are removed before compilation begins
