require 'rubygems'
require 'bundler'
require 'minitest'
require 'minitest/autorun'
Bundler.require(:default, :test)

require_relative '../lib/bayes/bishop'

class TestBayes < Minitest::Test
  parallelize_me!

  LINCOLN1 = "Four score and seven years ago our fathers brought forth on this continent,"+
    " a new nation, conceived in Liberty, and dedicated to the proposition that all"+
    " men are created equal."
  LINCOLN2 ="Now we are engaged in a great civil war, testing whether that nation, "+
    "or any nation so conceived and so dedicated, can long endure. We are met on"+
    " a great battle-field of that war. We have come to dedicate a portion of that"+
    " field, as a final resting place for those who here gave their lives that that"+
    " nation might live. It is altogether fitting and proper that we should do this."
  LINCOLN3 = "But, in a larger sense, we can not dedicate -- we can not consecrate -- we can not hallow --"+
  " this ground. "
  LINCOLN4 = "The brave men, living and dead, who struggled here, have consecrated it, far above our poor power to add or detract. "
  
  JABBER1 = "Beware the Jabberwock, my son!"+
    " The jaws that bite, the claws that catch!"+
    " Beware the Jubjub bird, and shun The frumious Bandersnatch!"
  JABBER2 = "He took his vorpal sword in hand:"+
    " Long time the manxome foe he sought -- " +
    " So rested he by the Tumtum tree, " +
    " And stood awhile in thought. "
  JABBER3 = "And, as in uffish thought he stood, " +
    " The Jabberwock, with eyes of flame, " +
    " Came whiffling through the tulgey wood, " +
    " And burbled as it came!"  
  JABBER4 = "One, two! One, two! And through and through" +
    " The vorpal blade went snicker-snack! " +
    " He left it dead, and with its head " +
    " He went galumphing back." 
    
  ROMEO = "Two households, both alike in dignity, "+
        "In fair Verona, where we lay our scene, "+
        "From ancient grudge break to new mutiny, "
        
  def test_bayes_initializer
    b = Bishop::Bayes.new
    assert_instance_of Bishop::SimpleTokenizer, b.tokenizer
    refute_nil b.combiner
    assert_equal 0, b.pool_names.length
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
  
  def test_duplicate_stop_words
    b = Bishop::Bayes.new
    sw = %w{ Alpha bEta gammA delta epsilon alpha betA omega }
    sw2 = sw.map { |s| s.downcase }.uniq.sort
    assert_equal 0, b.stop_words.length
    b.add_stop_words( sw )
    assert_equal sw2.length, b.stop_words.length
    assert_equal sw2, b.stop_words.sort
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
    refute_nil b.pool('testing')
    assert_equal b.pool('testing'),p

    b.remove_pool('testing')
    assert_nil b.pool('testing')
  end
  
  def test_rename_pool
    b = Bishop::Bayes.new
    p = b.new_pool('testing')
    refute_nil b.pool('testing')
    b.rename_pool('testing','gnitset')
    assert_nil b.pool('testing')
    refute_nil b.pool('gnitset')
  end
  
  def test_pool_names
    b = Bishop::Bayes.new
    names1 = %w{ gamma alpha beta}
    names1.each { |n| b.new_pool(n) }
    assert_equal names1.sort, b.pool_names
  end
  
  def test_train_simple
    b = Bishop::Bayes.new
            
    b.load_default_stop_words
    
    b.train('lincoln', LINCOLN1)
    b.train('lincoln', LINCOLN2)
    b.train('lincoln', LINCOLN3)
    
    b.train('jabber', JABBER1)
    b.train('jabber', JABBER2)
    b.train('jabber', JABBER3)
    
    guess_lincoln = b.guess(LINCOLN4)
    
    assert_kind_of Hash, guess_lincoln
    
    guess_jabber = b.guess(JABBER4)
    
    guess_romeo = b.guess(ROMEO)
    
    assert guess_lincoln.has_key?('lincoln')
    assert guess_jabber.has_key?('jabber')
    refute guess_romeo.has_key?('lincoln')
    refute guess_romeo.has_key?('jabber')

    assert guess_lincoln['lincoln'] > 0.9
    assert guess_jabber['jabber'] > 0.9
  end
  
  def test_train_array
    b = Bishop::Bayes.new
    t = Bishop::SimpleTokenizer.new
  
    b.train('a', t.tokenize(LINCOLN1))
    b.train('a', t.tokenize(LINCOLN2))
    b.train('a', t.tokenize(LINCOLN3))

    b.train('b', LINCOLN1)
    b.train('b', LINCOLN2)
    b.train('b', LINCOLN3)
  
    assert_equal b.pool('a').data, b.pool('b').data
  end
 
  def test_pool_merge
    b = Bishop::Bayes.new
            
    b.load_default_stop_words
    
    b.train('lincoln', LINCOLN1)
    b.train('lincoln', LINCOLN2)
    b.train('lincoln', LINCOLN3)
    
    b.train('jabber', JABBER1)
    b.train('jabber', JABBER2)
    b.train('jabber', JABBER3)
    
    guess = b.guess(LINCOLN4)

    assert guess.has_key?('lincoln')
    refute guess.has_key?('jabber')

    b.merge_pools('jabber','lincoln')
    
    guess = b.guess(LINCOLN4)

    assert guess.has_key?('jabber')
    assert guess.has_key?('lincoln')

    
  end
 
  def test_to_json
    b = Bishop::Bayes.new

            
    b.load_default_stop_words
    
    b.train('lincoln', LINCOLN1)
    b.train('lincoln', LINCOLN2)
    b.train('lincoln', LINCOLN3)
    
    b.train('jabber', JABBER1)
    b.train('jabber', JABBER2)
    b.train('jabber', JABBER3)
    
    b.train('romeo',ROMEO)
    
    j = JSON.parse(b.to_json)
    
    assert j.has_key?('stop_words')
    assert j.has_key?('pools')
    train_counts = { 'lincoln' => 3, 'jabber' => 3, 'romeo' => 1}
    ['lincoln','jabber','romeo'].each do |p|
      assert j['pools'].has_key?(p)
      assert train_counts[p], j['pools'][p]['train_count']
      assert_equal j['pools'][p]['token_count'],j['pools'][p]['data'].inject(0) { |sum,n| sum + n[1] }
    end
  end
  
  
end