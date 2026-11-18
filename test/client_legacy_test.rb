# frozen_string_literal: true

require_relative "test_helper"

class ClientLegacyTest < Minitest::Test
  include FixtureHelpers

  def client(transport, soft_id: 0, sleeps: nil)
    sleeps ||= []
    Azcaptcha::Client.new("test-key", transport: transport, soft_id: soft_id,
                                      sleeper: ->(seconds) { sleeps << seconds })
  end

  def test_solves_image_from_fixture
    transport = FakeTransport.new(fixture_body("submit-image"), { "status" => 1, "request" => "wxyz" })
    assert_equal "wxyz", client(transport).solve_image("PNG".b)

    call = transport.calls.first
    assert_equal "form", call.kind
    assert_equal "/in.php", call.path
    assert_equal "base64", call.payload["method"]
    assert_equal "test-key", call.payload["key"]
    assert_equal "1", call.payload["json"]
    assert_equal Base64.strict_encode64("PNG".b), call.payload["body"]
  end

  def test_submits_recaptcha_v2_fixture
    transport = FakeTransport.new(fixture_body("submit-recaptcha-v2"))
    id = client(transport).submit("userrecaptcha",
                                  googlekey: "6Le-wvkSAAAAAPBMRTvw0Q4Muexq9bi0DJwx_mJ-",
                                  pageurl: "https://example.com/login")
    assert_equal "1234567891", id
    refute transport.calls.first.payload.key?("soft_id")
  end

  def test_sends_soft_id_when_configured
    transport = FakeTransport.new({ "status" => 1, "request" => "1" })
    client(transport, soft_id: 4242).submit("base64", body: "AA==")
    assert_equal 4242, transport.calls.first.payload["soft_id"]
  end

  def test_normalises_proxy_fields
    transport = FakeTransport.new({ "status" => 1, "request" => "1" })
    client(transport).submit("turnstile", sitekey: "0x4AAA", pageurl: "https://e.com",
                                         proxy: "socks5://u:p@1.2.3.4:1080")
    form = transport.calls.first.payload
    assert_equal "u:p@1.2.3.4:1080", form["proxy"]
    assert_equal "SOCKS5", form["proxytype"]
  end

  def test_zero_balance_fixture
    error = assert_raises(Azcaptcha::BalanceError) do
      client(FakeTransport.new(fixture_body("error-zero-balance")))
        .submit("userrecaptcha", googlekey: "k", pageurl: "https://e.com")
    end
    assert_equal "ERROR_ZERO_BALANCE", error.code
    refute error.retryable?
  end

  def test_no_slot_fixture
    error = assert_raises(Azcaptcha::CapacityError) do
      client(FakeTransport.new(fixture_body("error-no-slot")))
        .submit("turnstile", sitekey: "k", pageurl: "https://e.com")
    end
    assert_equal "ERROR_NO_SLOT_AVAILABLE", error.code
    assert error.retryable?
  end

  def test_poll_fixtures
    ready = FakeTransport.new(fixture_body("poll-ready-recaptcha"))
    assert_equal "03AGdBq26...", client(ready).result("1234567891")

    processing = FakeTransport.new(fixture_body("poll-processing"))
    assert_raises(Azcaptcha::ProcessingError) { client(processing).result("1234567891") }
  end

  def test_wait_result_contract_delays
    transport = FakeTransport.new(fixture_body("poll-processing"), fixture_body("poll-ready-recaptcha"))
    sleeps = []
    assert_equal "03AGdBq26...", client(transport, sleeps: sleeps).wait_result("1234567891")
    assert_equal [1.0], sleeps
  end

  def test_wait_result_backs_off_on_no_slot
    transport = FakeTransport.new(
      { "status" => 0, "request" => "ERROR_NO_SLOT_AVAILABLE" },
      { "status" => 1, "request" => "token" }
    )
    sleeps = []
    assert_equal "token", client(transport, sleeps: sleeps).wait_result("1")
    assert_equal [10.0], sleeps
  end

  def test_wait_result_raises_non_retryable_immediately
    transport = FakeTransport.new({ "status" => 0, "request" => "ERROR_CAPTCHA_UNSOLVABLE" })
    assert_raises(Azcaptcha::ResultError) { client(transport).wait_result("1") }
  end

  def test_wait_result_timeout
    transport = FakeTransport.new({ "status" => 0, "request" => "CAPCHA_NOT_READY" })
    assert_raises(Azcaptcha::ResultError) { client(transport).wait_result("1", timeout: 0.001) }
  end

  def test_balance_and_report_bad
    transport = FakeTransport.new(
      { "status" => 1, "request" => 12.5 },
      { "status" => 1, "request" => "OK_REPORT_RECORDED" }
    )
    instance = client(transport)
    assert_in_delta 12.5, instance.balance
    assert instance.report_bad("123")
  end

  def test_rejects_empty_key
    assert_raises(Azcaptcha::AuthError) { Azcaptcha::Client.new("") }
  end
end
