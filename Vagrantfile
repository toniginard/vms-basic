Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/jammy64"

  config.vm.provision :shell, inline: "hostnamectl set-hostname local"
  config.vm.provision :hosts do |provisioner|
    provisioner.add_host '127.0.0.1', ["server.local.cat"]
  end

  config.vm.network "private_network", ip: "192.168.33.20"

  config.vm.synced_folder "../web", "/var/www/html"

  config.vm.provider "virtualbox" do |v|
    v.customize ["modifyvm", :id, "--memory", "1024"]
    v.customize ["modifyvm", :id, "--cpus", "2"]
    v.customize ["modifyvm", :id, "--name", "PHP 8.2"]
    v.customize ["modifyvm", :id, "--cpuexecutioncap", "100"]
    v.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    v.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
  end

  config.vm.provision :shell, path: "bootstrap.sh"

end
