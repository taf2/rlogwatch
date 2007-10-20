require 'rake'
require 'rake/testtask'
require 'rake/clean'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'tools/rakehelp'
require 'fileutils'
include FileUtils

setup_tests
setup_clean ["lib/*.bundle", "*.gem", "doc/site/output", ".config"]

setup_rdoc ['README', 'LICENSE', 'COPYING', 'lib/**/*.rb', 'doc/**/*.rdoc']

desc "Compile and test"
task :default => [:test]

namespace :net do
  Rake::TestTask.new do |t|
    t.libs << "test/net"
    t.test_files = FileList['test/net/test*.rb']
    t.verbose = true
  end
end

task :package => [:clean,:compile,:test,:rerdoc]

setup_extension("logwatch", "logwatch")

name="log-watch"
version="0.0.1"

setup_gem(name, version) do |spec|
  spec.summary = "A simple log watch tool"
  spec.description = spec.summary
  spec.test_files = Dir.glob('test/test_*.rb')
  spec.author="Todd A. Fisher"
  spec.executables=['logwatch']
  spec.files += %w(COPYING LICENSE README Rakefile setup.rb)

  spec.required_ruby_version = '>= 1.8.5'

  spec.add_dependency('daemons', '>= 1.0.3')
  spec.add_dependency('fastthread', '>= 1.0.0')
  
  spec.add_dependency('gem_plugin', '>= 0.2.2')
  spec.add_dependency('cgi_multipart_eof_fix', '>= 1.0.0')
end

task :install do
  sub_project("gem_plugin", :install)
  sub_project("fastthread", :install)
  sh %{rake package}
  sh %{gem install pkg/logwatch-#{version}}
  if RUBY_PLATFORM =~ /mswin/
    sub_project("mongrel_service", :install)
  end
end

task :uninstall => [:clean] do
  sh %{gem uninstall logwatch}
  sub_project("gem_plugin", :uninstall)
  sub_project("fastthread", :uninstall)
  if RUBY_PLATFORM =~ /mswin/
    sub_project("mongrel_service", :install)
  end
end


task :gem_source do
  mkdir_p "pkg/gems"
 
  FileList["**/*.gem"].each { |gem| mv gem, "pkg/gems" }
  FileList["pkg/*.tgz"].each {|tgz| rm tgz }
  rm_rf "pkg/#{name}-#{version}"

  sh %{ index_gem_repository.rb -d pkg }
  # TODO: setup something like this
  #sh %{ scp -r ChangeLog pkg/* rubyforge.org:/var/www/gforge-projects/mongrel/releases/ }
end
