VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.network "forwarded_port", guest: 3838, host: 13838 # Shiny
  config.vm.provision "shell", path: "increase_swap.sh"
  config.vm.provision "docker" do |d|
    d.build_image "/vagrant", args: "-t humpty/shiny-goat"
    d.run "humpty/shiny-goat", args: "-d -t -p 3838:3838 -v /vagrant:/tmp/shared"
  end
end
