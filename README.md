vagrant-mesos-cluster
=====================

A vagrant configuration to set up a cluster of mesos master, slaves and zookeepers through ansible.

# Usage

## Prerequisites
Install the following software onto your Mac OS X or Linux box.   Note: Windows is unsupported at this time, because the vagrant-ansible provisioner doesn't support Windows.

1. Install [virtualbox 5.x](https://www.virtualbox.org/).
2. Install [Vagrant 1.8.x](https://www.vagrantup.com/downloads.html).
3. Install [vagrant-hosts](https://github.com/oscar-stack/vagrant-hosts#installation) plugin. 
4. Install [Ansible](http://docs.ansible.com/ansible/intro_installation.html).
5. Install Python [virtualenv](https://virtualenv.readthedocs.org/en/latest/).

## Clone the repository
The repository contains a submodule, so clone it using the `--recursive` flag.

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

## Deploying Spark
Installing Spark on a Mesos cluster allows Spark applications to be launched into the cluster with `spark-submit` in [cluster mode](http://spark.apache.org/docs/latest/running-on-mesos.html#cluster-mode).   In technical terms, the Mesos Cluster Dispatcher is installed as a Marathon app.

Use the DCOS cli to install the Spark package.

```
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

## Deploying Docker containers

Submitting a Docker container to run on the cluster is done by making a call to
Marathon's REST API:

First create a file, `ubuntu.json`, with the details of the Docker container that you want to run:

```
{
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "libmesos/ubuntu"
    }
  },
  "id": "ubuntu",
  "instances": "1",
  "cpus": "0.5",
  "mem": "128",
  "uris": [],
  "cmd": "while sleep 10; do date -u +%T; done"
}
```

And second, submit this container to Marathon by using curl:

```
$ curl -X POST -H "Content-Type: application/json" http://100.0.10.11:8080/v2/apps -d@ubuntu.json
```

You can monitor and scale the instance by going to the Marathon web interface linked above. 

# Remarks

## Package Repositories
The DCOS CLI draws on a few online repositories for installable packages.  Those repositories are:

- [Mesosphere Universe](https://github.com/mesosphere/universe/)
- [Mesosphere Multiverse](https://github.com/mesosphere/multiverse/)

Note that the packages are DCOS-specific.  At least, they assume that Mesos DNS and the Admin Router are in play.

It is possible to fork the multiverse to add new packages.   You must reconfigure the CLI accordingly (see `bin/env-setup` script).

## Admin Router
The Admin Router acts as an HTTP gateway for the services and webui's in DCOS.   

It contains large amounts of service-specific knowledge.  For example, it recognizes the `/services/sparkcli` path as a reference to the spark dispatcher's REST port.   The associated Marathon app also assumes the use of the admin router (see the `APPLICATION_WEB_PROXY_BASE` environment variable).

## Mesos DNS
Mesos DNS provides *service discovery*, not a fully-fledged DNS solution.   Applications use Mesos DNS to easily locate the Mesos master and their own frameworks and tasks.

The hosts are expected to have a fully-functional DNS configuration, not provided by Mesos DNS.  In other words, don't expect to resolve the hostnames using Mesos DNS.   Hostnames are automatically configured by Vagrant, and resolvable across the cluster thanks to the `vagrant-hosts` plugin.    

In the below example, the `marathon` service is discovered via Mesos DNS and resolved to the associated host:
```
$ vagrant@mesos-slave1:~$ ping marathon
PING marathon.mesos (100.0.10.11) 56(84) bytes of data.
64 bytes from mesos-master1 (100.0.10.11): icmp_seq=1 ttl=64 time=0.352 ms
64 bytes from mesos-master1 (100.0.10.11): icmp_seq=2 ttl=64 time=0.342 ms
```

Various packages in the Universe assume the use of Mesos DNS.   For example, the spark Marathon app uses a hardcoded reference to the ZK endpoint, as `--zk master.mesos:2181`.

## Apache Spark
The DCOS Universe provides a Spark package which installs the Mesos Cluster Dispatcher and an associated CLI.  

The CLI (source code [here](https://github.com/mesosphere/dcos-spark)) provides the following functionality:

- Automatically downloads the Spark tools (i.e. `spark-submit`).
- Wraps `spark-submit` to automatically set the deploy mode to Mesos cluster mode, with the appropriate endpoint.
- Manages running applications.
- Easily launches the dispatcher webui.

Notably absent from the installed components is the [Mesos Shuffle Service](http://spark.apache.org/docs/latest/running-on-mesos.html#dynamic-resource-allocation-with-mesos).  The shuffle service is a prerequisite for dynamic resource allocation in coarse-grained mode.
