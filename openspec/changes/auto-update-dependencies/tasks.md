# Tasks: Automated Maven Dependency Updates

**Status:** In Progress  
**Created:** 2026-03-22  
**Updated:** 2026-03-23

## Summary

| Task | Description | Est. | Status |
|------|-------------|------|--------|
| 0 | Property-back all hardcoded versions in pom.xml | 0.5h | ✅ Done |
| 1 | Synthetic validation project | 1h | ✅ Done |
| 2 | Nightly dependency update workflow | 3h | ✅ Done (schedule pending activation) |
| 3 | Repository secrets & permissions | 0.5h | ✅ Done |
| 4 | Documentation | 1h | ❌ Not started |

**Total Estimated Effort:** ~6 hours

**Note:** The release workflow (`release.yml` / `_release_common.yml`) already exists and is fully
implemented. No changes are being made to it. Validation checks (dependency resolve, CVE scan) run
nightly via the dependency update workflow — no pre-publish validation step is added to `publish.yml`.

---

### ~~Task 0: Property-back All Hardcoded Versions (Prerequisite)~~ ✅ DONE
**Status:** Completed 2026-03-22

**Implemented:**
- ✅ Added `bc-fips.version`, `bcpkix-fips.version`, `bctls-fips.version` properties to `<properties>` block
- ✅ Replaced hardcoded version literals in `<dependencyManagement>` with `${property}` references
- ✅ `automation-exclusions.txt` created at repository root with all three FIPS entries and explanatory comments
- ✅ `mvn validate` passes

---

### Task 1: Create Synthetic Validation Project
**Estimated effort:** 1 hour

**Description:**
Create a minimal Maven project inside the repository (`validation/pom.xml`) whose sole purpose is
to **resolve** (not compile) a representative set of dependencies declared in the BOM. This serves
as the test harness for all three workflows.

**What it does:**
- Declares `izgw-bom` as its parent
- Declares one `<dependency>` from each major library group: Spring Boot, Spring Framework,
  Spring Security, HAPI FHIR, HAPI V2, Jackson, Netty, Apache Commons, Logging (SLF4J/Logback),
  Saxon, AWS SDK, Bouncy Castle FIPS, JUnit, Testcontainers
- Uses `<packaging>pom</packaging>` — has no `src/` directory
- `mvn dependency:resolve` confirms every resolved version exists in Maven Central / GitHub Packages
- `mvn dependency:tree` produces the transitive tree consumed by OWASP Dependency-Check

**What it does NOT do:**
- Compile any code
- Run any tests
- Produce or publish any artifact

**Acceptance Criteria:**
- [ ] `validation/pom.xml` exists with `izgw-bom` as parent and `<packaging>pom</packaging>`
- [ ] At least one dependency from each major library group is declared
- [ ] No `src/` directory exists under `validation/`
- [ ] `mvn dependency:resolve` passes when run from `validation/` using built-in `GITHUB_TOKEN` for GitHub Packages auth
- [ ] `validation/target/` is listed in the root `.gitignore`
- [ ] The project is NOT listed in the root POM's `<modules>` (not part of a reactor build)

---

### Task 2: Publish / Validation Workflow (`publish.yml`)
**Estimated effort:** 1.5 hours

**Description:**
The existing `publish.yml` workflow already runs on every push and PR to `develop` and on
`workflow_dispatch`. Validation steps are added to it directly — before the `Build & Publish`
step — so that every dependency change is validated before it is published. No separate
`pr-validate.yml` is needed.

**Acceptance Criteria:**
- [ ] Runs `mvn validate` on the root POM; fails on XML/schema errors
- [ ] Fails if any `<version>` in `<dependencyManagement>` is a literal string rather than a `${property}` reference (grep/xmllint check)
- [ ] Runs `mvn dependency:resolve` on `validation/pom.xml`; fails if any version is unresolvable
- [ ] Validation steps run before `Build & Publish` so a bad POM is never published
- [ ] Validation steps complete in under 3 minutes
- [ ] Uses built-in `GITHUB_TOKEN` for GitHub Packages access (already wired in existing step)

---

### Task 3: Nightly Dependency Update Workflow (`dependency-updates.yml`)
**Estimated effort:** 3 hours

**Description:**
Scheduled workflow that detects available version upgrades for BOM-managed library properties,
applies patch/minor bumps, runs CVE scanning, and opens a PR with full context.

**Exclusion configuration:**
The file `automation-exclusions.txt` at the repository root controls which `groupId:artifactId`
entries are skipped. Lines beginning with `#` are comments. The workflow reads this file and
constructs the `--excludes` argument passed to `versions:update-properties`. To exclude a new
library, a developer adds one line to this file — no workflow changes required.

Initial contents (created in Task 0):
```
# Bouncy Castle FIPS — must be manually reviewed for FIPS 140-2 certification compatibility
org.bouncycastle:bc-fips
org.bouncycastle:bcpkix-fips
org.bouncycastle:bctls-fips
```

**Acceptance Criteria:**
- [ ] Triggers on schedule (Mon–Fri ~4 AM ET) and `workflow_dispatch`
- [ ] Reads `automation-exclusions.txt`; skips listed `groupId:artifactId` entries
- [ ] Uses `versions:update-properties` to apply patch/minor bumps only (no major bumps)
- [ ] Includes excluded libraries and their latest available version in the PR body (visibility without automation)
- [ ] Includes major-version-available libraries in the PR body as "manual review required"
- [ ] Runs `mvn dependency:resolve` on `validation/pom.xml` after updates to confirm nothing broken
- [ ] Runs OWASP Dependency-Check on effective dependency tree; includes CVE findings in PR body
- [ ] Opens a PR only if updates or CVEs were found; exits cleanly otherwise
- [ ] PR includes: version bump table, CVE summary, excluded libs status, major bumps section
- [ ] Branch name: `security-updates-YYYYMMDD-HH-MM`
- [ ] Applies `dependencies` label; also applies `security` label if CVEs are present
- [ ] Uses `GITHUB_TOKEN` (built-in) for Maven auth and PR creation; `OSS_INDEX_USERNAME` / `OSS_INDEX_PASSWORD` for CVE scanning; `MAIL_USERNAME` / `MAIL_PASSWORD` for notifications

---

### ~~Task 4: Repository Secrets & Permissions~~ ✅ DONE
**Status:** Completed 2026-03-22

**Verified:**
- ✅ `OSS_INDEX_USERNAME` and `OSS_INDEX_PASSWORD` — already configured and validated in other projects (izgw-core, izgw-hub)
- ✅ `MAIL_USERNAME` and `MAIL_PASSWORD` — already configured and validated (AWS SES) in other projects
- ✅ `GITHUB_TOKEN` — built-in; `permissions: contents: write` and `pull-requests: write` already set in `dependency-updates.yml`; read access confirmed locally (`mvn dependency:resolve` works)
- ✅ `GITHUB_TOKEN` PR creation and branch push permissions — will be confirmed during the first `workflow_dispatch` test run

---

### Task 5: Documentation
**Estimated effort:** 1 hour

**Description:**
Update `README.md` so maintainers understand how to work with the new workflows.

**Acceptance Criteria:**
- [ ] `README.md` describes the two new workflows (`publish.yml` validation steps, `dependency-updates.yml`) and when each runs
- [ ] Documents how to review a dependency update PR (checklist)
- [ ] Documents how to add a library to `automation-exclusions.txt` and when to do so
- [ ] Documents how to handle a major version flag in an update PR
- [ ] Documents which secrets each workflow uses and that all are pre-existing (`GITHUB_TOKEN` built-in; `OSS_INDEX_*` and `MAIL_*` already configured org-wide)
- [ ] Documents how to rotate `OSS_INDEX_*` and `MAIL_*` credentials if needed
