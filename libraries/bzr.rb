require 'chef/exceptions'
require 'chef/log'
require 'chef/provider'
require 'chef/mixin/shell_out'
require 'fileutils'

# we don't define the provider as a classical LWRP but more as a HWRP
# because we want to inherit from the standard Chef::Provider
# and because we want the associated resource to inherit from Chef::Scm
# as explained here http://tech.yipit.com/2013/05/09/advanced-chef-writing-heavy-weight-resource-providers-hwrp/
class Chef
  class Provider
    class AkBzr < Chef::Provider

      include ::Chef::Mixin::ShellOut

      def load_current_resource
        @current_resource ||= Chef::Resource::AkBzrBranch.new(new_resource.name)
        if current_revision = find_current_revision
          @current_resource.revision current_revision
        end
      end

      def revid?(string)
        string =~ /@/
      end

      # we use bzr revision-info --tree
      # however that would break if somebody used bzr revert -r rev_X instead of bzr update -r rev_X ...
      # see https://answers.launchpad.net/bzr/+question/132321
      def find_current_revision
        Chef::Log.info("#{@new_resource} finding current bzr revision")
        if existing_bzr_clone?
          result = shell_out!('bzr revision-info --tree', :cwd => cwd, :returns => [0,128]).stdout.split(' ')[1]
          revid?(result) ? result : nil
        else
          nil
        end
      end

      def remote_resolve_reference
        Chef::Log.debug("#{@new_resource} resolving remote reference")
        cmd = "bzr log #{@new_resource.repo} -r #{@new_resource.revision} --show-ids"
        resolved_reference = shell_out!(cmd, opts_cwd).stdout
        ref_lines = resolved_reference.split("\n")
        found_line = ref_lines.select { |l| l.start_with?('revision-id:') }
        if found_line
          found_line[0].gsub('revision-id:', '').strip
        else
          nil
        end
      end

      def current_revision_matches_target_revision?
        (!@current_resource.revision.nil?) && (target_revision.strip == @current_resource.revision.strip)
      end

      def target_revision
        @target_revision ||= begin
          if revid?(@new_resource.revision)
            @target_revision = @new_resource.revision
          else
            @target_revision = remote_resolve_reference
          end
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

      # SLAVE/STAGING/DEV SERVER (a bit specific to OpenERP context)
      def checkout_slave(target)
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
          shell_out!("bzr revert", opts_cwd)
        rescue #FIXME bzr branch can be crappy occasionnally, but we don't wan't to block everything
          Chef::Log.error("Failed bzr revert")
        end
        shell_out!("chown -R #{@new_resource.user} #{@new_resource.destination}", opts)
      end

      # TARBALL:
      # eventually we prepared a tarball to speed up the download
      # Not use with full branch mode
      def checkout_tarball(target)
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
        make_conf()
        fetch_updates
      end

      def action_checkout
        assert_target_directory_valid!

        if target_dir_non_existent_or_empty?
          target = @new_resource.destination.split("/").last

          if @new_resource.parent && @new_resource.parent != ""
            checkout_slave(target)
          elsif not @new_resource.full_branch_location and @new_resource.tarball
            checkout_tarball(target)
          else # NORMAL BRANCH
            converge_by("checkout ref #{@new_resource.revision} branch #{@new_resource.repository}") do
              #If full branch mode, original branch are downloaded in /opt/openerp/branch/ref/VERSION
              #And server branch are stacked from it
              if @new_resource.full_branch_location
                if !::File.exist?(@new_resource.full_branch_location)
                  Chef::Log.info("Reference branch do not exit download it in #{@new_resource.full_branch_location}")
                  ref_cmd = "bzr branch --use-existing-dir #{@new_resource.stacked_on_location || @new_resource.repository} #{@new_resource.full_branch_location}"
                else # NOTE debatable do pull it on checkout, no?
                  ref_cmd = "cd #{@new_resource.full_branch_location}; bzr pull"
                end
                Chef::Log.info(ref_cmd)
                shell_out!(ref_cmd, opts)
              end
 
              clone_cmd = "bzr branch --stacked --use-existing-dir #{@new_resource.full_branch_location || @new_resource.stacked_on_location || @new_resource.repository} #{@new_resource.destination}"
              clone_cmd += " -r #{@new_resource.revision}" if @new_resource.revision
              Chef::Log.info(clone_cmd)
              shell_out!(clone_cmd, opts)
              make_conf()
            end
          end
          @new_resource.updated_by_last_action(true)
        else
          Chef::Log.info "#{@new_resource} checkout destination #{@new_resource.destination} already exists or is a non-empty directory"
        end
      end

      def fetch_updates
        #TODO test if modified/added/removed with bzr status; if yes send email + do nothing
        converge_by("fetch updates for #{@new_resource.repository}") do

          fetch_command = "bzr pull :parent && bzr update -r #{target_revision}" # NOTE we could do --overwrite if some option
          Chef::Log.debug "Fetching updates from #{@new_resource.repo} and resetting to revision #{target_revision}"
          cmd = Mixlib::ShellOut.new(fetch_command, opts_cwd)
          cmd.run_command
          if cmd.stderr.index('branches have diverged')
            merge_cmd = "bzr merge #{@new_resource.repository}" # NOTE we merge and abandon the target_revision, fair enough?
            Chef::Log.info(merge_cmd)
            cmd = Mixlib::ShellOut.new(merge_cmd, opts_cwd)
            cmd.run_command
            Chef::Log.info(cmd.stdout)
            #TODO detect if merge failed, then rollback + email
            unless cmd.stderr.index('Nothing to do')
              @new_resource.updated_by_last_action(true)
            end
          end

        end
      end

      def action_sync
        assert_target_directory_valid!

        if existing_bzr_clone?
          current_rev = find_current_revision
          Chef::Log.debug "#{@new_resource} current revision: #{current_rev} target revision: #{target_revision}"
          unless current_revision_matches_target_revision?
            fetch_updates
            Chef::Log.info "#{@new_resource} updated to revision #{target_revision}"
          end
        else
          action_checkout
          @new_resource.updated_by_last_action(true)
        end
      end

      def opts
        opts = {}
        opts[:user] = @new_resource.user if @new_resource.user
        opts[:group] = @new_resource.group if @new_resource.group
        opts[:environment] = {'USER' => opts[:user], 'HOME' => "/home/#{opts[:user]}", 'LC_ALL'=>nil}
        opts
      end

      def opts_cwd
        opts.merge({cwd: cwd})
      end 

      def cwd
        @new_resource.destination
      end

      protected


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

    end
  end
end
