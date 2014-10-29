require 'rubygems'
require 'bundler'
require 'minitest'
require 'minitest/autorun'
Bundler.require(:default, :test)

require_relative '../lib/bayes/bishop'

class TestBayesData < Minitest::Test
  parallelize_me!

  def test_creation_simple
    bd = Bishop::BayesData.new
    refute_nil bd
    assert bd.name.empty?
    assert_equal 0, bd.training.length
    assert_nil bd.pool
    refute_nil bd.data
    assert_equal 0, bd.token_count
    assert_equal 0, bd.train_count
    refute bd.trained_on?('test')
    assert_equal "<BayesDict: noname, 0 tokens>", bd.to_s
  end
  
  def test_creation_with_name
    bd = Bishop::BayesData.new('george')
    assert_equal 'george', bd.name
    assert_equal "<BayesDict: george, 0 tokens>", bd.to_s
  end
end