# Recursive PkgDiff for WAR Comparison

Prerequisites:
- Java JDK 8 or higher installed
- PkgDiff
    - https://github.com/lvc/pkgdiff
- JD CMD CLI (If committed Jar no longer works)
    - https://github.com/kwart/jd-cli

General Usage:
1. Open execute.sh in Text Editor
2. Set Older/Newer WAR file path variables
3. Open terminal/gitbash/cygwin to this script directory - just in case
4. sh execute.sh

Whitelist Usage:
1. Open execute.sh in Text Editor
2. Add partial strings that match the desired jar files to variable
3. Open terminal/gitbash/cygwin to this script directory - just in case
4. sh execute.sh

Features:
- Whitelisting of Desired JAR String Matches
- Option to enable/disable whitelisting
- pkgdiff over parent WARs and all children JAR files
- Option to enable/disable decompiling 
    - Decompiles all detected/whitelisted (if enabled) jar files and attaches source back to jar file
    - Used for delta analysis in html report that pkgdiff creates
- Timestamped Reports - Both Zipped and Regular Folders
    - Each time script is ran clears current working report directory
    - At end of script takes output and copies to timestamped directory
    - At end of script zips the timestamped directory for portability

What it does:
1. Runs pkgdiff on the initial two WAR files
2. Unzips the WAR files
3. Searches for any JAR files in each unzipped path and indexes them
4. Attempts to find a JAR match across both of the unzipped WAR paths
    - Strips version numbers from the jar filenames
    - Checks the whitelist to see if the JAR matches ones you desire to be processed
5. (Optional) Runs JD Decompiler and attaches the decompiled code back to the JAR 
6. Runs pkgdiff on the matched jar files
7. Repeat steps 4-6 on all jars
8. Takes output and copies all to timestamped directory
9. Zips timestamped directory for portability 
    - Does not remove timestamped directory just zips it

Currently Committed Example:
- Sample WAR from Apache Tomcat Website:
  - https://tomcat.apache.org/tomcat-7.0-doc/appdev/sample/sample.war
- Jar added to tomcat-sample-new.war from Joda Time Github:
  - https://github.com/JodaOrg/joda-time/releases/download/v2.10.9/joda-time-2.10.9.jar
- Jar added to tomcat-sample-old.war from Joda Time Github:
  - https://github.com/JodaOrg/joda-time/releases/download/v2.10.3/joda-time-2.10.3.jar
- Setup Commands for WARs/JARs for example that are committed to this repo are in setup_example.sh
