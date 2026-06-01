## ADDED Requirements

### Requirement: OpenTelemetry version is centrally overridden to 1.62.0

The BOM SHALL manage all `io.opentelemetry:*` modules at version **1.62.0**, overriding both the version pinned transitively by the imported `spring-boot-dependencies` BOM (1.49.0) and the version requested by `hapi-fhir-base` (1.60.1). The version MUST be expressed through a `${opentelemetry.version}` property declared in the `<properties>` block, consistent with the BOM's property-backed-version invariant.

#### Scenario: Consumer resolves the overridden OpenTelemetry version

- **WHEN** a consumer of `izgw-bom` runs `mvn dependency:tree -Dincludes=io.opentelemetry`
- **THEN** `io.opentelemetry:opentelemetry-api` and `io.opentelemetry:opentelemetry-context` resolve to `1.62.0`
- **AND** no "version managed" downgrade note is present

#### Scenario: Version is property-backed

- **WHEN** the `opentelemetry-bom` import is read in `pom.xml`
- **THEN** its `<version>` is the `${opentelemetry.version}` property reference, not a hardcoded literal
- **AND** `<opentelemetry.version>1.62.0</opentelemetry.version>` is declared in the `<properties>` block

### Requirement: The opentelemetry-bom import precedes the spring-boot-dependencies import

The `io.opentelemetry:opentelemetry-bom` import (`<type>pom</type>`, `<scope>import</scope>`) SHALL be declared in `<dependencyManagement>` **before** the `spring-boot-dependencies` import, because for competing imported BOMs the first-declared import wins version resolution. The entry MUST carry a comment explaining that the ordering is load-bearing.

#### Scenario: Declaration order makes the override authoritative

- **WHEN** the `<dependencyManagement>` block is inspected
- **THEN** the `opentelemetry-bom` import appears earlier in declaration order than the `spring-boot-dependencies` import

#### Scenario: Reordering reverts the override

- **WHEN** the `opentelemetry-bom` import is moved to after `spring-boot-dependencies` (or removed)
- **THEN** OpenTelemetry resolves back to the Spring-pinned 1.49.0
- **AND** this regression is detectable via `mvn dependency:tree -Dincludes=io.opentelemetry`

### Requirement: The overridden version is verified by the validation module

The validation module (`validation/pom.xml`) SHALL declare a dependency on `io.opentelemetry:opentelemetry-api` (version inherited from the BOM) with an `<!-- opentelemetry.version -->` comment, so the overridden version is resolution-checked and CVE-scanned by CI like every other managed version.

#### Scenario: CI resolves the OpenTelemetry artifact

- **WHEN** CI runs `mvn -B clean package -f validation/pom.xml`
- **THEN** `io.opentelemetry:opentelemetry-api:1.62.0` resolves successfully from the configured repositories
- **AND** the OWASP Dependency-Check scan includes the resolved OpenTelemetry JAR
</content>
