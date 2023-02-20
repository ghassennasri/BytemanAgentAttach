
#export TF_VAR_region_name='eu-west-3'
#export TF_VAR_key_name='gnasri'
export TF_VAR_access_key=$1
export TF_VAR_secret_key=$2
export TF_VAR_key_name=$4
export TF_VAR_region_name=$3

#apply terraform to provion an instance and launch docker compose
echo "applying terraform plan"
terraform init
terraform apply --auto-approve=true

public_ip=$(terraform output --raw public_ip)
BOOTSTRAP_SERVERS="${public_ip}:9092"

secs=$((0 * 60))
#sleep and wait for aws stack to be provisionned
while [ $secs -gt 0 ]; do
   echo -ne "------ Waiting $secs s for kafka cluster to be deployed------------\033[0K\r"
   sleep 1
   : $((secs--))
done

echo "bootstrap kafka broker ${BOOTSTRAP_SERVERS}"

#create kafka topic test
docker run --rm confluentinc/cp-kafka kafka-topics --bootstrap-server ${BOOTSTRAP_SERVERS} --topic test-topic2 --create --partitions 20

#delete consumer groups
#docker run --rm confluentinc/cp-kafka kafka-consumer-groups --bootstrap-server  ${BOOTSTRAP_SERVERS}  --list | grep 'test-group-' | xargs -I {} kafka-consumer-groups --bootstrap-server  ${BOOTSTRAP_SERVERS} --delete --group {}

echo  "Create datagen connector...."
#nohup ssh -o "StrictHostKeyChecking no"  ec2-user@${public_ip} "docker exec ksql-datagen ksql-datagen quickstart=orders topic=test-topic bootstrap-server=broker:29092" &
curl -s -X PUT \
      -H "Content-Type: application/json" \
      --data '{
                "name": "datagen-orders",
                "connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector",
                "value.converter": "org.apache.kafka.connect.json.JsonConverter",
                "tasks.max": "10",
                "kafka.topic": "test-topic2",
                "iterations": "-1",
                "quickstart": "orders"
            }' \
      http://$public_ip:8083/connectors/datagen-orders/config | jq

sleep 2

#run consumer application
./gradlew -q build; ./gradlew -q compileJava; ./gradlew -q shadowJar
#java -Xmx8g -jar ./build/libs/kafkaConsumerReproExamples-1.0-SNAPSHOT-all.jar $BOOTSTRAP_SERVERS test-topic2 20 

#> /tmp/ConsumerReproExamples.log

LOG_FILE="/tmp/ConsumerReproExamples.log"
rm -f $LOG_FILE
JAVA_PROGRAM="java -Xmx8g -jar ./build/libs/kafkaConsumerReproExamples-1.0-SNAPSHOT-all.jar ${BOOTSTRAP_SERVERS} test-topic2 20"

$JAVA_PROGRAM 2>&1 | tee /dev/tty > /dev/null & 
PID=$!

trap "kill $PID; exit 1" INT TERM EXIT

sleep 10

while true; do
    count=$(grep -c "org\.apache\.kafka\.common\.errors\.DisconnectException: null" $LOG_FILE)
    if [ $count -gt 0 ]; then
        printf  "\rFound %d occurrences of org.apache.kafka.common.errors.DisconnectException:null, still searching..." $count
    fi
    sleep 1
done