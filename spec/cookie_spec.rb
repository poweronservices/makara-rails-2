require 'spec_helper'
require 'rack'
require 'time'

describe Makara::Cookie do
  let(:now) { Time.parse('2018-02-11 11:10:40 +0000') }
  let(:cookie_key) { Makara::Cookie::IDENTIFIER }

  before do
    Timecop.freeze(now)
  end

  after do
    Timecop.return
  end

  describe 'fetch' do
    let(:cookie_string) { "mysql:#{now.to_f + 5}|redis:#{now.to_f + 5}" }
    let(:request) { Rack::Request.new('HTTP_COOKIE' => "#{cookie_key}=#{cookie_string}") }

    it 'parses stickiness context from cookie string' do
      context_data = Makara::Cookie.fetch(request)

      expect(context_data['mysql']).to eq(now.to_f + 5)
      expect(context_data['redis']).to eq(now.to_f + 5)
      expect(context_data.key?('mariadb')).to be_falsey
    end

    it 'returns empty context data when there is no cookie' do
      context_data = Makara::Cookie.fetch(Rack::Request.new('HTTP_COOKIE' => "another_cookie=1"))

      expect(context_data).to eq({})
    end

    it 'returns empty context data when the cookie contents are invalid' do
      context_data = Makara::Cookie.fetch(Rack::Request.new('HTTP_COOKIE' => "#{cookie_key}=1"))

      expect(context_data).to eq({})
    end
  end

  describe 'store' do
    let(:headers) { {} }
    let(:context_data) { { "mysql" => now.to_f + 5, "redis" => now.to_f + 5 } }

    # rack gem changed the date format for expires
    # https://github.com/rack/rack/commit/a060429848db47bf75dbb102d9059787c96de8bf#diff-85960cbd609e7f51a9881d1876b82d748f4ba8312a31e3329a5bb9bf791c60be
    if Rack.release < '3'
      def httpdate(time)
        wday = Time::RFC2822_DAY_NAME[time.wday]
        mon = Time::RFC2822_MONTH_NAME[time.mon - 1]
        time.strftime("#{wday}, %d-#{mon}-%Y %H:%M:%S GMT")
      end
    else
      def httpdate(time)
        time.httpdate
      end
    end

    it 'does not set a cookie if there is no next context' do
      Makara::Cookie.store(nil, headers)

      expect(headers).to eq({})
    end

    it 'sets the context cookie with updated stickiness and enough expiration time' do
      Makara::Cookie.store(context_data, headers)

      expect(headers['Set-Cookie']).to include("#{cookie_key}=mysql%3A#{(now + 5).to_f}%7Credis%3A#{(now + 5).to_f};")
      expect(headers['Set-Cookie']).to include("path=/; expires=#{httpdate(Time.now + 10)}")
    end

    it 'expires the cookie if the next context is empty' do
      Makara::Cookie.store({}, headers)

      expect(headers['Set-Cookie']).to eq("#{cookie_key}=; path=/; expires=#{httpdate(Time.now)}")
    end

    it 'allows custom cookie options to be provided' do
      Makara::Cookie.store(context_data, headers, { secure: true })

      expect(headers['Set-Cookie']).to include("#{cookie_key}=mysql%3A#{(now + 5).to_f}%7Credis%3A#{(now + 5).to_f};")
      expect(headers['Set-Cookie']).to include("path=/; expires=#{httpdate(Time.now + 10)}; secure")
    end
  end
end
