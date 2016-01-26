#!/bin/bash

APP_IMAGE="mesosphere/spark:1.6.0"
#APP_JAR="file:/tmp/mesos/spark-examples-1.6.0-hadoop2.6.0.jar"
APP_JAR="http://137.69.172.213/spark/spark-1.6.0-bin-hadoop2.6/lib/spark-examples-1.6.0-hadoop2.6.0.jar"
APP_CLASS="org.apache.spark.examples.SparkPi"
APP_ARGS="10"

dcos spark run --docker-image=$APP_IMAGE --submit-args "--driver-memory=512M --driver-cores=0.5 --executor-memory 512M --total-executor-cores=1 --class $APP_CLASS $APP_JAR $APP_ARGS" --verbose

