# frozen_string_literal: true

require "net/http"
require "uri"

module Promproto
  class CLI
    ACCEPT_HEADER = "application/vnd.google.protobuf; proto=io.prometheus.client.MetricFamily; encoding=delimited"
    DEFAULT_WATCH_INTERVAL = 2

    def initialize(url, watch: false, interval: DEFAULT_WATCH_INTERVAL)
      @url = url
      @watch = watch
      @interval = interval
    end

    def run
      if @watch
        run_watch
      else
        run_once
      end
    end

    private

    def run_once
      data = fetch_metrics
      families = parse_delimited(data)
      render(families)
    rescue Errno::ECONNREFUSED => e
      abort "Error: Connection refused to #{@url}\n\nMake sure the metrics server is running and accessible."
    rescue Errno::ETIMEDOUT, Net::OpenTimeout
      abort "Error: Connection timed out to #{@url}\n\nThe server may be unreachable or behind a firewall."
    rescue SocketError => e
      abort "Error: Could not resolve host for #{@url}\n\n#{e.message}"
    rescue Net::ReadTimeout
      abort "Error: Read timeout waiting for response from #{@url}"
    rescue StandardError => e
      abort "Error: #{e.message}"
    end

    def run_watch
      loop do
        print "\e[2J\e[H" # Clear screen and move cursor to top
        puts "\e[90m#{Time.now.strftime("%Y-%m-%d %H:%M:%S")} - #{@url}\e[0m"
        puts

        begin
          data = fetch_metrics
          families = parse_delimited(data)
          render(families)
        rescue Errno::ECONNREFUSED
          puts "\e[31mError: Connection refused\e[0m"
          puts "\e[90mMake sure the metrics server is running and accessible.\e[0m"
        rescue Errno::ETIMEDOUT, Net::OpenTimeout
          puts "\e[31mError: Connection timed out\e[0m"
        rescue SocketError => e
          puts "\e[31mError: #{e.message}\e[0m"
        rescue StandardError => e
          puts "\e[31mError: #{e.message}\e[0m"
        end

        sleep @interval
      end
    rescue Interrupt
      puts "\nStopped."
    end

    def fetch_metrics
      uri = URI.parse(@url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri.request_uri)
      request["Accept"] = ACCEPT_HEADER

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise "HTTP #{response.code} #{response.message}"
      end

      content_type = response["Content-Type"] || ""
      unless content_type.include?("application/vnd.google.protobuf")
        warn "Warning: Server returned Content-Type: #{content_type}"
        warn "Expected: #{ACCEPT_HEADER}"
        warn ""
      end

      response.body
    end

    def parse_delimited(data)
      families = []
      pos = 0

      while pos < data.bytesize
        # Read varint length
        len, bytes_read = read_varint(data, pos)
        break if len.zero? || bytes_read.zero?

        pos += bytes_read

        break if pos + len > data.bytesize

        msg_data = data[pos, len]
        begin
          family = Io::Prometheus::Client::MetricFamily.decode(msg_data)
          families << family
        rescue Google::Protobuf::ParseError => e
          warn "Warning: Failed to decode message at offset #{pos}: #{e.message}"
        end

        pos += len
      end

      families
    end

    def read_varint(data, pos)
      value = 0
      shift = 0
      bytes_read = 0

      loop do
        return [0, 0] if pos >= data.bytesize

        byte = data.getbyte(pos)
        pos += 1
        bytes_read += 1

        value |= (byte & 0x7F) << shift

        break if (byte & 0x80).zero?

        shift += 7
        return [0, 0] if shift > 63 # Overflow protection
      end

      [value, bytes_read]
    end

    def render(families)
      families.each do |family|
        render_family(family)
      end
    end

    def render_family(family)
      puts "\e[1;36m#{family.name}\e[0m \e[33m(#{type_name(family.type)})\e[0m"
      puts "  \e[90m#{family.help}\e[0m" unless family.help.empty?

      family.metric.each do |metric|
        render_metric(metric, family.type)
      end
      puts
    end

    def type_name(type)
      case type
      when :COUNTER then "counter"
      when :GAUGE then "gauge"
      when :SUMMARY then "summary"
      when :HISTOGRAM then "histogram"
      when :GAUGE_HISTOGRAM then "gauge_histogram"
      when :UNTYPED then "untyped"
      else type.to_s.downcase
      end
    end

    def render_metric(metric, type)
      labels = format_labels(metric.label)

      case type
      when :COUNTER
        puts "  #{labels} \e[32m#{metric.counter.value}\e[0m"
      when :GAUGE
        puts "  #{labels} \e[32m#{metric.gauge.value}\e[0m"
      when :SUMMARY
        render_summary(metric, labels)
      when :HISTOGRAM
        render_histogram(metric, labels)
      when :UNTYPED
        puts "  #{labels} \e[32m#{metric.untyped.value}\e[0m"
      end
    end

    def format_labels(labels)
      return "" if labels.empty?

      pairs = labels.map { |l| "\e[35m#{l.name}\e[0m=\"\e[34m#{l.value}\e[0m\"" }
      "{#{pairs.join(", ")}}"
    end

    def render_summary(metric, labels)
      summary = metric.summary
      puts "  #{labels}"
      puts "    count: \e[32m#{summary.sample_count}\e[0m  sum: \e[32m#{summary.sample_sum}\e[0m"
      summary.quantile.each do |q|
        puts "    p#{(q.quantile * 100).to_i}: \e[32m#{q.value}\e[0m"
      end
    end

    def render_histogram(metric, labels)
      histogram = metric.histogram
      puts "  #{labels}"
      puts "    count: \e[32m#{histogram.sample_count}\e[0m  sum: \e[32m#{format_number(histogram.sample_sum)}\e[0m"

      # Check if this is a native histogram (has schema) or classic
      if histogram.schema != 0 || histogram.positive_span.any? || histogram.negative_span.any?
        render_native_histogram(histogram)
      elsif histogram.bucket.any?
        render_classic_histogram(histogram)
      end
    end

    def render_native_histogram(histogram)
      puts "    \e[90mschema: #{histogram.schema}  zero_threshold: #{histogram.zero_threshold}\e[0m"

      if histogram.zero_count > 0
        puts "    zero: \e[32m#{histogram.zero_count}\e[0m"
      end

      if histogram.negative_span.any?
        puts "    \e[90mnegative buckets:\e[0m"
        render_spans(histogram.negative_span, histogram.negative_delta, histogram.schema, negative: true)
      end

      if histogram.positive_span.any?
        puts "    \e[90mpositive buckets:\e[0m"
        render_spans(histogram.positive_span, histogram.positive_delta, histogram.schema, negative: false)
      end
    end

    def render_spans(spans, deltas, schema, negative:)
      bucket_idx = 0
      count = 0
      delta_idx = 0

      spans.each do |span|
        bucket_idx += span.offset

        span.length.times do
          break if delta_idx >= deltas.size

          count += deltas[delta_idx]
          delta_idx += 1

          lower, upper = bucket_bounds(bucket_idx, schema)
          if negative
            lower, upper = -upper, -lower
          end

          bar = bar_chart(count, 20)
          puts "      [#{format_bound(lower)}, #{format_bound(upper)}): #{bar} \e[32m#{count}\e[0m"

          bucket_idx += 1
        end
      end
    end

    def bucket_bounds(index, schema)
      base = 2.0 ** (2.0 ** -schema)
      lower = base ** index
      upper = base ** (index + 1)
      [lower, upper]
    end

    def render_classic_histogram(histogram)
      puts "    \e[90mclassic buckets:\e[0m"
      histogram.bucket.each do |bucket|
        bar = bar_chart(bucket.cumulative_count, 20)
        puts "      le=#{format_bound(bucket.upper_bound)}: #{bar} \e[32m#{bucket.cumulative_count}\e[0m"
      end
    end

    def bar_chart(value, max_width)
      return "" if value <= 0

      width = [Math.log10(value + 1) * max_width / 5, max_width].min.to_i
      "\e[44m#{" " * width}\e[0m"
    end

    def format_bound(value)
      if value.infinite?
        value.positive? ? "+Inf" : "-Inf"
      elsif value.abs >= 1000 || (value.abs < 0.001 && value != 0)
        format("%.3e", value)
      else
        format("%.4g", value)
      end
    end

    def format_number(value)
      if value.abs >= 1000 || (value.abs < 0.001 && value != 0)
        format("%.3e", value)
      else
        format("%.4g", value)
      end
    end
  end
end
