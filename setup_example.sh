
VARIABLE_SAMPLE_WAR="./sample.war"
VARIABLE_SAMPLE_WAR_OLD="./tomcat-sample-old.war"
VARIABLE_SAMPLE_WAR_NEW="./tomcat-sample-new.war"

VARIABLE_SAMPLE_WAR_URL="https://tomcat.apache.org/tomcat-7.0-doc/appdev/sample/sample.war"

VARIABLE_SAMPLE_JAR_OLD="./WEB-INF/lib/joda-time-2.10.3.jar"
VARIABLE_SAMPLE_JAR_OLD_URL="https://github.com/JodaOrg/joda-time/releases/download/v2.10.3/joda-time-2.10.3.jar"

VARIABLE_SAMPLE_JAR_NEW="./WEB-INF/lib/joda-time-2.10.9.jar"
VARIABLE_SAMPLE_JAR_NEW_URL="https://github.com/JodaOrg/joda-time/releases/download/v2.10.9/joda-time-2.10.9.jar"

#Download the Sample WAR
curl -o "$VARIABLE_SAMPLE_WAR" "$VARIABLE_SAMPLE_WAR_URL"

#Duplicate Sample WAR to a "New" and "Old" version
cp "$VARIABLE_SAMPLE_WAR" "$VARIABLE_SAMPLE_WAR_OLD"
cp "$VARIABLE_SAMPLE_WAR" "$VARIABLE_SAMPLE_WAR_NEW"

#Remove No Longer Needed Sample WAR - we've duplicated it
rm -f "$VARIABLE_SAMPLE_WAR"

#Remove WEB-INF temp working directory and recreate it for consistency sake
rm -Rf "./WEB-INF"
mkdir -p "./WEB-INF/lib"

#Download the New JAR and add it to the New WAR

#Option 1
#Can't use curl due to github release redirection issue
#curl -o "$VARIABLE_SAMPLE_JAR_NEW" "$VARIABLE_SAMPLE_JAR_NEW_URL"

#Option 2 
cd "./WEB-INF/lib"
wget "$VARIABLE_SAMPLE_JAR_NEW_URL"
cd ../../
jar -uf "$VARIABLE_SAMPLE_WAR_NEW" "./WEB-INF"  

#Remove WEB-INF temp working directory and recreate it for consistency sake
rm -Rf "./WEB-INF"
mkdir -p "./WEB-INF/lib"

#Download the Old JAR and add it to the Old WAR

#Option 1
#Can't use curl due to github release redirection issue
#curl -o "$VARIABLE_SAMPLE_JAR_OLD" "$VARIABLE_SAMPLE_JAR_OLD_URL"

cd "./WEB-INF/lib"
wget "$VARIABLE_SAMPLE_JAR_OLD_URL"
cd ../../
jar -uf "$VARIABLE_SAMPLE_WAR_OLD" "./WEB-INF"  

#Remove WEB-INF temp working directory - be tidy.
# rm -Rf "./WEB-INF"