require 'rack/ssl'

require 'test/unit'
require 'rack/test'

class TestSSL < Test::Unit::TestCase
  include Rack::Test::Methods

  def default_app
    lambda { |env|
      headers = {'Content-Type' => "text/html"}
      headers['Set-Cookie'] = ["id=1; path=/", "token=abc; path=/; secure; HttpOnly"]
      [200, headers, ["OK"]]
    }
  end

  def app
    @app ||= Rack::SSL.new(default_app)
  end
  attr_writer :app

  def test_allows_https_url
    get "https://example.org/path?key=value"
    assert last_response.ok?
  end

  def test_allows_https_proxy_header_url
    get "http://example.org/", {}, 'HTTP_X_FORWARDED_PROTO' => "https"
    assert last_response.ok?
  end

  def test_redirects_http_to_https
    get "http://example.org/path?key=value"
    assert last_response.redirect?
    assert_equal "https://example.org/path?key=value",
      last_response.headers['Location']
  end

  def test_exclude_from_redirect
    self.app = Rack::SSL.new(default_app, :exclude => lambda { |env| true })
    get "http://example.org/"
    assert last_response.ok?
  end

  def test_hsts_header_by_default
    get "https://example.org/"
    assert_equal "max-age=31536000",
      last_response.headers['Strict-Transport-Security']
  end

  def test_hsts_header
    self.app = Rack::SSL.new(default_app, :hsts => true)
    get "https://example.org/"
    assert_equal "max-age=31536000",
      last_response.headers['Strict-Transport-Security']
  end

  def test_disable_hsts_header
    self.app = Rack::SSL.new(default_app, :hsts => false)
    get "https://example.org/"
    assert !last_response.headers['Strict-Transport-Security']
  end

  def test_hsts_expires
    self.app = Rack::SSL.new(default_app, :hsts => { :expires => 500 })
    get "https://example.org/"
    assert_equal "max-age=500",
      last_response.headers['Strict-Transport-Security']
  end

  def test_hsts_include_subdomains
    self.app = Rack::SSL.new(default_app, :hsts => { :subdomains => true })
    get "https://example.org/"
    assert_equal "max-age=31536000; includeSubDomains",
      last_response.headers['Strict-Transport-Security']
  end

  def test_flag_cookies_as_secure
    get "https://example.org/"
    assert_equal ["id=1; path=/; secure", "token=abc; path=/; secure; HttpOnly"],
      last_response.headers['Set-Cookie']
  end

  def test_no_cookies
    self.app = Rack::SSL.new(lambda { |env|
      [200, {'Content-Type' => "text/html"}, ["OK"]]
    })
    get "https://example.org/"
    assert !last_response.headers['Set-Cookie']
  end

  def test_redirect_to_secure_subdomain
    self.app = Rack::SSL.new(default_app, :subdomain => "ssl")
    get "http://example.org/path?key=value"
    assert_equal "https://ssl.example.org/path?key=value",
      last_response.headers['Location']
  end

  def test_redirect_exclude_redirects_https_to_http
    self.app = Rack::SSL.new(default_app, :exclude => lambda { |env| true }, :redirect_exclude => true)
    get "https://example.org/"
    assert_equal "http://example.org/", last_response.headers['Location']
  end

  def test_redirect_exclude_does_not_redirect_http
    self.app = Rack::SSL.new(default_app, :exclude => lambda { |env| true }, :redirect_exclude => true)
    get "http://example.org/"
    assert last_response.ok?
  end

  def test_redirect_exclude_redirects_without_subdomain
    self.app = Rack::SSL.new(default_app,
                             :exclude => lambda { |env| true },
                             :subdomain => "ssl",
                             :redirect_exclude => true)
    get "https://ssl.example.org/"
    assert_equal "http://example.org/", last_response.headers['Location']
  end
end
