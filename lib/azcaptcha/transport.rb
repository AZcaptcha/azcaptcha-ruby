# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Azcaptcha
  # Minimal interface the client needs; tests provide a fake.
  class Transport
    def post_form(_path, _form)
      raise NotImplementedError
    end

    def post_json(_path, _payload)
      raise NotImplementedError
    end

    def get(_path, _params)
      raise NotImplementedError
    end
  end

  # Default transport — net/http, JSON envelopes only.
  class HttpTransport < Transport
    USER_AGENT = "azcaptcha-ruby/1.0.0"

    def initialize(base_url = "https://azcaptcha.com", timeout = 30)
      @base_url = base_url.sub(%r{/+\z}, "")
      @timeout = timeout
    end

    def post_form(path, form)
      request(path, Net::HTTP::Post.new(path)) do |req|
        req["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = URI.encode_www_form(form.reject { |_, value| value.nil? })
      end
    end

    def post_json(path, payload)
      request(path, Net::HTTP::Post.new(path)) do |req|
        req["Content-Type"] = "application/json"
        req.body = JSON.generate(payload)
      end
    end

    def get(path, params)
      query = URI.encode_www_form(params.reject { |_, value| value.nil? })
      full_path = query.empty? ? path : "#{path}?#{query}"
      request(full_path, Net::HTTP::Get.new(full_path))
    end

    private

    def request(path, req)
      req["Accept"] = "application/json"
      req["User-Agent"] = USER_AGENT
      yield req if block_given?
      uri = URI.parse(@base_url + path)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                 open_timeout: @timeout, read_timeout: @timeout) do |http|
        http.request(req)
      end
      body = JSON.parse(response.body)
      raise Error.for("ERROR_HTTP_5XX", "HTTP #{response.code}") if response.code.to_i >= 500

      body
    rescue JSON::ParserError
      raise Error.for("ERROR_BAD_RESPONSE", response&.body.to_s[0, 200])
    rescue NetworkError
      raise
    rescue StandardError => e
      raise NetworkError.new("ERROR_NETWORK", e.message)
    end
  end
end
