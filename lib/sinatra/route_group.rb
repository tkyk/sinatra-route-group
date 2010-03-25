require 'sinatra/base'

module Sinatra
  module RouteGroup
    def self.registered(app)
      app.helpers Helpers
    end

    module Helpers
      def route_group
        @route_group
      end
    end

    class RouteGroup
      attr_reader :name

      def initialize(name)
        @name = name
        @before = []
      end

      def before_filter(block)
        @before.push(block)
      end

      def execute_before_filters(app)
        @before.each { |block| app.instance_eval(&block) }
      end
    end

    # DSL method group
    def group(name)
      prev_group = @current_group
      @current_group = name.nil? ? nil : ensure_group(name)

      if block_given?
        yield
        @current_group = prev_group
      end
    end

    # DSL method before_filter
    # 
    # This is not an 'actual' before filter.
    # 
    def before_filter(&block)
      return before(&block) unless @current_group
      ensure_group(@current_group.name).before_filter(block)
    end

    private
    def ensure_group(name)
      (@groups||= {})[name]||= RouteGroup.new(name)
    end

    def route(verb, path, options={}, &block)
      return super unless @current_group

      current_group = @current_group
      define_method "__#{verb} #{path}", &block
      unbound_method = instance_method("__#{verb} #{path}")
      block =
        if block.arity != 0
          lambda {
            (@route_group = current_group).execute_before_filters(self)
            unbound_method.bind(self).call(*@block_params)
          }
        else
          lambda {
            (@route_group = current_group).execute_before_filters(self)
            unbound_method.bind(self).call
          }
        end
      super(verb, path, options, &block)
    end
  end

  register RouteGroup
end
