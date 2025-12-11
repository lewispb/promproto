# frozen_string_literal: true

require "test_helper"

class PromprotoTest < Minitest::Test
  test "version is defined" do
    refute_nil Promproto::VERSION
  end

  test "normalize_url adds http scheme" do
    assert_equal "http://localhost/metrics", Promproto.normalize_url("localhost")
  end

  test "normalize_url adds http scheme with port" do
    assert_equal "http://localhost:9090/metrics", Promproto.normalize_url("localhost:9090")
  end

  test "normalize_url preserves https scheme" do
    assert_equal "https://example.com/metrics", Promproto.normalize_url("https://example.com")
  end

  test "normalize_url preserves http scheme" do
    assert_equal "http://example.com/metrics", Promproto.normalize_url("http://example.com")
  end

  test "normalize_url adds metrics path when empty" do
    assert_equal "http://localhost:9090/metrics", Promproto.normalize_url("http://localhost:9090")
  end

  test "normalize_url adds metrics path when root" do
    assert_equal "http://localhost:9090/metrics", Promproto.normalize_url("http://localhost:9090/")
  end

  test "normalize_url preserves custom path" do
    assert_equal "http://localhost:9090/custom/path", Promproto.normalize_url("http://localhost:9090/custom/path")
  end

  test "normalize_url preserves query params" do
    assert_equal "http://localhost:9090/metrics?foo=bar", Promproto.normalize_url("http://localhost:9090?foo=bar")
  end

  test "normalize_url handles full url" do
    assert_equal "https://prometheus.example.com:9090/api/metrics",
                 Promproto.normalize_url("https://prometheus.example.com:9090/api/metrics")
  end
end
