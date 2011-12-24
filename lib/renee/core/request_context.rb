module Renee
  class Core
    module ClassMethods
      def use(mw, *args, &blk)
        middlewares << [mw, args, blk]
      end

      def middlewares
        @middlewares ||= []
      end
    end

    # This module deals with the Rack#call compilance. It defines #call and also defines several critical methods
    # used by interaction by other application modules.
    module RequestContext
      attr_reader :env, :request, :detected_extension

      # Provides a rack interface compliant call method.
      # @param[Hash] env The rack environment.
      def call(e)
        init_application
        idx = 0
        next_app = proc do |env|
          if idx == self.class.middlewares.size
            @env, @request = env, Rack::Request.new(env)
            @detected_extension = env['PATH_INFO'][/\.([^\.\/]+)$/, 1]
            # TODO clear template cache in development? `template_cache.clear`
            catch(:halt) do
              begin
                instance_eval(&self.class.application_block)
              rescue ClientError => e
                e.response ? instance_eval(&e.response) : halt("There was an error with your request", 400)
              rescue NotMatchedError => e
                # unmatched, continue on
              end
              Renee::Core::Response.new("Not found", 404).finish
            end
          else
            middleware = self.class.middlewares[idx]
            idx += 1
            middleware[0].new(next_app, *middleware[1], &middleware[2]).call(env)
          end
        end
        next_app[e]
      end # call

      def init_application
        self.class.included_modules.select{|m| m.respond_to?(:init_application)}.each(&:init_application)
        extend Module.new { define_method(:init_application) { } }
      end
    end
  end
end
