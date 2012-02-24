if node[:platform_version].to_f < 11.10

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

else
  package "bzr"
end

directory "/home/#{node[:openerp][:prod][:unix_user]}/.bazaar" do
  owner node[:openerp][:prod][:unix_user]
  group node[:openerp][:group_unix]
  action :create
end

directory "/home/#{node[:openerp][:dev][:unix_user]}/.bazaar" do
  owner node[:openerp][:dev][:unix_user]
  group node[:openerp][:group_unix]
  action :create
end

template "/home/#{node[:openerp][:prod][:unix_user]}/.bazaar/bazaar.conf" do
  owner node[:openerp][:prod][:unix_user]
  group node[:openerp][:group_unix]
  source "bazaar.conf.erb"
end

template "/home/#{node[:openerp][:dev][:unix_user]}/.bazaar/bazaar.conf" do
  owner node[:openerp][:dev][:unix_user]
  group node[:openerp][:group_unix]
  source "bazaar.conf.erb"
end

