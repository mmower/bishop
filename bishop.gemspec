require 'rubygems'

SPEC = Gem::Specification.new do |s|
	s.name			=		"bishop"
	s.version		=		"0.5.0"
	s.author		=		"Richard Harrington"
	s.email			=		"richard@maymount.com"
	s.homepage		=		"https://github.com/maymount/bishop"
	s.platform		=		Gem::Platform::RUBY
	s.summary		=		"Bayesian classification and ART-2 clustering library. Refactoring of mmowers/bishop version."
	
	candidates		=		Dir.glob( "{bin,docs,lib,test}/**/*" )
	
	s.files 		=		candidates.delete_if do |item|
								item.include?( "CVS" ) || item.include?( "rdoc" )
							end
	s.require_path	=		"lib"
	s.has_rdoc		=		true
end