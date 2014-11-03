require 'rubygems'
require 'bundler'
require 'minitest'
require 'minitest/autorun'
Bundler.require(:default, :test)

require_relative '../lib/bayes/bishop'

class TestBayesPool < Minitest::Test
  parallelize_me!

  LINCOLN1 = "Four score and seven years ago our fathers brought forth on this continent,"+
    " a new nation, conceived in Liberty, and dedicated to the proposition that all"+
    " men are created equal."
    
  def test_creation_simple
    bp = Bishop::BayesPool.new
    refute_nil bp
    refute_nil bp.data
    assert_equal 0, bp.token_count
    assert_equal 0, bp.train_count
    assert_equal "<BayesPool: 0 tokens>", bp.to_s
  end
  
  def test_merge
    bp = Bishop::BayesPool.new
  end
  
  def test_indexing
    b = Bishop::Bayes.new
            
    b.train('lincoln', LINCOLN1)

    pool = b.pool('lincoln')
    
    pool.tokens.each do |token|
      assert_equal pool.data[token], pool[token]
    end
  end
  
  def test_index_set
    b = Bishop::Bayes.new
            
    pool = b.new_pool('simple')

    (1..10).each { |i| pool["token#{i}"] = i}

    (1..10).each do |i|
      assert_equal i, pool["token#{i}"]
    end
  end
  
  def test_enumerable
    b = Bishop::Bayes.new
            
    b.train('lincoln', LINCOLN1)
    
    pool = b.pool('lincoln')
    
    pool.each do |k,v|
      assert_equal pool.data[k],v
      assert_equal pool[k],v
    end
  end
  
  
end