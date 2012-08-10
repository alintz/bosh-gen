require 'yaml'
require 'thor/group'

module Bosh::Gen
  module Generators
    class JobGenerator < Thor::Group
      include Thor::Actions

      argument :job_name
      argument :dependencies, :type => :array
      argument :purpose
      
      def self.source_root
        File.join(File.dirname(__FILE__), "job_generator", "templates")
      end
      
      def check_root_is_release
        unless File.exist?("jobs") && File.exist?("packages")
          raise Thor::Error.new("run inside a BOSH release project")
        end
      end
      
      def check_name
        raise Thor::Error.new("'#{job_name}' is not a valid BOSH id") unless job_name.bosh_valid_id?
      end

      def check_purpose
        unless valid_purposes.include?(purpose)
          raise Thor::Error.new("'#{purpose}' is not a valid job purpose #{valid_purposes.inspect}")
        end
      end
      
      def warn_missing_dependencies
        dependencies.each do |d|
          raise Thor::Error.new("dependency '#{d}' is not a valid BOSH id") unless d.bosh_valid_id?
          unless File.exist?(File.join("packages", d))
            say_status "warning", "missing dependency '#{d}'", :yellow
          end
        end
      end
      
      def template_files
        directory "jobs/%job_name%_#{purpose}", "jobs/#{job_name}"
        @template_files = { "#{job_name}_ctl" => "bin/#{job_name}_ctl" }
      end
      
      def job_specification
        config = { "name" => job_name, "packages" => dependencies, "templates" => @template_files }
        create_file job_dir("spec"), YAML.dump(config)
      end
      
      private
      def filenames
        files.map {|f| File.basename(f) }
      end
      
      def job_dir(path)
        File.join("jobs", job_name, path)
      end
      
      def valid_purposes
        %w[simple nginx_rack]
      end
      
      # Run a command in git.
      #
      # ==== Examples
      #
      #   git :init
      #   git :add => "this.file that.rb"
      #   git :add => "onefile.rb", :rm => "badfile.cxx"
      #
      def git(commands={})
        if commands.is_a?(Symbol)
          run "git #{commands}"
        else
          commands.each do |cmd, options|
            run "git #{cmd} #{options}"
          end
        end
      end
    end
  end
end
