vagrant-mesos-cluster
=====================

A vagrant configuration to set up a cluster of mesos master, slaves and zookeepers through ansible

# Usage

## Prerequisites
1. Install Ansible onto the Vagrant host.
2. Install Python [virtualenv](https://virtualenv.readthedocs.org/en/latest/) onto the Vagrant host.

## Launching the cluster
Clone the repository, and run:

```
$ vagrant up
```

This will provision a mini Mesos cluster with one master, one slave, and one
HAProxy instance.  The Mesos master server also contains Zookeeper and the
Marathon framework. The slave will come with Docker installed. 

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

# Deploying Docker containers

After provisioning the servers you can access Marathon here:
http://100.0.10.11:8080/ and the master itself here: http://100.0.10.11:5050/

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
curl -X POST -H "Content-Type: application/json" http://100.0.10.11:8080/v2/apps -d@ubuntu.json
```

You can monitor and scale the instance by going to the Marathon web interface linked above. 
