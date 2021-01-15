#Ensure nothing happens outside the directory this script is ran from
cd "$(dirname "$0")"
SCRIPT_DIRECTORY=$(pwd)

#Convert Passed Array to WhiteList
eval "declare -A VARIABLE_WHITELIST="${1#*=}

# Variables that are in if statements in the top of this file are
# passed in via export statements in a parent script instead
# aka export statements from the execute.sh script

if [ ! -n "$OLDER_WAR_FILE" ]; then
    echo "Required Parameter OLDER_WAR_FILE not set - check execute.sh or your export statements!"
    exit 1
fi

if [ ! -n "$NEWER_WAR_FILE" ]; then
    echo "Required Parameter NEWER_WAR_FILE not set - check execute.sh or your export statements!"
    exit 1
fi

#JAR Comparison Whitelist - only run pkgdiff on these specified fuzzy matches
if [ ! -n "$VARIABLE_WHITELIST_MODE" ]; then
    VARIABLE_WHITELIST_MODE="FALSE"
    VARIABLE_WHITELIST=( "string1" "string2" "string3" )
fi

if [ ! -n "$VARIABLE_DEBUG_MODE" ]; then
    VARIABLE_DEBUG_MODE="FALSE"
fi

if [ ! -n "$VARIABLE_ENABLE_DECOMPILER" ]; then
    VARIABLE_ENABLE_DECOMPILER="TRUE"
fi

if [ ! -n "$VARIABLE_WIPE_CURRENT_REPORT_DIRECTORY" ]; then
    VARIABLE_WIPE_CURRENT_REPORT_DIRECTORY="TRUE"
fi

if [ ! -n "$VARIABLE_WIPE_TEMP_DIRECTORY" ]; then
    VARIABLE_WIPE_TEMP_DIRECTORY="TRUE"
fi

if [ ! -n "$VARIABLE_RUN_PKGDIFF" ]; then
    VARIABLE_RUN_PKGDIFF="TRUE"
fi

if [ ! -n "$VARIABLE_RUN_PKGDIFF_RECURSIVE" ]; then
    VARIABLE_RUN_PKGDIFF_RECURSIVE="TRUE"
fi

#Working Directory Setup for Exploding the WAR
export VARIABLE_TEMP_BASE_DIRECTORY="/opt"
export VARIABLE_TEMP_SUBDIRECTORY="pkgdiff_temp"
export VARIABLE_TEMP="$VARIABLE_TEMP_BASE_DIRECTORY/$VARIABLE_TEMP_SUBDIRECTORY"

#Clean Temp Directory before starting
if [ "$VARIABLE_WIPE_TEMP_DIRECTORY" == "TRUE" ]; then
    rm -Rf "$VARIABLE_TEMP"
fi

mkdir -p "$VARIABLE_TEMP"

#Convert Path remove extension
OLDER_FILE_NAME=$(basename -- "$OLDER_WAR_FILE")
OLDER_FILE_EXTENSION="${OLDER_FILE_NAME##*.}"
OLDER_FILE_NAME="${OLDER_FILE_NAME%.*}"

NEWER_FILE_NAME=$(basename -- "$NEWER_WAR_FILE")
NEWER_FILE_EXTENSION="${NEWER_FILE_NAME##*.}"
NEWER_FILE_NAME="${NEWER_FILE_NAME%.*}"

#Workaround since pkgdiff doesn't support war files
OLDER_ZIP_FILE="$VARIABLE_TEMP/$OLDER_FILE_NAME-old.zip"
NEWER_ZIP_FILE="$VARIABLE_TEMP/$NEWER_FILE_NAME-new.zip"

#Temp working copy so we don't touch the originals
OLDER_WAR_FILE_TEMP="$VARIABLE_TEMP/$OLDER_FILE_NAME-old.war"
NEWER_WAR_FILE_TEMP="$VARIABLE_TEMP/$NEWER_FILE_NAME-new.war"

#Timestamps for Report 
VARIABLE_TIMESTAMP=$(date "+%Y-%m-%d_%H_%M_%S")
VARIABLE_REPORT_NAME="$OLDER_FILE_NAME-to-$NEWER_FILE_NAME"
VARIABLE_REPORT_NAME_TIMESTAMPED="$VARIABLE_TIMESTAMP-$OLDER_FILE_NAME-to-$NEWER_FILE_NAME"

#Log File
export VARIABLE_LOG_FILE="$SCRIPT_DIRECTORY/output.log"

if [ ! -f "$VARIABLE_LOG_FILE" ]; then
    touch "$VARIABLE_LOG_FILE"
fi

#Declare Recursive Unzip Function
performConditionalActionOnFile()
{
    FILE_NAME=$(basename -- "$1")
    FILE_EXTENSION="${FILE_NAME##*.}"
    FILE_NAME="${FILE_NAME%.*}"

    ARCHIVE_DIRECTORY=$(dirname "$1")
    ARCHIVE_OUTPUT_DIRECTORY="$ARCHIVE_DIRECTORY/$FILE_NAME"

    FILE_TYPE_MATCH="FALSE"

    #If for some reason we find that jars contain jars - shouldn't be
    #COMPRESSED_ARCHIVE_TYPES=( "zip" "gz" "jar")
    COMPRESSED_ARCHIVE_TYPES=( "zip" "gz" )
    for fileType in "${COMPRESSED_ARCHIVE_TYPES[@]}"
    do
        if [[ $1 =~ \.$fileType ]]; then
            echo COMPRESSED_ARCHIVE "$1"
            unzip -o -q "$1" -d "$ARCHIVE_OUTPUT_DIRECTORY"
            echo "Unzipped $1 to $ARCHIVE_OUTPUT_DIRECTORY"
            
            searchDirectory "$ARCHIVE_OUTPUT_DIRECTORY"
            return 
        fi
    done

}

#Declare Recursive Loop Function based on file extensions
searchDirectory()
{
    FILE_EXTENSIONS=( "war" "jar" "class" "zip" "gz"  )
    for fileType in "${FILE_EXTENSIONS[@]}"
    do
        find "$1" -name "*.$fileType" -print -type f -exec bash -c 'performConditionalActionOnFile "$0"' {} \;
    done
}


decompileArtifact()
{
    SOURCE_BINARY_FILE="$1"

    if [ ! -n "$2" ]; then
        OPTIONAL_DESTINATION_BINARY_FOR_DECOMPILED_SOURCE="$SOURCE_BINARY_FILE"
    else
        OPTIONAL_DESTINATION_BINARY_FOR_DECOMPILED_SOURCE="$2"
    fi

    if [ "$VARIABLE_ENABLE_DECOMPILER" == "TRUE" ]; then

        if [ ! -n "$JAVA_HOME" ]; then
            JAVA_HOME="/usr/lib/jvm/java-1.8.0/"
        fi

        VARIABLE_JAVA_PATH="$JAVA_HOME/bin/java"
        VARIABLE_JAR_PATH="$JAVA_HOME/bin/jar"
        VARIABLE_JAVA_DECOMPILER_JAR="$SCRIPT_DIRECTORY/jd-cmd-master/jd-cli/target/jd-cli.jar"

        FILE_NAME=$(basename -- "$SOURCE_BINARY_FILE")
        FILE_EXTENSION="${FILE_NAME##*.}"
        FILE_NAME="${FILE_NAME%.*}"
 
        ARCHIVE_DIRECTORY=$(dirname "$SOURCE_BINARY_FILE")
        ARCHIVE_OUTPUT_DIRECTORY="$ARCHIVE_DIRECTORY/$FILE_NAME"
        ARCHIVE_OUTPUT_DIRECTORY_SRC="$ARCHIVE_OUTPUT_DIRECTORY/src"

        mkdir -p "$ARCHIVE_OUTPUT_DIRECTORY"
        mkdir -p "$ARCHIVE_OUTPUT_DIRECTORY_SRC"

        FILE_TYPE_MATCH="FALSE"

        JAVA_CLASS_TYPES=( "class" )
        for fileType in "${JAVA_CLASS_TYPES[@]}"
        do
            if [[ $1 =~ \.$fileType ]]; then
                debugString "JAVA_CLASS $SOURCE_BINARY_FILE"
                "$VARIABLE_JAVA_PATH" -jar "$VARIABLE_JAVA_DECOMPILER_JAR" -dm -rn -n -od "$ARCHIVE_OUTPUT_DIRECTORY_SRC" "$SOURCE_BINARY_FILE" >> "$VARIABLE_LOG_FILE" 2>&1
                debugString "Decompiled $SOURCE_BINARY_FILE to $ARCHIVE_OUTPUT_DIRECTORY_SRC"

                #Change Directory to src directory for filtering
                cd "$ARCHIVE_OUTPUT_DIRECTORY_SRC"

                #Remove any files that are not .java files in the src
                find . -type f ! -name '*.java' -delete
                
                #Remove any empty directories
                find . -empty -type d -delete

                #Change Directory to parent dir above src for filtering
                cd "$ARCHIVE_OUTPUT_DIRECTORY"

                "$VARIABLE_JAR_PATH" -uf "$OPTIONAL_DESTINATION_BINARY_FOR_DECOMPILED_SOURCE" "./src"  

                debugString "Added Source from $ARCHIVE_OUTPUT_DIRECTORY_SRC to $OPTIONAL_DESTINATION_BINARY_FOR_DECOMPILED_SOURCE"

                return
            fi
        done

        JAVA_ARCHIVE_TYPES=( "war" "jar" )
        for fileType in "${JAVA_ARCHIVE_TYPES[@]}"
        do
            if [[ $1 =~ \.$fileType ]]; then
                debugString "JAVA_ARCHIVE $SOURCE_BINARY_FILE"
                "$VARIABLE_JAVA_PATH" -jar "$VARIABLE_JAVA_DECOMPILER_JAR" -dm -rn -n -od "$ARCHIVE_OUTPUT_DIRECTORY_SRC" "$SOURCE_BINARY_FILE" >> "$VARIABLE_LOG_FILE" 2>&1
                debugString "Decompiled $SOURCE_BINARY_FILE to $ARCHIVE_OUTPUT_DIRECTORY_SRC"

                #Change Directory to src directory for filtering
                cd "$ARCHIVE_OUTPUT_DIRECTORY_SRC"

                #Remove any files that are not .java files in the src
                find . -type f ! -name '*.java' -delete
                
                #Remove any empty directories
                find . -empty -type d -delete

                #Change Directory to parent dir above src for filtering
                cd "$ARCHIVE_OUTPUT_DIRECTORY"

                "$VARIABLE_JAR_PATH" -uf "$OPTIONAL_DESTINATION_BINARY_FOR_DECOMPILED_SOURCE" "./src"  

                debugString "Added Source from $ARCHIVE_OUTPUT_DIRECTORY_SRC to $OPTIONAL_DESTINATION_BINARY_FOR_DECOMPILED_SOURCE"
                return 
            fi
        done
    fi
}

removeHyphenDotAndVersionNumberFromJar()
{
    #Remove Numbers from String
    CORRECTED_FILENAME=$(printf '%s' "$1" | sed 's/[0-9]//g')

    #Remove Hyphens from String
    CORRECTED_FILENAME=$(printf '%s' "$CORRECTED_FILENAME" | sed 's/-//g')

    #Remove Underscore from String
    CORRECTED_FILENAME=$(printf '%s' "$CORRECTED_FILENAME" | sed 's/_//g')

    #Remove Dots from String
    CORRECTED_FILENAME=$(printf '%s' "$CORRECTED_FILENAME" | sed 's/\.//g')

    #Remove Build from String
    CORRECTED_FILENAME=$(printf '%s' "$CORRECTED_FILENAME" | sed 's/Build//g')

    #Remove SNAPSHOT from String
    CORRECTED_FILENAME=$(printf '%s' "$CORRECTED_FILENAME" | sed 's/SNAPSHOT//g')

    echo "$CORRECTED_FILENAME"
}

debugString()
{
    if [ "$VARIABLE_DEBUG_MODE" == "TRUE" ]; then
        echo "$1" >> "$VARIABLE_LOG_FILE"
    fi
}

checkIfInWhitelist()
{
    OLDER_JAR_FILE_NAME="$1"
    BOOLEAN_PROCESS_THIS_JAR="FALSE"

    if [ "$VARIABLE_WHITELIST_MODE" == "TRUE" ]; then
        debugString "Checking if $OLDER_JAR_FILE_NAME is whitelisted..."

        for WHITELISTED_STRING in "${VARIABLE_WHITELIST[@]}"
        do
            OLDER_JAR_FILE_NAME_UPPER=${OLDER_JAR_FILE_NAME^^}
            WHITELISTED_STRING_UPPER=${WHITELISTED_STRING^^}

            debugString "Comparing $OLDER_JAR_FILE_NAME_UPPER to $WHITELISTED_STRING_UPPER"

            if [[ "$OLDER_JAR_FILE_NAME_UPPER" == *"$WHITELISTED_STRING_UPPER"* ]]; then
                debugString "Match found! $OLDER_JAR_FILE_NAME_UPPER has $WHITELISTED_STRING_UPPER in it."
                BOOLEAN_PROCESS_THIS_JAR="TRUE"
                break;
            fi
        done 
    else
        BOOLEAN_PROCESS_THIS_JAR="TRUE"
    fi

    echo "$BOOLEAN_PROCESS_THIS_JAR"
}

#Declare pkgdiff recursive function
pkgdiff_recursive()
{
    OLDER_ZIP_FILE_NAME=$(basename -- "$1")
    OLDER_ZIP_FILE_EXTENSION="${OLDER_ZIP_FILE_NAME##*.}"
    OLDER_ZIP_FILE_NAME="${OLDER_ZIP_FILE_NAME%.*}"

    OLDER_ZIP_ARCHIVE_DIRECTORY=$(dirname "$1")
    OLDER_ZIP_ARCHIVE_OUTPUT_DIRECTORY="$OLDER_ZIP_ARCHIVE_DIRECTORY/$OLDER_ZIP_FILE_NAME"

    NEWER_ZIP_FILE_NAME=$(basename -- "$2")
    NEWER_ZIP_FILE_EXTENSION="${NEWER_ZIP_FILE_NAME##*.}"
    NEWER_ZIP_FILE_NAME="${NEWER_ZIP_FILE_NAME%.*}"

    NEWER_ZIP_ARCHIVE_DIRECTORY=$(dirname "$2")
    NEWER_ZIP_ARCHIVE_OUTPUT_DIRECTORY="$NEWER_ZIP_ARCHIVE_DIRECTORY/$NEWER_ZIP_FILE_NAME"

    OLDER_JAR_FILE_LIST=$(find "$OLDER_ZIP_ARCHIVE_OUTPUT_DIRECTORY" -name "*.jar" -print -type f)
    NEWER_JAR_FILE_LIST=$(find "$NEWER_ZIP_ARCHIVE_OUTPUT_DIRECTORY" -name "*.jar" -print -type f)

    for OLDER_JAR_FILE in $OLDER_JAR_FILE_LIST; do 
        OLDER_JAR_FILE_NAME=$(basename -- "$OLDER_JAR_FILE")
        OLDER_JAR_FILE_EXTENSION="${OLDER_JAR_FILE_NAME##*.}"
        OLDER_JAR_FILE_NAME="${OLDER_JAR_FILE_NAME%.*}"

        OLDER_JAR_FILE_DEVERSIONED=$(removeHyphenDotAndVersionNumberFromJar "$OLDER_JAR_FILE_NAME")

        #This is done twice for optimization and speed purposes
        #Since this is a for loop within a for loop we want to get the heck out
        #of this execution as quickly as possible
        BOOLEAN_PROCESS_THIS_JAR=$(checkIfInWhitelist "$OLDER_JAR_FILE_NAME")

        if [ "$BOOLEAN_PROCESS_THIS_JAR" == "TRUE" ]; then
            for NEWER_JAR_FILE in $NEWER_JAR_FILE_LIST; do 
                NEWER_JAR_FILE_NAME=$(basename -- "$NEWER_JAR_FILE")
                NEWER_JAR_FILE_EXTENSION="${NEWER_JAR_FILE_NAME##*.}"
                NEWER_JAR_FILE_NAME="${NEWER_JAR_FILE_NAME%.*}"

                NEWER_JAR_FILE_DEVERSIONED=$(removeHyphenDotAndVersionNumberFromJar "$NEWER_JAR_FILE_NAME")

                #This is done twice for optimization and speed purposes
                #Since this is a for loop within a for loop we want to get the heck out
                #of this execution as quickly as possible
                BOOLEAN_PROCESS_THIS_JAR=$(checkIfInWhitelist "$NEWER_JAR_FILE_NAME")

                if [ "$BOOLEAN_PROCESS_THIS_JAR" == "TRUE" ]; then
                    debugString "####################"
                    debugString "### Debug Output ###"
                    debugString "####################"
                    debugString ""
                    debugString "Older Jar File - $OLDER_JAR_FILE"
                    debugString "Older Jar File Deversioned - $OLDER_JAR_FILE_DEVERSIONED"
                    debugString ""
                    debugString "Newer Jar File - $NEWER_JAR_FILE"
                    debugString "Newer Jar File Deversioned - $NEWER_JAR_FILE_DEVERSIONED"
                    debugString ""
                    
                    if [ "$OLDER_JAR_FILE_DEVERSIONED" == "$NEWER_JAR_FILE_DEVERSIONED" ]; then
                        echo "###################"
                        echo "### Match Found ###"
                        echo "###################"
                        echo ""
                        echo "Older Jar File - $OLDER_JAR_FILE"
                        echo "Older Jar File Deversioned - $OLDER_JAR_FILE_DEVERSIONED"
                        echo ""
                        echo "Newer Jar File - $NEWER_JAR_FILE"
                        echo "Newer Jar File Deversioned - $NEWER_JAR_FILE_DEVERSIONED"
                        echo ""

                        
                        debugString "Comparing $OLDER_JAR_FILE and $NEWER_JAR_FILE to see if pkgdiff/decompile can be skipped..."

                        diff -q "$OLDER_JAR_FILE" "$NEWER_JAR_FILE" 1>/dev/null

                        if [[ $? == "0" ]]
                        then
                            debugString "Diff - Files are the same - Not Running pkgDiff/decompile..."
                        else
                            debugString "Diff - Files are not the same - running analysis..."
                    
                            #Setup the JAR Comparison Directory for Report
                            VARIABLE_REPORT_JAR_COMPARISON_DIRECTORY="$VARIABLE_REPORT_DIRECTORY/$OLDER_JAR_FILE_NAME-to-$NEWER_JAR_FILE_NAME"
                            
                            if [ "$VARIABLE_WIPE_CURRENT_REPORT_DIRECTORY" == "TRUE" ]; then
                                rm -Rf "$VARIABLE_REPORT_JAR_COMPARISON_DIRECTORY"
                            fi

                            mkdir -p "$VARIABLE_REPORT_JAR_COMPARISON_DIRECTORY"

                            #Report file for WAR Comparison
                            VARIABLE_REPORT_JAR_COMPARISON_HTML_FILE="$VARIABLE_REPORT_JAR_COMPARISON_DIRECTORY/report.html"

                            #Decompile the code and add it back into the jar for pkgdiff in next step
                            decompileArtifact "$OLDER_JAR_FILE"
                            decompileArtifact "$NEWER_JAR_FILE"

                            if [ "$VARIABLE_RUN_PKGDIFF" == "TRUE" ]; then
                                pkgdiff -report-path "$VARIABLE_REPORT_JAR_COMPARISON_HTML_FILE" -hide-unchanged "$OLDER_JAR_FILE" "$NEWER_JAR_FILE"
                            fi
                        fi

                        break
                    fi
                fi        
            done
        fi
    done
}

generateReport_list_addRow()
{
    REPORT_SUBDIRECTORY="$1"
    echo "<tr><td nowrap><a href=\"./$REPORT_SUBDIRECTORY/report.html\" target=\"reportFrame\">$REPORT_SUBDIRECTORY</a></td></tr>"
}

generateReport_list_header()
{
    echo "<html><body><h2>Reports</h2><table border=\"0\"><tbody>"
}

generateReport_list_footer()
{
    echo "</tbody></table></body></html>"
}

generateReport_index()
{
    echo "<html><head><title>WAR Comparison Recursive Report</title></head><frameset cols=\"20%,80%\"><frame src=\"./list.html\" name=\"listFrame\"></frame><frame src=\"WAR_COMPARISON/report.html\" name=\"reportFrame\"></frame></frameset></html>"
}

generateReport() {
    REPORT_DIRECTORY="$1"

    REPORT_LIST_FILE="$REPORT_DIRECTORY/list.html"
    rm -f "$REPORT_LIST_FILE"
    touch "$REPORT_LIST_FILE"

    REPORT_INDEX_FILE="$REPORT_DIRECTORY/index.html"
    rm -f "$REPORT_INDEX_FILE"
    touch "$REPORT_INDEX_FILE"

    echo "Report generating index at $REPORT_INDEX_FILE..."
    generateReport_index >> "$REPORT_INDEX_FILE"

    echo "Report generating list at $REPORT_LIST_FILE..."
    generateReport_list_header >> "$REPORT_LIST_FILE"

    cd "$REPORT_DIRECTORY"

    for REPORT_SUBDIRECTORY in *; do
        if [ -d "$REPORT_SUBDIRECTORY" ]; then
            echo "Report - Directory detected - adding $REPORT_SUBDIRECTORY to $REPORT_LIST_FILE..."
            generateReport_list_addRow "$REPORT_SUBDIRECTORY" >> "$REPORT_LIST_FILE"
        fi
    done

    generateReport_list_footer >> "$REPORT_LIST_FILE"
}

main()
{
    #Workaround to copy the war to a zip file extension
    cp "$OLDER_WAR_FILE" "$OLDER_ZIP_FILE"
    cp "$NEWER_WAR_FILE" "$NEWER_ZIP_FILE"

    #Create working copy temporarily
    cp "$OLDER_WAR_FILE" "$OLDER_WAR_FILE_TEMP"
    cp "$NEWER_WAR_FILE" "$NEWER_WAR_FILE_TEMP"

    #Decompile the code and add it back into the zip for pkgdiff in next step
    decompileArtifact "$OLDER_WAR_FILE_TEMP" "$OLDER_ZIP_FILE"
    decompileArtifact "$NEWER_WAR_FILE_TEMP" "$NEWER_ZIP_FILE"

    #Compare File Sizes
    # ls -al "$OLDER_WAR_FILE"
    # ls -al "$NEWER_WAR_FILE"

    #Sample
    #pkgdiff OLD.jar NEW.jar

    #Setup the Reports Directory
    export VARIABLE_REPORT_DIRECTORY="$SCRIPT_DIRECTORY/reports/$VARIABLE_REPORT_NAME"
    export VARIABLE_REPORT_DIRECTORY_TIMESTAMPED="$SCRIPT_DIRECTORY/reports/$VARIABLE_REPORT_NAME_TIMESTAMPED"

    if [ "$VARIABLE_WIPE_CURRENT_REPORT_DIRECTORY" == "TRUE" ]; then
        rm -Rf "$VARIABLE_REPORT_DIRECTORY"
    fi

    mkdir -p "$VARIABLE_REPORT_DIRECTORY"

    #Setup the WAR Comparison Directory for Report
    export VARIABLE_REPORT_WAR_COMPARISON_DIRECTORY="$VARIABLE_REPORT_DIRECTORY/WAR_COMPARISON"

    if [ "$VARIABLE_WIPE_CURRENT_REPORT_DIRECTORY" == "TRUE" ]; then
        rm -Rf "$VARIABLE_REPORT_WAR_COMPARISON_DIRECTORY"
    fi

    mkdir -p "$VARIABLE_REPORT_WAR_COMPARISON_DIRECTORY"

    #Report file for WAR Comparison
    export VARIABLE_REPORT_WAR_COMPARISON_HTML_FILE="$VARIABLE_REPORT_WAR_COMPARISON_DIRECTORY/report.html"

    if [ "$VARIABLE_RUN_PKGDIFF" == "TRUE" ]; then
        pkgdiff -report-path "$VARIABLE_REPORT_WAR_COMPARISON_HTML_FILE" -hide-unchanged "$OLDER_ZIP_FILE" "$NEWER_ZIP_FILE"
    fi
    
    export -f performConditionalActionOnFile
    export -f searchDirectory

    #Expand the WAR Files and Jar Files
    searchDirectory "$OLDER_ZIP_FILE"
    searchDirectory "$NEWER_ZIP_FILE"

    if [ "$VARIABLE_RUN_PKGDIFF_RECURSIVE" == "TRUE" ]; then
        pkgdiff_recursive "$OLDER_ZIP_FILE" "$NEWER_ZIP_FILE"
    fi

    #Let the output catch up for a second so the log file doesn't look weird
    sleep 5

    #Generate Customized Report with iFrames
    generateReport "$VARIABLE_REPORT_DIRECTORY"

    cp -R "$VARIABLE_REPORT_DIRECTORY" "$VARIABLE_REPORT_DIRECTORY_TIMESTAMPED"
    cp "$VARIABLE_LOG_FILE" "$VARIABLE_REPORT_DIRECTORY_TIMESTAMPED/output.log"

    #Compress Reports to Zip
    cd "$VARIABLE_REPORT_DIRECTORY_TIMESTAMPED"
    zip -r "../$VARIABLE_REPORT_NAME_TIMESTAMPED.zip" *

    echo "pkgdiff_recursive.sh has finished running - you can ctrl+c or close the window now..."
}

main
