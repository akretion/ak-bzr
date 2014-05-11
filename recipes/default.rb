include_recipe "apt::default"

python_pkgs = value_for_platform_family(
                  "debian"  => ["bzr", "bzrtools"],
                  "default" => ["bzr", "bzrtools"]
              )


if platform_family?('ubuntu') && node[:platform_version].to_f < 11.10 #installs bzr 2.3 to be able to commit on stacked branches, see https://bugs.launchpad.net/bzr/+bug/375013

  apt_repository "bzr-beta" do
    uri "http://ppa.launchpad.net/bzr/beta/ubuntu"
    distribution node[:lsb][:codename]
    components ["main"]
    action :add
    notifies :run, "execute[apt-get update-bzr]", :immediately
  end

  execute "apt-get update-bzr" do
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
  python_pkgs.each do |pkg|
    package pkg do
      action :install
    end
  end
end
