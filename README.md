vagrant-mesos-cluster
=====================

A vagrant configuration to set up a cluster of mesos master, slaves and zookeepers through ansible

# Usage

## Prerequisites
Install the following software onto your Mac OS X or Linux box.   Note: Windows is unsupported at this time, because the vagrant-ansible provisioner doesn't support Windows.

1. Install [virtualbox 5.x](https://www.virtualbox.org/).
2. Install [Vagrant 1.8.x](https://www.vagrantup.com/downloads.html).
3. Install [vagrant-hosts](https://github.com/oscar-stack/vagrant-hosts#installation) plugin. 
4. Install [Ansible](http://docs.ansible.com/ansible/intro_installation.html).
5. Install Python [virtualenv](https://virtualenv.readthedocs.org/en/latest/).

## Launching the cluster
Clone the repository, and run:

```
$ vagrant up
```

This will provision a mini Mesos cluster with one master, one slave, and one
HAProxy instance.  The Mesos master server also contains Zookeeper, the
Marathon framework, and Mesos DNS.   The slave will come with Docker installed,
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

# Working with Applications
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
