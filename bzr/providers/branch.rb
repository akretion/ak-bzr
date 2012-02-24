require 'chef/log'
require 'chef/provider'
require 'chef/mixin/shell_out'
require 'fileutils'
      
include Chef::Mixin::ShellOut

      def find_current_revision
        Chef::Log.debug("#{@new_resource} finding current bzr revision")
        if ::File.exist?(::File.join(cwd, ".bzr"))
          return shell_out!('bzr revno', :cwd => cwd).stdout.strip #FIXME, may be rev id is better, see git provider
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

      def action_checkout(opts)
        assert_target_directory_valid!

        if target_dir_non_existent_or_empty?

          if @new_resource.tarball #eventually we prepared a tarball to speed up the download
            opts[:cwd] = "/tmp"
            shell_out!("wget #{@new_resource.tarball}", opts)
            download = @new_resource.tarball.split("/").last #FIXME brittle!
            target = @new_resource.destination.split("/").last
            dir = @new_resource.destination.split("/#{target}")[0]
            puts "dir"
            p dir
            shell_out!("tar -jxvf /tmp/#{download} -C #{dir}", opts)
            fetch_updates(opts)
          else
            clone_cmd = "bzr branch --stacked #{@new_resource.repository} #{@new_resource.destination}"
            shell_out!(clone_cmd, opts)
            @new_resource.updated_by_last_action(true)
          end
        else
          Chef::Log.debug "#{@new_resource} checkout destination #{@new_resource.destination} already exists or is a non-empty directory"
        end
      end
      
      def fetch_updates(opts)
        opts[:cwd] = @new_resource.destination
        #TODO test if modified/added/removed with bzr status; if yes send email + do nothing

#       remote_revno = shell_out!("bzr revno #{@new_resource.repository}", opts).stdout.strip
        #TODO look at last commit msg to search for MERGE + rev, eventually compare to avoid merge
        cmd = shell_out!("bzr merge #{@new_resource.repository}", opts) #TODO location
        puts "******"
        p cmd
        #TODO detect if merge failed, then rollback + email
        unless cmd.stderr.index('Nothing to do')
          cmd = shell_out!("bzr commit -m 'merged with rev TODO'", opts)
          @new_resource.updated_by_last_action(true)
        end
      end

      action :sync do
        assert_target_directory_valid!

        opts = {}
        opts[:user] = @new_resource.user if @new_resource.user
        opts[:group] = @new_resource.group if @new_resource.group
        opts[:environment] = {'USER' => opts[:user], 'HOME' => "/home/#{opts[:user]}"}

        if existing_bzr_clone?
          fetch_updates(opts)
        else
          action_checkout(opts)
          @new_resource.updated_by_last_action(true)
        end
      end
      
      def current_revision_matches_target_revision?
        (!@current_resource.revision.nil?) && (target_revision.strip.to_i(16) == @current_resource.revision.strip.to_i(16))
      end
