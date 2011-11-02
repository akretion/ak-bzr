package "python-software-properties" do
  action :install
end

apt_repository "bzr-beta" do
  uri "http://ppa.launchpad.net/bzr/beta/ubuntu"
  distribution node['lsb']['codename']
  components ["main"]
  action :add
  notifies :run, "execute[apt-get update]", :immediately
end

execute "apt-get update" do
  command "apt-get update"
  action :nothing
  notifies :upgrade, "package[bzr]", :immediately
end

package "bzr" do
  action :nothing
  options "--force-yes"
  notifies :upgrade, "package[bzrtools]", :immediately
end

package "bzrtools" do
  action :nothing
  options "--force-yes"
end
