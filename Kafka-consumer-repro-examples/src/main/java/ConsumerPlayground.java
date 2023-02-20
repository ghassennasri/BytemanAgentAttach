
import java.sql.Timestamp;
import java.time.Duration;
import java.util.Scanner;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;




public class ConsumerPlayground {
    private static final String GROUP_ID = "consumer-group";
    private static Logger logger= LogManager.getLogger(ConsumerPlayground.class);

    public static void main(String[] args) {
        //Configurator.initialize(new PropertiesConfigurationFactory().getConfiguration(null,null,"log4j2.properties"));
        Scanner scanner = new Scanner(System.in);

        // get the number of partitions
        int numPartitions = Integer.parseInt(args[2]);
        // get the topic's name
        String topic = args[1];
        // get the bootstrap server
        String bootstrapServers = args[0];

        // Prompt the user for input
        System.out.print("Enter the number of consumer threads (default 1): ");
        String input = scanner.nextLine();
        int numThreads = !input.isEmpty()?Integer.parseInt(input):1;
        logger.info("number of consumer threads {}",numThreads);

        System.out.print("Enter the value of request.timeout.ms (default 30s): ");
        input = scanner.nextLine();
        int requestTimeoutMs = !input.isEmpty()?Integer.parseInt(input):30000;
        logger.info("request.timeout.ms= {}",requestTimeoutMs);

        System.out.print("Enter the value of connections.max.idle.timeout.ms (default 5min): ");
        input = scanner.nextLine();
        int connectionsMaxIdleTimeoutMs = !input.isEmpty()?Integer.parseInt(input):300000;
        logger.info("connections.max.idle.timeout.ms= {}",connectionsMaxIdleTimeoutMs);

        // Calculate number of partitions and consumer groups based on number of threads
        int numConsumerGroups = (int) Math.ceil((double) (numThreads / numPartitions));

        if (numConsumerGroups==0)numConsumerGroups=1;


        java.util.Properties config = new java.util.Properties();
        config.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);

        config.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        config.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG,
                "org.apache.kafka.common.serialization.StringDeserializer");
        config.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG,
                "org.apache.kafka.common.serialization.StringDeserializer");
        config.put(ConsumerConfig.REQUEST_TIMEOUT_MS_CONFIG, String.valueOf(requestTimeoutMs));
        config.put(ConsumerConfig.CONNECTIONS_MAX_IDLE_MS_CONFIG, String.valueOf(connectionsMaxIdleTimeoutMs));
        //config.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, "io.confluent.kafka.serializers.KafkaAvroDeserializer");
        //config.put("schema.registry.url", "http://"+bootstrapServers.split(":")[0]+":8081");
        Timestamp timestamp = new Timestamp(System.currentTimeMillis());
        // Create the Kafka consumers
        int j = 0;
        while (numThreads > 0) {
            int threadsPerGroup = Math.min(numThreads, numPartitions);
            for (int i = 0; i < threadsPerGroup; i++) {
                String consumerGroup = timestamp.toString()+"-test-group-" + j;
                config.put(ConsumerConfig.GROUP_ID_CONFIG, consumerGroup);
                new Thread(new ConsumerWorker(config,topic)).start();
            }
            numThreads -= threadsPerGroup;
            j++;
            /*try{
                Thread.sleep(1000);
            }catch(InterruptedException e){
                e.printStackTrace();
            }*/
        }
        int remainingThreads = numThreads + numPartitions;
        if(remainingThreads<0) {
            for (int i = 0; i < remainingThreads; i++) {
                String consumerGroup = timestamp.toString()+"-test-group-" + j;
                config.put(ConsumerConfig.GROUP_ID_CONFIG, consumerGroup);

                new Thread(new ConsumerWorker(config,topic)).start();
            }
        }

    }

    private static class ConsumerWorker implements Runnable {
        //private final KafkaConsumer<String, String> consumer;
        private final java.util.Properties consumerConfig;
        private final String topic;


        public ConsumerWorker(java.util.Properties consumerConfig, String topic) {
            this.consumerConfig = consumerConfig;
            this.topic=topic;
        }

        @Override
        public void run() {
            KafkaConsumer<String, String>  consumer = new KafkaConsumer<>(consumerConfig);
            try {
                consumer.subscribe(java.util.Collections.singletonList(topic));
                while (true) {
                    ConsumerRecords<String, String> records = consumer
                            .poll(Duration.ofSeconds(1));
                    for (org.apache.kafka.clients.consumer.ConsumerRecord<String, String> record : records) {
                        logger.info("Thread %s: Received message: key={}, value={}, partition={}, offset={}",
                                Thread.currentThread().getName(), record.key(), record.value(), record.partition(),
                                record.offset());
                    }
                }
            } finally {
                consumer.close();
            }
        }
    }
}