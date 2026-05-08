## 1. Workflow modifications in `_release_common.yml`

- [ ] 1.1 Add `sudo apt-get install -qq -y xmlstarlet` to the "Set release version" step, before any pom edit
- [ ] 1.2 In the "Set release version" step, replace `mvn versions:update-parent -f validation/pom.xml -DparentVersion=${{ inputs.release-version }} -DgenerateBackupPoms=false` with `xmlstarlet ed --inplace -u "/project/parent/version" -v "${{ inputs.release-version }}" validation/pom.xml`
- [ ] 1.3 In the "Set release version" step, immediately after the xmlstarlet edit, add a read-back assertion: `xmlstarlet sel -t -v "/project/parent/version" validation/pom.xml`, compare to `${{ inputs.release-version }}`, exit 1 with `::error::` and expected/actual on mismatch
- [ ] 1.4 Add `sudo apt-get install -qq -y xmlstarlet` to the "Update develop branch" step, before the snapshot edit (idempotent — safe even if 1.1 already ran on the same job, though "Update develop branch" runs on a different job step so the install is required)
- [ ] 1.5 In the "Update develop branch" step, replace `mvn versions:update-parent -f validation/pom.xml -DparentVersion=${{ steps.next-version.outputs.next_snapshot_version }} -DallowSnapshots=true -DgenerateBackupPoms=false` with the same `xmlstarlet ed --inplace -u "/project/parent/version" -v ...` pattern, using the next-snapshot version
- [ ] 1.6 In the "Update develop branch" step, add the same read-back assertion against the next-snapshot version, with the same fail-loud behavior on mismatch
- [ ] 1.7 Confirm the `mvn install -N -DskipDependencyCheck=true` invocation that precedes each xmlstarlet edit is retained (still needed by later steps that resolve the parent BOM locally — only the `versions:update-parent` lines are being replaced)
- [ ] 1.8 Confirm the existing `git add pom.xml validation/pom.xml` and commit messages remain unchanged so the spec scenarios about commit content continue to hold

## 2. Local verification

- [ ] 2.1 YAML-lint the modified `_release_common.yml` (e.g., `yamllint .github/workflows/_release_common.yml` or `actionlint`) and resolve any warnings
- [ ] 2.2 On a scratch directory copy of `validation/pom.xml`, run the new xmlstarlet edit + read-back command sequence with a dummy version (e.g. `9.9.9-TEST`) and confirm the file is updated and the assertion passes
- [ ] 2.3 On the same scratch copy, deliberately corrupt the edit (e.g., point xmlstarlet at a wrong XPath like `/project/parent/groupId`) and confirm the read-back assertion fails with a non-zero exit and the expected/actual diagnostic
- [ ] 2.4 Verify xmlstarlet is available via apt on `ubuntu-latest`: search GitHub Actions runner-images repo or run a one-off `workflow_dispatch` in a throwaway branch that just runs `apt-cache show xmlstarlet`

## 3. PR and rollout

- [ ] 3.1 Open the PR against `develop` after the user's separate one-line `validation/pom.xml` parent-version PR has merged (so the nightly is already unblocked and this change can be reviewed on a stable baseline)
- [ ] 3.2 In the PR description, link to this change folder (`openspec/changes/fix-release-snapshot-parent-bump/`) and call out that the next standard release will exercise the new code path end-to-end
- [ ] 3.3 After merge, monitor the next standard release run for: (a) both "prepare release X.Y.Z" and "bump version to X.(Y+1).0-SNAPSHOT" commits modifying `pom.xml` AND `validation/pom.xml`, and (b) the read-back assertion log lines being present and showing matches
- [ ] 3.4 After the next standard release completes, confirm the following nightly `dependency-updates.yml` run resolves the parent BOM successfully (no `Non-resolvable parent POM` error)
