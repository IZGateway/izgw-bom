# Design: Automated Maven Dependency Updates

**Project:** izgw-bom  
**Created:** 2026-03-22  
**Status:** Design Phase

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│            publish.yml (push/PR to develop)                  │
│                                                              │
│  Validate POM → Check property-backed versions →             │
│  Resolve dependencies → Build & Publish                      │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│        dependency-updates.yml (nightly + manual)             │
│                                                              │
│  Scheduled: Mon-Fri 2:00 AM ET (07:00 UTC)                   │
│  Manual: workflow_dispatch                                   │
└──────────────────────────────────────────────────────────────┘
                              │
                              ↓
                    ┌─────────────────┐
                    │  Prerequisites  │
                    │  - Checkout     │
                    │  - Setup Java   │
                    │  - Maven Cache  │
                    │  - Maven Auth   │
                    └─────────────────┘
                              │
                              ↓
                    ┌─────────────────┐
                    │  Read Exclusions│
                    │  automation-    │
                    │  exclusions.txt │
                    └─────────────────┘
                              │
                              ↓
                    ┌─────────────────┐
                    │  CVE Scan       │
                    │  (before)       │
                    │  validation/    │
                    │  dep tree       │
                    └─────────────────┘
                              │
                              ↓
                    ┌─────────────────┐
                    │  Detect Updates │
                    │  versions:      │
                    │  display-prop-  │
                    │  erty-updates   │
                    └─────────────────┘
                              │
                              ↓
                   ┌──────────────────┐
                   │  Has Updates or  │
                   │  CVEs?           │
                   └──────────────────┘
                     │              │
                    Yes            No → Exit (success)
                     │
                     ↓
          ┌────────────────────┐
          │  Apply Updates     │
          │  versions:update-  │
          │  properties        │
          │  (patch/minor only)│
          └────────────────────┘
                     │
                     ↓
          ┌────────────────────┐
          │  Validate          │
          │  mvn dependency:   │
          │  resolve on        │
          │  validation/       │
          └────────────────────┘
                     │
                     ↓
          ┌────────────────────┐
          │  Open PR           │
          │  - Bump table      │
          │  - CVE summary     │
          │  - Excluded libs   │
          │  - Major flags     │
          └────────────────────┘
                     │
                     ↓
          ┌────────────────────┐
          │  Email             │
          │  notification      │
          │  (if PR created)   │
          └────────────────────┘
```

**Note on scheduling:** izgw-bom runs at 2:00 AM ET — the earliest slot — so updated BOM versions
are available by the time downstream projects (izgw-core at 4:00 AM, izgw-hub at 5:00 AM, etc.)
run their own dependency update workflows.

## Component Details

### 1. Workflow File Structure

**Files:**
- `.github/workflows/publish.yml` — validation + build + publish on every push/PR to `develop`
- `.github/workflows/dependency-updates.yml` — nightly dependency update automation
- `.github/workflows/release.yml` / `_release_common.yml` — **already fully implemented; no changes**

### 2. Authentication Configuration

`GITHUB_TOKEN` is sufficient for all workflows since all IZ Gateway package repositories are
public. It is wired into Maven via a `~/.m2/settings.xml` written at runtime.

All workflows pin Maven to **3.9.14** via `stCarolas/setup-maven@v5`, matching the latest
`3.9.x` release and consistent across all CI/CD jobs. The `4.x` line is not yet adopted.

```yaml
- name: Set up Maven 3.9.14
  uses: stCarolas/setup-maven@v5
  with:
    maven-version: 3.9.14
```

The `versions-maven-plugin` is configured in `pluginManagement` with a `rulesUri` pointing to
`.github/versions-rules.xml`. This file constrains `display-plugin-updates` so it will not
suggest bumping Maven itself past `3.9.x`, and suppresses all suggestions for the Bouncy Castle
FIPS libraries (which are also excluded via `automation-exclusions.txt`).

```yaml
- name: Configure Maven authentication
  run: |
    mkdir -p ~/.m2
    cat > ~/.m2/settings.xml <<EOF
    <settings>
      <servers>
        <server>
          <id>github</id>
          <username>${{ github.actor }}</username>
          <password>${{ secrets.GITHUB_TOKEN }}</password>
        </server>
        <server>
          <id>github-bom</id>
          <username>${{ github.actor }}</username>
          <password>${{ secrets.GITHUB_TOKEN }}</password>
        </server>
      </servers>
    </settings>
    EOF
```

**Note:** `${{ github.actor }}` and `${{ secrets.GITHUB_TOKEN }}` are GitHub Actions expressions
substituted before the shell runs — confirmed from the working `izgw-hub/maven.yml` pattern. No
`env:` block is needed on this step since the values are baked into the heredoc content by Actions
before bash executes.

### 3. Synthetic Validation Project

Because `izgw-bom` is a BOM-only POM with no source code, a synthetic child project at
`validation/pom.xml` is used as the scan and resolution target for all workflows.

**Structure:**
```xml
<project>
  <parent>
    <groupId>gov.cdc.izgw</groupId>
    <artifactId>izgw-bom</artifactId>
    <version><!-- current snapshot --></version>
    <relativePath>../pom.xml</relativePath>
  </parent>
  <artifactId>izgw-bom-validation</artifactId>
  <packaging>pom</packaging>

  <dependencies>
    <!-- One dependency per version property declared in the BOM <properties> block -->

    <!-- spring-boot.version -->
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
    <!-- spring-framework.version -->
    <dependency><groupId>org.springframework</groupId><artifactId>spring-core</artifactId></dependency>
    <!-- spring-security.version -->
    <dependency><groupId>org.springframework.security</groupId><artifactId>spring-security-core</artifactId></dependency>
    <!-- springdoc.version -->
    <dependency><groupId>org.springdoc</groupId><artifactId>springdoc-openapi-starter-webmvc-ui</artifactId></dependency>
    <!-- tomcat.version -->
    <dependency><groupId>org.apache.tomcat.embed</groupId><artifactId>tomcat-embed-core</artifactId></dependency>
    <!-- jackson.version -->
    <dependency><groupId>com.fasterxml.jackson.core</groupId><artifactId>jackson-databind</artifactId></dependency>
    <!-- jackson-annotations.version -->
    <dependency><groupId>com.fasterxml.jackson.core</groupId><artifactId>jackson-annotations</artifactId></dependency>
    <!-- stax2.version -->
    <dependency><groupId>org.codehaus.woodstox</groupId><artifactId>stax2-api</artifactId></dependency>
    <!-- saxon.version -->
    <dependency><groupId>net.sf.saxon</groupId><artifactId>Saxon-HE</artifactId></dependency>
    <!-- netty.version -->
    <dependency><groupId>io.netty</groupId><artifactId>netty-handler</artifactId></dependency>
    <!-- slf4j.version -->
    <dependency><groupId>org.slf4j</groupId><artifactId>slf4j-api</artifactId></dependency>
    <!-- logback.version -->
    <dependency><groupId>ch.qos.logback</groupId><artifactId>logback-classic</artifactId></dependency>
    <!-- junit.version -->
    <dependency><groupId>org.junit.jupiter</groupId><artifactId>junit-jupiter</artifactId><scope>test</scope></dependency>
    <!-- mockito.version -->
    <dependency><groupId>org.mockito</groupId><artifactId>mockito-core</artifactId><scope>test</scope></dependency>
    <!-- testcontainers.version -->
    <dependency><groupId>org.testcontainers</groupId><artifactId>testcontainers</artifactId><scope>test</scope></dependency>
    <!-- httpclient.version -->
    <dependency><groupId>org.apache.httpcomponents.client5</groupId><artifactId>httpclient5</artifactId></dependency>
    <!-- commons-lang3.version -->
    <dependency><groupId>org.apache.commons</groupId><artifactId>commons-lang3</artifactId></dependency>
    <!-- commons-io.version -->
    <dependency><groupId>commons-io</groupId><artifactId>commons-io</artifactId></dependency>
    <!-- commons-compress.version -->
    <dependency><groupId>org.apache.commons</groupId><artifactId>commons-compress</artifactId></dependency>
    <!-- commons-text.version -->
    <dependency><groupId>org.apache.commons</groupId><artifactId>commons-text</artifactId></dependency>
    <!-- commons-validator.version -->
    <dependency><groupId>commons-validator</groupId><artifactId>commons-validator</artifactId></dependency>
    <!-- commons-beanutils.version -->
    <dependency><groupId>commons-beanutils</groupId><artifactId>commons-beanutils</artifactId></dependency>
    <!-- commons-math3.version -->
    <dependency><groupId>org.apache.commons</groupId><artifactId>commons-math3</artifactId></dependency>
    <!-- hapi-v2.version -->
    <dependency><groupId>ca.uhn.hapi</groupId><artifactId>hapi-structures-v251</artifactId></dependency>
    <!-- hapi-fhir.version -->
    <dependency><groupId>ca.uhn.hapi.fhir</groupId><artifactId>hapi-fhir-base</artifactId></dependency>
    <!-- opencsv.version -->
    <dependency><groupId>com.opencsv</groupId><artifactId>opencsv</artifactId></dependency>
    <!-- ulidj.version -->
    <dependency><groupId>io.azam.ulidj</groupId><artifactId>ulidj</artifactId></dependency>
    <!-- jakarta-validation.version -->
    <dependency><groupId>jakarta.validation</groupId><artifactId>jakarta.validation-api</artifactId></dependency>
    <!-- javax-activation.version -->
    <dependency><groupId>com.sun.activation</groupId><artifactId>javax.activation</artifactId></dependency>
    <!-- hibernate-validator.version -->
    <dependency><groupId>org.hibernate.validator</groupId><artifactId>hibernate-validator</artifactId></dependency>
    <!-- nimbus-jose-jwt.version -->
    <dependency><groupId>com.nimbusds</groupId><artifactId>nimbus-jose-jwt</artifactId></dependency>
    <!-- io-jsonwebtoken.version -->
    <dependency><groupId>io.jsonwebtoken</groupId><artifactId>jjwt-api</artifactId></dependency>
    <!-- mysql.version -->
    <dependency><groupId>com.mysql</groupId><artifactId>mysql-connector-j</artifactId></dependency>
    <!-- aws-sdk.version -->
    <dependency><groupId>software.amazon.awssdk</groupId><artifactId>secretsmanager</artifactId></dependency>
    <!-- camel.version -->
    <dependency><groupId>org.apache.camel</groupId><artifactId>camel-core</artifactId></dependency>
    <!-- lombok.version -->
    <dependency><groupId>org.projectlombok</groupId><artifactId>lombok</artifactId><scope>provided</scope></dependency>
    <!-- bc-fips.version -->
    <dependency><groupId>org.bouncycastle</groupId><artifactId>bc-fips</artifactId></dependency>
    <!-- bcpkix-fips.version -->
    <dependency><groupId>org.bouncycastle</groupId><artifactId>bcpkix-fips</artifactId></dependency>
    <!-- bctls-fips.version -->
    <dependency><groupId>org.bouncycastle</groupId><artifactId>bctls-fips</artifactId></dependency>
    <!-- ipaddress.version -->
    <dependency><groupId>com.github.seancfoley</groupId><artifactId>ipaddress</artifactId></dependency>
  </dependencies>
</project>
```

**Usage per workflow:**

| Workflow | Command | Purpose |
|----------|---------|---------|
| `publish.yml` | `mvn dependency:resolve -f validation/pom.xml` | Confirm all declared versions resolve |
| `dependency-updates.yml` | `mvn dependency:resolve -f validation/pom.xml` | Validate nothing broken after bumps |
| `dependency-updates.yml` | `mvn dependency:tree -f validation/pom.xml` | Feed transitive tree to OWASP scan |

### 4. Publish / Validation Workflow (`publish.yml`)

Validation steps are inserted before `Build & Publish` so a bad POM is never published:

```yaml
- name: Validate POM is well-formed
  run: mvn validate
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

- name: Check all dependencyManagement versions are property-backed
  run: |
    # Fail if any <version> inside <dependencyManagement> is a literal (not ${...})
    HARDCODED=$(xmllint --xpath \
      "//dependencyManagement/dependencies/dependency/version[not(starts-with(text(), '\${'))]" \
      pom.xml 2>/dev/null || true)
    if [ -n "$HARDCODED" ]; then
      echo "ERROR: Hardcoded version(s) found in <dependencyManagement>:"
      echo "$HARDCODED"
      exit 1
    fi
    echo "All dependencyManagement versions are property-backed."

- name: Resolve BOM dependencies (synthetic validation project)
  run: mvn dependency:resolve -f validation/pom.xml -q
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 5. Automation Exclusions

The file `automation-exclusions.txt` at the repository root is read by `dependency-updates.yml`
to build the `--excludes` argument for `versions:update-properties`.

```bash
# Read exclusions, strip comments and blank lines, join with comma
EXCLUDES=$(grep -v '^\s*#' automation-exclusions.txt | grep -v '^\s*$' | paste -sd ',' -)
```

Used in the Maven invocation:
```bash
mvn versions:update-properties \
    -DallowMajorUpdates=false \
    -DallowMinorUpdates=true \
    -DallowIncrementalUpdates=true \
    -DgenerateBackupPoms=false \
    -Dexcludes="$EXCLUDES"
```

Current exclusions (from `automation-exclusions.txt`):
- `org.bouncycastle:bc-fips` — FIPS 140-2 certification requires manual review
- `org.bouncycastle:bcpkix-fips` — FIPS 140-2 certification requires manual review
- `org.bouncycastle:bctls-fips` — FIPS 140-2 certification requires manual review

### 6. CVE Scanning

**Decision:** Use `dependency-check/Dependency-Check_Action` (GitHub Action), not the Maven plugin.
See proposal.md § Design Decisions for full rationale. The Maven plugin remains in `pom.xml` for
local developer use; all CI `mvn` invocations pass `-DskipDependencyCheck=true`.

**Scan target:** `mvn dependency:tree -f validation/pom.xml` output — the full transitive
dependency tree of the synthetic validation project. This covers all BOM-declared versions.

```yaml
- name: Generate dependency tree for CVE scan
  run: mvn dependency:tree -f validation/pom.xml -DoutputFile=dependency-tree.txt -q
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

- name: CVE scan (dependency-check/Dependency-Check_Action)
  uses: dependency-check/Dependency-Check_Action@main
  continue-on-error: true
  timeout-minutes: 10
  env:
    JAVA_HOME: /opt/jdk
  with:
    project: izgw-bom
    path: validation/
    format: 'HTML,JSON'
    out: 'reports'
    args: >
      --ossIndexUsername ${{ secrets.OSS_INDEX_USERNAME }}
      --ossIndexPassword ${{ secrets.OSS_INDEX_PASSWORD }}
      --failOnCVSS 0
      --suppression ./dependency-suppression.xml
      --disableNuspec
      --disableNugetconf
      --disableAssembly

- name: Parse CVE report
  run: |
    jq '[.dependencies[] | select(.vulnerabilities) |
        {name: .fileName,
         cves: [.vulnerabilities[].name],
         severity: [.vulnerabilities[].severity]}]' \
        reports/dependency-check-report.json > cve-findings.json
    echo "CVE_COUNT=$(jq length cve-findings.json)" >> $GITHUB_ENV
```

### 7. Update Detection and Application

```bash
# 1. Detect available property updates (respecting exclusions)
mvn versions:display-property-updates \
    -DallowMajorUpdates=false \
    -DallowMinorUpdates=true \
    -DallowIncrementalUpdates=true \
    -Dexcludes="$EXCLUDES" \
    -DoutputFile=property-updates.txt -q

# 2. Detect available plugin version updates (for PR reporting)
# Uses Maven 3.9.0 as the compatibility baseline (matches CI/CD runtime)
mvn -B versions:display-plugin-updates \
    -DallowMajorUpdates=false \
    -DallowMinorUpdates=true \
    -DallowIncrementalUpdates=true \
    -DoutputFile=plugin-updates.txt

# 3. Detect major-version-only updates (for PR reporting — not applied)
mvn versions:display-property-updates \
    -DallowMajorUpdates=true \
    -DallowMinorUpdates=false \
    -DallowIncrementalUpdates=false \
    -Dexcludes="$EXCLUDES" \
    -DoutputFile=major-updates.txt -q

# 3. Detect latest versions of excluded libraries (for PR visibility)
mvn versions:display-property-updates \
    -DallowMajorUpdates=true \
    -DinclEcludes="$EXCLUDES" \
    -DoutputFile=excluded-updates.txt -q

# 4. Apply patch/minor bumps
mvn versions:update-properties \
    -DallowMajorUpdates=false \
    -DallowMinorUpdates=true \
    -DallowIncrementalUpdates=true \
    -DgenerateBackupPoms=false \
    -Dexcludes="$EXCLUDES"

# 5. Check if pom.xml actually changed
git diff --quiet pom.xml && echo "NO_UPDATES=true" >> $GITHUB_ENV
```

### 8. Post-Update Validation

After applying updates, confirm all bumped versions still resolve:

```bash
mvn dependency:resolve -f validation/pom.xml -q
```

If this fails, the workflow aborts without opening a PR — a broken BOM is never proposed.

### 9. Pull Request Content

The PR body is assembled from the outputs of steps 6–8:

```markdown
## Automated BOM Dependency Updates — YYYYMMDD-HH-MM

### Version Bumps Applied
| Property | Old | New |
|----------|-----|-----|
| `spring-boot.version` | 3.4.0 | 3.4.1 |
| ...                   | ...   | ...   |

### Plugin Updates Available (not applied — manual review required)
| Plugin | Current | Latest Compatible |
|--------|---------|------------------|
| `maven-compiler-plugin` | 3.13.0 | 3.14.1 |
| ...                     | ...     | ...    |

### CVE Findings
| Library | CVE | Severity | Fixed by update? |
|---------|-----|----------|-----------------|
| ...     | ... | ...      | ...             |

### Excluded Libraries (manual review)
| Library | Current | Latest Available |
|---------|---------|-----------------|
| `bc-fips` | 2.1.2 | 2.1.3 |
| ...       | ...   | ...   |

### Major Version Updates Available (not applied — manual review required)
| Property | Current | Latest Major |
|----------|---------|-------------|
| ...      | ...     | ...         |
```

Branch name: `security-updates-YYYYMMDD-HH-MM`  
Labels: `dependencies` (always); `security` (if CVE_COUNT > 0)

### 10. Email Notification

Sent only when a PR is created, using `dawidd6/action-send-mail@v3` via AWS SES:

```yaml
- name: Send email notification
  if: env.PR_CREATED == 'true'
  uses: dawidd6/action-send-mail@v3
  with:
    server_address: email-smtp.us-east-1.amazonaws.com
    server_port: 465
    secure: true
    username: ${{ secrets.MAIL_USERNAME }}
    password: ${{ secrets.MAIL_PASSWORD }}
    subject: "[izgw-bom] Automated dependency update PR ready for review"
    to: kboone@ainq.com,weckels@ainq.com,pcahill@ainq.com
    cc: devops@izgateway.opsgenie.net
    body: "A dependency update PR has been opened: ${{ env.PR_URL }}"
```

### 11. Secrets Summary

| Secret | Source | Used by |
|--------|--------|---------|
| `GITHUB_TOKEN` | Built-in | All workflows — Maven auth, `gh pr create` |
| `OSS_INDEX_USERNAME` | Org-level (already configured) | CVE scan |
| `OSS_INDEX_PASSWORD` | Org-level (already configured) | CVE scan |
| `MAIL_USERNAME` | Org-level (already configured) | Email notification |
| `MAIL_PASSWORD` | Org-level (already configured) | Email notification |

No new secrets required.

## Key Differences from izgw-core Design

| Aspect | izgw-core | izgw-bom |
|--------|-----------|----------|
| Update target | `<dependency>` versions in pom.xml | `<property>` values in `<properties>` block |
| CVE scan target | Built JAR (`target/*.jar`) | Synthetic validation project dependency tree |
| Build validation | `mvn clean install` + tests | `mvn dependency:resolve -f validation/pom.xml` |
| BOM version check | Checks if izgw-bom has newer version | N/A — this IS the BOM |
| Schedule slot | 4:00 AM ET | 2:00 AM ET (runs first; gates downstream) |
| Major version detection | `display-dependency-updates` | `display-property-updates` |
