# frozen_string_literal: true

require_relative "lib/azcaptcha/version"

Gem::Specification.new do |spec|
  spec.name = "azcaptcha"
  spec.version = Azcaptcha::VERSION
  spec.authors = ["AZcaptcha"]
  spec.email = ["support@azcaptcha.com"]

  spec.summary = "Official AZcaptcha SDK — reCAPTCHA, hCaptcha, Turnstile and image captchas"
  spec.description = "Ruby client for the AZcaptcha API: 2Captcha-compatible in.php/res.php " \
                     "plus the modern createTask API, typed errors and contract polling."
  spec.homepage = "https://azcaptcha.com/lang/ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => "https://github.com/AZcaptcha/azcaptcha-ruby",
    "changelog_uri" => "https://github.com/AZcaptcha/azcaptcha-ruby/blob/main/CHANGELOG.md",
    "documentation_uri" => "https://azcaptcha.com/docs",
    "rubygems_mfa_required" => "true"
  }

  spec.files = Dir["lib/**/*.rb"] + %w[README.md CHANGELOG.md LICENSE]
  spec.require_paths = ["lib"]
end
