require "chef/resource/scm"

class ::Chef
  class Resource
    class AkBzrBranch < ::Chef::Resource::Scm

      def initialize(name, run_context=nil)
        super
        @revision = 'last:1' if @revision == "HEAD"
        @resource_name = :ak_bzr_branch
        @provider = ::Chef::Provider::AkBzr
      end

      def tarball(arg=nil)
        set_or_return(
          :tarball,
          arg,
          :kind_of => [String, FalseClass]
        )
      end

      def full_branch_location(arg=nil)
        set_or_return(
          :full_branch_location,
          arg,
          :kind_of => [String, FalseClass]
        )
      end

      def parent(arg=nil)
        set_or_return(
          :parent,
          arg,
          :kind_of => [String, FalseClass]
        )
      end

      def push_location(arg=nil)
        set_or_return(
          :push_location,
          arg,
          :kind_of => [String, FalseClass]
        )
      end

      def stacked_on_location(arg=nil)
        set_or_return(
          :stacked_on_location,
          arg,
          :kind_of => [String, FalseClass]
        )
      end

      def public_location(arg=nil)
        set_or_return(
          :public_location,
          arg,
          :kind_of => [String, FalseClass]
        )
      end

      alias :branch :revision
      alias :reference :revision

      alias :repo :repository

    end
  end
end
