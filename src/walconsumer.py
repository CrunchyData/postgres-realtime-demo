import json
import os
import sys

from kafka import KafkaProducer
from kafka.errors import KafkaError

import psycopg2
import psycopg2.extras

TABLES = set([
    'availability',
    'availability_rule',
    'room',
    'unavailability',
])

class WALConsumer(object):
    def __init__(self):
        if os.environ.get('POSTGRES_URI'):
            self.connection = psycopg2.connect(
                os.environ.get('POSTGRES_URI'),
                connection_factory=psycopg2.extras.LogicalReplicationConnection,
            )
        else:
            self.connection = psycopg2.connect(
                host=os.environ.get('POSTGRES_HOST'),
                port=os.environ.get('POSTGRES_PORT'),
                user=os.environ.get('POSTGRES_USER'),
                password=os.environ.get('POSTGRES_PASSWORD'),
                dbname=os.environ.get('POSTGRES_DBNAME'),
                connection_factory=psycopg2.extras.LogicalReplicationConnection,
            )

        bootstrap_servers = []
        if os.environ.get('STRIMZI_KAFKA_BOOTSTRAP_SERVERS'):
            for server in os.environ.get('STRIMZI_KAFKA_BOOTSTRAP_SERVERS').split(' '):
                host = server.split("://")
                if host[0].startswith("PLAIN"):
                    bootstrap_servers.append(
                        "{}:{}".format(host[1], host[0].split("_")[1])
                    )
        elif os.environ.get('KAFKA_BOOTSTRAP_SERVERS'):
            bootstrap_servers = [os.environ.get('KAFKA_BOOTSTRAP_SERVERS')]

        self.producer = producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers,
            value_serializer=lambda m: json.dumps(m).encode('ascii'),
        )

    def __call__(self, msg):
        payload = json.loads(msg.payload, strict=False)
        print(payload)
        # determine if the payload should be passed on to a consumer listening
        # to the Kafka que
        for data in payload['change']:
            if data.get('table') in TABLES:
                self.producer.send(data.get('table').replace('_', '-'), data)
        # ensure everything is sent; call flush at this point
        self.producer.flush()
        # acknowledge that the change has been read - tells PostgreSQL to stop
        # holding onto this log file
        msg.cursor.send_feedback(flush_lsn=msg.data_start)

if __name__ == "__main__":
    reader = WALConsumer()
    cursor = reader.connection.cursor()
    cursor.start_replication(slot_name='schedule', decode=True)
    try:
        cursor.consume_stream(reader)
    except KeyboardInterrupt:
        print("Stopping reader...")
    finally:
        cursor.close()
        reader.connection.close()
        print("Exiting reader")
