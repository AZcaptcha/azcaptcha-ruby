# frozen_string_literal: true

module Azcaptcha
  # AZcaptcha client — legacy (in.php/res.php) and modern (createTask) APIs.
  # Contract: https://github.com/AZcaptcha/sdk-spec (spec-v1.0.0).
  class Client
    NOT_READY = "CAPCHA_NOT_READY"
    SOFT_ID = 0
    POLL_INTERVAL = 5.0
    FIRST_DELAY = 1.0
    NO_SLOT_BACKOFF = 10.0

    attr_reader :api_key

    def initialize(api_key, host: "https://azcaptcha.com", timeout: 30, soft_id: SOFT_ID,
                   transport: nil, sleeper: nil)
      raise Error.for("ERROR_KEY_DOES_NOT_EXIST", "api_key is required") if api_key.to_s.empty?

      @api_key = api_key
      @soft_id = soft_id
      @http = transport || HttpTransport.new(host, timeout)
      @sleeper = sleeper || ->(seconds) { sleep(seconds) }
    end

    # ── legacy API ────────────────────────────────────────────────────
    def submit(method, **params)
      form = { "key" => @api_key, "method" => method, "json" => "1" }
      form["soft_id"] = @soft_id if @soft_id.positive?
      values = params.transform_keys(&:to_s)
      if values["proxy"]
        proxy, proxytype = Params.normalize_proxy(values.delete("proxy"))
        form["proxy"] = proxy
        form["proxytype"] = proxytype
      end
      form["proxytype"] = values.delete("proxytype").to_s.upcase if values["proxytype"]
      Params.clean(values).each { |key, value| form[key] = value }
      unwrap(@http.post_form("/in.php", form))
    end

    def result(task_id)
      body = @http.get("/res.php", "key" => @api_key, "action" => "get",
                                 "id" => task_id.to_s, "json" => "1")
      raise Error.for(NOT_READY) if body["request"] == NOT_READY

      unwrap(body)
    end

    def wait_result(task_id, timeout: nil, poll_interval: POLL_INTERVAL)
      deadline = Time.now + (timeout || 300)
      delay = FIRST_DELAY
      backoff = NO_SLOT_BACKOFF
      loop do
        begin
          return result(task_id)
        rescue ProcessingError
          pause = delay
          delay = poll_interval
        rescue CapacityError
          pause = backoff
          backoff = [backoff * 1.5, 60.0].min
        rescue LimitError => e
          raise unless e.retryable?

          pause = backoff
          backoff = [backoff * 1.5, 60.0].min
        end
        raise Error.for("ERROR_TIMEOUT", "task #{task_id} not ready") if Time.now + pause >= deadline

        @sleeper.call(pause)
      end
    end

    def balance
      unwrap(@http.get("/res.php", "key" => @api_key, "action" => "getbalance", "json" => "1")).to_f
    end

    def report_bad(task_id)
      unwrap(@http.get("/res.php", "key" => @api_key, "action" => "reportbad",
                                 "id" => task_id.to_s, "json" => "1")).upcase.start_with?("OK")
    end

    # ── modern API ────────────────────────────────────────────────────
    def create_task(type, **task)
      payload = { "clientKey" => @api_key, "task" => { "type" => type }.merge(Params.clean(task.transform_keys(&:to_s))) }
      payload["softId"] = @soft_id if @soft_id.positive?
      body = @http.post_json("/createTask", payload)
      raise_modern(body)
      body["taskId"].to_i
    end

    def get_task_result(task_id)
      body = @http.post_json("/getTaskResult", "clientKey" => @api_key, "taskId" => task_id)
      raise_modern(body)
      body
    end

    def wait_task_result(task_id, timeout: 300)
      deadline = Time.now + timeout
      delay = FIRST_DELAY
      loop do
        body = get_task_result(task_id)
        return body["solution"] || {} if body["status"] == "ready"
        raise Error.for("ERROR_TIMEOUT", "modern task #{task_id} not ready") if Time.now + delay >= deadline

        @sleeper.call(delay)
        delay = POLL_INTERVAL
      end
    end

    # ── helpers ───────────────────────────────────────────────────────
    def solve(method, timeout: nil, **params)
      task_id = submit(method, **params)
      wait_result(task_id, timeout: timeout || Params::DEFAULT_TIMEOUTS.fetch(method, 300))
    end

    def solve_image(image, **params)
      solve("base64", **params.merge(body: Params.image_body(image)))
    end

    def solve_recaptcha_v2(sitekey, pageurl, invisible: false, enterprise: false, **params)
      solve("userrecaptcha", **params.merge(
        googlekey: sitekey, pageurl: pageurl,
        invisible: invisible ? 1 : nil, enterprise: enterprise ? 1 : nil
      ))
    end

    def solve_recaptcha_v3(sitekey, pageurl, action:, min_score: 0.6, **params)
      solve("userrecaptcha", **params.merge(
        googlekey: sitekey, pageurl: pageurl, version: "v3",
        action: action, min_score: min_score
      ))
    end

    def solve_hcaptcha(sitekey, pageurl, **params)
      solve("hcaptcha", **params.merge(sitekey: sitekey, pageurl: pageurl))
    end

    def solve_turnstile(sitekey, pageurl, **params)
      solve("turnstile", **params.merge(sitekey: sitekey, pageurl: pageurl))
    end

    def solve_funcaptcha(publickey, pageurl, **params)
      solve("funcaptcha", **params.merge(publickey: publickey, pageurl: pageurl))
    end

    def solve_geetest(gt, challenge, pageurl, **params)
      solve("geetest", **params.merge(gt: gt, challenge: challenge, pageurl: pageurl))
    end

    private

    def unwrap(body)
      request = body["request"]
      raise Error.for(request) if request.is_a?(String) && request.start_with?("ERROR_")

      raise Error.for(request.is_a?(String) ? request : "ERROR_REQUEST_FAILED") unless body["status"].to_i == 1

      request.nil? ? "" : request.to_s
    end

    def raise_modern(body)
      return if body["errorId"].to_i.zero?

      raise Error.for(body["errorCode"] || "ERROR_UNKNOWN", body["errorDescription"])
    end
  end
end
