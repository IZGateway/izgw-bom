# Proposal: Automated Maven Dependency Updates

## Why

`izgw-bom` is the Bill of Materials POM that every IZ Gateway project inherits from. It centralizes
version declarations for 60+ libraries. Today there is no automated process to:

1. **Detect stale or vulnerable versions** — library updates and CVEs must be noticed and applied manually
2. **Validate BOM changes** — nothing prevents a malformed or unresolvable version declaration from being merged
3. **Release new BOM versions** — the release process is undocumented and fully manual, creating bottlenecks
   and risking version drift between the tag, the published artifact, and the next snapshot

Because every downstream project gates its own dependency versions on the BOM, these gaps compound: a CVE
left unaddressed in the BOM propagates to every service until a developer notices and manually opens PRs
across multiple repositories.

## What Changes

Three GitHub Actions workflows are introduced, plus a lightweight synthetic validation project.

### Workflow 1 — Publish & Validation (`publish.yml`)

Runs on every push to `develop`, every PR targeting `develop`, and via `workflow_dispatch`. The
existing `publish.yml` is extended with validation steps that run **before** the `Build & Publish`
step, ensuring a bad POM is never published:

- Runs `mvn validate` on the root POM to catch XML/schema errors
- Runs `mvn dependency:resolve` on the synthetic validation project to confirm every declared version
  resolves from Maven Central or GitHub Packages (catches typos and yanked versions)
- Fails if any `<dependency>` version in `<dependencyManagement>` is a hardcoded literal rather than
  a `${property}` reference — enforcing the property-backed convention

### Workflow 2 — Nightly Dependency Updates (`dependency-updates.yml`)

Triggered on schedule (Mon–Fri, ~4 AM ET) and via `workflow_dispatch`.

- Uses `versions-maven-plugin` (`display-property-updates`) to enumerate available upgrades for each
  `<property>` that pins a library version — **this only works if versions are property-backed** (see below)
- Reads `automation-exclusions.txt` to build the `excludes` list passed to the plugin — any
  `groupId:artifactId` listed there is skipped entirely
- **Patch and minor** bumps: applied automatically to a branch, validated, then opened as a PR
- **Major** bumps: listed in the PR description as "manual review required" items — never auto-applied
- Runs OWASP Dependency-Check against the synthetic validation project's effective dependency tree
  to identify CVE-affected libraries; CVE findings are included in the PR body
- PR includes: version bump table, CVE summary, links to changelogs/release notes where available
- If no updates are found and no CVEs exist: workflow exits cleanly with no PR

### Workflow 3 — Release (`release.yml` / `_release_common.yml`)

Already fully implemented — **no changes are being made**. The existing workflows handle the
complete BOM release lifecycle (validate, set version, tag, publish to GitHub Packages, advance
to next snapshot).

## Synthetic Validation Project

Because a BOM-only POM produces no compiled output, validation requires a small companion project
checked into the repository (`validation/pom.xml`) that **resolves — but does not compile — a
representative set of dependencies**.

**What it does:**
- Declares `izgw-bom` as its parent
- Declares one representative `<dependency>` from each major library group in `<dependencyManagement>`
  (Spring Boot, Spring Framework, HAPI FHIR, HAPI V2, Jackson, Netty, Commons, Logging, etc.)
- Has **no `src/` directory** — there is nothing to compile
- Running `mvn dependency:resolve` downloads the declared JARs (or confirms they are cached),
  proving that every version resolves to a real artifact
- Running `mvn dependency:tree` produces the full transitive tree used by OWASP Dependency-Check

**What it does NOT do:**
- Compile any code
- Run any tests
- Produce a JAR or any publishable artifact

It is used by all three workflows but is never deployed or released.

## Design Decisions

### OWASP Dependency-Check: GitHub Action vs Maven Plugin

**Decision:** Use `dependency-check/Dependency-Check_Action` (GitHub Action) rather than the
`dependency-check-maven` Maven plugin for CVE scanning in the dependency update workflow.

**Rationale:**

| Concern | Maven Plugin | GitHub Action |
|---------|-------------|---------------|
| NVD database freshness | Downloaded at build time — can be hours/days stale | Updated nightly on GitHub's infrastructure |
| Build time | Adds 3–10 minutes to every Maven build | Runs as a separate parallel step; does not slow `mvn` |
| Scan target | Scans whatever Maven resolves at build time | Scans the `validation/` dependency tree directly via `mvn dependency:tree` output |
| Configuration | Bound to Maven lifecycle; harder to conditionally skip | Independently configurable; easy to `continue-on-error` without affecting build result |
| Suppression file | `dependency-suppression.xml` passed via plugin config | Same file passed via `--suppression` arg — identical coverage |

The GitHub Action approach follows the pattern already established in `izgw-hub` and recommended
in the `izgw-core` auto-update-dependencies design.

The Maven plugin (`dependency-check-maven`) **remains in `pom.xml`** for local developer use and
is skipped in CI via `-DskipDependencyCheck=true` on all `mvn` invocations in the workflows.

## Property-backed Versions

`versions-maven-plugin display-property-updates` can only detect updates for versions expressed
as `${property}` references. Any `<dependency>` in `<dependencyManagement>` with a hardcoded
literal version string is **invisible to the update workflow**.

Currently the Bouncy Castle FIPS libraries (`bc-fips`, `bcpkix-fips`, `bctls-fips`) have hardcoded
versions. As a prerequisite to the dependency update workflow, **all versions in
`<dependencyManagement>` must be backed by a `<property>`**. The PR validation workflow will
enforce this going forward.

For FIPS libraries specifically: once property-backed, they are added to `automation-exclusions.txt`
so they are tracked (visible in `display-property-updates` output) but never auto-updated.

## Configurable Automation Exclusions

A plain-text file `automation-exclusions.txt` at the repository root controls which
`groupId:artifactId` patterns are excluded from automatic version bumping.

Format:
```
# Lines starting with # are comments
# Format: groupId:artifactId  (glob * supported for artifactId)

# Bouncy Castle FIPS — must be manually reviewed for FIPS 140-2 certification
org.bouncycastle:bc-fips
org.bouncycastle:bcpkix-fips
org.bouncycastle:bctls-fips
```

The nightly workflow reads this file and constructs the `--excludes` argument to
`versions:update-properties`. To exclude a new library from automation, a developer adds one line
to this file — no workflow changes required.

## Secrets Required

Based on the izgw-core CI/CD design, which investigated this question in detail, the built-in
`GITHUB_TOKEN` is sufficient for Maven package authentication and PR creation since all IZ Gateway
package repositories are public. The following secrets are used across the workflows:

| Secret | Source | Purpose |
|--------|--------|---------|
| `GITHUB_TOKEN` | **Built-in** — auto-injected by GitHub Actions | Maven auth for GitHub Packages resolution and publishing; PR creation via `gh pr create` |
| `OSS_INDEX_USERNAME` | ✅ Already configured org-wide | Sonatype OSS Index authentication for OWASP Dependency-Check CVE scanning |
| `OSS_INDEX_PASSWORD` | ✅ Already configured org-wide | Sonatype OSS Index authentication for OWASP Dependency-Check CVE scanning |
| `MAIL_USERNAME` | ✅ Already configured (AWS SES) | Email notifications when a PR is opened |
| `MAIL_PASSWORD` | ✅ Already configured (AWS SES) | Email notifications when a PR is opened |

**No new secrets need to be created.** All required secrets already exist at the organisation level.

Maven authentication is configured at workflow runtime by writing a `~/.m2/settings.xml` that
maps each GitHub Packages server ID to `GITHUB_ACTOR` / `GITHUB_TOKEN`:

```xml
<server>
  <id>github-bom</id>
  <username>${env.GITHUB_ACTOR}</username>
  <password>${env.GITHUB_TOKEN}</password>
</server>
```

> **Note on publishing:** `GITHUB_TOKEN` has `write:packages` permission within its own repository
> by default, which is sufficient for `mvn deploy` in the release workflow. This should be verified
> when Task 5 (secrets & permissions) is worked.

## Non-Goals

- Automatically merging dependency update PRs (human review always required)
- Publishing to Maven Central
- Modifying Maven plugin versions automatically (separate concern)
- Managing versions for projects that do not inherit from this BOM
