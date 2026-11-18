# frozen_string_literal: true

require_relative "test_helper"

class ErrorsTest < Minitest::Test
  include FixtureHelpers

  def setup
    @spec = fixture("errors")
  end

  def test_every_spec_code_maps_to_typed_error
    codes = @spec["errors"].keys + @spec["envelope_codes"].keys
    codes.each do |code|
      error = Azcaptcha::Error.for(code)
      refute_instance_of Azcaptcha::UnknownError, error, code
      assert_equal code, error.code
    end
  end

  def test_retryable_flags_match_spec
    flags = Azcaptcha::Error.taxonomy
    @spec["errors"].each do |code, meta|
      assert_equal meta["retryable"], flags[code], code
      assert_equal meta["retryable"], Azcaptcha::Error.for(code).retryable?, code
    end
    @spec["envelope_codes"].each do |code, meta|
      assert_equal meta["retryable"], Azcaptcha::Error.for(code).retryable?, code
    end
  end

  def test_unknown_codes_are_forward_compatible
    error = Azcaptcha::Error.for("ERROR_FROM_THE_FUTURE")
    assert_instance_of Azcaptcha::UnknownError, error
    refute error.retryable?
  end
end
