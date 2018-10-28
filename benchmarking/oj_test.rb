require_relative '../lib/grac'
require 'benchmark/ips'
require 'json'
require 'oj'

TYPHOEUS_RESPONSE = Struct.new(:body)

files = Dir.glob("./benchmarking/test_files/*.json").each_with_object({}) do |file, hash_object|
  hash_object[File.basename(file)] = File.read(file)
end

Oj.default_options = { mode: :compat, use_to_json: true }

# Configure the number of seconds used during
# the warmup phase (default 2) and calculation phase (default 5)
benchmark_config = { time: 30 }

files.each do |filename, file_contents|
  typhoeus_response = TYPHOEUS_RESPONSE.new(file_contents)
  grac_response = Grac::Response.new(typhoeus_response)
  result = JSON.parse(file_contents) == grac_response.parsed_json

  puts result
  raise "#{filename} Not equal" unless result

  Benchmark.ips do |x|
    x.config(benchmark_config)

    x.report("JSON.parse: #{filename}") do
      JSON.parse(file_contents)
    end

    x.report("OJ.load: #{filename}") do
      grac_response.parsed_json
    end

    x.compare!
  end
end
