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

end
