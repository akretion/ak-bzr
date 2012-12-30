define :bzr_user_conf do

  directory "/home/#{params[:owner]}/.bazaar" do
    owner params[:owner]
    group params[:group]
    action :create
  end

  template "/home/#{params[:owner]}/.bazaar/bazaar.conf" do
    owner params[:owner]
    group params[:group]
    source "bazaar.conf.erb"
    action :create
  end

  directory "/home/#{params[:owner]}/.bazaar/plugins" do
    owner params[:owner]
    group params[:group]
    mode "0755"
    action :create
  end

  execute "bzr branch lp:bzr-push-and-update /home/#{params[:owner]}/.bazaar/plugins/push_and_update" do
    creates "/home/#{params[:owner]}/.bazaar/plugins/push_and_update"
    environment 'USER' => params[:owner], 'HOME' => "/home/#{params[:owner]}", 'LC_ALL'=>nil
    user params[:owner]
  end

end
