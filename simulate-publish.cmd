@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM simulate-publish.cmd
REM
REM Simulates the izgw-bom publish CI workflow locally through
REM the dependency-copy step, then runs OWASP Dependency-Check
REM CLI against the resolved JARs.
REM
REM Required environment variables (set before running):
REM   GITHUB_TOKEN        GitHub PAT with read:packages scope
REM   NVD_API_KEY         NVD API key (https://nvd.nist.gov/developers/request-an-api-key)
REM
REM Optional environment variables:
REM   OSS_INDEX_USERNAME  Sonatype OSS Index username (improves scan quality)
REM   OSS_INDEX_PASSWORD  Sonatype OSS Index password / token
REM   DC_HOME             Path to dependency-check CLI installation
REM                       Default: C:\tools\dependency-check
REM   SKIP_DC             Set to 1 to skip the dependency-check scan (build only)
REM ============================================================

set SCRIPT_DIR=%~dp0
set SCRIPT_DIR=%SCRIPT_DIR:~0,-1%
cd /d "%SCRIPT_DIR%"

REM ---- Defaults ----
if not defined DC_HOME set DC_HOME=C:\tools\dependency-check
if not defined SKIP_DC set SKIP_DC=0

set DC_CLI=%DC_HOME%\bin\dependency-check.bat
set REPORT_DIR=%SCRIPT_DIR%\dependency-check-report
set SUPPRESSION=%SCRIPT_DIR%\dependency-suppression.xml

echo.
echo ============================================================
echo  izgw-bom publish simulation
echo ============================================================
echo.

REM ---- Prerequisite checks ----
echo [1/7] Checking prerequisites...

where mvn >nul 2>&1
if errorlevel 1 (
    echo ERROR: mvn not found on PATH. Install Maven 3.9+ and add to PATH.
    exit /b 1
)

where java >nul 2>&1
if errorlevel 1 (
    echo ERROR: java not found on PATH. Install JDK 21.
    exit /b 1
)

if not defined GITHUB_TOKEN (
    echo ERROR: GITHUB_TOKEN is not set.
    echo        Set it to a GitHub PAT with read:packages scope.
    exit /b 1
)

if "%SKIP_DC%"=="0" (
    if not defined NVD_API_KEY (
        echo WARNING: NVD_API_KEY is not set. Dependency-Check will use the public NVD feed
        echo          which is heavily rate-limited. Scan may be slow or incomplete.
        echo          Get a key at: https://nvd.nist.gov/developers/request-an-api-key
        echo.
    )
    if not exist "%DC_CLI%" (
        echo ERROR: Dependency-Check CLI not found at: %DC_CLI%
        echo        Download from https://github.com/jeremylong/DependencyCheck/releases
        echo        and extract to %DC_HOME%, or set DC_HOME to your installation path.
        exit /b 1
    )
)

echo   mvn:  OK
echo   java: OK
echo   GITHUB_TOKEN: set
if "%SKIP_DC%"=="0" echo   DC_HOME: %DC_HOME%
echo.

REM ---- Ensure ~/.m2/settings.xml has GitHub server entries ----
echo [2/7] Checking Maven settings for GitHub Packages auth...

set M2_SETTINGS=%USERPROFILE%\.m2\settings.xml

powershell -NoProfile -Command ^
    "$s='%M2_SETTINGS%'.Replace('\','/'); " ^
    "if (!(Test-Path $s)) { " ^
    "  New-Item -ItemType File -Path $s -Force | Out-Null; " ^
    "  Set-Content $s '<settings><servers></servers></settings>'; " ^
    "} " ^
    "$xml=[xml](Get-Content $s); " ^
    "$ids = $xml.settings.servers.server | ForEach-Object { $_.id }; " ^
    "if ($ids -notcontains 'github') { Write-Host 'MISSING_GITHUB' } " ^
    "else { Write-Host 'OK' } " > "%TEMP%\mvn_settings_check.txt" 2>&1

set /p SETTINGS_CHECK=<"%TEMP%\mvn_settings_check.txt"
del "%TEMP%\mvn_settings_check.txt" >nul 2>&1

if "%SETTINGS_CHECK%"=="MISSING_GITHUB" (
    echo   Adding github server entry to %M2_SETTINGS%...
    powershell -NoProfile -Command ^
        "$s='%M2_SETTINGS%'; " ^
        "$xml=[xml](Get-Content $s); " ^
        "$svr=$xml.CreateElement('server'); " ^
        "$id=$xml.CreateElement('id'); $id.InnerText='github'; " ^
        "$user=$xml.CreateElement('username'); $user.InnerText='${env.GITHUB_ACTOR}'; " ^
        "$pass=$xml.CreateElement('password'); $pass.InnerText='${env.GITHUB_TOKEN}'; " ^
        "$svr.AppendChild($id)|Out-Null; $svr.AppendChild($user)|Out-Null; $svr.AppendChild($pass)|Out-Null; " ^
        "$xml.settings.servers.AppendChild($svr)|Out-Null; " ^
        "$xml.Save($s); Write-Host 'Added github server entry.'"
) else (
    echo   settings.xml OK ^(github server already present^)
)
echo.

REM ---- Step: Validate POM ----
echo [3/7] Validating POM...
call mvn -B validate -q
if errorlevel 1 (
    echo ERROR: mvn validate failed.
    exit /b 1
)
echo   POM is well-formed.
echo.

REM ---- Step: Check no hardcoded versions in dependencyManagement ----
echo [4/7] Checking dependencyManagement versions are property-backed...
powershell -NoProfile -Command ^
    "$content = Get-Content '%SCRIPT_DIR%\pom.xml' -Raw; " ^
    "$block = [regex]::Match($content, '(?s)<dependencyManagement>.*?</dependencyManagement>').Value; " ^
    "$hardcoded = [regex]::Matches($block, '(?<=<version>)(?!\$\{)[^<]+') | ForEach-Object { $_.Value }; " ^
    "if ($hardcoded) { Write-Host ('HARDCODED:' + ($hardcoded -join ',')); exit 1 } " ^
    "else { Write-Host 'OK' } " > "%TEMP%\version_check.txt" 2>&1

set /p VERSION_CHECK=<"%TEMP%\version_check.txt"
del "%TEMP%\version_check.txt" >nul 2>&1

if "%VERSION_CHECK:~0,10%"=="HARDCODED:" (
    echo ERROR: Hardcoded version^(s^) found in ^<dependencyManagement^>:
    echo   %VERSION_CHECK:~10%
    exit /b 1
)
echo   All dependencyManagement versions are property-backed.
echo.

REM ---- Step: Install BOM to local repo ----
echo [5/7] Installing BOM to local Maven repository...
call mvn -B install -N -DskipDependencyCheck=true -DskipTests=true -q
if errorlevel 1 (
    echo ERROR: mvn install -N failed.
    exit /b 1
)
echo   BOM installed.
echo.

REM ---- Step: Build validation project + copy runtime deps ----
echo [6/7] Building validation project and copying runtime dependencies...
call mvn -B clean package -f validation\pom.xml -DskipDependencyCheck=true -DskipTests=true -q
if errorlevel 1 (
    echo ERROR: mvn package on validation project failed.
    exit /b 1
)

call mvn -B dependency:copy-dependencies -f validation\pom.xml ^
    -DoutputDirectory=validation\target\dependency ^
    -DincludeScope=runtime ^
    -DskipDependencyCheck=true -q
if errorlevel 1 (
    echo ERROR: dependency:copy-dependencies failed.
    exit /b 1
)

REM Count the JARs
set JAR_COUNT=0
for %%f in (validation\target\dependency\*.jar) do set /a JAR_COUNT+=1
echo   Build complete. %JAR_COUNT% runtime JARs in validation\target\dependency\
echo.

REM ---- Step: OWASP Dependency-Check ----
if "%SKIP_DC%"=="1" (
    echo [7/7] Skipping dependency-check scan ^(SKIP_DC=1^).
    echo.
    echo Build output ready at: %SCRIPT_DIR%\validation\target\dependency\
    echo To run the scan manually, see the command at the bottom of this script.
    goto :done
)

echo [7/7] Running OWASP Dependency-Check...
echo   Scan target : %SCRIPT_DIR%\validation
echo   Report dir  : %REPORT_DIR%
echo   Suppression : %SUPPRESSION%
echo   (This may take several minutes on first run while downloading the NVD database)
echo.

if not exist "%REPORT_DIR%" mkdir "%REPORT_DIR%"

set DC_ARGS=--project "izgw-bom-validation" ^
    --scan "%SCRIPT_DIR%\validation" ^
    --format HTML ^
    --out "%REPORT_DIR%" ^
    --suppression "%SUPPRESSION%" ^
    --failOnCVSS 7 ^
    --disableNuspec ^
    --disableNugetconf ^
    --disableAssembly ^
    --data "%USERPROFILE%\.dependency-check-data"

if defined NVD_API_KEY (
    set DC_ARGS=!DC_ARGS! --nvdApiKey "%NVD_API_KEY%"
)
if defined OSS_INDEX_USERNAME (
    set DC_ARGS=!DC_ARGS! --ossIndexUsername "%OSS_INDEX_USERNAME%" --ossIndexPassword "%OSS_INDEX_PASSWORD%"
)

call "%DC_CLI%" %DC_ARGS%
set DC_EXIT=%errorlevel%

echo.
if %DC_EXIT%==0 (
    echo Dependency-Check completed — no CVEs at CVSS ^>= 7 found.
) else (
    echo Dependency-Check found issues ^(exit code %DC_EXIT%^).
    echo Check the report in: %REPORT_DIR%
)

for %%f in ("%REPORT_DIR%\*.html") do (
    echo Report: %%f
    start "" "%%f"
)

:done
echo.
echo Done.
endlocal
exit /b %DC_EXIT%
