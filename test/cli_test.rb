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

  test "fetches and renders counter metrics" do
    family = Io::Prometheus::Client::MetricFamily.new(
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

    stub_metrics_endpoint([ family ])

    output = run_cli

    assert_includes output, "http_requests_total"
    assert_includes output, "counter"
    assert_includes output, "1234"
    assert_includes output, "method"
    assert_includes output, "GET"
    assert_includes output, "status"
    assert_includes output, "200"
  end

  test "fetches and renders gauge metrics" do
    family = Io::Prometheus::Client::MetricFamily.new(
      name: "temperature_celsius",
      help: "Current temperature",
      type: :GAUGE,
      metric: [
        Io::Prometheus::Client::Metric.new(
          label: [ Io::Prometheus::Client::LabelPair.new(name: "location", value: "office") ],
          gauge: Io::Prometheus::Client::Gauge.new(value: 22.5)
        )
      ]
    )

    stub_metrics_endpoint([ family ])

    output = run_cli

    assert_includes output, "temperature_celsius"
    assert_includes output, "gauge"
    assert_includes output, "22.5"
    assert_includes output, "location"
    assert_includes output, "office"
  end

  test "fetches and renders histogram metrics" do
    family = Io::Prometheus::Client::MetricFamily.new(
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

    stub_metrics_endpoint([ family ])

    output = run_cli

    assert_includes output, "request_duration_seconds"
    assert_includes output, "histogram"
    assert_includes output, "count:"
    assert_includes output, "100"
    assert_includes output, "sum:"
    assert_includes output, "le="
    assert_includes output, "+Inf"
  end

  test "fetches and renders summary metrics" do
    family = Io::Prometheus::Client::MetricFamily.new(
      name: "request_latency_seconds",
      help: "Request latency summary",
      type: :SUMMARY,
      metric: [
        Io::Prometheus::Client::Metric.new(
          summary: Io::Prometheus::Client::Summary.new(
            sample_count: 1000,
            sample_sum: 123.45,
            quantile: [
              Io::Prometheus::Client::Quantile.new(quantile: 0.5, value: 0.05),
              Io::Prometheus::Client::Quantile.new(quantile: 0.9, value: 0.1),
              Io::Prometheus::Client::Quantile.new(quantile: 0.99, value: 0.2)
            ]
          )
        )
      ]
    )

    stub_metrics_endpoint([ family ])

    output = run_cli

    assert_includes output, "request_latency_seconds"
    assert_includes output, "summary"
    assert_includes output, "count:"
    assert_includes output, "1000"
    assert_includes output, "sum:"
    assert_includes output, "p50"
    assert_includes output, "p90"
    assert_includes output, "p99"
  end

  test "fetches and renders untyped metrics" do
    family = Io::Prometheus::Client::MetricFamily.new(
      name: "some_untyped_metric",
      help: "An untyped metric",
      type: :UNTYPED,
      metric: [
        Io::Prometheus::Client::Metric.new(
          untyped: Io::Prometheus::Client::Untyped.new(value: 42.0)
        )
      ]
    )

    stub_metrics_endpoint([ family ])

    output = run_cli

    assert_includes output, "some_untyped_metric"
    assert_includes output, "untyped"
    assert_includes output, "42"
  end

  test "fetches and renders multiple metric families" do
    families = [
      Io::Prometheus::Client::MetricFamily.new(
        name: "metric_one",
        help: "First metric",
        type: :COUNTER,
        metric: [
          Io::Prometheus::Client::Metric.new(
            counter: Io::Prometheus::Client::Counter.new(value: 111.0)
          )
        ]
      ),
      Io::Prometheus::Client::MetricFamily.new(
        name: "metric_two",
        help: "Second metric",
        type: :GAUGE,
        metric: [
          Io::Prometheus::Client::Metric.new(
            gauge: Io::Prometheus::Client::Gauge.new(value: 222.0)
          )
        ]
      )
    ]

    stub_metrics_endpoint(families)

    output = run_cli

    assert_includes output, "metric_one"
    assert_includes output, "111"
    assert_includes output, "metric_two"
    assert_includes output, "222"
  end

  test "renders metrics without labels" do
    family = Io::Prometheus::Client::MetricFamily.new(
      name: "simple_counter",
      help: "A simple counter",
      type: :COUNTER,
      metric: [
        Io::Prometheus::Client::Metric.new(
          counter: Io::Prometheus::Client::Counter.new(value: 99.0)
        )
      ]
    )

    stub_metrics_endpoint([ family ])

    output = run_cli

    assert_includes output, "simple_counter"
    assert_includes output, "99"
  end

  private
    def stub_metrics_endpoint(families, url: "http://localhost:9090/metrics")
      body = families.map do |family|
        encoded = family.to_proto
        varint_encode(encoded.bytesize) + encoded
      end.join

      stub_request(:get, url)
        .to_return(
          status: 200,
          body: body,
          headers: { "Content-Type" => "application/vnd.google.protobuf; proto=io.prometheus.client.MetricFamily; encoding=delimited" }
        )
    end

    def run_cli(url: "http://localhost:9090/metrics")
      cli = Promproto::CLI.new(url)
      capture_io { cli.run }.first
    end

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
