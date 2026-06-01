## Context

`izgw-bom` imports `org.springframework.boot:spring-boot-dependencies` (3.5.14) with `<scope>import</scope>`. That BOM declares `<opentelemetry.version>1.49.0</opentelemetry.version>` and imports `io.opentelemetry:opentelemetry-bom:1.49.0`, so every OTel artifact is managed to 1.49.0 in all consumers.

`ca.uhn.hapi.fhir:hapi-fhir-base:8.10.0` (managed by this BOM) was built against OpenTelemetry 1.60.1 and requests it transitively, but Maven's dependencyManagement wins: consumers resolve `opentelemetry-api:jar:1.49.0:compile (version managed from 1.60.1)`. This was confirmed in `v2tofhir` via `mvn dependency:tree -Dincludes=io.opentelemetry`.

Constraints:
- `izgw-bom` is `<packaging>pom</packaging>` and does **not** extend `spring-boot-starter-parent`. The Spring Boot property-override mechanism (where redefining `<opentelemetry.version>` in a child of the starter parent retroactively changes the imported BOM) therefore never fires here. This is the same gotcha already documented inline for log4j2 in `pom.xml`.
- The BOM's invariant requires every managed version to be `${property}`-backed, and the validation module must carry one dependency per version property so CI resolves and CVE-scans it.

## Goals / Non-Goals

**Goals:**
- Make all `io.opentelemetry:*` modules resolve to **1.62.0** (latest stable; clears the CVE AWS ECR reported against 1.60.1) in every consumer of `izgw-bom`, with no per-consumer pom changes.
- Keep the override `${property}`-backed and CI-verified (resolution + CVE scan) like every other managed version.
- Keep all OTel modules version-aligned automatically (avoid drift between `opentelemetry-api`, `-context`, etc.).

**Non-Goals:**
- Overriding the separate `io.opentelemetry.instrumentation:*` group (e.g. `opentelemetry-instrumentation-annotations`), which is not governed by `opentelemetry-bom`.
- Changing `v2tofhir` or any other consumer pom.
- Adding OTel instrumentation, agents, or runtime configuration — this is purely dependency-version management.
- Bumping the `izgw-bom` artifact version or triggering a release (handled by the team's release process separately).

## Decisions

### Decision: Import `opentelemetry-bom` ahead of `spring-boot-dependencies`

Add `<opentelemetry.version>1.62.0</opentelemetry.version>` to `<properties>` and import `io.opentelemetry:opentelemetry-bom:${opentelemetry.version}` (`type=pom`, `scope=import`) in `<dependencyManagement>` **immediately before** the `spring-boot-dependencies` import.

**Rationale:** When two imported BOMs manage the same artifacts, Maven resolves the version from the **first-declared** import ("nearest/first wins" for imports in declaration order). Declaring `opentelemetry-bom` first makes 1.62.0 authoritative; Spring's later import of 1.49.0 is then a no-op for OTel. This keeps all OTel modules aligned through a single BOM and is future-proof as new OTel modules appear.

**Alternatives considered:**
- **Bare `<opentelemetry.version>` property override** — Rejected. Does not work without `spring-boot-starter-parent`; the property is never consulted by the already-imported `spring-boot-dependencies`.
- **Explicit per-artifact `dependencyManagement` entries** (the log4j2 pattern in this pom) — Works and is order-independent, but requires enumerating and maintaining every OTel artifact the tree pulls in. Rejected as more brittle/verbose than a single BOM import; the BOM import keeps modules aligned automatically.

### Decision: Target version 1.62.0

Initially targeted 1.60.1 (exactly what `hapi-fhir-base:8.10.0` was built against). A CVE was subsequently reported against 1.60.1 and AWS ECR image scanning named **1.62.0** (latest stable) as the remediation, so the target was raised to 1.62.0. `opentelemetry-api` follows semver and is API-stable across 1.x, so the bump above HAPI's requested 1.60.1 is low-risk; the BOM import forces every OTel module up together regardless of what HAPI requests.

### Decision: Add a validation entry

Add `io.opentelemetry:opentelemetry-api` (the core artifact) to `validation/pom.xml` with an `<!-- opentelemetry.version -->` comment and no explicit version (inherited from the BOM). This upholds the repo convention that every managed version property has a corresponding validation dependency, so the new 1.62.0 version is resolution-checked and OWASP-scanned in CI.

## Risks / Trade-offs

- **Ordering regression** → A future edit that moves the `opentelemetry-bom` import after `spring-boot-dependencies` (or removes it) silently reverts OTel to 1.49.0. Mitigation: an inline comment on the import explaining the ordering requirement, and a spec requirement asserting the order; verification step (`dependency:tree`) catches it.
- **Spring/OTel API skew** → Spring Boot 3.5.14 was tested against OTel 1.49.0; forcing 1.62.0 could in theory surface an incompatibility in Spring's OTel-touching autoconfig. Mitigation: HAPI already requires 1.60.1 in the same tree and 1.62.0 is only two minors above it, OTel 1.x is API-stable, and CI resolution + the consumer `dependency:tree` check validate the resolved graph.
- **Consumers on GitHub Packages vs. local install** → Local `mvn install` only updates the consumer's `~/.m2`; consumers pulling the BOM from GitHub Packages need a published `1.9.0-SNAPSHOT` (or release) to see the change. Mitigation: note in the proposal/tasks; defer the version-bump/release decision to the team's process.

## Migration Plan

1. Edit `izgw-bom/pom.xml` (property + ordered BOM import) and `validation/pom.xml` (validation dependency).
2. `mvn -B validate` then `mvn -B install -N` and `mvn -B clean package -f validation/pom.xml` to confirm resolution.
3. `mvn install` to publish `1.9.0-SNAPSHOT` to local `~/.m2`.
4. In a consumer (`v2tofhir`, `xform`): `mvn dependency:tree -Dincludes=io.opentelemetry` → expect `1.62.0:compile` with no "version managed" downgrade note.
5. Rollback: revert the two pom edits; no state migration is involved.

## Open Questions

- Should the `izgw-bom` version be bumped / a release cut so consumers can pull the override from GitHub Packages rather than relying on a local install? Deferred to the team's release/automation process.
