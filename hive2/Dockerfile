FROM openjdk:8-slim

ARG HADOOP_VERSION=3.2.0

RUN apt-get update && apt-get install -y curl --no-install-recommends \
	&& rm -rf /var/lib/apt/lists/*

RUN curl https://archive.apache.org/dist/hadoop/core/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz \
	| tar xvz -C /opt/  \
	&& ln -s /opt/hadoop-$HADOOP_VERSION /opt/hadoop \
	&& rm -r /opt/hadoop/share/doc 

RUN ln -s /opt/hadoop/share/hadoop/tools/lib/hadoop-aws* /opt/hadoop/share/hadoop/common/lib/ && \
    ln -s /opt/hadoop/share/hadoop/tools/lib/aws-java-sdk* /opt/hadoop/share/hadoop/common/lib/

ENV HADOOP_HOME="/opt/hadoop"
ENV PATH="/opt/spark/bin:/opt/hadoop/bin:${PATH}"

RUN curl https://downloads.apache.org/hive/hive-2.3.9/apache-hive-2.3.9-bin.tar.gz \
	| tar xvz -C /opt/ \
	&& ln -s /opt/apache-hive-2.3.9-bin /opt/hive

RUN curl -L https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-5.1.47.tar.gz \
	| tar xvz -C /opt/ \
	&& ln -s /opt/mysql-connector-java-5.1.47/mysql-connector-java-5.1.47.jar /opt/hadoop/share/hadoop/common/lib/ \
	&& ln -s /opt/mysql-connector-java-5.1.47/mysql-connector-java-5.1.47.jar /opt/hive/lib/ 

