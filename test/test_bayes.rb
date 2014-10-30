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
    #assert_instance_of Bishop::BayesPool, b.data_class
    refute_nil b.combiner
    assert_equal 1, b.pools.length
    refute_nil b.corpus
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
  
  def test_load_stop_words
    skip
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
  
  def test_pool_names
    b = Bishop::Bayes.new
    names1 = %w{ gamma alpha beta}
    names1.each { |n| b.new_pool(n) }
    assert_equal names1.sort, b.pool_names
  end
  
  def test_merge_pools
    skip
  end
  
  def test_save_state
    skip
  end

  def test_train_simple
    b = Bishop::Bayes.new
    l1 = "Four score and seven years ago our fathers brought forth on this continent,"+
      " a new nation, conceived in Liberty, and dedicated to the proposition that all"+
      " men are created equal."
    l2 ="Now we are engaged in a great civil war, testing whether that nation, "+
      "or any nation so conceived and so dedicated, can long endure. We are met on"+
      " a great battle-field of that war. We have come to dedicate a portion of that"+
      " field, as a final resting place for those who here gave their lives that that"+
      " nation might live. It is altogether fitting and proper that we should do this."
    l3 = "But, in a larger sense, we can not dedicate -- we can not consecrate -- we can not hallow --"+
    " this ground. "
    l4 = "The brave men, living and dead, who struggled here, have consecrated it, far above our poor power to add or detract. "
    
    j1 = "Beware the Jabberwock, my son!"+
      " The jaws that bite, the claws that catch!"+
      " Beware the Jubjub bird, and shun The frumious Bandersnatch!"
    j2 = "He took his vorpal sword in hand:"+
      " Long time the manxome foe he sought -- " +
      " So rested he by the Tumtum tree, " +
      " And stood awhile in thought. "
    j3 = "And, as in uffish thought he stood, " +
      " The Jabberwock, with eyes of flame, " +
      " Came whiffling through the tulgey wood, " +
      " And burbled as it came!"  
    j4 = "One, two! One, two! And through and through" +
      " The vorpal blade went snicker-snack! " +
      " He left it dead, and with its head " +
      " He went galumphing back." 
      
    r = "Two households, both alike in dignity, "+
          "In fair Verona, where we lay our scene, "+
          "From ancient grudge break to new mutiny, "
            
    b.load_default_stop_words
    
    b.train('lincoln', l1)
    b.train('lincoln', l2)
    b.train('lincoln', l3)
    
    b.train('jabber', j1)
    b.train('jabber', j2)
    b.train('jabber', j3)
    
    guess_lincoln = b.guess(l4)
    
    guess_jabber = b.guess(j4)
    
    guess_romeo = b.guess(r)
    
    assert guess_lincoln.has_key?('lincoln')
    assert guess_jabber.has_key?('jabber')
    refute guess_romeo.has_key?('lincoln')
    refute guess_romeo.has_key?('jabber')

    assert guess_lincoln['lincoln'] > 0.9
    assert guess_jabber['jabber'] > 0.9
    
    #STDOUT.puts "\nlincoln: #{b.pool_data('lincoln').join(',')}"
    #STDOUT.puts "\njabber: #{b.pool_data('jabber').join(',')}"
    b.train('romeo',r)
    #STDOUT.puts "\nromeo: #{b.pool_data('romeo').join(',')}"
    g1 = b.guess('vorpal')
    g2 = b.guess('consecrate')
    
    #g1.each { |k,v| STDOUT.puts "\nmerge1: #{k}: #{v}" }
    #g2.each { |k,v| STDOUT.puts "\nmerge2: #{k}: #{v}" }
    refute g1.has_key?('romeo')
    refute g2.has_key?('romeo')
    
    b.merge_pools('romeo','jabber')
    #STDOUT.puts "\nromeo: #{b.pool_data('romeo').join(',')}"
    
    g3 = b.guess('vorpal')
    #g3.each { |k,v| STDOUT.puts "\nmerge3: #{k}: #{v}" }
    assert g3.has_key?('jabber')
    assert g3.has_key?('romeo')
    refute g3.has_key?('lincoln')

    b.merge_pools('romeo','lincoln')
    #STDOUT.puts "\nromeo: #{b.pool_data('romeo').join(',')}"
    
    g4 = b.guess('consecrate')
    #g4.each { |k,v| STDOUT.puts "\nmerge4: #{k}: #{v}" }
    refute g4.has_key?('jabber')
    assert g4.has_key?('romeo')
    assert g4.has_key?('lincoln')
    
  end
  
  def test_to_json
    b = Bishop::Bayes.new
    l1 = "Four score and seven years ago our fathers brought forth on this continent,"+
      " a new nation, conceived in Liberty, and dedicated to the proposition that all"+
      " men are created equal."
    l2 ="Now we are engaged in a great civil war, testing whether that nation, "+
      "or any nation so conceived and so dedicated, can long endure. We are met on"+
      " a great battle-field of that war. We have come to dedicate a portion of that"+
      " field, as a final resting place for those who here gave their lives that that"+
      " nation might live. It is altogether fitting and proper that we should do this."
    l3 = "But, in a larger sense, we can not dedicate -- we can not consecrate -- we can not hallow --"+
    " this ground. "
    l4 = "The brave men, living and dead, who struggled here, have consecrated it, far above our poor power to add or detract. "
    
    j1 = "Beware the Jabberwock, my son!"+
      " The jaws that bite, the claws that catch!"+
      " Beware the Jubjub bird, and shun The frumious Bandersnatch!"
    j2 = "He took his vorpal sword in hand:"+
      " Long time the manxome foe he sought -- " +
      " So rested he by the Tumtum tree, " +
      " And stood awhile in thought. "
    j3 = "And, as in uffish thought he stood, " +
      " The Jabberwock, with eyes of flame, " +
      " Came whiffling through the tulgey wood, " +
      " And burbled as it came!"  
    j4 = "One, two! One, two! And through and through" +
      " The vorpal blade went snicker-snack! " +
      " He left it dead, and with its head " +
      " He went galumphing back." 
      
    r = "Two households, both alike in dignity, "+
          "In fair Verona, where we lay our scene, "+
          "From ancient grudge break to new mutiny, "
            
    b.load_default_stop_words
    
    b.train('lincoln', l1)
    b.train('lincoln', l2)
    b.train('lincoln', l3)
    
    b.train('jabber', j1)
    b.train('jabber', j2)
    b.train('jabber', j3)
    
    b.train('romeo',r)
    
    j = JSON.parse(b.to_json)
    
    assert j.has_key?('tokenizer')
    assert j.has_key?('stop_words')
    assert j.has_key?('pools')
    train_counts = { '__Corpus__' => 7, 'lincoln' => 3, 'jabber' => 3, 'romeo' => 1}
    ['__Corpus__','lincoln','jabber','romeo'].each do |p|
      assert j['pools'].has_key?(p)
      assert train_counts[p], j['pools'][p]['train_count']
      assert_equal j['pools'][p]['token_count'],j['pools'][p]['data'].inject(0) { |sum,n| sum + n[1] }
    end
  end
  
  
end