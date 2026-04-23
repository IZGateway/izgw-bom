## 1. Create the Maven Versions rules file

- [x] 1.1 Create `.github/versions-rules.xml` with the Maven Versions Plugin `ruleset` XML schema, containing a global `<rule>` with `<ignoreVersion>` entries for each pre-release qualifier family: RC, alpha, beta, milestone (M), SNAPSHOT, and CR — all using `type="regex"` with `(?i)` for case-insensitive matching
- [x] 1.2 Verify the XML is well-formed and uses the correct namespace (`http://mojo.codehaus.org/versions-maven-plugin/rule/2.0.0`)

## 2. Update workflow to reference the rules file

- [x] 2.1 Add `-DrulesUri=file:///${GITHUB_WORKSPACE}/.github/versions-rules.xml` to the `versions:display-property-updates` invocation (line ~63 in `dependency-updates.yml`)
- [x] 2.2 Add `-DrulesUri=file:///${GITHUB_WORKSPACE}/.github/versions-rules.xml` to the `versions:display-plugin-updates` invocation (line ~76 in `dependency-updates.yml`)
- [x] 2.3 Add `-DrulesUri=file:///${GITHUB_WORKSPACE}/.github/versions-rules.xml` to the `versions:display-dependency-updates` invocation (line ~112 in `dependency-updates.yml`)
- [x] 2.4 Add `-DrulesUri=file:///${GITHUB_WORKSPACE}/.github/versions-rules.xml` to the `versions:update-properties` invocation (line ~186 in `dependency-updates.yml`)
- [x] 2.5 Confirm existing `-Dexcludes` parameters remain unchanged on the invocations that already use them

## 3. Validation

- [ ] 3.1 Run the workflow via `workflow_dispatch` on a test branch and confirm RC/alpha/beta/milestone/SNAPSHOT/CR versions no longer appear in the update logs
- [ ] 3.2 Verify stable versions (e.g., `4.34.1`, `5.6.15.Final`) still appear as valid update candidates
- [ ] 3.3 Verify artifacts listed in `automation-exclusions.txt` are still excluded independently of the rules file
