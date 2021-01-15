#Ensure nothing happens outside the directory this script is ran from
cd "$(dirname "$0")"
SCRIPT_DIRECTORY=$(pwd)

#Two WAR Files to Compare
export OLDER_WAR_FILE="$SCRIPT_DIRECTORY/tomcat-sample-old.war"
export NEWER_WAR_FILE="$SCRIPT_DIRECTORY/tomcat-sample-new.war"

#JAR Comparison Whitelist
export VARIABLE_WHITELIST_MODE="TRUE"

VARIABLE_WHITELIST=( "joda" )

export VARIABLE_DEBUG_MODE="TRUE"

####################
### Do not touch ###
####################

#Kill any running instances of pkgdiff_recursive.sh
pkill -f pkgdiff_recursive.sh 

#Empty log file before running if it exists
VARIABLE_LOG_FILE="$SCRIPT_DIRECTORY/output.log"

if [ -f "$VARIABLE_LOG_FILE" ]; then
    truncate -s 0 "$VARIABLE_LOG_FILE"
fi

#Run pkgdiff_recursive...
echo "Running pkgdiff_recursive.sh in background..."
sh pkgdiff_recursive.sh "$(declare -p VARIABLE_WHITELIST)" >> $SCRIPT_DIRECTORY/output.log 2>&1 &
tail -F -n+1 "$SCRIPT_DIRECTORY/output.log"