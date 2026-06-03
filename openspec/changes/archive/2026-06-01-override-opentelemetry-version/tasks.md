## 1. Override the OpenTelemetry version in the BOM

- [x] 1.1 Add `<opentelemetry.version>1.62.0</opentelemetry.version>` to the `<properties>` block in `pom.xml`, near the other `*.version` entries. (Latest stable; clears the CVE AWS ECR flagged against 1.60.1.)
- [x] 1.2 In `<dependencyManagement><dependencies>`, add the `io.opentelemetry:opentelemetry-bom` import (`<type>pom</type>`, `<scope>import</scope>`, version `${opentelemetry.version}`) **immediately before** the `spring-boot-dependencies` import.
- [x] 1.3 Add an inline comment on the import explaining that it overrides Spring's pinned 1.49.0 and that the ordering (before `spring-boot-dependencies`) is load-bearing.

## 2. Add the validation entry

- [x] 2.1 In `validation/pom.xml`, add a `<dependency>` on `io.opentelemetry:opentelemetry-api` (no explicit `<version>` — inherited from the BOM) with an `<!-- opentelemetry.version -->` comment, alongside the other validation dependencies.

## 3. Verify resolution locally

- [x] 3.1 Run `mvn -B validate` in `izgw-bom` to confirm the POM is well-formed.
- [x] 3.2 Run `mvn -B install -N -DskipTests=true` then `mvn -B clean package -f validation/pom.xml -DskipTests=true` and confirm `io.opentelemetry:opentelemetry-api:1.62.0` resolves successfully.
- [x] 3.3 Run `mvn install` to publish the updated `1.9.0-SNAPSHOT` to the local `~/.m2` repository.

## 4. Verify in a consumer

- [x] 4.1 In `v2tofhir` (or another consumer), run `mvn dependency:tree -Dincludes=io.opentelemetry`.
- [x] 4.2 Confirm `opentelemetry-api` and `opentelemetry-context` resolve to `1.62.0:compile` with **no** "version managed" downgrade note.
