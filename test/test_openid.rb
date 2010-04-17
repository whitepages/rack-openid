require 'test/unit'
require 'net/http'

require 'rack'
require 'rack/openid'

log = Logger.new(STDOUT)
log.level = Logger::WARN
OpenID::Util.logger = log

class MockFetcher
  def initialize(app)
    @app = app
  end

  def fetch(url, body = nil, headers = nil, limit = nil)
    opts = (headers || {}).dup
    opts[:input]  = body
    opts[:method] = "POST" if body
    env = Rack::MockRequest.env_for(url, opts)

    status, headers, body = @app.call(env)

    buf = []
    buf << "HTTP/1.1 #{status} #{Rack::Utils::HTTP_STATUS_CODES[status]}"
    headers.each { |header, value| buf << "#{header}: #{value}" }
    buf << ""
    body.each { |part| buf << part }

    io = Net::BufferedIO.new(StringIO.new(buf.join("\n")))
    res = Net::HTTPResponse.read_new(io)
    res.reading_body(io, true) {}
    OpenID::HTTPResponse._from_net_response(res, url)
  end
end


class TestHeader < Test::Unit::TestCase
  def test_build_header
    assert_equal 'OpenID identity="http://example.com/"',
      Rack::OpenID.build_header(:identity => "http://example.com/")
    assert_equal 'OpenID identity="http://example.com/?foo=bar"',
      Rack::OpenID.build_header(:identity => "http://example.com/?foo=bar")

    header = Rack::OpenID.build_header(:identity => "http://example.com/", :return_to => "http://example.org/")
    assert_match(/OpenID /, header)
    assert_match(/identity="http:\/\/example\.com\/"/, header)
    assert_match(/return_to="http:\/\/example\.org\/"/, header)

    header = Rack::OpenID.build_header(:identity => "http://example.com/", :required => ["nickname", "email"])
    assert_match(/OpenID /, header)
    assert_match(/identity="http:\/\/example\.com\/"/, header)
    assert_match(/required="nickname,email"/, header)
  end

  def test_parse_header
    assert_equal({"identity" => "http://example.com/"},
      Rack::OpenID.parse_header('OpenID identity="http://example.com/"'))
    assert_equal({"identity" => "http://example.com/?foo=bar"},
      Rack::OpenID.parse_header('OpenID identity="http://example.com/?foo=bar"'))
    assert_equal({"identity" => "http://example.com/", "return_to" => "http://example.org/"},
      Rack::OpenID.parse_header('OpenID identity="http://example.com/", return_to="http://example.org/"'))
    assert_equal({"identity" => "http://example.com/", "required" => ["nickname", "email"]},
      Rack::OpenID.parse_header('OpenID identity="http://example.com/", required="nickname,email"'))

    # ensure we don't break standard HTTP basic auth
    assert_equal({},
      Rack::OpenID.parse_header('Realm="Example"'))
  end
end

class TestOpenID < Test::Unit::TestCase
  RotsServerUrl = 'http://localhost:9292'

  RotsApp = Rack::Builder.new do
    require 'rots'

    config = {
      'identity' => 'john.doe',
      'sreg' => {
        'nickname' => 'jdoe',
        'fullname' => 'John Doe',
        'email' => 'jhon@doe.com',
        'dob' => Date.parse('1985-09-21'),
        'gender' => 'M'
      }
    }

    map("/%s" % config['identity']) do
      run Rots::IdentityPageApp.new(config, {})
    end

    map '/server' do
      run Rots::ServerApp.new(config, :storage => Dir.tmpdir)
    end
  end

  OpenID.fetcher = MockFetcher.new(RotsApp)

  def test_with_get
    @app = app
    process('/', :method => 'GET')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_deprecated_identity
    @app = app
    process('/', :method => 'GET', :identity => "#{RotsServerUrl}/john.doe?openid.success=true")
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_post_method
    @app = app
    process('/', :method => 'POST')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'POST', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_custom_return_to
    @app = app(:return_to => 'http://example.org/complete')
    process('/', :method => 'GET')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/complete', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_post_method_custom_return_to
    @app = app(:return_to => 'http://example.org/complete')
    process('/', :method => 'POST')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/complete', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_custom_return_method
    @app = app(:method => 'put')
    process('/', :method => 'GET')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'PUT', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_simple_registration_fields
    @app = app(:required => ['nickname', 'email'], :optional => 'fullname')
    process('/', :method => 'GET')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_attribute_exchange
    @app = app(
      :required => ['http://axschema.org/namePerson/friendly', 'http://axschema.org/contact/email'],
      :optional => 'http://axschema.org/namePerson')
    process('/', :method => 'GET')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'success', @response.body
  end

  def test_with_missing_id
    @app = app(:identifier => "#{RotsServerUrl}/john.doe")
    process('/', :method => 'GET')
    follow_redirect!
    assert_equal 400, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'cancel', @response.body
  end

  def test_with_timeout
    @app = app(:identifier => RotsServerUrl)
    process('/', :method => "GET")
    assert_equal 400, @response.status
    assert_equal 'GET', @response.headers['X-Method']
    assert_equal '/', @response.headers['X-Path']
    assert_equal 'missing', @response.body
  end

  def test_sanitize_query_string
    @app = app
    process('/', :method => 'GET')
    follow_redirect!
    assert_equal 200, @response.status
    assert_equal '/', @response.headers['X-Path']
    assert_equal '', @response.headers['X-Query-String']
  end

  def test_passthrough_standard_http_basic_auth
    @app = app
    process('/', :method => 'GET', "MOCK_HTTP_BASIC_AUTH" => '1')
    assert_equal 401, @response.status
  end

  private
    def app(options = {})
      options[:identifier] ||= "#{RotsServerUrl}/john.doe?openid.success=true"

      app = lambda { |env|
        if resp = env[Rack::OpenID::RESPONSE]
          headers = {
            'X-Path' => env['PATH_INFO'],
            'X-Method' => env['REQUEST_METHOD'],
            'X-Query-String' => env['QUERY_STRING']
          }
          if resp.status == :success
            [200, headers, [resp.status.to_s]]
          else
            [400, headers, [resp.status.to_s]]
          end
        elsif env["MOCK_HTTP_BASIC_AUTH"]
          [401, {Rack::OpenID::AUTHENTICATE_HEADER => 'Realm="Example"'}, []]
        else
          [401, {Rack::OpenID::AUTHENTICATE_HEADER => Rack::OpenID.build_header(options)}, []]
        end
      }
      Rack::Session::Pool.new(Rack::OpenID.new(app))
    end

    def process(*args)
      env = Rack::MockRequest.env_for(*args)
      @response = Rack::MockResponse.new(*@app.call(env))
    end

    def follow_redirect!
      assert @response
      assert_equal 303, @response.status

      env = Rack::MockRequest.env_for(@response.headers['Location'])
      status, headers, body = RotsApp.call(env)

      uri = URI(headers['Location'])
      process("#{uri.path}?#{uri.query}")
    end
end
