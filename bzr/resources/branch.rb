# example of bzr_branch resource:
#
#bzr_branch "test" do
#  repo "lp:openobject-serveri/6.1"
#  destination "/opt/openerp/test2/server"
#  tarball "#{node[:openerp][:bzr][:snaphot_repo]}server.tar.bz2"
#  revision "HEAD"
#  action :sync
#  user node[:openerp][:super_user][:unix_user]
#  group node[:openerp][:group_unix]
#end


actions :sync

attribute :destination,        :kind_of => String
attribute :repo,        :kind_of => String
attribute :repository,        :kind_of => String
attribute :revision,        :kind_of => String
attribute :autosync,        :kind_of => String #no, weekly, daily...
attribute :tarball,        :kind_of => String

attribute :user,        :kind_of => [String, Integer]
attribute :group,        :kind_of => [String, Integer]
attribute :cwd,        :kind_of => String

alias :branch :revision
alias :reference :revision
alias :repo :repository
