module Throttling
  class Limit
    
    attr_accessor :name, :interval, :limit, :values, :default_value
    
    def initialize(name, opts = {})
      self.name     = name
      self.interval = opts[:period].to_i
      self.limit    = opts[:limit].nil? ? nil : opts[:limit].to_i
      self.values   = opts[:values]
      self.default_value = opts[:default_value]
    end

    def interval=(val)
      raise ArgumentError, "Invalid or no 'period' parameter in the #{name} limit." if val < 1
      @interval = val
    end

    def limit=(val)
      raise ArgumentError, "Invalid 'limit' parameter in the #{name} limits." if !val.nil? && val < 0
      @limit = val
    end

    def self.from_action(action)
      limits = Throttling.limits[action]
      if limits[:period]
        if limits[:values]
          limits[:values] = limits[:values].sort_by { |name, params| params && params[:limit] }
        end
        [new('global', limits)]
      else
        limits.sort_by do |name, params|
          params && params[:period]
        end.map do |name, params|
          new(name, params)
        end
      end
    end

    def ttl
      interval - Time.now.to_i % interval
    end
  end
end