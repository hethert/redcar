$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. vendor})))

require 'java'
require 'scm_svn/change'
begin
  require 'svnkit.jar'
rescue
  #Subversion Libraries not found
end

module Redcar
  module Scm
    module Subversion
      class Manager
        include Redcar::Scm::Model
        include_package 'org.tmatesoft.svn.core.wc'
        import 'org.tmatesoft.svn.core.SVNURL'
        import 'org.tmatesoft.svn.core.SVNDepth'

        def client_manager
          @manager ||= SVNClientManager.newInstance()
        end

        def repository_type
          "subversion"
        end

        def self.scm_module
          Redcar::Scm::Subversion::Manager
        end

        def self.supported?
          puts "    Subversion support is currently in progress" if debug
          true
        end

        def load(path)
          raise "Already loaded repository" if @path
          @path = path
          puts "loaded repository at #{path}" if debug
        end

        def repository?(path)
          File.exist?(File.join(path, %w{.svn}))
        end

        def refresh
        end

        def supported_commands
          [
            :pull, :commit,:index_delete, :index_add,
            :index_ignore ,:index_revert, :index_restore,
            :index_save   ,:index_unsave, :index
          ]
        end

        def pull!(path)
          if repository?(@path)
            client_manager.getUpdateClient().doUpdate(
              Java::JavaIo::File.new(path),
              SVNRevision.HEAD,
              true, # allow unversioned files to exist in directory
              false # store depth in directory
            )
          else
            client_manager.getUpdateClient().doCheckout(
              SVNURL.parseURIEncoded(path),
              Java::JavaIo::File.new(@path),
              SVNRevision.HEAD,
              SVNDepth.INFINITY,
              true # allow unversioned files to exist already in directory
            )
          end
        end

        #TODO: commit! and commit_message
        def uncommited_changes
          indexed_changes + unindexed_changes
        end

        def unindexed_changes
          populate_changes(@path,false)
        end

        def indexed_changes
          populate_changes(@path,true)
        end

        def populate_changes(path,indexed)
          nodes = []
          find_dirs(path,indexed,nodes)
          nodes
        end

        def find_dirs(path,indexed,nodes=[])
          Dir["#{path.to_s}/*/"].map do |a|
            find_dirs(a,indexed,nodes)
          end
          check_files(path,indexed,nodes)
        end

        def check_files(path,indexed,nodes)
          files = File.join(path.to_s, "*")
          Dir.glob(files).each do |file_path|
            if File.file?(file_path)
              status = check_file_status(file_path,indexed)
              nodes << Scm::Subversion::Change.new(file_path,status,[]) if status
            end
          end
        end

        def check_file_status(path,indexed)
          status_client = client_manager.getStatusClient()
          status = status_client.doStatus(Java::JavaIo::File.new(path),false).getContentsStatus()
          if indexed
            s = case status
            when SVNStatusType::STATUS_MODIFIED then :changed
            when SVNStatusType::STATUS_MISSING  then :missing
            when SVNStatusType::STATUS_DELETED  then :deleted
            when SVNStatusType::STATUS_ADDED    then :indexed
            end
            s
          else
            s = case status
            when SVNStatusType::STATUS_UNVERSIONED then :new
            end
            s
          end
          puts "Final status: #{s} Path: #{path}" if debug and s
        end

        def translations
          t = super
          if repository?(@path)
            t[:push] = "Commit Changes",
            t[:pull] = "Update Working Copy"
          else
            t[:push] = "Commit Changes",
            t[:pull] = "Checkout Repository"
          end
          t
        end

        def self.debug
          Redcar::Scm::Manager.debug
        end

        def debug
          Redcar::Scm::Subversion::Manager.debug
        end

        def inspect
          if @path
            %Q{#<Scm::Subversion::Manager "#{@path}">}
          else
            %Q{#<Scm::Subversion::Manager>}
          end
        end
      end
    end
  end
end