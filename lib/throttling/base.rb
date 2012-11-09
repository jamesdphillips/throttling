module Throttling
  # Class implements throttling for a single action.
  class Base
    attr_accessor :action, :limits

    def initialize(action)
      @action = action.to_s

      raise ArgumentError, "No throttling limits specified" unless Throttling.limits
      @limits = Throttling.limits[action]
      raise ArgumentError, "No Throttling.limits[#{action}] section found" unless limits

      # Convert simple limits to a hash
      if @limits[:period]
        if @limits[:values]
          @limits[:values] = @limits[:values].sort_by { |name, params| params && params[:limit] }
        end
        @limits = [[ 'global', @limits ]]
      else
        @limits = @limits.sort_by { |name, params| params && params[:period] }
      end
    end

    def check_ip(ip)
      check(:ip, ip)
    end

    def check_user_id(user_id)
      check(:user_id, user_id)
    end

    def check(check_type, check_value, auto_increment = true)
      # Disabled?
      return true if !Throttling.enabled? || check_value.nil?

      limits.each do |period_name, params|
        period = Limit.new(period_name, params)

        key = hits_store_key(check_type, check_value, period.name, period.interval)

        # Retrieve current value
        hits = Throttling.storage.fetch(key, :expires_in => period.ttl, :raw => true) { '0' }.to_i

        if period.values
          value = period.default_value || false
          period.values.each do |value_name, value_params|
            if hits < value_params[:limit].to_i
              value = value_params[:value] || value_params[:default_value] || false
              break
            end
          end
        else
          # Over limit?
          if !period.limit.nil? && hits >= period.limit
            yield(period) if block_given?
            return false
          end
        end

        Throttling.storage.increment(key) if auto_increment
        if period.values
          yield(period) if block_given? and value == true
          return value
        end
      end

      return true
    end

    private

    def hits_store_key(check_type, check_value, period_name, period_value)
      "throttle:#{action}:#{check_type}:#{check_value}:#{period_name}:#{Time.now.to_i / period_value}"
    end
  end
end
