## Why

`izgw-bom` imports `spring-boot-dependencies` (Spring Boot 3.5.14), which pins `io.opentelemetry:opentelemetry-bom` to **1.49.0**. `ca.uhn.hapi.fhir:hapi-fhir-base:8.10.0` requests OpenTelemetry **1.60.1**, but Spring's managed BOM forces it back down to 1.49.0 in every consumer (confirmed in `v2tofhir`: `opentelemetry-api:jar:1.49.0:compile (version managed from 1.60.1)`). Consumers should run a current OTel version, and the fix belongs centrally in the BOM so all consumers inherit it.

The override target is **1.62.0** (latest stable). A CVE was reported against 1.60.1 — AWS ECR image scanning flags it and names 1.62.0 as the remediation — so the override is set above both Spring's 1.49.0 and HAPI's requested 1.60.1. OpenTelemetry's API artifacts follow semver and are stable across 1.x, so the bump is low-risk.

## What Changes

- Add an `<opentelemetry.version>1.62.0</opentelemetry.version>` property to the `<properties>` block.
- Import `io.opentelemetry:opentelemetry-bom:${opentelemetry.version}` (`<type>pom</type>`, `<scope>import</scope>`) in `<dependencyManagement>` **immediately before** the `spring-boot-dependencies` import. Declaration order is load-bearing: with two imported BOMs the first-declared wins, so this entry must precede Spring's to override 1.49.0.
- A bare property override does **not** work here: `izgw-bom` does not extend `spring-boot-starter-parent`, so Spring Boot's property-override mechanism never fires (the same gotcha documented in the existing log4j2 comment). The BOM-import-ordering approach is the reliable fix.
- Add a matching `opentelemetry-api` (and/or `opentelemetry-context`) dependency to `validation/pom.xml` with an `<!-- opentelemetry.version -->` comment, so the new version is resolution-checked and CVE-scanned by CI like every other managed version.

## Capabilities

### New Capabilities
- `opentelemetry-version-override`: Centrally overrides the OpenTelemetry version that `spring-boot-dependencies` pins, by importing a newer `opentelemetry-bom` ahead of the Spring import so all OTel modules resolve to the BOM-controlled version across consumers.

### Modified Capabilities
<!-- None: no existing spec's requirements change. -->

## Impact

- **`izgw-bom/pom.xml`**: new version property + new `opentelemetry-bom` import (order-sensitive, before `spring-boot-dependencies`).
- **`validation/pom.xml`**: new dependency entry so the version is resolved and CVE-scanned in CI.
- **All consumers** (e.g. `v2tofhir`, `xform`) inherit OTel 1.62.0 once the updated `1.9.0-SNAPSHOT` is installed/published; no consumer pom changes required.
- **Dependencies**: `io.opentelemetry:*` bumped 1.49.0 → 1.62.0 (above HAPI's requested 1.60.1; semver-compatible within 1.x; low risk). Note: the separate `io.opentelemetry.instrumentation:*` group (e.g. `opentelemetry-instrumentation-annotations`) is **not** governed by `opentelemetry-bom` and is unaffected by this change.
- **Release/automation**: consumers pulling from GitHub Packages (vs. a local `mvn install`) need a published BOM snapshot/release; OTel is not property-backed in the automation's per-property sense but the import is governed by `${opentelemetry.version}`.
