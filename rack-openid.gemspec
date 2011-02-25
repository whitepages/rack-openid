Gem::Specification.new do |s|
  s.name      = "rack-openid"
  s.version   = "1.3.1"
  s.date      = "2011-02-25"

  s.homepage    = "http://github.com/josh/rack-openid"
  s.summary     = "Provides a more HTTPish API around the ruby-openid library"
  s.description = <<-EOS
    Provides a more HTTPish API around the ruby-openid library
  EOS

  s.files = [
    "lib/rack/openid.rb",
    "lib/rack/openid/simple_auth.rb",
    "LICENSE",
    "README.rdoc"
  ]

  s.add_dependency "rack", ">=1.1.0"
  s.add_dependency "ruby-openid", ">= 2.1.8"

  s.author = "Joshua Peek"
  s.email  = "josh@joshpeek.com"
end
