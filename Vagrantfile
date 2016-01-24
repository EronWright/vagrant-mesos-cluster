VAGRANTFILE_API_VERSION = "2"
Vagrant.require_version ">= 1.8.1"

base_dir = File.expand_path(File.dirname(__FILE__))
cluster = {
  "mesos-master1" => { :ip => "100.0.10.11",  :cpus => 1, :mem => 1024, :primary => true },
  "mesos-slave1"  => { :ip => "100.0.10.101", :cpus => 4, :mem => 4096 },
  "mesos-slave2"  => { :ip => "100.0.10.102", :cpus => 2, :mem => 2048, :autostart => false },
  "mesos-slave3"  => { :ip => "100.0.10.103", :cpus => 2, :mem => 2048, :autostart => false },
  "mesos-slave4"  => { :ip => "100.0.10.104", :cpus => 2, :mem => 2048, :autostart => false },
  "mesos-slave5"  => { :ip => "100.0.10.105", :cpus => 2, :mem => 2048, :autostart => false },
}

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :machine
    config.cache.enable :apt
  end

  cluster.each do |hostname, info|

    config.vm.define hostname, info do |cfg|

      cfg.vm.provider :virtualbox do |vb, override|
        override.vm.box = "trusty64"
        override.vm.box_url = "https://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box"
        override.vm.network :private_network, ip: "#{info[:ip]}"
        override.vm.hostname = hostname

        vb.linked_clone = true
        vb.name = 'vagrant-mesos-' + hostname
        vb.customize ["modifyvm", :id, "--memory", info[:mem], "--cpus", info[:cpus], "--hwvirtex", "on" ]
      end

      if Vagrant.has_plugin?("vagrant-hosts")
        cfg.vm.provision :hosts, :add_localhost_hostnames => false, :autoconfigure => true, :sync_hosts => true
      end
      
      # provision nodes with ansible
      cfg.vm.provision :ansible do |ansible|
        ansible.verbose = "v"

        ansible.inventory_path = base_dir + "/inventory/vagrant"
        ansible.playbook = base_dir + "/cluster.yml"
        ansible.extra_vars = {
          vagrant_ip: "#{info[:ip]}",
          dns_resolver: "100.0.2.3"
        }
        ansible.limit = "#{info[:ip]}" # Ansible hosts are identified by ip
      end

    end

  end

end
