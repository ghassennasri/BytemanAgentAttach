#!/bin/bash

# Usage: ./traceException.sh PID RULE_FILE BYTEMAN_AGENT_JAR

# Check that all arguments are present
if [ $# -lt 2 ]; then
  echo "Usage: $0 PID RULE_FILE [BYTEMAN_HOME] [time_limit default 5min] "
  exit 1
fi

BYTEMAN_INPUT=0
#get optional arguments  [BYTEMAN_HOME] [time_limit default 5min]
while getopts ":b:t:" opt; do
  case $opt in
    b) BYTEMAN_HOME_INPUT="$OPTARG"
            BYTEMAN_INPUT=1
    ;;
    t) TIME_INPUT="$OPTARG"
    ;;
    \?) echo "Invalid option: -$OPTARG" >&2
    ;;
  esac
done

shift $((OPTIND-1))
args="$@"


# Check if BYTEMAN_HOME is set and not empty
if [ $BYTEMAN_INPUT -eq 0 ] && [ ! -d $(pwd)/byteman-download-4.0.20 ]; then
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
 export BYTEMAN_HOME=$BYTEMAN_HOME_INPUT
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

echo "Executing rules...."

if [ -z "$time_limit" ]; then
  time_limit=5
fi
# Convert the time limit to seconds
time_limit=$(($TIME_INPUT*60))
echo "Time limit set to $time_limit seconds"
start_time="$(date +%s)"

# Run an infinite loop until the time limit is reached
while true; do
  # Tail the log file to see the stack trace output
  #tail -f /tmp/traceException.txt

  # Get the current time in seconds
  current_time="$(date +%s)"

  # Calculate the elapsed time
  elapsed_time=$((current_time - start_time))

  #line to earased
  echo "Executing rules...."

  echo -ne "$(tput cuu1)\r$(tput el)Time remaining before exit: $((time_limit - elapsed_time)) seconds \r"
  # Check if the time limit has been reached
  if [[ $elapsed_time -ge $time_limit ]]; then
    echo "Time limit reached, uninstalling rules..."
    java -cp "${PWD}/build/libs/stackTraceBmHelper-1.0-SNAPSHOT.jar:$BYTEMAN_HOME/lib/byteman-submit.jar"  org.jboss.byteman.agent.submit.Submit -u
    echo "exiting script, please collect logs at /tmp/traceException.txt ..."
    exit 0
  fi

  # Sleep for some amount of time before running the loop again
  sleep 1
done