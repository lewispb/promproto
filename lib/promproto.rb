# frozen_string_literal: true

require_relative "promproto/version"
require_relative "promproto/metrics_pb"
require_relative "promproto/cli"

module Promproto
  def self.normalize_url(input)
    url = input.dup

    # Add http:// if no scheme
    unless url.match?(%r{^https?://})
      url = "http://#{url}"
    end

    # Parse to check/add path
    uri = URI.parse(url)

    # Add /metrics if path is empty or just /
    if uri.path.nil? || uri.path.empty? || uri.path == "/"
      uri.path = "/metrics"
    end

    uri.to_s
  end
end
