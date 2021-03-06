require 'uri'

require 'renee/version'

module Renee
  # URL generator for creating paths and URLs within your application.
  module URLGeneration
    # Current version of Renee::URLGeneration
    VERSION = Renee::VERSION

    # @api private
    def self.included(o)
      o.extend(ClassMethods)
    end

    # Generates a url
    # @see ClassMethods#url
    def make_url(name, *args)
      self.class.url(name, *args)
    end

    # Generates a path
    # @see ClassMethods#path
    def make_path(name, *args)
      self.class.path(name, *args)
    end

    # Class-methods included by this module.
    module ClassMethods
      def define_url_generation(&blk)
        url_generator.instance_eval(&blk)
      end

      private
      def url_generator
        @generator ||= GeneratorSet.new
      end
    end

    class GeneratorSet
      attr_accessor :generation_prefix

      def initialize(prefix = '', defaults = nil, generators = {})
        @url_generators = generators
        @generation_prefix = prefix
        @generation_defaults = defaults
      end

      def defaults_for_generation(defaults)
        @generation_defaults && defaults ? @generation_defaults.merge(defaults) : (defaults || @generation_defaults)
      end

      # Registers new paths for generation.
      # @param [Symbol] name The name of the path
      # @param [String] pattern The pattern used for generation.
      # @param [Hash, nil] defaults Any default values used for generation.
      #
      # @example
      #     renee.register(:path, "/my/:var/path")
      #     renee.path(:path, 123) # => "/my/123/path"
      #     renee.path(:path, :var => 'hey you') # => "/my/hey%20you/path"
      def register(name, pattern, defaults = nil)
        @url_generators[name] = Generator.new("#{@generation_prefix}#{pattern}", defaults_for_generation(defaults))
      end

      # Allows the creation of generation contexts.
      # @param [String] prefix The prefix to add to subsequent calls to #register.
      # @param [Hash, nil] defaults The defaults to add to subsequent calls to #register.
      # @see #register
      #
      # @example
      #     renee.prefix("/prefix") {
      #       renee.register(:prefix_path, "/path") # would register /prefix/path
      #     }
      def prefix(prefix, defaults = nil, &blk)
        subgenerator = GeneratorSet.new("#{@generation_prefix}#{prefix}", defaults_for_generation(defaults), @url_generators)
        if block_given?
          old_prefix, old_defaults = @generation_prefix, @generation_defaults
          @generation_prefix, @generation_defaults = "#{@generation_prefix}#{prefix}", defaults_for_generation(defaults)
          subgenerator.instance_eval(&blk)
          @generation_prefix, @generation_defaults = old_prefix, old_defaults
        end
        subgenerator
      end

      # Generates a path for a given name.
      # @param [Symbol] name The name of the path
      # @param [Object] args The values used to generate the path. Can be named with using :name => "value" or supplied
      #                   in the order for which the variables were decalared in #register.
      #
      # @see #register
      def path(name, *args)
        generator = @url_generators[name]
        generator ? generator.path(*args) : raise("Generator for #{name} doesn't exist")
      end

      # Generates a url for a given name.
      # @param (see #path)
      # @see #path
      def url(name, *args)
        generator = @url_generators[name]
        generator ? generator.url(*args) : raise("Generator for #{name} doesn't exist")
      end
    end

    # @private
    class Generator
      attr_reader :defaults

      def initialize(template, defaults = nil)
        @defaults = defaults
        parsed_template = URI.parse(template)
        @host = parsed_template.host
        @template = parsed_template.path
        @scheme = parsed_template.scheme
        port = parsed_template.port
        if !port.nil? and (@scheme.nil? or @scheme == "http" && port != '80' or @scheme == "https" && port != '443')
          @port_part = ":#{port}"
        end
      end

      def path(*args)
        opts = args.last.is_a?(Hash) ? args.pop : nil
        opts = opts ? defaults.merge(opts) : defaults.dup if defaults
        path = @template.gsub(/:([a-zA-Z0-9_]+)/) { |name|
          name = name[1, name.size - 1].to_sym
          (opts && opts.delete(name)) || (defaults && defaults[name]) || args.shift || raise("variable #{name.inspect} not found")
        }
        URI.encode(opts.nil? || opts.empty? ? path : "#{path}?#{Rack::Utils.build_query(opts)}")
      end

      def url(*args)
        raise "This URL cannot be generated as no host has been defined." if @host.nil?
        "#{@scheme}://#{@host}#{@port_part}#{path(*args)}"
      end
    end
  end
end
