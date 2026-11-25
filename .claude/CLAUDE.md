# izgw-bom — Project Instructions

Maven Bill of Materials (BOM) for IZ Gateway. Manages consistent dependency versions
across all IZ Gateway Java projects. Published to GitHub Packages.

**Public repo** — follow IZ Gateway Public Repo Policy (in global CLAUDE.md).

---

## Notes

- No Java source — only `pom.xml` with `<dependencyManagement>`
- Version bumps here affect all consuming projects (`izgw-hub`, `izgw-core`, `izgw-transform`, `v2tofhir`, etc.)
- Check impact across consuming repos before bumping any version
- Published via CI on merge to main
