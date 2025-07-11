require "http/client"
require "../utils"

struct Geolocation
  property latitude : Float64
  property longitude : Float64
  property country_acr : String
  property country_num : Int32
  
  def initialize(@latitude : Float64, @longitude : Float64, @country_acr : String, @country_num : Int32)
  end
end

module Geoloc
  @@client = HTTP::Client.new("ip-api.com", tls: false)
  @@cache = Hash(String, Geolocation).new
  @@order = Array(String).new
  @@capacity = 256
  @@mutex = Mutex.new

  def self.fetch(ip : String) : Geolocation?
    return nil if ip.empty?
    
    @@mutex.synchronize do
      if geo = @@cache[ip]?
        @@order.delete(ip)
        @@order << ip
        return geo
      end
    end

    response = @@client.get("/line/#{ip}?fields=status,message,countryCode,lat,lon")
    return nil unless response.status_code == 200

    lines = response.body.lines
    return nil unless lines[0]? == "success"

    country_acr = lines[1].downcase
    geo = Geolocation.new(
      latitude: lines[2].to_f,
      longitude: lines[3].to_f,
      country_acr: country_acr, # should i store acronym?
      country_num: COUNTRY_CODES[country_acr]? || 0
    )

    @@mutex.synchronize do
      if @@cache.has_key?(ip)
        @@order.delete(ip)
      elsif @@cache.size >= @@capacity
        old_key = @@order.shift
        @@cache.delete(old_key)
      end
      
      @@cache[ip] = geo
      @@order << ip
    end
    
    geo
  end
end