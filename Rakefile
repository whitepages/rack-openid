begin
  require 'mg'
  MG.new('rack-openid.gemspec')
rescue LoadError
end


require 'rake/testtask'

task :default => :test

Rake::TestTask.new do |t|
  t.warning = true
end
