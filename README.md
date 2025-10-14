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
            <version>1.0.0-SNAPSHOT</version>
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

## Files

- `pom.xml` - The main BOM POM file

## Benefits

1. **Consistency**: Ensures all IZ Gateway projects use the same dependency versions
2. **Maintainability**: Central place to update dependency versions
3. **Flexibility**: External properties file allows for easy version management
4. **Spring Integration**: Optimized for Spring Boot and Spring Framework projects

---

For a full list of managed dependencies and BOM imports, see the [`pom.xml`](pom.xml).