## Context

The standard release workflow in `_release_common.yml` performs two parent-version updates on `validation/pom.xml`:

1. **Release-version step** (line ~245): `mvn versions:update-parent -DparentVersion=<release>` — runs on the release branch before deploy.
2. **Next-snapshot bump step** (line ~355): `mvn versions:update-parent -DparentVersion=<next-snapshot> -DallowSnapshots=true` — runs on develop after the release is published.

Step 1 has worked on every release. Step 2 silently skipped on the 2026-05-07 release of 1.7.0 (commit `d4cd572` modified only `pom.xml`, leaving `validation/pom.xml`'s parent at `1.7.0`), which broke the 2026-05-08 nightly `dependency-updates.yml` run with a non-resolvable parent POM error.

The asymmetry is empirical: `versions:update-parent` queries remote repositories for candidate versions and treats `parentVersion` as a range. For step 1 the constraint `[1.7.0,)` happens to be satisfiable; for step 2 the constraint `[1.8.0-SNAPSHOT,)` matches nothing remote (Maven Central does not host this private artifact, GitHub Packages has only releases through 1.7.0, and the just-installed local snapshot is not consulted for "available versions"), so the plugin reports no update and exits 0. The follow-up `git commit` produces a partial change.

The hotfix release path (`hotfix.yml`) reuses `_release_common.yml`. It runs step 1 but not step 2 (the workflow guards step 2 behind `next-snapshot-version` being set, which only standard releases provide).

The workflow already references `xmlstarlet` elsewhere (`dependency-updates.yml` installs it on the fly inside its auto-fix-transitives code path), so the tool is a known quantity for this repo's CI.

## Goals / Non-Goals

**Goals:**
- Eliminate the silent-skip failure mode by replacing `versions:update-parent` with a mechanism that does not depend on remote repository metadata.
- Keep both update points (release-version and next-snapshot) symmetric, so failure modes converge.
- Surface any future regression of this behavior during the release run itself, not days later in an unrelated workflow.
- Preserve current outputs: same commit messages, same branches updated, same `mvn install -N` and `mvn deploy` steps unchanged.

**Non-Goals:**
- Restructuring `validation/` as a Maven reactor module of the BOM. Considered and rejected (see Decisions).
- One-time repair of the currently stale `validation/pom.xml` on develop. The user is handling that in a separate one-line PR; this change only prevents recurrence.

## Decisions

### D1: Use xmlstarlet for the parent-version edit

Replace both invocations of `mvn versions:update-parent -f validation/pom.xml ...` with:

```bash
xmlstarlet ed --inplace \
    -N pom=http://maven.apache.org/POM/4.0.0 \
    -u "/pom:project/pom:parent/pom:version" \
    -v "$TARGET_VERSION" \
    validation/pom.xml
```

**Rationale:** xmlstarlet performs a literal XPath-targeted text edit. It never queries any repository, never inspects metadata, and has no special handling for snapshot vs. release versions — directly satisfying the "does not depend on remote metadata" requirement. The `-N pom=...` declaration and `pom:` prefix on each XPath segment are required because `validation/pom.xml` declares `xmlns="http://maven.apache.org/POM/4.0.0"` as its default namespace; XPath without a namespace declaration silently does not match elements in a default namespace and the edit becomes a no-op. This was empirically verified against `validation/pom.xml` on this branch (both edit and read-back behave correctly with the namespace prefix; both fail to match without it).

**Alternatives considered:**
- **`mvn versions:set -DartifactId=izgw-bom -DnewVersion=$V -DupdateMatchingVersions=false`**: still goes through the versions plugin, still risks remote-metadata behavior, harder to reason about.
- **`sed -i 's|<version>OLD</version>|<version>NEW</version>|' validation/pom.xml`**: brittle. The file contains other `<version>` elements (none today, but no structural protection); needs context-aware matching that re-invents what XPath gives us for free.
- **Hand-rolled Python/Node script**: more dependencies than necessary; xmlstarlet is a single apt package and is already in use in this repo's CI scripts.

### D2: Apply the xmlstarlet edit to BOTH the release-version step and the next-snapshot step

The release-version step works today, but for empirical rather than principled reasons. Leaving it on `versions:update-parent` keeps an asymmetric, fragile path in the workflow. Replacing both:

- Both steps share one mechanism, one failure mode, one verification block.
- Future Maven plugin upgrades cannot break one step independently.
- The verification step (D3) becomes uniform.

**Alternative considered:** Touch only the snapshot step. Smaller diff, lower regression surface for the release-version flow. Rejected because it preserves the asymmetry that masked this bug for previous releases — the silent-skip class of failure could re-emerge under different conditions (Maven update, plugin update, repo configuration change).

### D3: Verify each edit with a read-back assertion in the same shell step

Immediately after each `xmlstarlet ed` call, read the value back and fail loudly on mismatch:

```bash
ACTUAL=$(xmlstarlet sel \
    -N pom=http://maven.apache.org/POM/4.0.0 \
    -t -v "/pom:project/pom:parent/pom:version" \
    validation/pom.xml)
if [ "$ACTUAL" != "$TARGET_VERSION" ]; then
  echo "::error::validation/pom.xml parent version not synchronized."
  echo "Expected: $TARGET_VERSION"
  echo "Actual:   $ACTUAL"
  exit 1
fi
```

The verification lives inside the same step that performs the edit, before `git add`/`git commit`/`git push`. Any future regression — bad XPath, missing tool install, unexpected pom layout — fails the release run itself, not a downstream workflow days later.

**Alternative considered:** A `git diff --exit-code validation/pom.xml` check. Rejected because it asserts "something changed," not "the right thing is now there." The xmlstarlet read-back asserts the actual end state.

### D4: Install xmlstarlet at the start of the relevant steps

`xmlstarlet` is not pre-installed on `ubuntu-latest`. The workflow will run `sudo apt-get install -qq -y xmlstarlet` before the first edit, matching the pattern already used in `dependency-updates.yml`. The install is idempotent and adds ~1 second.

### D5: Reject reactor-module restructuring

A "proper" Maven solution would make `validation/` a `<module>` of the parent BOM, after which a single `mvn versions:set -DnewVersion=X -DprocessAllModules=true` would propagate to both poms atomically. Considered and rejected because:

- The BOM is `<packaging>pom</packaging>` with no source. Adding a reactor module changes its build semantics and ripples into every downstream project that imports the BOM, with unclear effects on transitive resolution.
- The validation pom is a CI-only synthetic project that is explicitly never published. Promoting it to a reactor child gives it weight it does not deserve.
- The xmlstarlet approach solves the actual problem in ~10 lines of YAML, with no impact on consumers of the BOM.

## Risks / Trade-offs

- **Risk:** xmlstarlet XPath without a namespace declaration silently does not match elements in `validation/pom.xml`'s default namespace and the edit becomes a no-op (empirically confirmed on this branch). A future contributor copying the surrounding pattern without the `-N pom=...` flag and `pom:` prefixes would reintroduce the silent-no-op class of failure.
  → **Mitigation:** the read-back assertion in D3 fails loudly on any mismatch (including the empty string returned by a no-match XPath), so even an XPath regression cannot ship a stale `validation/pom.xml`. The design's code blocks include the namespace declaration prominently, and the implementation comments will reference this gotcha.

- **Risk:** Replacing the working release-version step (D2) introduces regression risk on a path that has not failed before.
  → **Mitigation:** the verification step (D3) runs after the edit, so any regression fails the release immediately. The new mechanism is also strictly simpler than the one being replaced.

- **Risk:** Future contributors may add additional `<version>` elements inside `<parent>` (impossible per Maven schema) or change the file's root structure.
  → **Mitigation:** the XPath `/project/parent/version` is anchored to the Maven POM schema, which is fixed. Schema-violating edits would already break Maven before they could affect our XPath.

- **Trade-off:** xmlstarlet adds an apt package install (~1 second) to the release workflow. Acceptable given the alternative is debugging silent-skip failures retroactively.

## Migration Plan

1. Land this change as a PR against `develop`.
2. The PR's CI runs the existing release workflows on a dispatch dry-run? — _not applicable_; the release workflow only runs on `workflow_dispatch` and from `develop`/`hotfix/*`. Verification will happen on the next real release.
3. The user's separate one-line PR (bumping `validation/pom.xml`'s parent from `1.7.0` to `1.8.0-SNAPSHOT`) lands first to unblock the nightly job. This change lands second.
4. **No rollback complexity.** If the new mechanism misbehaves on the next release, the verification step fails the run before any commit/push/deploy. The release operator can revert this PR and use the old workflow on the next attempt.

## Open Questions

- Whether the post-edit verification should also check for an empty diff with `git diff --exit-code` (defense-in-depth) or trust the xmlstarlet read-back alone. Current design trusts the read-back; if false-confidence concerns arise, a `git diff` check is a one-line addition.
