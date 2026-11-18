# frozen_string_literal: true

require "base64"

module Azcaptcha
  # Proxy and image parameter normalisation.
  module Params
    module_function

    DEFAULT_TIMEOUTS = {
      "base64" => 120, "grid" => 120,
      "userrecaptcha" => 300, "recaptcha_v3" => 300,
      "hcaptcha" => 120, "hcaptcha_enterprise" => 120,
      "turnstile" => 180,
      "funcaptcha" => 300, "geetest" => 300, "geetest_v4" => 300,
      "mtcaptcha" => 300, "friendlycaptcha" => 300, "altcha" => 300,
      "cf_clearance" => 300, "aws_waf" => 300, "filecrypt" => 300
    }.freeze

    SCHEMES = { "http" => "HTTP", "https" => "HTTP", "socks4" => "SOCKS4", "socks5" => "SOCKS5" }.freeze

    # Returns [proxy, proxytype]; the scheme is never sent upstream.
    def normalize_proxy(proxy)
      raw = proxy.strip
      proxytype = "HTTP"
      if (index = raw.index("://"))
        proxytype = SCHEMES.fetch(raw[0...index].downcase, "HTTP")
        raw = raw[(index + 3)..]
      end
      parts = raw.split(":")
      if parts.length == 4 && parts[1].match?(/\A\d+\z/)
        raw = "#{parts[2]}:#{parts[3]}@#{parts[0]}:#{parts[1]}"
      elsif !raw.include?("@")
        port = raw.split(":").last
        raise ArgumentError, "proxy must include a numeric port" unless port&.match?(/\A\d+\z/)
      end
      [raw, proxytype]
    end

    def image_body(image)
      return Base64.strict_encode64(image) if image.is_a?(String) && image.encoding == Encoding::BINARY

      value = image.to_s.strip
      return value.split(",", 2)[1] if value.start_with?("data:") && value.include?(",")
      return Base64.strict_encode64(File.binread(value)) if value.length < 4096 && File.file?(value)
      return value.gsub(/\s+/, "") if value.match?(/\A[A-Za-z0-9+\/=\s]+\z/)

      Base64.strict_encode64(value)
    end

    def clean(params)
      params.reject { |_, value| value.nil? }
    end
  end
end
