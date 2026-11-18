# frozen_string_literal: true

require_relative "test_helper"

class ParamsTest < Minitest::Test
  def test_normalises_proxies
    assert_equal ["1.2.3.4:8080", "HTTP"], Azcaptcha::Params.normalize_proxy("1.2.3.4:8080")
    assert_equal ["user:pass@1.2.3.4:8080", "HTTP"],
                 Azcaptcha::Params.normalize_proxy("user:pass@1.2.3.4:8080")
    assert_equal ["user:pass@1.2.3.4:8080", "HTTP"],
                 Azcaptcha::Params.normalize_proxy("1.2.3.4:8080:user:pass")
    assert_equal ["u:p@1.2.3.4:1080", "SOCKS5"],
                 Azcaptcha::Params.normalize_proxy("socks5://u:p@1.2.3.4:1080")
    assert_equal ["u:p@1.2.3.4:1080", "SOCKS4"],
                 Azcaptcha::Params.normalize_proxy("socks4://u:p@1.2.3.4:1080")
    assert_equal ["u:p@1.2.3.4:8080", "HTTP"],
                 Azcaptcha::Params.normalize_proxy("https://u:p@1.2.3.4:8080")
  end

  def test_rejects_proxy_without_port
    assert_raises(ArgumentError) { Azcaptcha::Params.normalize_proxy("1.2.3.4") }
  end

  def test_image_encodings
    assert_equal "UE5H", Azcaptcha::Params.image_body("PNG".b)
    assert_equal "AAAA", Azcaptcha::Params.image_body("data:image/png;base64,AAAA")
    assert_equal "iVBORw0KGgo=", Azcaptcha::Params.image_body("iVBORw0KGgo=\n")

    Tempfile.create(["captcha", ".png"]) do |file|
      file.binmode
      file.write("PNG")
      file.close
      assert_equal "UE5H", Azcaptcha::Params.image_body(file.path)
    end
  end
end
