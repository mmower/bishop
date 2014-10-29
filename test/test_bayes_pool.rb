require 'rubygems'
require 'bundler'
require 'minitest'
require 'minitest/autorun'
Bundler.require(:default, :test)

require_relative '../lib/bayes/bishop'

class TestBayesPool < Minitest::Test
  parallelize_me!

  def test_creation_simple
    bp = Bishop::BayesPool.new
    refute_nil bp
    assert bp.name.empty?
    assert_equal 0, bp.training.length
    refute_nil bp.data
    assert_equal 0, bp.token_count
    assert_equal 0, bp.train_count
    refute bp.trained_on?('test')
    assert_equal "<BayesDict: noname, 0 tokens>", bp.to_s
  end
  
  def test_creation_with_name
    bp = Bishop::BayesPool.new('george')
    assert_equal 'george', bp.name
    assert_equal "<BayesDict: george, 0 tokens>", bp.to_s
  end
end