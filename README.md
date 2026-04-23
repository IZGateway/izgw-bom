# IZ Gateway Bill of Materials (BOM)


This repository contains a Maven Bill of Materials (BOM) POM that provides centralized dependency management for all IZ Gateway projects.

## Features

- **Centralized Dependency Management**: Defines and manages versions for all common dependencies used across IZ Gateway projects.
- **Spring Boot & Framework Integration**: Imports BOMs for Spring Boot, Spring Framework, and Spring Security.
- **Comprehensive Library Support**: Manages versions for:
  - **Spring Boot**
  - **Spring Framework**
  - **Spring Security**
  - **Jackson** (JSON processing)
  - **JUnit** (testing)
  - **Mockito** (mocking)
  - **Testcontainers** (integration testing)
  - **SLF4J & Logback** (logging)
  - **Apache Commons** (lang3, io, compress, text, validator, beanutils)
  - **Jakarta Validation & Hibernate Validator**
  - **HAPI HL7 v2** (hapi-base, hapi-structures-v2*)
  - **HAPI FHIR** (hapi-fhir-base, hapi-fhir-structures-r4, validation, caching)
  - **OpenCSV**
  - **ULIDJ**
  - **Netty**
  - **HTTP Client** (Apache HttpClient5)
- **External Properties Support**: Version properties can be loaded from external files using the properties-maven-plugin.

## Usage

### As a BOM Import

In your project's `pom.xml`, add this BOM to your `dependencyManagement` section:

```xml
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>gov.cdc.izgw</groupId>
            <artifactId>izgw-bom</artifactId>
            <version>1.0.0-RELEASE</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

### Managed Dependencies

This BOM manages and imports versions for:

- **Spring Boot**
- **Spring Framework**
- **Spring Security**
- **Jackson**
- **JUnit**
- **Mockito**
- **Testcontainers**
- **SLF4J & Logback**
- **Apache Commons**
- **Jakarta Validation & Hibernate Validator**
- **HAPI HL7 v2 & HAPI FHIR**
- **OpenCSV**
- **ULIDJ**
- **Netty**
- **Apache HttpClient5**

## CI/CD Workflows

### Publish Workflow (`publish.yml`)

Runs on every push to `develop`, every PR targeting `develop`, and via `workflow_dispatch`. Before building and publishing the BOM to GitHub Packages, this workflow runs three validation steps:

1. **POM validation** (`mvn validate`) to catch XML or schema errors.
2. **Property-backed version check** to ensure every `<version>` inside `<dependencyManagement>` uses a `${property}` reference rather than a hardcoded literal. This is required for the dependency update workflow to detect available upgrades.
3. **Dependency resolution** (`mvn dependency:resolve` on `validation/pom.xml`) to confirm that every declared version resolves from Maven Central or GitHub Packages.

If any validation step fails, the build is aborted and the BOM is not published.

### Dependency Update Workflow (`dependency-updates.yml`)

Runs on a nightly schedule (Mon-Fri, 2:00 AM ET / 07:00 UTC) and via `workflow_dispatch`. This workflow automates patch and minor version bumps for BOM-managed libraries:

1. Reads `automation-exclusions.txt` to determine which libraries to skip.
2. Uses `versions:display-property-updates` and `versions:update-properties` to detect and apply available patch/minor bumps.
3. Runs `mvn dependency:resolve` on the validation project to confirm the updated versions still resolve.
4. Runs OWASP Dependency-Check to scan for CVEs in the dependency tree.
5. Opens a PR if any updates were applied or CVEs were found. If nothing changed and no CVEs exist, the workflow exits cleanly.

The PR includes a table of version changes, CVE scan results, a list of excluded libraries, and a dependency tree diff showing what changed.

### Release Workflow (`release.yml` / `_release_common.yml`)

Already fully implemented and not modified by the dependency update automation. Handles the complete BOM release lifecycle: validate, set version, tag, publish to GitHub Packages, and advance to the next snapshot.

## Reviewing a Dependency Update PR

When a dependency update PR is opened automatically, use this checklist:

1. Review the version bump table. Confirm the changes are patch or minor bumps as expected.
2. Check the CVE scan results. If vulnerabilities are listed, determine whether the applied updates address them.
3. Check the excluded libraries section. If a newer version is available for an excluded library, evaluate whether a manual update is warranted.
4. Look at the dependency tree diff for unexpected transitive changes.
5. Pull the branch locally and run `mvn dependency:resolve -f validation/pom.xml` to verify resolution.
6. If everything looks good, merge to `develop`.

## Automation Exclusions

The file `automation-exclusions.txt` at the repository root controls which libraries are excluded from automatic version bumping. Excluded libraries still appear in the PR body for visibility, but the workflow will not apply version changes to them.

### File Format

```
# Lines starting with # are comments
# Format: groupId:artifactId (one entry per line)

org.bouncycastle:bc-fips
org.bouncycastle:bcpkix-fips
org.bouncycastle:bctls-fips
```

### When to Exclude a Library

Exclude a library when automatic updates could introduce risk that requires human review:

- **FIPS-certified libraries** (e.g., Bouncy Castle FIPS) where a new version may not yet have certification.
- **Libraries with known breaking changes** in minor releases.
- **Libraries that require coordinated upgrades** across multiple IZ Gateway projects.

### Adding an Exclusion

Add a line with the `groupId:artifactId` to `automation-exclusions.txt`. No workflow changes are required. The next nightly run will skip that library automatically.

## Handling Major Version Flags

The dependency update workflow only applies patch and minor bumps. When a major version is available for a library, it is flagged in the PR body under "manual review required." To handle these:

1. Evaluate the changelog and migration guide for the new major version.
2. Check for breaking API changes that would affect downstream IZ Gateway projects.
3. If the upgrade is safe, update the version property in `pom.xml` manually and open a separate PR.
4. If the upgrade requires coordinated changes across projects, plan the rollout before updating the BOM.

## Secrets and Permissions

All workflows use secrets that are already configured at the organization level. No new secrets need to be created.

| Secret | Source | Used By |
|--------|--------|---------|
| `GITHUB_TOKEN` | Built-in (auto-injected by GitHub Actions) | All workflows. Maven authentication for GitHub Packages, PR creation via `gh`. |
| `OSS_INDEX_USERNAME` | Organization secret (already configured) | Dependency update workflow. Sonatype OSS Index authentication for CVE scanning. |
| `OSS_INDEX_PASSWORD` | Organization secret (already configured) | Dependency update workflow. Sonatype OSS Index authentication for CVE scanning. |
| `MAIL_USERNAME` | Organization secret (already configured, AWS SES) | Dependency update workflow. Email notification when a PR is opened. |
| `MAIL_PASSWORD` | Organization secret (already configured, AWS SES) | Dependency update workflow. Email notification when a PR is opened. |

### Rotating Credentials

- **OSS Index** (`OSS_INDEX_USERNAME` / `OSS_INDEX_PASSWORD`): These authenticate against Sonatype's OSS Index API. To rotate, generate new credentials at [ossindex.sonatype.org](https://ossindex.sonatype.org) and update the organization secrets in GitHub Settings > Secrets and variables > Actions. These secrets are shared across `izgw-bom`, `izgw-core`, and `izgw-hub`.
- **Mail** (`MAIL_USERNAME` / `MAIL_PASSWORD`): These are AWS SES SMTP credentials. To rotate, create new SMTP credentials in the AWS SES console under SMTP Settings, then update the organization secrets. These secrets are shared across all IZ Gateway repositories that send CI/CD notifications.
- **GITHUB_TOKEN**: Managed automatically by GitHub Actions. No rotation needed.

## Files

- `pom.xml` - The main BOM POM file
- `validation/pom.xml` - Synthetic validation project used by CI workflows to verify dependency resolution (never published)
- `automation-exclusions.txt` - Libraries excluded from automated dependency updates
- `.github/workflows/publish.yml` - Build, validate, and publish workflow
- `.github/workflows/dependency-updates.yml` - Nightly dependency update workflow

## Benefits

1. **Consistency**: Ensures all IZ Gateway projects use the same dependency versions
2. **Maintainability**: Central place to update dependency versions
3. **Flexibility**: External properties file allows for easy version management
4. **Spring Integration**: Optimized for Spring Boot and Spring Framework projects

---

For a full list of managed dependencies and BOM imports, see the [`pom.xml`](pom.xml).
