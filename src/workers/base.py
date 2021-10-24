import json
import os

from kafka import KafkaConsumer
from kafka.structs import OffsetAndMetadata, TopicPartition

import psycopg2

class Worker(object):
    """Base class to work perform any post processing on changes"""
    OPERATIONS = set([]) # override with "insert", "update", "delete"

    def __init__(self, topic):
        # connect to the PostgreSQL database
        if os.environ.get('POSTGRES_URI'):
            self.connection = psycopg2.connect(os.environ.get('POSTGRES_URI'))
        else:
            self.connection = psycopg2.connect(
                host=os.environ.get('POSTGRES_HOST'),
                port=os.environ.get('POSTGRES_PORT'),
                user=os.environ.get('POSTGRES_USER'),
                password=os.environ.get('POSTGRES_PASSWORD'),
                dbname=os.environ.get('POSTGRES_DBNAME'),
            )
        # connect to Kafka
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

        self.consumer = KafkaConsumer(
            bootstrap_servers=bootstrap_servers,
            value_deserializer=lambda m: json.loads(m.decode('utf8')),
            auto_offset_reset="earliest",
            group_id='1')
        # subscribe to the topic(s)
        topic = topic.replace('_', '-')
        self.consumer.subscribe(topic if isinstance(topic, list) else [topic])

    def run(self):
        """Function that runs ad-infinitum"""
        # loop through the payloads from the consumer
        # determine if there are any follow-up actions based on the kind of
        # operation, and if so, act upon it
        # always commit when done.
        for msg in self.consumer:
            print(msg)
            # load the data from the message
            data = msg.value
            # determine if there are any follow-up operations to perform
            if data['kind'] in self.OPERATIONS:
                # open up a cursor for interacting with PostgreSQL
                cursor = self.connection.cursor()
                # put the parameters in an easy to digest format
                params = {}
                if data['kind'] == 'delete':
                    params = dict(zip(data['oldkeys']['keynames'], data['oldkeys']['keyvalues']))
                else:
                    params = dict(zip(data['columnnames'], data['columnvalues']))
                # all the function
                getattr(self, data['kind'])(cursor, params)
                # commit any work that has been done, and close the cursor
                self.connection.commit()
                cursor.close()
            # acknowledge the message has been handled
            tp = TopicPartition(msg.topic, msg.partition)
            offsets = {tp: OffsetAndMetadata(msg.offset, None)}
            self.consumer.commit(offsets=offsets)

    # override with the appropriate post-processing code
    def insert(self, cursor, params):
        """Override with any post-processing to be done on an ``INSERT``"""
        raise NotImplementedError()

    def update(self, cursor, params):
        """Override with any post-processing to be done on an ``UPDATE``"""
        raise NotImplementedError()

    def delete(self, cursor, params):
        """Override with any post-processing to be done on an ``DELETE``"""
        raise NotImplementedError()
