## Context

The `dependency-updates.yml` workflow runs nightly and uses four Maven Versions Plugin goals to detect and apply dependency updates:

1. `versions:display-property-updates` — reports available property-backed version bumps
2. `versions:display-plugin-updates` — reports available plugin version bumps
3. `versions:display-dependency-updates` — reports outdated transitive/direct dependencies (run against `validation/pom.xml`)
4. `versions:update-properties` — applies patch/minor version bumps to properties in the root `pom.xml`

All four goals currently rely on `-DallowMajorUpdates=false` and artifact-level `-Dexcludes` (from `automation-exclusions.txt`) to limit what gets proposed. Neither mechanism filters by version **qualifier** — so pre-release versions like `4.35.0-RC1`, `2.0.0-alpha1`, `3.1.0-M2` are treated as valid update candidates.

The Maven Versions Plugin natively supports a **rules XML file** passed via `-DrulesUri` that can define ignored version patterns globally or per-artifact. This is the intended extension point for this kind of filtering.

## Goals / Non-Goals

**Goals:**
- Prevent all `mvn versions:*` goals from proposing or applying pre-release versions (RC, alpha, beta, milestone, snapshot qualifiers)
- Use the Maven Versions Plugin's built-in rules mechanism — no custom shell-script post-filtering
- Apply filtering consistently across all four plugin invocations
- Keep the solution maintainable: a single rules file, easy to extend with new patterns

**Non-Goals:**
- Filtering by version number ranges (e.g., "never go above 4.x") — that's handled by `allowMajorUpdates=false`
- Replacing the existing `automation-exclusions.txt` artifact-level exclusion mechanism
- Filtering plugin updates differently from dependency updates (same rules apply to both)

## Decisions

### 1. Use Maven Versions Plugin `rulesUri` with a rules XML file

**Choice:** Create a `.github/versions-rules.xml` file and pass it to all `mvn versions:*` invocations via `-DrulesUri=file:///${GITHUB_WORKSPACE}/.github/versions-rules.xml`.

**Rationale:** This is the plugin's first-class mechanism for version filtering. It supports regex-based `ignoreVersion` patterns that match against the full version string. No shell post-processing needed.

**Alternatives considered:**
- **Shell-based post-filter** (grep out RC lines from logs, revert RC bumps after `update-properties`): Fragile, race-prone, and wouldn't prevent the plugin from *selecting* RC versions in the first place.
- **Per-artifact exclusions in `automation-exclusions.txt`**: Would require listing every artifact that has an RC release — not scalable and doesn't address new artifacts.

### 2. Use a global `ignoreVersion` rule with regex patterns

**Choice:** Define a single `<rule>` with no `<groupId>`/`<artifactId>` filter (making it global) containing `<ignoreVersion>` entries for common pre-release qualifiers.

**Patterns to exclude (case-insensitive via `(?i)`):**
```xml
<ignoreVersion type="regex">(?i).*[-.]RC\d*$</ignoreVersion>
<ignoreVersion type="regex">(?i).*[-.]alpha\d*$</ignoreVersion>
<ignoreVersion type="regex">(?i).*[-.]beta\d*$</ignoreVersion>
<ignoreVersion type="regex">(?i).*[-.]M\d+$</ignoreVersion>
<ignoreVersion type="regex">(?i).*-SNAPSHOT$</ignoreVersion>
<ignoreVersion type="regex">(?i).*[-.]cr\d*$</ignoreVersion>
```

**Rationale:** A global rule covers all artifacts without per-artifact configuration. Regex gives precise control. The `(?i)` flag handles inconsistent casing across Maven Central (e.g., `RC1` vs `rc1`). Covering `cr` (candidate release) handles JBoss/Hibernate conventions.

**Alternatives considered:**
- **Exact string matching**: Too brittle — would miss `RC2`, `alpha2`, etc.
- **Single catch-all regex**: Harder to read and maintain than individual patterns per qualifier type.

### 3. Place the rules file at `.github/versions-rules.xml`

**Choice:** Store the file under `.github/` alongside the workflow that uses it.

**Rationale:** It's a CI configuration file, not a build artifact. Placing it in `.github/` makes the relationship to the workflow clear and keeps the project root clean. It also avoids interfering with any local developer Maven configuration.

### 4. Reference via `file:///` URI in the workflow

**Choice:** Use `-DrulesUri=file:///${GITHUB_WORKSPACE}/.github/versions-rules.xml` in the workflow.

**Rationale:** The `rulesUri` parameter requires a URI. Using `file:///` with `${GITHUB_WORKSPACE}` resolves to the correct absolute path in GitHub Actions runners. This avoids needing to host the file at an HTTP URL or embed it in the Maven settings.

## Risks / Trade-offs

- **[Over-filtering]** → Some legitimate releases use qualifiers like `.Final` or `.RELEASE` (e.g., Hibernate). Our patterns specifically target `RC`, `alpha`, `beta`, `M`, `SNAPSHOT`, and `cr` — none of which are used for stable releases. If a false positive is discovered, the rules file is easy to adjust.
- **[Under-filtering]** → Some projects may use non-standard pre-release qualifiers (e.g., `-preview`, `-dev`, `-ea`). These will not be caught initially. The rules file can be extended as new patterns are discovered.
- **[Plugin version compatibility]** → The `rulesUri` feature has been in the Maven Versions Plugin since version 2.x and is well-supported in 2.16+. No compatibility risk with the current plugin version.
- **[Local developer impact]** → None. The `-DrulesUri` is only passed in the CI workflow. Local `mvn versions:*` commands are unaffected unless a developer explicitly passes it.
