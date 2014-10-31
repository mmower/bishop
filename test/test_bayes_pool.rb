require 'rubygems'
require 'bundler'
require 'minitest'
require 'minitest/autorun'
Bundler.require(:default, :test)

require_relative '../lib/bayes/bishop'

class TestBayesPool < Minitest::Test
  #parallelize_me!

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
  
end