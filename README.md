vagrant-mesos-cluster
=====================

A vagrant configuration to set up a cluster of mesos master, slaves and zookeepers through ansible.

- [Usage](#usage)
  - [Prerequisites](#prerequisites)
  - [Clone the repository](#clone-the-repository)
  - [Launching the cluster](#launching-the-cluster)
  - [Using SSH](#using-ssh)
  - [Installing the CLI](#installing-the-cli)
  - [Adding Slaves](#adding-slaves)
- [Working with Applications](#working-with-applications)
  - [Deploying Kafka](#deploying-kafka)
    - [Kafka Package](#kafka-package)
    - [Broker](#broker)
    - [Topic](#topic)
    - [Validation](#validation)
    - [Kafka Manager (UI)](#kafka-manager-optional)
  - [Deploying Spark](#deploying-spark)
    - [Spark Package](#spark-package)
    - [Example App](#example-app)
- [Remarks](#remarks)
  - [Package Repositories](#package-repositories)
  - [Admin Router](#admin-router)
  - [Mesos DNS](#mesos-dns)
  - [HAProxy](#haproxy)
  - [Apache Spark](#apache-spark)
    - [Dispatcher](#dispatcher)
    - [CLI](#cli)
    - [Docker Image](#docker-image)
    - [Shuffle Service](#shuffle-service)
- [Troubleshooting](#troubleshooting)
  - [Information Sources](#information-sources)
    - [DCOS CLI](#dcos-cli)
    - [Docker Logs](#docker-logs)
    - [Sandbox Output](#sandbox-output)
  - [Spark](#spark)
    - [Insufficient Resources](#insufficient-resources)
    - [Custom Docker Image](#custom-docker-image)
    - [Source Code](#source-code)
    
# Usage

## Prerequisites
Install the following software onto your Mac OS X or Linux box.   Note: Windows is unsupported at this time, because the vagrant-ansible provisioner doesn't support Windows.

1. Install [virtualbox 5.x](https://www.virtualbox.org/).
2. Install [Vagrant 1.8.x](https://www.vagrantup.com/downloads.html).
3. Install [vagrant-hosts](https://github.com/oscar-stack/vagrant-hosts#installation) plugin. 
4. Install [Ansible](http://docs.ansible.com/ansible/intro_installation.html).
5. Install Python [virtualenv](https://virtualenv.readthedocs.org/en/latest/).

Optionally, install [kafkacat](https://github.com/edenhill/kafkacat) for experimenting with Kafka.

## Clone the repository
The repository contains a submodule, so clone it using the `--recursive` flag.
```
$ git clone --recursive https://github.com/EronWright/vagrant-mesos-cluster.git
$ cd vagrant-mesos-cluster
```

## Launching the cluster
Launch the cluster VMs:

```
$ vagrant up
```

This will provision a mini Mesos cluster with one master, one slave, and one
HAProxy instance.  The Mesos master server also contains Zookeeper, the
Marathon framework, Mesos DNS, and the Admin Router.   The slave will come with Docker installed,
and with the Mesos Docker containerizer ready for use.

- Browse to the Mesos UI:     http://100.0.10.11:5050/
- Browse to the Marathon UI:  http://100.0.10.11:8080/

## Using SSH
Access the virtual machines using the `vagrant ssh` command:
```
$ vagrant ssh mesos-master1
...
```

## Installing the CLI
The `dcos` CLI is capable of remotely managing the cluster from the Vagrant host.

The following command installs the CLI into an isolated virtual environment:
```
$ bin/install-cli.sh
```

Whenever you wish to use the `dcos` CLI, activate the virtual environment:
```
$ source bin/env-setup
...

$ dcos node
  HOSTNAME         IP                        ID
100.0.10.101  100.0.10.101  20160117-085745-185204836-5050-1-S1
```

## Adding Slaves
The vagrant script is pre-configured with addditional slaves (mesos-slave2 thru mesos-slave5).   They are configured to not auto-start and must be started manually:
```
$ vagrant up mesos-slave2
```

# Working with Applications

## Deploying Kafka
Installing Kafka on a Mesos cluster allows brokers to be launched into the cluster, and to serve topics.

### Kafka Package
Use the DCOS cli to install the Kafka package.
```
$ source bin/env-setup
...
(dcoscli) $ dcos package install kafka
...
```

It takes 5 minutes or so for the Kafka scheduler to start.   Proceed once the Mesos task named `Kafka` reaches the running state.

### Broker
Create at least one broker to host a topic.

Create a broker using the dcos cli.  Note that the `0` argument shall be the broker's unique identifier.
```
(dcoscli) $ dcos kafka broker add 0
broker added:
  id: 0
  active: false
  state: stopped
  resources: cpus:1.00, mem:2048, heap:1024, port:auto
  failover: delay:1m, max-delay:10m
  stickiness: period:10m
```

Start the broker:
```
(dcoscli) $ dcos kafka broker start 0
broker started:
  id: 0
  active: true
  state: running
  resources: cpus:1.00, mem:2048, heap:1024, port:auto
  failover: delay:1m, max-delay:10m
  stickiness: period:10m, hostname:100.0.10.101
  task: 
    id: broker-0-3589972d-a101-41b3-98d1-ba2fa16eb0ec
    state: running
    endpoint: 100.0.10.101:31000
```

Verify that the task has started (it may take a few minutes).  You should see a task named `broker-0`.
```
(dcoscli) $ dcos task 
NAME           HOST          USER  STATE  ID                                                  
broker-0       100.0.10.101  root    R    broker-0-3589972d-a101-41b3-98d1-ba2fa16eb0ec       
kafka          100.0.10.101  root    R    kafka.f5940006-c4b5-11e5-9a57-024270adf267          
kafka-manager  100.0.10.101  root    R    kafka-manager.e42a8fb4-c4b4-11e5-9a57-024270adf267  
```

List the installed brokers at any time:
```
(dcoscli) $ dcos kafka broker list
...
```

## Topic
Now, add a topic to the Kafka cluster:
```
(dcoscli) $ dcos kafka topic add topic1
topic added:
  name: topic1
  partitions: 0:[0]
```

### Validation
Let's use kafkacat to produce and consume some data.  Notice that the broker endpoint is needed from above.

_If kafkacat isn't available on your system, build and use the kafkacat image provided in `tools/kafkacat/`._

```
(dcoscli) $ kafkacat -L -b 100.0.10.101:31000
Metadata for all topics (from broker -1: 100.0.10.101:31000/bootstrap):
 1 brokers:
  broker 0 at 100.0.10.101:31000
 1 topics:
  topic "topic1" with 1 partitions:
    partition 0, leader 0, replicas: 0, isrs: 0

(dcoscli) $ kafkacat -P -b 100.0.10.101:31000 -t topic1
Hello
World
(ctrl-C)(ctrl-C)

(dcoscli) $ kafkacat -C -b 100.0.10.101:31000 -t topic1
Hello
World
(ctrl-C)(ctrl-C)
```

Hint: tmux keyboard shortcuts are `ctrl-b,shift-"` to split the window, then `ctrl-b,o` to switch panes.

### Kafka Manager (Optional)
Yahoo open-sourced a user interface for Kafka called [Kafka Manager](https://github.com/yahoo/kafka-manager).  The UI simplifies the management of brokers and topics.

Let's deploying the manager using the provided marathon app descriptor ([source code](apps/kafka-manager/marathon.json)):
```
(dcoscli) $ dcos marathon app add apps/kafka-manager/marathon.json
```

Once it is deployed (use the Marathon UI to monitor the progress), browse to its endpoint (also displayed in the UI).   

Register the Kafka cluster by selecting 'Add Cluster' then entering the following details:
- **Cluster Name**:            `cluster1`
- **Cluster Zookeeper Hosts**: `master.mesos:2181`
- **Kafka Version**:           `0.8.2.2`

Also check the **Poll consumer information** checkbox. 

## Deploying Spark
Installing Spark on a Mesos cluster allows Spark applications to be launched into the cluster with `spark-submit` in [cluster mode](http://spark.apache.org/docs/latest/running-on-mesos.html#cluster-mode).   In technical terms, the Mesos Cluster Dispatcher is installed as a Marathon app.

### Spark Package
Use the DCOS cli to install the Spark package.

```
$ source bin/env-setup
...
(dcoscli) $ dcos package install spark

Note that the Apache Spark DCOS Service is beta and there may be bugs, incomplete features, incorrect documentation or other discrepancies.
We recommend a minimum of two nodes with at least 2 CPU and 2GB of RAM available for the Spark Service and running a Spark job.
Note: The Spark CLI may take up to 5min to download depending on your connection.
Continue installing? [yes/no] yes
Installing Marathon app for package [spark] version [1.6.0]
Installing CLI subcommand for package [spark] version [1.6.0]
New command available: dcos spark
The Apache Spark DCOS Service has been successfully installed!

	Documentation: https://spark.apache.org/docs/latest/running-on-mesos.html
	Issues: https://issues.apache.org/jira/browse/SPARK
```

Now, open the webui, whose address may be obtained using the cli:
```
(dcoscli) $ dcos spark webui
http://100.0.10.11/service/spark/
```

### Example App
Let's deploy the SparkPI example app for demonstration purposes.   

The `dcos spark run` command is used to launch a spark app into the cluster.  Usually an `hdfs:` or `http:` URL to the app jar is supplied by the user, but a `file:` URL may be used if the file is already present on the slave nodes.  With that in mind, Ansible copied the `spark-examples-1.6.0-hadoop2.6.0.jar` file to the slaves already.

Run the SparkPI example now:
```
$ spark/bin/run-example.sh

Ran command: /Users/eron/.dcos/subcommands/spark/env/lib/python2.7/site-packages/dcos_spark/data/spark-1.6.0/bin/spark-submit --deploy-mode cluster --master mesos://100.0.10.11/service/sparkcli/ --driver-memory=512M --driver-cores=0.5 --executor-memory 512M --total-executor-cores=1 --class org.apache.spark.examples.SparkPi file:/tmp/mesos/spark-examples-1.6.0-hadoop2.6.0.jar 10
Stdout:

Stderr:
Using Spark's default log4j profile: org/apache/spark/log4j-defaults.properties
16/01/26 09:34:04 INFO RestSubmissionClient: Submitting a request to launch an application in mesos://100.0.10.11/service/sparkcli/.
16/01/26 09:34:05 INFO RestSubmissionClient: Submission successfully created as driver-20160126173404-0001. Polling submission state...
16/01/26 09:34:05 INFO RestSubmissionClient: Submitting a request for the status of submission driver-20160126173404-0001 in mesos://100.0.10.11/service/sparkcli/.
16/01/26 09:34:05 INFO RestSubmissionClient: State of driver driver-20160126173404-0001 is now QUEUED.
16/01/26 09:34:05 INFO RestSubmissionClient: Server responded with CreateSubmissionResponse:
{
  "action" : "CreateSubmissionResponse",
  "serverSparkVersion" : "1.6.0",
  "submissionId" : "driver-20160126173404-0001",
  "success" : true
}

Run job succeeded. Submission id: driver-20160126173404-0001
```

1. Open the Spark dispatcher's webui (at http://100.0.10.11/service/spark) and observe that the SparkPI driver was launched.   
2. The driver program will register itself as a Mesos framework ("Spark Pi"), observable on the Mesos Frameworks page.   Tasks will spawn soon thereafter.
3. While the SparkPi driver is running, a web interface will exist at http://100.0.10.101:4040
4. Once it finishes, look at the sandbox of the task labeled 'Driver for org.apache.spark.examples.SparkPi' to see the output.

# Remarks

## Package Repositories
The DCOS CLI draws on a few online repositories for installable packages.  Those repositories are:

- [Mesosphere Universe](https://github.com/mesosphere/universe/)
- [Mesosphere Multiverse](https://github.com/mesosphere/multiverse/)

Note that the packages are DCOS-specific.  At least, they assume that Mesos DNS and the Admin Router are in play.

It is possible to fork the multiverse to add new packages.   You must reconfigure the CLI accordingly (see `bin/env-setup` script).

## Admin Router
The Admin Router acts as an HTTP gateway for the services and webui's in DCOS.   

It contains large amounts of service-specific knowledge.  For example, it recognizes the `/services/sparkcli` path as a reference to the spark dispatcher's REST port.   The Spark Marathon app also assumes the use of the admin router (see the `APPLICATION_WEB_PROXY_BASE` environment variable).

## Mesos DNS
Mesos DNS provides *service discovery*, not a full-fledged DNS solution.   Applications use Mesos DNS to easily locate the Mesos master and their own frameworks and tasks.

The hosts are expected to have a fully-functional DNS configuration, not provided by Mesos DNS.  In other words, don't expect to resolve the hostnames using Mesos DNS.   Hostnames are automatically configured by Vagrant, and resolvable across the cluster thanks to the `vagrant-hosts` plugin.    

In the below example, the `marathon` service is discovered via Mesos DNS and resolved to the associated host:
```
$ vagrant@mesos-slave1:~$ ping marathon
PING marathon.mesos (100.0.10.11) 56(84) bytes of data.
64 bytes from mesos-master1 (100.0.10.11): icmp_seq=1 ttl=64 time=0.352 ms
64 bytes from mesos-master1 (100.0.10.11): icmp_seq=2 ttl=64 time=0.342 ms
```

Various packages in the Universe assume the use of Mesos DNS.   For example, the spark Marathon app uses a hardcoded reference to the ZK endpoint, as `--zk master.mesos:2181`.

## HAProxy
Another way to facilitate service discovery is by making services available on well-known ports.   The solution described in the [Marathon Service Discovery & Load Balancing](https://mesosphere.github.io/marathon/docs/service-discovery-load-balancing) page describes a solution involving Mesos-managed ports plus haproxy.

## Apache Spark
The DCOS Universe provides a Spark package which installs the Mesos Cluster Dispatcher and an associated CLI.  

### Dispatcher
The dispatcher is a Mesos framework responsible for launching and supervising Spark driver programs.   Programs are submitted to the dispatcher via its REST endpoint from `spark-submit`.

The dispatcher is itself a Marathon application, see the definition at [github.com/mesosphere/universe/...](https://github.com/mesosphere/universe/blob/version-1.x/repo/packages/S/spark/5/marathon.json).

### CLI
The CLI (source code [here](https://github.com/mesosphere/dcos-spark)) provides the following functionality:

- Automatically downloads the Spark tools (i.e. `spark-submit`).
- Wraps `spark-submit` to automatically set the deploy mode to Mesos cluster mode, with the appropriate endpoint.
- Enforces the use of a docker image to run the application.
- Manages running applications.
- Easily launches the dispatcher webui.

### Docker Image
Both the dispatcher and the application run within a (separate) Docker container.  By default, the `mesosphere/spark:1.6.0` image is used, but the CLI allows the app to override it with another image. 

The source code for the `mesosphere/spark` image at [github.com/mesosphere/spark/...](https://github.com/mesosphere/spark/tree/mesosphere/dockerfile/mesos_docker/).

### Shuffle Service
Notably absent from the installed components is the [Mesos Shuffle Service](http://spark.apache.org/docs/latest/running-on-mesos.html#dynamic-resource-allocation-with-mesos).  The shuffle service is a prerequisite for dynamic resource allocation in coarse-grained mode.

# Troubleshooting

## Information Sources
Here are some sources of information to troubleshoot any issue.

### DCOS CLI
The CLI supports the `--json` flag for most commands, which reveals a lot more information than the usual summary info.  For example, the node information reveals how much memory/cpu is used/available for frameworks:

```
(dcoscli) $ dcos node --json
[
  {
    "TASK_ERROR": 0,
    "TASK_FAILED": 4,
    "TASK_FINISHED": 3,
    "TASK_KILLED": 0,
    "TASK_LOST": 0,
    "TASK_RUNNING": 1,
    "TASK_STAGING": 0,
    "TASK_STARTING": 0,
    "active": true,
    "attributes": {},
    "framework_ids": [
      "20160126-054935-185204836-5050-1-0000",
      "20160126-154450-185204836-5050-1-0000"
    ],
    "hostname": "100.0.10.101",
    "id": "20160126-172018-185204836-5050-1-S0",
    "offered_resources": {
      "cpus": 0,
      "disk": 0,
      "mem": 0
    },
    "pid": "slave(1)@100.0.10.101:5051",
    "registered_time": 1453828863.50592,
    "reregistered_time": 1453830383.81005,
    "reserved_resources": {},
    "resources": {
      "cpus": 4,
      "disk": 35164,
      "mem": 2929,
      "ports": "[31000-32000]"
    },
    "unreserved_resources": {
      "cpus": 4,
      "disk": 35164,
      "mem": 2929,
      "ports": "[31000-32000]"
    },
    "used_resources": {
      "cpus": 1,
      "disk": 0,
      "mem": 1024,
      "ports": "[31412-31413]"
    }
  }
] 
```

Likewise, the `dcos service --json` output reveals information on frameworks and tasks.

### Docker Logs
Containerized processes typically write to stdout.  Use `sudo docker logs <container-name>` to see the output. The verbosity of Mesos is set to INFO, so use this technique to troubleshoot issues with Mesos master/agent.

### Sandbox Output
The output of Mesos tasks are accessible via the Mesos UI.   Click on the appropriate framework, then use the sandbox link to see stdout and stderr of the corresponding tasks.

Remember, the Spark dispatcher is a task of Marathon.   The Spark driver program is a task of the Spark dispatcher.   The Spark executor(s) is a task of the Spark driver program.
```
  Marathon
  └─Spark (i.e. Mesos cluster dispatcher)
    └─Driver (e.g. SparkPI)
      └─Executor (e.g. SparkPI's tasks)
```

## Spark
Some advanced techniques for troubleshooting Spark apps. 

Important: the Spark driver program output is observable in the stderr of the sandbox of the task launched by the Spark framework.

### Insufficient Resources
When a Spark driver program appears to be hung at startup, the likely cause is insufficient resources to launch any tasks.   In this situation, the driver program emits the following message:
```
INFO: Initial job has not accepted any resources.
```

At DEBUG level, one may observe additional messages indicating that offers were rejected (likely due to insufficient memory).

### Custom Docker Image
To increase the logging verbosity of a Spark application, it is necessary to use a custom image.   Here's how:

On the Mesos slave, build the custom image:
```
vagrant@mesos-slave1:~$ cd /vagrant/spark
vagrant@mesos-slave1:/vagrant/spark$ sudo docker build -t eronwright/spark:1.6.0 .
```

On your host computer, edit `spark/bin/run-example.sh` to use a custom image.   Edit the `APP_IMAGE` variable to refer to the custom image from above.  Re-launch the example app, and the sandbox logs should contain DEBUG-level information.

### Source Code
When all else fails, turn to the Spark source code.

- the cluster dispatcher is mostly implemented in [MesosClusterDispatcher](https://github.com/apache/spark/blob/branch-1.6/core/src/main/scala/org/apache/spark/deploy/mesos/MesosClusterDispatcher.scala) and [MesosClusterScheduler](https://github.com/apache/spark/blob/branch-1.6/core/src/main/scala/org/apache/spark/scheduler/cluster/mesos/MesosClusterScheduler.scala).
- the driver program's scheduler is in [CoarseMesosSchedulerBackend](https://github.com/apache/spark/blob/branch-1.6/core/src/main/scala/org/apache/spark/scheduler/cluster/mesos/CoarseMesosSchedulerBackend.scala).

