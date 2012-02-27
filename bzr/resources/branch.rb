# example of bzr_branch resource:
#
#bzr_branch "#{node[:openerp][:home]}/prod/pt-br-localiz" do
#  repo "lp:openerp.pt-br-localiz#HEAD"
#  action :sync 
#  is_addons_pack true
#  user node[:openerp][:super_user][:unix_user]
#  group node[:openerp][:group_unix]
#  notifies :run, resources(:execute => "openerp-prod-restart-update")
#end


actions :sync

attribute :destination,        :kind_of => String
attribute :repo,        :kind_of => String
attribute :repository,        :kind_of => String
attribute :revision,        :kind_of => String
attribute :autosync,        :kind_of => String #no, weekly, daily...
attribute :tarball,        :kind_of => String
attribute :is_addons_pack,        :kind_of => [TrueClass, FalseClass]

attribute :user,        :kind_of => [String, Integer]
attribute :group,        :kind_of => [String, Integer]
attribute :cwd,        :kind_of => String

alias :branch :revision
alias :reference :revision
alias :repo :repository

def destination=(dest)
  @destination = dest
end

def repository=(rep)
  @repository = rep
end

def revision=(rev)
  @revision = rev
end
