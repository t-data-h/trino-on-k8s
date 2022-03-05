FROM openjdk:8-slim

ARG HADOOP_VERSION=3.2.0
ARG hadoop_uri=https://archive.apache.org/dist/hadoop/core
ARG hive_uri=https://downloads.apache.org
ARG mysql_uri=https://dev.mysql.com/get/Downloads/Connector-J

RUN apt-get update && apt-get install -y curl --no-install-recommends \
	&& rm -rf /var/lib/apt/lists/*

RUN curl ${hadoop_uri}/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz \
	| tar xvz -C /opt/  \
	&& ln -s /opt/hadoop-$HADOOP_VERSION /opt/hadoop \
	&& rm -r /opt/hadoop/share/doc 

RUN ln -s /opt/hadoop/share/hadoop/tools/lib/hadoop-aws* /opt/hadoop/share/hadoop/common/lib/ && \
    ln -s /opt/hadoop/share/hadoop/tools/lib/aws-java-sdk* /opt/hadoop/share/hadoop/common/lib/

ENV HADOOP_HOME="/opt/hadoop"
ENV PATH="/opt/hadoop/bin:${PATH}"

RUN curl ${hive_uri}/hive/hive-3.1.2/apache-hive-3.1.2-bin.tar.gz \
	| tar xvz -C /opt/ \
	&& ln -s /opt/apache-hive-3.1.2-bin /opt/hive

RUN curl -L ${mysql_uri}/mysql-connector-java-5.1.47.tar.gz \
	| tar xvz -C /opt/ \
	&& ln -s /opt/mysql-connector-java-5.1.47/mysql-connector-java-5.1.47.jar /opt/hadoop/share/hadoop/common/lib/ \
	&& ln -s /opt/mysql-connector-java-5.1.47/mysql-connector-java-5.1.47.jar /opt/hive/lib/ 

