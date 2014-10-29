require 'rubygems'
require 'bundler'
require 'minitest'
require 'minitest/autorun'
Bundler.require(:default, :test)

require_relative '../lib/bayes/bishop'

class TestBayes < Minitest::Test
  parallelize_me!

  def test_bayes_initializer
    b = Bishop::Bayes.new
    assert_instance_of Bishop::SimpleTokenizer, b.tokenizer
    #assert_instance_of Bishop::BayesData, b.data_class
    refute_nil b.combiner
    assert_equal 1, b.pools.length
    refute_nil b.corpus
    assert_equal 0, b.train_count
    assert b.dirty
    assert b.dirty?
    assert_equal 0, b.stop_words.length
  end

  def test_add_stop_words
    b = Bishop::Bayes.new
    sw = %w{ Alpha bEta gammA }
    assert_equal 0, b.stop_words.length
    b.add_stop_words( sw )
    assert_equal 3, b.stop_words.length
    assert_equal sw.map {|s| s.downcase }, b.stop_words
  end  
  
  def test_default_stop_words
    b = Bishop::Bayes.new
    assert_equal 0, b.stop_words.length
    b.load_default_stop_words
    refute_equal 0, b.stop_words.length
  end
  
  def test_new_pool
    b = Bishop::Bayes.new
    p = b.new_pool('testing')
    assert b.dirty?
    assert b.pools.has_key?('testing')
    assert_equal b.pools['testing'],p

    b.remove_pool('testing')
    refute b.pools.has_key?('testing')
  end
  
  def test_rename_pool
    b = Bishop::Bayes.new
    p = b.new_pool('testing')
    assert b.pools.has_key?('testing')
    b.rename_pool('testing','gnitset')
    refute b.pools.has_key?('testing')
    assert b.pools.has_key?('gnitset')
  end
end