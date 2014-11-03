require 'rubygems'

SPEC = Gem::Specification.new do |s|
	s.name			=		"bishop"
	s.version		=		"0.5.0"
	s.author		=		"Richard Harrington"
	s.email			=		"richard@maymount.com"
  s.license  = 'LGPL'
	s.homepage		=		"https://github.com/maymount/bishop"
	s.platform		=		Gem::Platform::RUBY
	s.summary		=		"Bayesian classification library. Refactoring of mmowers/bishop version."
	s.description		=		"Bayesian classification library. Refactoring of mmowers/bishop version."
	s.add_runtime_dependency 'stemmer'
	candidates		=		Dir.glob( "{docs,lib,test}/**/*" )
	
	s.files 		=		candidates.delete_if do |item|
								item.include?( "CVS" ) || item.include?( "rdoc" )
							end
  s.extra_rdoc_files = ['README.md','CHANGELOG.md','COPYING','COPYING.LESSER']
	s.require_path	=		"lib"
	s.has_rdoc		=		true
end