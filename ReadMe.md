# Description

The provided shell script is a generic script that can be used to attach a Byteman agent to any running Java process. Once attached, it can run any Byteman rule that has been created to modify the bytecode of a specific class or method.

In this specific case, the shell script uses the Byteman rule `kafka-fetch-session-handle-error` to modify the method 'handleError()' of the class `org.apache.kafka.clients.FetchSessionHandler`. This rule adds a log statement that outputs the stacktrace of the exception when it is an instance of `org.apache.kafka.common.errors.DisconnectException`.

The reason for adding this log statement is that the current code only provides the class of the exception and the message, which is null. 

https://github.com/a0x8o/kafka/blob/master/clients/src/main/java/org/apache/kafka/clients/FetchSessionHandler.java#L602

A quick fix would be to replace the line mentioned by

```java
log.info(String.format("Error sending fetch request %s to node %s:", nextMetadata, node), t);
```

This does not provide the full stacktrace of the exception. Collecting the stacktrace allows pinpointing the reason for the network disconnection issue and, hence, enables targeting the appropriate Kafka parameters.

The `org.apache.kafka.common.errors.DisconnectException: null` exception captured in the `org.apache.kafka.clients.consumer.internals.sendFetches()` method of the Kafka consumer through the RequestFutureListener.onFailure() listener method of the RequestFuture object, can occur when the broker closes the connection to the consumer unexpectedly. This can happen for a variety of reasons, such as a network issue, broker outage, or other issue that causes the connection to be interrupted. The exception typically indicates that the consumer was disconnected while it was waiting for a response from the broker, causing the fetch request to fail. To troubleshoot this issue, it is important to examine the logs on both the consumer and the broker to identify the root cause of the disconnection.

Please note that the 'kafka-fetch-session-handle-error' rule is only an example, and it can be replaced with any other Byteman rule that targets any class or method in the Java process.

## Requirements

- Java 8 or later
- Byteman 4.0 or later

## Helper Class

The helper class, `KafkaFetchSessionHandleErrorHelper`, contains a method `traceStack` that can be used to print the stack trace of the  the stack trace of the ``org.apache.kafka.common.errors.DisconnectException` and the current thread stack trace. To use this method in a Byteman rule, simply import the class and call the `traceStack` method as follows:

```
RULE myRule
CLASS myClass
METHOD myMethod(java.lang.Throwable)
HELPER io.confluent.examples.KafkaFetchSessionHandleErrorHelper
AT EXIT
IF TRUE
DO traceStack($1);
ENDRULE
```

## Shell Script

The shell script, `traceException.btm`, is used to attach a Byteman agent to a running Java process and run one or more Byteman rules. The script takes the following arguments:

- `PID`: the process ID of the Java process to which the agent will be attached
- `RULE_FILE`: the path to a file containing one or more Byteman rules
- `BYTEMAN_HOME`: the path to the Byteman installation directory (optional)

If `BYTEMAN_HOME` is not specified, the script will prompt the user to download Byteman and set the `BYTEMAN_HOME` environment variable. Once Byteman is installed and `BYTEMAN_HOME` is set, the script will attach the Byteman agent to the specified Java process and run the rules in `RULE_FILE`.

## Rules

Two example Byteman rules are provided in the rule file `traceDisconnect.btm` directory:

- `kafka-fetch-session-handle-error`: a rule that adds a log statement to the `handleError` method of the `FetchSessionHandler` class in the Kafka client library. The log statement includes the current time, the message "Error sending fetch request", and the stack trace of the `Throwable` parameter.
- `test-with-sample-Application`: a rule that adds a log statement to the `handleException` method of a test class. The log statement includes the current time, the message "an exception occurred", and the stack trace of the `Throwable` parameter.
- `print-on-Channel-Close` : Trace kafka channel close call 
- ` print-on-Disconnect-response-create` : A rule to trace the creation of ClientResponse when there is a disconnection
- `print-stack-trace-on-exception` : A rule to dump stacktrace of the RuntimeException from org.apache.kafka.clients.consumer.internals.
ConsumerNetworkClient$RequestFutureCompletionHandler when disconnection occurs.
- `print-on-Disconnect-Response` : A rule to get a toString() of ClientResponse when when disconnection occurs.
To run these rules, simply specify the path to the rule file as the `RULE_FILE` argument when running the `run_byteman.sh` script.

## Usage

To use this code to attach Byteman to a Kafka Streams application and run one or more rules, follow these steps:

1. (optional) Download and install [Byteman java agent](https://downloads.jboss.org/byteman/4.0.20/byteman-download-4.0.20-bin.zip) 4.0 later and set `BYTEMAN_HOME` env. variable, otherwise the script `btm_attach.sh` will do it for you.
2. Clone this repository and navigate to the root directory.
3. Create your rule file to create your custom rules or use the provided one. Set new variables for `RULE_FILE`  and `PID`  (linux pid of the application you would like to attach to), and optionally set the `BYTEMAN_HOME` environment variable.
4. Run the `btm_attach.sh` script **as root** to attach the Byteman agent to your application and run the rules in `RULE_FILE`.
5. Verify that the rules are being executed and that the expected log output is being produced in `/tmp/traceException-(JavaThreadName).txt`

Example (using the javaTestApplication): 

1. Navigate to `javaApplicationExample` directory and run 
```shell
./gradlew run

```
2. Open another shell terminal, navigate to the project root directory and run

```shell
#Syntax : ./btm_attach.sh [-t time_limit default 5min] [-b BYTEMAN_HOME]  PID RULE_FILE 
sudo ./btm_attach.sh -t 5 $(jps | grep JavaTestApplication | awk '{ print $1 }') ./traceDisconnect.btm
```

Example (using the ConsumerPlayground): 
1. Navigate to Kafka-consumer-repro-examples directory and run 
```shell
./do_provision [aws_key] [aws_secret_key] [aws_regin_name] [aws_ec2-key_name]

```
You will be prompted to enter the following:
- the number of consumer threads (default 1)
- the value of request.timeout.ms (default 30s)
- the value of connections.max.idle.timeout.ms (default 5min)

To reproduce the "org.apache.kafka.common.errors.DisconnectException:null" exception either enter;
- A very small value for request.timeout.ms (10ms for example)
- A  very small value for connections.max.idle.timeout.ms (10ms for example)
- A very high number of consumer threads (1000 for example)

After few seconds, on the console, you will start to notice messages tracking the number of "org.apache.kafka.common.errors.DisconnectException:null";
`Found [n] occurrences of org.apache.kafka.common.errors.DisconnectException:null, still searching..`

2. Open another shell terminal, navigate to the project root directory and run;
```shell
sudo ./btm_attach.sh -t 10 $(jps | grep kafkaConsumerReproExamples-1.0-SNAPSHOT-all.jar | awk '{ print $1 }') ./traceDisconnect.btm
```