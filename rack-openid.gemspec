Gem::Specification.new do |s|
  s.name     = 'rack-openid'
  s.version  = '1.0.0'
  s.date     = '2010-02-18'
  s.summary  = 'Provides a more HTTPish API around the ruby-openid library'
  s.description = <<-EOS
    Rack::OpenID provides a more HTTPish API around the ruby-openid library.
  EOS

  s.add_dependency 'rack', '>= 0.4'
  s.add_dependency 'ruby-openid', '>=2.1.6'

  s.files = ['lib/rack/openid.rb']

  s.extra_rdoc_files = %w[README.rdoc LICENSE]

  s.author   = 'Joshua Peek'
  s.email    = 'josh@joshpeek.com'
  s.homepage = 'http://github.com/josh/rack-openid'
end
