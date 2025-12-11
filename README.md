# Promproto

A command-line tool to fetch and display Prometheus metrics in protobuf format.

## Installation

```bash
gem install promproto
```

## Usage

```bash
# Fetch metrics from a target
promproto localhost:9394

# Watch mode - continuously refresh
promproto -w localhost:9394

# Custom refresh interval (in seconds)
promproto -w -n 5 localhost:9394

# Full URL
promproto http://localhost:9394/metrics
```

## Features

- Fetches metrics using the Prometheus protobuf exposition format
- Color-coded output for easy reading
- Supports both classic and native histograms
- Watch mode for continuous monitoring
- Automatic URL normalization (adds http:// and /metrics if missing)

## Native Histograms

When the server exports native histograms, promproto displays:
- Schema and zero threshold
- Zero bucket count
- Positive and negative bucket spans with computed bounds
- Visual bar charts for bucket counts

## Requirements

- Ruby 3.1+
- google-protobuf gem

## License

MIT
