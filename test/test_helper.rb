# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "azcaptcha"
require "json"
require "minitest/autorun"
require "tempfile"

# Replays canned JSON bodies and records every call.
class FakeTransport < Azcaptcha::Transport
  Call = Struct.new(:kind, :path, :payload)

  attr_reader :calls

  def initialize(*responses)
    super()
    @responses = responses
    @calls = []
  end

  def post_form(path, form)
    next_response("form", path, form)
  end

  def post_json(path, payload)
    next_response("json", path, payload)
  end

  def get(path, params)
    next_response("get", path, params)
  end

  private

  def next_response(kind, path, payload)
    @calls << Call.new(kind, path, payload)
    raise "unexpected call: #{kind} #{path}" if @responses.empty?

    @responses.shift
  end
end

module FixtureHelpers
  def fixture(name)
    JSON.parse(File.read(File.expand_path("fixtures/#{name}.json", __dir__)))
  end

  def fixture_body(name)
    fixture(name)["response"]["json"]
  end
end
