require 'rake/testtask'
require 'rdoc/task'

#desc "Default task: test"
task :default => [:test]

desc "Run Tests"
Rake::TestTask.new( :test ) do |t|
  t.pattern = "test/test_*.rb"
  t.verbose = true
end

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.main = 'README.md'
  rdoc.rdoc_files.include 'README.md', 'CHANGELOG.md', "lib/**/*\.rb" 
  rdoc.rdoc_dir = 'docs/rdoc'
  rdoc.title = "Bayes::Bishop Documentation"
  rdoc.options << '--line-numbers'
  rdoc.options << '--fileboxes'
end

RDoc::Task.new(:rdoc => "rdoc_markdown",:clobber_rdoc => "clobber_rdoc_markdown", :rerdoc => "rerdoc_markdown") do |rdoc|
  rdoc.main = 'README.md'
  rdoc.rdoc_files.include 'README.md', 'CHANGELOG.md', "lib/**/*\.rb" 
  rdoc.rdoc_dir = 'docs/md'
  rdoc.title = "Bayes::Bishop Documentation"
  rdoc.markup = 'MARKUP' 
  rdoc.options << '--line-numbers'
  rdoc.options << '--fileboxes'
end