require 'rubygems'
require 'bundler'
require 'minitest'
require 'minitest/autorun'
Bundler.require(:default, :test)

require_relative '../lib/bayes/bishop'

class TestTokenizers < Minitest::Test
  #parallelize_me!

  def test_simple_tokenizer
    tokenizer = Bishop::SimpleTokenizer.new
    s1 = '  this " :-) ;.; % $ &*# is a hyPhen-Test to see - what happens --  '
    r1 = ["this", "is", "a", "hyphen-test", "to", "see", "what", "happens"] 
    assert_equal r1, tokenizer.tokenize(s1)
  end
  
  def test_simple_tokenizer_stop_words
    tokenizer = Bishop::SimpleTokenizer.new
    s1 = '  alpha beta delta gamma omega phi psi tau  '
    r1 = %w( alpha beta gamma omega psi tau )
    assert_equal r1, tokenizer.tokenize(s1,%w(delta phi))
  end
  
  def test_stemming_tokenizer
    tokenizer = Bishop::StemmingTokenizer.new
    s1 = '  thankfulness liveliness socializer socialism  '
    r1 = %w( thank liveli social social )
    tokens = tokenizer.tokenize(s1)
    assert_equal r1, tokens
  end
end