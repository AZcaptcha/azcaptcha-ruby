# frozen_string_literal: true

module Azcaptcha
  # Base error: +code+ is the raw API code, +retryable?+ mirrors the taxonomy.
  class Error < StandardError
    RETRYABLE = false
    attr_reader :code

    def initialize(code = "ERROR_UNKNOWN", message = nil, retryable = self.class::RETRYABLE)
      @code = code
      @retryable = retryable
      super(message || code)
    end

    def retryable?
      @retryable
    end

    TABLE = {}

    def self.register(klass, codes, retryable)
      codes.each { |code| TABLE[code] = [klass, retryable] }
    end

    def self.for(code, message = nil)
      klass, retryable = TABLE[code]
      (klass || UnknownError).new(code, message, retryable || false)
    end

    def self.taxonomy
      TABLE.transform_values { |(_, retryable)| retryable }
    end
  end

  class ProcessingError < Error; RETRYABLE = true; end
  class AuthError < Error; end
  class BalanceError < Error; end
  class RequestError < Error; end
  class LimitError < Error; end
  class CapacityError < Error; RETRYABLE = true; end
  class ServiceError < Error; end
  class ResultError < Error; end
  class ProxyError < Error; end
  class PingbackError < Error; end
  class ModuleError < Error; end
  class NetworkError < Error; RETRYABLE = true; end
  class UnknownError < Error; end

  Error.register(ProcessingError, ["CAPCHA_NOT_READY"], true)
  Error.register(AuthError, %w[ERROR_KEY_DOES_NOT_EXIST ERROR_ACCOUNT_SUSPENDED], false)
  Error.register(BalanceError, ["ERROR_ZERO_BALANCE"], false)
  Error.register(RequestError, %w[
    ERROR_BAD_PARAMETERS ERROR_WRONG_ID_FORMAT ERROR_NO_SUCH_CAPCHA_ID ERROR_TASK_NOT_FOUND
    ERROR_TASK_NOT_SUPPORTED ERROR_WRONG_GOOGLEKEY ERROR_RECAPTCHA_INVALID_SITEKEY
    ERROR_WRONG_PAGEURL ERROR_IMAGE_NOT_FOUND ERROR_IMAGE_TYPE_NOT_SUPPORTED
    ERROR_ZERO_CAPTCHA_FILESIZE ERROR_TOO_BIG_CAPTCHA_FILESIZE
  ], false)
  Error.register(LimitError, ["ERROR_DAILY_LIMIT_EXCEEDED"], false)
  Error.register(LimitError, ["ERROR_TOO_MANY_THREADS"], true)
  Error.register(CapacityError, ["ERROR_NO_SLOT_AVAILABLE"], true)
  Error.register(ServiceError, ["ERROR_MAINTENANCE"], false)
  Error.register(ResultError, %w[ERROR_TIMEOUT ERROR_TTL ERROR_TOKEN_EXPIRED ERROR_CAPTCHA_UNSOLVABLE], false)
  Error.register(ProxyError, %w[ERROR_PROXY_REQUIRED ERROR_PROXY_NOT_AUTHORIZED ERROR_PROXY_BANNED], false)
  Error.register(PingbackError, ["ERROR_PINGBACK_NOT_VERIFIED"], false)
  Error.register(ModuleError, %w[ERROR_MODULE_ACCESS_DENIED ERROR_MODULE_NOT_TRAINED], false)
end
