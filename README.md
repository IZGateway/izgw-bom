# IZ Gateway Bill of Materials (BOM)

This repository contains a Maven Bill of Materials (BOM) POM that provides centralized dependency management for all IZ Gateway projects.

## Features

- **Centralized Dependency Management**: Defines versions for common dependencies used across IZ Gateway projects
- **External Properties Support**: Version properties can be loaded from external files using the properties-maven-plugin
- **Spring Boot & Framework Integration**: Pre-configured with appropriate Spring Boot and Spring Framework versions
- **Common Libraries**: Includes management for testing, logging, HTTP clients, and utility libraries

## Usage

### As a BOM Import

In your project's `pom.xml`, add this BOM to your `dependencyManagement` section:

```xml
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>gov.cdc.izgw</groupId>
            <artifactId>izgw-bom</artifactId>
            <version>1.0.0-SNAPSHOT</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

### Using External Properties

To use the external version properties in your project, configure the properties-maven-plugin:

```xml
<build>
    <plugins>
        <plugin>
            <groupId>org.codehaus.mojo</groupId>
            <artifactId>properties-maven-plugin</artifactId>
            <version>1.2.1</version>
            <executions>
                <execution>
                    <phase>initialize</phase>
                    <goals>
                        <goal>read-project-properties</goal>
                    </goals>
                    <configuration>
                        <files>
                            <file>izgw-versions.properties</file>
                        </files>
                    </configuration>
                </execution>
            </executions>
        </plugin>
    </plugins>
</build>
```

### Managed Dependencies

This BOM manages versions for:

- **Spring Boot** (3.1.5)
- **Spring Framework** (6.0.13)
- **Spring Security** (6.1.5)
- **Jackson** (2.19.2)
- **JUnit** (5.12.2)
- **Mockito** (5.17.0)
- **Testcontainers** (1.19.1)
- **SLF4J & Logback** for logging
- **Apache Commons** utilities
- **Jakarta Validation** and Hibernate Validator 
- And more...

## Files

- `pom.xml` - The main BOM POM file
- `izgw-versions.properties` - External properties file with version definitions

## Benefits

1. **Consistency**: Ensures all IZ Gateway projects use the same dependency versions
2. **Maintainability**: Central place to update dependency versions
3. **Flexibility**: External properties file allows for easy version management
4. **Spring Integration**: Optimized for Spring Boot and Spring Framework projects
