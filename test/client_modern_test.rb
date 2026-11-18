# frozen_string_literal: true

require_relative "test_helper"

class ClientModernTest < Minitest::Test
  include FixtureHelpers

  def client(transport, sleeps = [])
    Azcaptcha::Client.new("test-key", transport: transport,
                                      sleeper: ->(seconds) { sleeps << seconds })
  end

  def test_create_task_fixture
    transport = FakeTransport.new(fixture_body("modern-create-task"))
    id = client(transport).create_task("RecaptchaV2TaskProxyless",
                                       websiteURL: "https://example.com/login",
                                       websiteKey: "6Le-wvkSAAAAAPBMRTvw0Q4Muexq9bi0DJwx_mJ-")
    assert_equal 1234567892, id
    call = transport.calls.first
    assert_equal ["json", "/createTask"], [call.kind, call.path]
    assert_equal "test-key", call.payload["clientKey"]
    assert_equal fixture("modern-create-task")["request"]["json"]["task"], call.payload["task"]
  end

  def test_get_task_result_fixture
    transport = FakeTransport.new(fixture_body("modern-task-ready"))
    body = client(transport).get_task_result(1234567892)
    assert_equal "ready", body["status"]
    assert_equal "03AGdBq26...", body["solution"]["gRecaptchaResponse"]
  end

  def test_wait_task_result_polls
    transport = FakeTransport.new(
      { "errorId" => 0, "status" => "processing" },
      { "errorId" => 0, "status" => "ready", "solution" => { "token" => "abc" } }
    )
    sleeps = []
    assert_equal({ "token" => "abc" }, client(transport, sleeps).wait_task_result(1))
    assert_equal [1.0], sleeps
  end

  def test_modern_error_mapping
    transport = FakeTransport.new({ "errorId" => 12, "errorCode" => "ERROR_ZERO_BALANCE" })
    assert_raises(Azcaptcha::BalanceError) do
      client(transport).create_task("RecaptchaV2TaskProxyless")
    end
  end

  def test_wait_task_result_timeout
    transport = FakeTransport.new({ "errorId" => 0, "status" => "processing" })
    assert_raises(Azcaptcha::ResultError) { client(transport).wait_task_result(1, timeout: 0.001) }
  end
end
