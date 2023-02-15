#!/bin/bash

# Usage: ./traceException.sh PID RULE_FILE BYTEMAN_AGENT_JAR

# Check that all arguments are present
if [ $# -lt 2 ]; then
  echo "Usage: $0 PID RULE_FILE [BYTEMAN_HOME]"
  exit 1
fi

# Check if BYTEMAN_HOME is set and not empty
if [ -z "$3" ] && [ ! -d $(pwd)/byteman-download-4.0.20 ]; then
    echo "BYTEMAN_HOME is not set."
    read -p "Do you want to download and install Byteman now? (y/n) " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        # Download and install Byteman
        echo "Downloading Byteman..."
        wget https://downloads.jboss.org/byteman/4.0.20/byteman-download-4.0.20-bin.zip
        unzip -qq byteman-download-4.0.20-bin.zip || {
           echo "Unzip failed"
           exit 1
           }
        export BYTEMAN_HOME=$(pwd)/byteman-download-4.0.20
        echo "BYTEMAN_HOME is set to $BYTEMAN_HOME"
    else
        echo "Exiting script."
        exit 1
    fi
elif 
 [  -d $(pwd)/byteman-download-4.0.20 ]; then
  export BYTEMAN_HOME=$(pwd)/byteman-download-4.0.20
  echo "BYTEMAN_HOME is set to $BYTEMAN_HOME"
else
 # Set the path to the Byteman agent jar file
 BYTEMAN_HOME=$3
 export BYTEMAN_HOME=$3
 echo "BYTEMAN_HOME is set to $BYTEMAN_HOME"
fi
# Set the process ID of the Java application to attach to
PID=$1
echo "The java process to attach to is $PID"

# Set the path to the Byteman rule file
RULE_FILE=$2
echo "The specified rule file is $RULE_FILE"


# Compile the Byteman helper class and package it in a JAR file
echo "Building Rule helper class..."

./gradlew -q build; ./gradlew -q compileJava; ./gradlew -q jar
 if [ $? -ne 0 ]; then
        echo "Build failed."
        exit 1
 fi
#copy help Rule class jar to local dir
echo "Copying helper class jar to current dir..."
cp ${PWD}/build/libs/stackTraceBmHelper-1.0-SNAPSHOT.jar  stackTraceBmHelper-1.0-SNAPSHOT.jar
#change directory permission
chmod -R 777 .
# Install the Byteman agent into the Java process
echo "Installing Byteman agent into the java process with $PID..."
java -cp "$BYTEMAN_HOME/lib/byteman-install.jar:$JAVA_HOME/lib/tools.jar:${PWD}/build/libs/stackTraceBmHelper-1.0-SNAPSHOT.jar" \
  org.jboss.byteman.agent.install.Install $PID

# Submit the Byteman rule to the Java process
#$BYTEMAN_HOME/bin/bmsubmit.sh -cp ${PWD}/build/libs/stackTraceBmHelper-1.0-SNAPSHOT.jar  $RULE_FILE   
echo "Installing Rules into the java process with $PID..."
java -cp "${PWD}/build/libs/stackTraceBmHelper-1.0-SNAPSHOT.jar:$BYTEMAN_HOME/lib/byteman-submit.jar"  org.jboss.byteman.agent.submit.Submit -s ${PWD}/build/libs/stackTraceBmHelper-1.0-SNAPSHOT.jar
java -cp "${PWD}/build/libs/stackTraceBmHelper-1.0-SNAPSHOT.jar:$BYTEMAN_HOME/lib/byteman-submit.jar" org.jboss.byteman.agent.submit.Submit $RULE_FILE 

#create the log file
touch /tmp/traceException.txt; chmod 666 /tmp/traceException.txt

# Tail the log file to see the stack trace output
tail -f /tmp/traceException.txt