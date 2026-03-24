package gov.cdc.izgw.validation;

/**
 * Trivial entry point for the izgw-bom validation project.
 *
 * <p>This class exists solely so that the project compiles as a {@code jar}
 * rather than a {@code pom}-only module. The resulting JAR (along with all
 * runtime dependency JARs staged under {@code target/dependency}) is what the
 * OWASP dependency-check file scanner inspects during CI. The project is never
 * deployed or executed in production.</p>
 */
public class Main {

    private Main() {
        // utility class — not instantiated
    }

    /**
     * Prints a confirmation message and exits normally.
     *
     * @param args command-line arguments (ignored)
     */
    public static void main(String[] args) {
        System.out.println("izgw-bom validation project — dependency resolution OK");
    }
}
