package gov.cdc.izgw.validation;

/**
 * Marker class for the IZ Gateway BOM validation module.
 *
 * <p>This module exists solely to verify that all dependency versions declared in the
 * IZ Gateway BOM ({@code izgw-bom}) resolve correctly from Maven Central and GitHub
 * Packages, and to allow OWASP Dependency-Check to scan those resolved JARs for known
 * CVEs as part of CI/CD.</p>
 *
 * <p>It is never published or deployed; the {@code <packaging>jar</packaging>} declaration
 * causes Maven to compile this class and produce a conventional library JAR so that the
 * {@code dependency:copy-dependencies} goal can copy all transitive dependencies alongside
 * it for scanning.</p>
 */
public final class BomValidation {

    /** Utility class; do not instantiate. */
    private BomValidation() {
    }
}
