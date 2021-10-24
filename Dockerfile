FROM centos:8

RUN dnf install -y python3-psycopg2 python3-pip && dnf clean -y all
RUN pip3 install kafka

RUN mkdir /app
ADD ./src /app

USER 2
