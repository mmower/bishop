require 'rubygems'
require 'bundler'
require 'minitest'
require 'minitest/autorun'
Bundler.require(:default, :test)

require_relative '../lib/bayes/bishop'

class TestYaml < Minitest::Test
  parallelize_me!

  LINCOLN1 = "Four score and seven years ago our fathers brought forth on this continent,"+
    " a new nation, conceived in Liberty, and dedicated to the proposition that all"+
    " men are created equal."

    
  ROMEO = "Two households, both alike in dignity, "+
        "In fair Verona, where we lay our scene, "+
        "From ancient grudge break to new mutiny, "
        
  def test_yaml
    b1 = Bishop::Bayes.new
    b1.add_stop_words(ROMEO.split(/[^\w]+/))
    b1.train('lincoln',LINCOLN1)
    b1.save_yaml
    
    b2 = Bishop::Bayes.new
    b2.load_yaml
    
    assert_equal b1.stop_words, b2.stop_words
    
    b1_pool = b1.pool('lincoln')
    b2_pool = b2.pool('lincoln')
    assert_equal b1_pool.train_count, b2_pool.train_count
    assert_equal b1_pool.token_count, b2_pool.token_count
    assert_equal b1_pool.data, b2_pool.data
  end


end