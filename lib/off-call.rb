require "chronic"
require "date"
require "active_support"
require "active_support/core_ext/date/calculations"
require "json"
require "rest-client"
require "time"

ENV.instance_eval do
  def source(filename)
    return {} unless File.exists?(filename)

    env = File.read(filename).split("\n").inject({}) do |hash, line|
      if line =~ /\A([A-Za-z_0-9]+)=(.*)\z/
        key, val = [$1, $2]
        case val
          when /\A'(.*)'\z/ then hash[key] = $1
          when /\A"(.*)"\z/ then hash[key] = $1.gsub(/\\(.)/, '\1')
          else hash[key] = val
        end
      end
      hash
    end

    env.each { |k,v| ENV[k] = v unless ENV[k] }
  end
end

class String
  def to_datetime
    t = Time.parse(self) rescue Chronic.parse(self)
    #
    # Convert seconds + microseconds into a fractional number of seconds
    seconds = t.sec + Rational(t.usec, 10**6)

    # Convert a UTC offset measured in minutes to one measured in a
    # fraction of a day.
    offset = Rational(t.utc_offset, 60 * 60 * 24)
    DateTime.new(t.year, t.month, t.day, t.hour, t.min, seconds, offset)
  end

  def trunc(len)
    if (self.length > len)
      self[0...len-3] + "..."
    else
      self
    end
  end
end

class Hash
  def reverse_merge!(h)
    replace(h.merge(self))
  end
end

module OffCall
  module PagerDuty

    def self.api
      @api || raise("Initialize with PagerDuty.connect")
    end

    def self.connect(subdomain, user, password)
      @api = RestClient::Resource.new(
        "https://#{subdomain}.pagerduty.com/api/",
        user: user, password: password)
    end

    def self.paginated_get(resource, result_key, params)
      results = []
      offset = 0
      loop do
        params[:offset] = offset
        result = JSON.parse(PagerDuty.api[resource].get(params: params))
        results += result[result_key]
        break if results.length >= result["total"]
        offset += result[result_key].length
      end
      results
    end

    def self.params_with_dates(params, start, end_)
      p = Hash[params]
      p[:since] = start.iso8601
      p[:until] = end_.iso8601
      p
    end

    def self.thirty_days_batches(params)
      results = []
      start = params[:since]
      until_ = params[:until]
      loop do
        results += yield start, [start + 30, until_].min
        start += 30
        break if start >= until_
      end
      results
    end

    def self.alerts(params={})
      params.reverse_merge!(until: Time.now, since: Time.now-60*60*24)
      thirty_days_batches params do |start, end_|
        PagerDuty.paginated_get(
          "v1/alerts", "alerts", params_with_dates(params, start, end_))
      end
    end

    def self.incidents(params={})
      params.reverse_merge!(until: Time.now, since: Time.now-60*60*24)
      thirty_days_batches params do |start, end_|
        PagerDuty.paginated_get(
          "v1/incidents", "incidents", params_with_dates(params, start, end_))
      end
    end

    def self.log_entries(service, params={})
      PagerDuty.paginated_get(
        "v1/incidents/#{service}/log_entries", "log_entries", params)
    end

    class Service
      def initialize(id)
        @id = id
      end

      def incidents(opts={})
        opts.reverse_merge!(until: Time.now, since: Time.now-60*60*24)
        params = {
          service:  @id,
          until:    opts[:until].iso8601,
          since:    opts[:since].iso8601
        }

        PagerDuty.api["v1/incidents"].paginated_get(params: params)
      end

    end

    class Schedule
      def initialize(subdomain, user, password, id)
        @id  = id
        @api = PagerDuty.api["beta/schedules/#{@id}"]
      end

      def add_override(user_id, start_dt, end_dt)
        # TODO: check if exact override already exists
        params = {
          override: {
            user_id:  user_id,
            start:    start_dt.strftime("%Y-%m-%dT%H:%M:%S"),
            end:      end_dt.strftime("%Y-%m-%dT%H:%M:%S"),
          }
        }

        @api["overrides"].post(params.to_json, content_type: "application/json")
      end
    end
  end

end
