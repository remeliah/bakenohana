require "./utils"

module Middleware
  @@handlers = {} of String => Kemal::RouteHandler

  # register routes for a specific subdomain
  # usage:
  #   Middleware.sub("a") do |r|
  #     r.get "/foo" { |env| "hi" }
  #   end
  def self.sub(name : String, &block : Kemal::RouteHandler ->)
    handler = Kemal::RouteHandler.new
    block.call(handler)
    @@handlers[name] = handler
  end

  def self.register_all
    #Kemal.config.logger = Metrics.new # should i really place it here?
    Kemal.config.add_handler Metrics.new
    Kemal.config.add_handler Dispatcher.new(@@handlers)
  end

  class Dispatcher < Kemal::Handler
    def initialize(@handlers : Hash(String, Kemal::RouteHandler)); end

    def call(env : HTTP::Server::Context)
      host = env.request.headers["Host"]?
      return call_next(env) if host.nil?

      sub = host.split(".")[0]?
      return call_next(env) if sub.nil?

      handler = @handlers[sub]?
      if handler
        verb = env.request.method
        path = env.request.path

        route = handler.lookup_route(verb, path)

        if route.found?
          return call_route(route.payload, route.params, env)
        end

        env.response.status_code = 404
        env.response.print("not found")
      end
    end

    # 6,7, 6+7=13; 13th letter of the alphabet = M, M = Mango, M = Mustard, both Mango+Mustard are yellow, 7/6 = 1.166666(67), 
    # x = 78.16666(67), %, %, %, %, 0.00000078, 7-8=1, 8-1=7, 7-1= 6, 67, square root of 67.67 = 8.22(6)1(7)7/6 = 1.166666(67), 
    # x = 78.16666(67), %, %, %, %, 0.00000078, 7-8=1, 8-1=7, 7-1= 6, 67, square root of 67.67 = 8.22(6)1(7)772723 7/6 = 1.166666(67), 
    # x = 78.16666(67), %, %, %, %, 0.00000078, 7-8=1, 8-1=7, 7-1= 6, 67, square root of 67.67 = 8.22(6)1(7)7727237/6 = 1.166666(67), 
    # x = 78.16666(67), %, %, %, %, 0.00000078, 7-8=1, 8-1=7, 7-1= 6, 67, square root of 67.67 = 8.22(6)1(7)7727237/6 = 1.166666(67), 
    # x = 78.16666(67), %, %, %, %, 0.00000078, 7-8=1, 8-1=7, 7-1= 6, 67, square root of 67.67 = 8.22(6)1(7)7727237/6 = 1.166666(67), 
    # x = 78.16666(67), %, %, %, %, 0.00000078, 7-8=1, 8-1=7, 7-1= 6, 67, square root of 67.67 = 8.22(6)1(7)7727237/6 = 1.166666(67), 
    # x = 78.16666(67), %, %, %, %, 0.00000078, 7-8=1, 8-1=7, 7-1= 6, 67, square root of 67.67 = 8.22(6)1(7)7727237/6 = 1.166666(67), 
    # x = 78.16666(67), %, %, %, %, 0.00000078, 7-8=1, 8-1=7, 7-1= 6, 67, square root of 67.67 = 8.22(6)1(7)7727237/6 = 1.166666(67), 
    # x = 78.16666(67), %, %, %, %, 0.00000078, 7-8=1, 8-1=7, 7-1= 6, 67, square root of 67.67 = 8.22(6)1(7)772723🤔
    def call_route(route : Kemal::Route, params : Hash(String, String), env : HTTP::Server::Context)
      params.each { |k, v| env.params.url[k] = v }

      begin
        ngentot = route.handler.call(env)

        unless env.response.closed?
          env.response.print(ngentot) if ngentot.is_a?(String)
        end
      rescue ex : Exception
        if !Kemal.config.error_handlers.empty? && Kemal.config.error_handlers.has_key?(500)
          raise Kemal::Exceptions::CustomException.new(env)
        else
          env.response.status_code = 500
          env.response.print("internal server error")
        end
      end

      if !Kemal.config.error_handlers.empty? && Kemal.config.error_handlers.has_key?(env.response.status_code)
        raise Kemal::Exceptions::CustomException.new(env)
      end

      env.params.cleanup_temporary_files
      return
    end
  end

  class Metrics < Kemal::Handler # Kemal::BaseLogHandler
    def call(env : HTTP::Server::Context)
      s_ = Time.monotonic

      call_next env

      n_ = Time.monotonic
      elap = (n_ - s_).total_nanoseconds

      status = env.response.status_code
      color = status < 400 ? Ansi::LGREEN : Ansi::LRED

      begin
        host = env.request.headers["Host"]?
        path = env.request.path
        method = env.request.method

        rlog "[#{method}] #{status} #{host}#{path}#{Ansi::RESET} | #{Ansi::LBLUE}request took: #{format_time(elap)}", color
      rescue ex
        # someone tryna scan vulnerability?
        rlog "[scan?] #{env.request.path} | #{Ansi::LBLUE}request took: #{format_time(elap)}", color
        rlog env.request.to_s
      end

      env.response.headers["process-time"] = (elap / 1_000_000.0).round(2).to_s
    end
  end
end