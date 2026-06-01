## 1. Override the OpenTelemetry version in the BOM

- [ ] 1.1 Add `<opentelemetry.version>1.60.1</opentelemetry.version>` to the `<properties>` block in `pom.xml`, near the other `*.version` entries.
- [ ] 1.2 In `<dependencyManagement><dependencies>`, add the `io.opentelemetry:opentelemetry-bom` import (`<type>pom</type>`, `<scope>import</scope>`, version `${opentelemetry.version}`) **immediately before** the `spring-boot-dependencies` import.
- [ ] 1.3 Add an inline comment on the import explaining that it overrides Spring's pinned 1.49.0 and that the ordering (before `spring-boot-dependencies`) is load-bearing.

## 2. Add the validation entry

- [ ] 2.1 In `validation/pom.xml`, add a `<dependency>` on `io.opentelemetry:opentelemetry-api` (no explicit `<version>` — inherited from the BOM) with an `<!-- opentelemetry.version -->` comment, alongside the other validation dependencies.

## 3. Verify resolution locally

- [ ] 3.1 Run `mvn -B validate` in `izgw-bom` to confirm the POM is well-formed.
- [ ] 3.2 Run `mvn -B install -N -DskipTests=true` then `mvn -B clean package -f validation/pom.xml -DskipTests=true` and confirm `io.opentelemetry:opentelemetry-api:1.60.1` resolves successfully.
- [ ] 3.3 Run `mvn install` to publish the updated `1.9.0-SNAPSHOT` to the local `~/.m2` repository.

## 4. Verify in a consumer

- [ ] 4.1 In `v2tofhir` (or another consumer), run `mvn dependency:tree -Dincludes=io.opentelemetry`.
- [ ] 4.2 Confirm `opentelemetry-api` and `opentelemetry-context` resolve to `1.60.1:compile` with **no** "version managed from 1.60.1" downgrade note.

## 5. Release follow-up (decision, not code)

- [ ] 5.1 Decide with the team whether to bump the `izgw-bom` version / cut a release so consumers can pull the override from GitHub Packages rather than relying on a local `mvn install`.
</content>
