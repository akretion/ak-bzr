require 'chef/log'
require 'chef/provider'
require 'chef/mixin/shell_out'
require 'fileutils'
      
include Chef::Mixin::ShellOut


def find_current_revision(opts)
  Chef::Log.info("#{@new_resource} finding current equivalent bzr revision")
  if ::File.exist?(::File.join(@new_resource.destination, ".bzr"))
    logs = shell_out!('bzr log -l 10 --line', opts).stdout
    matches = /parent rev #[0-9]+/.match(logs)
    revno = matches && matches[0]
    if revno
      revno = revno.gsub("parent rev #", "")
    else
      if not (logs.index("Akretion Bot") || logs.index("[CUS]"))
        revno = shell_out!('bzr revno', opts).stdout.strip
        Chef::Log.info("Unable to know parent revision from logs")
        Chef::Log.info("But assuming local revno #{revno} because no customization found")
      else
        Chef::Log.info("Unable to know parent revision") 
      end
    end
    return revno
  else
    return nil
  end
end

def assert_target_directory_valid!
  target_parent_directory = ::File.dirname(@new_resource.destination)
  unless ::File.directory?(target_parent_directory)
    msg = "Cannot clone #{@new_resource} to #{@new_resource.destination}, the enclosing directory #{target_parent_directory} does not exist"
    raise Chef::Exceptions::MissingParentDirectory, msg
  end
end

def existing_bzr_clone?
  ::File.exist?(::File.join(@new_resource.destination, ".bzr"))
end

def target_dir_non_existent_or_empty?
  !::File.exist?(@new_resource.destination) || Dir.entries(@new_resource.destination).sort == ['.','..']
end

def make_bzr(branch_alias, branch_url)
  if branch_url
    if branch_alias == "push_location"
      branch_url.gsub!("lp:", "bzr+ssh://bazaar.launchpad.net/")
    else
      branch_url.gsub!("lp:", "http://bazaar.launchpad.net/")
    end
    "#{branch_alias} = #{branch_url}\n"
  else
    ""
  end
end

def make_conf(parent=nil)
  if ::File.exist?("#{@new_resource.destination}/.bzr")
    stack_on_location = false
    if @new_resource.stacked_on_location || @new_resource.full_branch_location
      stack_on_location = @new_resource.full_branch_location || @new_resource.stacked_on_location
    else
      ::File.open("#{@new_resource.destination}/.bzr/branch/branch.conf", "r") do |infile|
        while (line = infile.gets)
          stack_on_location = line.split("stacked_on_location")[1].gsub("=", "").strip() if line.index("stacked_on_location")
        end
      end
    end
    branch_conf = make_bzr("parent_location", parent || @new_resource.repository)
    branch_conf << make_bzr("push_location", @new_resource.push_location || parent || @new_resource.repository)
    branch_conf << make_bzr("public_location", @new_resource.public_location || parent)
    branch_conf << make_bzr("stacked_on_location", stack_on_location) if stack_on_location
    ::File.open("#{@new_resource.destination}/.bzr/branch/branch.conf", 'w') { |f| f.write(branch_conf) }
  end
end

def action_checkout(opts)
  assert_target_directory_valid!

  if target_dir_non_existent_or_empty?
    target = @new_resource.destination.split("/").last

    #SLAVE/STAGING/DEV SERVER:
    if @new_resource.parent && @new_resource.parent != ""
      full_parent = "#{@new_resource.parent}/#{target}"
      shell_out!("mkdir #{@new_resource.destination}", opts) unless ::File.exist?(@new_resource.destination)
      if @new_resource.parent.index("@") #slave of a remote master
        shell_out!("scp -r -o ConnectTimeout=3600 -C #{full_parent}/.bzr #{@new_resource.destination}", opts)
        make_conf("bzr+ssh://erp_dev@#{full_parent.split("@")[1].gsub(":", "")}") #TODO make erp_dev a parameter eventually
      else #local master
        shell_out!("cp -r #{full_parent}/.bzr #{@new_resource.destination}", opts)
        make_conf(full_parent)
      end
      begin
        shell_out!("bzr revert", opts.merge({:cwd => @new_resource.destination}))
      rescue #FIXME bzr branch can be crappy occasionnally, but we don't wan't to bloack everything
      end
      shell_out!("chown -R #{@new_resource.user} #{@new_resource.destination}", opts)

    #TARBALL:
    #eventually we prepared a tarball to speed up the download
    #Not use with full branch mode
    elsif not @new_resource.full_branch_location and @new_resource.tarball
      Chef::Log.info("Downloading #{@new_resource.tarball} for bzr branch #{@new_resource.destination}")
      opts[:cwd] = "/tmp"
      if @new_resource.tarball[0..3] == 'http'
        shell_out!("wget #{@new_resource.tarball}", opts)
      else
        shell_out!("cp #{@new_resource.tarball} .", opts)
      end
      download = @new_resource.tarball.split("/").last #FIXME brittle!
      parent_dir = @new_resource.destination.split("/#{target}")[0]
      Chef::Log.info("Deflating /tmp/#{download} archive to #{@new_resource.destination}")
      shell_out!("tar -jxvf /tmp/#{download} -C #{parent_dir}", opts)
      opts[:cwd] = @new_resource.destination
      make_conf()
      fetch_updates(opts, nil)

    #NORMAL BRANCH:
    else
      #If full branch mode, original branch are downloaded in /opt/openerp/branch/ref/VERSION
      #And server branch are stacked from it
      if @new_resource.full_branch_location
        if not ::File.exist?(@new_resource.full_branch_location)
            Chef::Log.info("Reference branch do not exit download it in #{@new_resource.full_branch_location}")
            ref_cmd = "bzr branch --use-existing-dir #{@new_resource.stacked_on_location || @new_resource.repository} #{@new_resource.full_branch_location}"
        else
            ref_cmd = "cd #{@new_resource.full_branch_location}; bzr pull"
        end
        Chef::Log.info(ref_cmd)
        shell_out!(ref_cmd, opts)
      end
 
      clone_cmd = "bzr branch --stacked --use-existing-dir #{@new_resource.full_branch_location || @new_resource.stacked_on_location || @new_resource.repository} #{@new_resource.destination}"
      #TODO make_conf() ?
      Chef::Log.info(clone_cmd)
      shell_out!(clone_cmd, opts)
      make_conf()
      @new_resource.updated_by_last_action(true)
    end
  else
    Chef::Log.info "#{@new_resource} checkout destination #{@new_resource.destination} already exists or is a non-empty directory"
  end
end

def fetch_updates(opts, current_rev)
  #TODO test if modified/added/removed with bzr status; if yes send email + do nothing

  if current_rev && @new_resource.revision && @new_resource.revision != "HEAD" && current_rev >= @new_resource.revision
    Chef::Log.info("not updating because current rev #{current_rev} >= target rev #{@new_resource.revision}")
    @new_resource.updated_by_last_action(false)
  else
    parent_revno = shell_out!("bzr revno #{@new_resource.repository}", opts).stdout.strip

    if current_rev && (current_rev.to_i == parent_revno.to_i)
      Chef::Log.info("Local rev #{current_rev} is already up to date")
      @new_resource.updated_by_last_action(false)
    else
      Chef::Log.info("upgrading current_rev #{current_rev.to_i} to parent rev #{parent_revno.to_i}")
      cmd = Mixlib::ShellOut.new("bzr pull --overwrite", opts)
      cmd.run_command
      if cmd.stderr.index('branches have diverged')
        merge_cmd = "bzr merge #{@new_resource.repository} -r #{parent_revno}"
        Chef::Log.info(merge_cmd)
        cmd = Mixlib::ShellOut.new(merge_cmd, opts)
        cmd.run_command
        Chef::Log.info(cmd.stdout)
        #TODO detect if merge failed, then rollback + email
        unless cmd.stderr.index('Nothing to do')
          cmd = shell_out!("bzr commit -m 'merged with parent rev ##{parent_revno}'", opts)
          @new_resource.updated_by_last_action(true)
        end
      end
    end

  end
end

def split_repo_rev(repository, revision_arg)
  if repository.index("#") #FIXME that test might be a bit weak
    l = repository.split("#")
    [l[0], revision_arg || l[1]]
  else
    [repository, revision_arg]
  end
end

action :sync do
  @new_resource.destination = @new_resource.name
  @new_resource.repository, @new_resource.revision = split_repo_rev(@new_resource.repo, @new_resource.revision)

  #update param to force update
  if @new_resource.reference_merge
    @new_resource.revision = "HEAD"
  end

  assert_target_directory_valid!

  opts = {}
  opts[:user] = @new_resource.user if @new_resource.user
  opts[:group] = @new_resource.group if @new_resource.group
  opts[:environment] = {'USER' => opts[:user], 'HOME' => "/home/#{opts[:user]}", 'LC_ALL'=>nil}

  if existing_bzr_clone?
    if @new_resource.revision
      opts[:cwd] = @new_resource.destination
      current_rev = find_current_revision(opts)
      fetch_updates(opts, current_rev)
    end
  else
    action_checkout(opts)
    @new_resource.updated_by_last_action(true)
  end

end

def current_revision_matches_target_revision?
  (!@current_resource.revision.nil?) && (target_revision.strip.to_i(16) == @current_resource.revision.strip.to_i(16))
end
