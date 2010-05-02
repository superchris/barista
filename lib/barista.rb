require 'active_support'
require 'pathname'

module Barista
  
  autoload :Compiler,  'barista/compiler'
  autoload :Filter,    'barista/filter'
  autoload :Framework, 'barista/framework'
  
  class << self
    
    def configure
      yield self if block_given?
    end
    
    def root
      @root ||= Rails.root.join("app", "coffeescripts")
    end
    
    def root=(value)
      @root = Pathname(value.to_s)
      Framework.default_framework = nil
    end
    
    def output_root
      @output_root ||= Rails.root.join("public", "javascripts")
    end
    
    def output_root=(value)
      @output_root = Pathname(value.to_s)
    end
    
    def compile_file!(file, force = false)
      file = Framework.full_path_for(file)
      return if file.blank?
      destination_path = self.output_path_for(file)
      return unless force || Compiler.dirty?(file, destination_path)
      debug "Compiling #{file}"
      FileUtils.mkdir_p File.dirname(destination_path)
      File.open(destination_path, "w+") do |f|
        f.write Compiler.compile(File.read(file))
      end
      true
    rescue SystemCallError
      false
    end
    
    def compile_all!(force = false)
      debug "Compiling all coffeescripts"
      Framework.exposed_coffeescripts.each do |coffeescript|
        compile_file! from, force
      end
      true
    end
    
    def output_path_for(file)
      output_root.join(file.gsub(/^\//, '')).gsub(/\.coffee$/, '.js')
    end
    
    def debug(message)
      Rails.logger.debug "[Barista] #{message}" if defined?(Rails.logger) && Rails.logger
    end
    
    # By default, only add it in dev / test
    def add_filter?
      Rails.env.test? || Rails.env.development?
    end
    
    def no_wrap?
      defined?(@no_wrap) && @no_wrap
    end
    
    def no_wrap!
      self.no_wrap = true
    end
    
    def no_wrap=(value)
      @no_wrap = !!value
    end
    
  end
  
  if defined?(Rails::Engine)
    class Engine < Rails::Engine
      
      rake_tasks do
        load File.expand_path('./barista/tasks/barista.rake', File.dirname(__FILE__))
      end
      
      initializer "barista.wrap_filter" do
        ActionController::Base.before_filter(Barista::Filter) if Barista.add_filter?
      end
      
    end
  end
  
end