package io.confluent.examples;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

import org.jboss.byteman.rule.Rule;

public class KafkaFetchSessionHandleErrorHelper extends org.jboss.byteman.rule.helper.Helper{
    private Rule rule;
    protected KafkaFetchSessionHandleErrorHelper(Rule rule) {
        super(rule);
        this.rule=rule;
    }

    public void traceStack(Throwable t) throws IOException {
        File file = new File("/tmp/traceException.txt");
        PrintWriter writer = new PrintWriter(new FileWriter(file, true));
        //get timestamp
        LocalDateTime now = LocalDateTime.now();
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss.SSS");
        String formattedDateTime = now.format(formatter);
        try {
            writer.println(String.format("%s: ByteMan rule '%s' on class %s on method %s fired ",formattedDateTime,rule.getName(),rule.getTargetClass(),rule.getTargetMethod()));
            t.printStackTrace(writer);
            writer.println("Thread dump:");
            new Throwable().printStackTrace(writer);
        } finally {
            writer.close();
        }
    }
}