# frozen_string_literal: true

require "test_helper"

class CLITest < Minitest::Test
  test "ACCEPT_HEADER constant" do
    expected = "application/vnd.google.protobuf; proto=io.prometheus.client.MetricFamily; encoding=delimited"
    assert_equal expected, Promproto::CLI::ACCEPT_HEADER
  end

  test "DEFAULT_WATCH_INTERVAL constant" do
    assert_equal 2, Promproto::CLI::DEFAULT_WATCH_INTERVAL
  end

  test "initialize with url" do
    cli = Promproto::CLI.new("http://localhost:9090/metrics")
    assert_instance_of Promproto::CLI, cli
  end

  test "initialize with watch option" do
    cli = Promproto::CLI.new("http://localhost:9090/metrics", watch: true)
    assert_instance_of Promproto::CLI, cli
  end

  test "initialize with custom interval" do
    cli = Promproto::CLI.new("http://localhost:9090/metrics", watch: true, interval: 5)
    assert_instance_of Promproto::CLI, cli
  end

  test "type_name for counter" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    assert_equal "counter", cli.send(:type_name, :COUNTER)
  end

  test "type_name for gauge" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    assert_equal "gauge", cli.send(:type_name, :GAUGE)
  end

  test "type_name for summary" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    assert_equal "summary", cli.send(:type_name, :SUMMARY)
  end

  test "type_name for histogram" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    assert_equal "histogram", cli.send(:type_name, :HISTOGRAM)
  end

  test "type_name for gauge_histogram" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    assert_equal "gauge_histogram", cli.send(:type_name, :GAUGE_HISTOGRAM)
  end

  test "type_name for untyped" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    assert_equal "untyped", cli.send(:type_name, :UNTYPED)
  end

  test "type_name for unknown" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    assert_equal "unknown", cli.send(:type_name, :UNKNOWN)
  end

  test "format_labels with empty labels" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    assert_equal "", cli.send(:format_labels, [])
  end

  test "format_labels with labels" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    label1 = Io::Prometheus::Client::LabelPair.new(name: "job", value: "prometheus")
    label2 = Io::Prometheus::Client::LabelPair.new(name: "instance", value: "localhost:9090")

    result = cli.send(:format_labels, [label1, label2])
    assert_includes result, "job"
    assert_includes result, "prometheus"
    assert_includes result, "instance"
    assert_includes result, "localhost:9090"
  end

  test "format_bound with positive infinity" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    assert_equal "+Inf", cli.send(:format_bound, Float::INFINITY)
  end

  test "format_bound with negative infinity" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    assert_equal "-Inf", cli.send(:format_bound, -Float::INFINITY)
  end

  test "format_bound with normal value" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    assert_equal "100", cli.send(:format_bound, 100.0)
  end

  test "format_bound with small value" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    result = cli.send(:format_bound, 0.0001)
    assert_match(/e/, result)
  end

  test "format_bound with large value" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    result = cli.send(:format_bound, 10000.0)
    assert_match(/e/, result)
  end

  test "format_bound with zero" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    assert_equal "0", cli.send(:format_bound, 0.0)
  end

  test "format_number with normal value" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    assert_equal "123.5", cli.send(:format_number, 123.5)
  end

  test "format_number with large value" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    result = cli.send(:format_number, 10000.0)
    assert_match(/e/, result)
  end

  test "format_number with small value" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    result = cli.send(:format_number, 0.0001)
    assert_match(/e/, result)
  end

  test "bar_chart with zero" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    assert_equal "", cli.send(:bar_chart, 0, 20)
  end

  test "bar_chart with negative value" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    assert_equal "", cli.send(:bar_chart, -1, 20)
  end

  test "bar_chart with positive value" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    result = cli.send(:bar_chart, 100, 20)
    assert_includes result, "\e[44m"
  end

  test "bucket_bounds returns lower and upper" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    lower, upper = cli.send(:bucket_bounds, 0, 0)
    assert lower < upper
  end

  test "read_varint with single byte" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    data = "\x05"
    value, bytes_read = cli.send(:read_varint, data, 0)
    assert_equal 5, value
    assert_equal 1, bytes_read
  end

  test "read_varint with multi byte" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    data = "\xAC\x02"
    value, bytes_read = cli.send(:read_varint, data, 0)
    assert_equal 300, value
    assert_equal 2, bytes_read
  end

  test "read_varint with empty data" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    value, bytes_read = cli.send(:read_varint, "", 0)
    assert_equal 0, value
    assert_equal 0, bytes_read
  end

  test "read_varint at offset" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    data = "XX\x05"
    value, bytes_read = cli.send(:read_varint, data, 2)
    assert_equal 5, value
    assert_equal 1, bytes_read
  end

  test "parse_delimited with empty data" do
    cli = Promproto::CLI.new("http://localhost/metrics")
    result = cli.send(:parse_delimited, "")
    assert_equal [], result
  end

  test "parse_delimited with valid metrics" do
    cli = Promproto::CLI.new("http://localhost/metrics")

    family = Io::Prometheus::Client::MetricFamily.new(
      name: "test_metric",
      help: "A test metric",
      type: :COUNTER,
      metric: [
        Io::Prometheus::Client::Metric.new(
          counter: Io::Prometheus::Client::Counter.new(value: 42.0)
        )
      ]
    )

    encoded = family.to_proto
    data = [encoded.bytesize].pack("C") + encoded

    result = cli.send(:parse_delimited, data)
    assert_equal 1, result.size
    assert_equal "test_metric", result.first.name
  end

  test "fetches and renders metrics from protobuf endpoint" do
    # Build protobuf response with multiple metric types
    families = []

    # Counter
    families << Io::Prometheus::Client::MetricFamily.new(
      name: "http_requests_total",
      help: "Total HTTP requests",
      type: :COUNTER,
      metric: [
        Io::Prometheus::Client::Metric.new(
          label: [
            Io::Prometheus::Client::LabelPair.new(name: "method", value: "GET"),
            Io::Prometheus::Client::LabelPair.new(name: "status", value: "200")
          ],
          counter: Io::Prometheus::Client::Counter.new(value: 1234.0)
        )
      ]
    )

    # Gauge
    families << Io::Prometheus::Client::MetricFamily.new(
      name: "temperature_celsius",
      help: "Current temperature",
      type: :GAUGE,
      metric: [
        Io::Prometheus::Client::Metric.new(
          label: [Io::Prometheus::Client::LabelPair.new(name: "location", value: "office")],
          gauge: Io::Prometheus::Client::Gauge.new(value: 22.5)
        )
      ]
    )

    # Histogram
    families << Io::Prometheus::Client::MetricFamily.new(
      name: "request_duration_seconds",
      help: "Request duration histogram",
      type: :HISTOGRAM,
      metric: [
        Io::Prometheus::Client::Metric.new(
          histogram: Io::Prometheus::Client::Histogram.new(
            sample_count: 100,
            sample_sum: 53.2,
            bucket: [
              Io::Prometheus::Client::Bucket.new(upper_bound: 0.1, cumulative_count: 20),
              Io::Prometheus::Client::Bucket.new(upper_bound: 0.5, cumulative_count: 70),
              Io::Prometheus::Client::Bucket.new(upper_bound: 1.0, cumulative_count: 95),
              Io::Prometheus::Client::Bucket.new(upper_bound: Float::INFINITY, cumulative_count: 100)
            ]
          )
        )
      ]
    )

    # Encode as length-delimited protobuf
    body = families.map do |family|
      encoded = family.to_proto
      varint_encode(encoded.bytesize) + encoded
    end.join

    stub_request(:get, "http://localhost:9090/metrics")
      .to_return(
        status: 200,
        body: body,
        headers: { "Content-Type" => "application/vnd.google.protobuf; proto=io.prometheus.client.MetricFamily; encoding=delimited" }
      )

    cli = Promproto::CLI.new("http://localhost:9090/metrics")
    output = capture_io { cli.run }.first

    # Verify output contains expected metric data
    assert_includes output, "http_requests_total"
    assert_includes output, "counter"
    assert_includes output, "1234"
    assert_includes output, "method"
    assert_includes output, "GET"

    assert_includes output, "temperature_celsius"
    assert_includes output, "gauge"
    assert_includes output, "22.5"
    assert_includes output, "office"

    assert_includes output, "request_duration_seconds"
    assert_includes output, "histogram"
    assert_includes output, "count:"
    assert_includes output, "100"
    assert_includes output, "le="
  end

  private

  def varint_encode(value)
    result = []
    while value > 127
      result << ((value & 0x7F) | 0x80)
      value >>= 7
    end
    result << value
    result.pack("C*")
  end
end
