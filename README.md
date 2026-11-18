# AZcaptcha Ruby SDK

Official Ruby client for [AZcaptcha](https://azcaptcha.com) — image captchas,
reCAPTCHA v2/v3, hCaptcha, Cloudflare Turnstile, FunCaptcha and GeeTest.

- 2Captcha-compatible surface (`solve`, `result`, `balance`, `report_bad`) plus the
  modern JSON API (`create_task`, `get_task_result`).
- Typed exceptions for every API code
  ([spec-v1.0.0](https://github.com/AZcaptcha/sdk-spec)).
- Contract polling with `NO_SLOT` backoff and per-type deadlines.
- Zero runtime dependencies (`net/http`), Ruby 2.6+.

## Install

```bash
gem install azcaptcha
```

or in a Gemfile:

```ruby
gem "azcaptcha", "~> 1.0"
```

## Quickstart

```ruby
require "azcaptcha"

client = Azcaptcha::Client.new("YOUR_API_KEY")

# reCAPTCHA v2
token = client.solve_recaptcha_v2(
  "6Le-wvkSAAAAAPBMRTvw0Q4Muexq9bi0DJwx_mJ-",
  "https://example.com/login"
)

# Image captcha (bytes, base64, data: URI or file path)
answer = client.solve_image("captcha.png")

# hCaptcha / Turnstile
token = client.solve_hcaptcha("SITEKEY", "https://example.com/")
token = client.solve_turnstile("0x4AAAAAAA...", "https://example.com/")
```

### Low-level (2Captcha style)

```ruby
task_id = client.submit("userrecaptcha",
                        googlekey: "SITEKEY",
                        pageurl: "https://example.com/")
token = client.wait_result(task_id) # polls 1s then every 5s
```

### Modern JSON API

```ruby
task_id = client.create_task("RecaptchaV2TaskProxyless",
                             websiteURL: "https://example.com/login",
                             websiteKey: "SITEKEY")
solution = client.wait_task_result(task_id)
puts solution["gRecaptchaResponse"]
```

## Proxies

```ruby
client.solve_recaptcha_v2(sitekey, pageurl,
                          proxy: "socks5://user:pass@1.2.3.4:1080")
```

Any accepted spelling works (`scheme://user:pass@host:port`,
`host:port:user:pass`, `user:pass@host:port`). The scheme is never sent
upstream; `proxytype` is derived (`http`/`https` → `HTTP`, `socks4`, `socks5`).

## Errors

```ruby
begin
  token = client.solve_turnstile(sitekey, pageurl)
rescue Azcaptcha::BalanceError
  # ERROR_ZERO_BALANCE
rescue Azcaptcha::CapacityError
  # ERROR_NO_SLOT_AVAILABLE — retry with backoff
rescue Azcaptcha::ResultError
  # unsolvable / timeout / expired
end
```

Every exception exposes `#code` and `#retryable?`. `wait_result` retries only
codes marked retryable and backs off 10s ×1.5 up to 60s.

## Timeouts

Defaults match server settings: image 120s, hCaptcha 120s, Turnstile 180s,
reCAPTCHA and others 300s. Override per call:
`client.solve("turnstile", timeout: 90, sitekey: key, pageurl: url)` or
`client.wait_result(id, timeout: 600)`.

## Custom transport

```ruby
client = Azcaptcha::Client.new("KEY", transport: MyTransport.new)
```

`MyTransport` must respond to `post_form`, `post_json` and `get`.

## Links

- API contract: <https://github.com/AZcaptcha/sdk-spec>
- Docs: <https://azcaptcha.com/docs>
- Ruby guide: <https://azcaptcha.com/lang/ruby>
- Changelog: [CHANGELOG.md](CHANGELOG.md)

## License

MIT — see [LICENSE](LICENSE).
