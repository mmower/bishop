require 'rubygems'

SPEC = Gem::Specification.new do |s|
	s.name			=		"bishop"
	s.version		=		"0.5.0"
	s.author		=		"Matt Mower"
	s.email			=		"self@mattmower.com"
	s.homepage		=		"https://github.com/maymount/bishop"
	s.platform		=		Gem::Platform::RUBY
	s.summary		=		"Bayesian classification and ART-2 clustering library."
	
	candidates		=		Dir.glob( "{bin,docs,lib,test}/**/*" )
	
	s.files 		=		candidates.delete_if do |item|
								item.include?( "CVS" ) || item.include?( "rdoc" )
							end
	s.require_path	=		"lib"
# 	s.autorequire	=		"bishop"
	s.has_rdoc		=		true
	
	#s.add_dependency( "stemmer", ">= 1.0.1" )
end