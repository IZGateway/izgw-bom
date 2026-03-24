# Automated Maven Dependency Updates

**Status:** In Progress
**Created:** 2026-03-22  
**Estimated Effort:** TBD (see tasks.md)  
**Project:** izgw-bom

## Overview

This change introduces automated dependency update workflows for the IZ Gateway Bill of Materials (izgw-bom). Because izgw-bom is
a parent POM and BOM — not an application — its pipeline has a different character than izgw-core or izgw-hub:

- There is **no application code to compile**, no unit tests, no JARs to scan for CVEs
- The primary artifacts are **version declarations**: `<properties>` and `<dependencyManagement>` entries
- Every downstream project (`izgw-core`, `izgw-hub`, `dmi-converter`, `v2tofhir`, `cda2fhir`, …) inherits
  from this POM, so **incorrect version declarations here break all of them**
- Publishing a new BOM version is a **gating event** for downstream releases

## Workflows

### 1. Dependency Version Update (`dependency-updates.yml`)

Nightly (or on-demand) workflow that:
- Checks upstream libraries declared in `<properties>` for available newer versions
- Proposes patch/minor bumps; flags major bumps for manual review
- Runs the OWASP Dependency-Check against the **effective dependency tree** of a synthetic
  validation project that imports the BOM (see Design)
- Opens a PR with a table of proposed changes and any CVE findings

### 2. Publish and Validate (`publish.yml`)

Runs on every push and PR to `develop`, and on `workflow_dispatch`. Extends the existing
publish workflow with validation steps that run before `Build & Publish`:
- Validates the POM parses cleanly (`mvn validate`)
- Checks that all `<dependencyManagement>` versions are property-backed (no hardcoded literals)
- Resolves the synthetic validation project (`mvn dependency:resolve -f validation/pom.xml`)
  to confirm all declared versions exist in Maven Central or GitHub Packages

### 3. Release (`release.yml` / `_release_common.yml`)

Already fully implemented — no changes being made as part of this work.

## Key Differences from izgw-core CI/CD

| Aspect | izgw-core | izgw-bom |
|--------|-----------|----------|
| Build artifact | JAR | POM only |
| Tests | JUnit / JaCoCo | Synthetic validation project |
| CVE scan target | Built JAR | Effective dependency tree |
| Release trigger | Tag / manual | Manual / tag |
| Downstream impact | izgw-hub, dmi-converter | **All** IZ Gateway projects |
| Version strategy | Inherits from BOM | **Defines** versions for others |

## Non-Goals

- Automatically merging dependency update PRs without review
- Modifying versions of BOM-internal tooling (Maven plugins) automatically
- Publishing to Maven Central (GitHub Packages only)