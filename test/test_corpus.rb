require 'rubygems'
require 'bundler'
require 'minitest'
require 'minitest/autorun'
Bundler.require(:default, :test)

require_relative '../lib/bayes/bishop'

class TestCorpus < Minitest::Test
  #parallelize_me!

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

  def test_corpus
    b = Bishop::Bayes.new
            
    b.load_default_stop_words
    
    b.train('lincoln', LINCOLN1)
    b.train('lincoln', LINCOLN2)
    b.train('lincoln', LINCOLN3)
    b.train('lincoln', ROMEO)
    
    b.train('jabber', JABBER1)
    b.train('jabber', JABBER2)
    b.train('jabber', JABBER3)
    b.train('jabber', ROMEO)
    
    corpus = b.corpus
    lincoln = b.pools['lincoln']
    jabber = b.pools['jabber']
    corpus.data.each do |token,count|
      assert_equal count, lincoln.data[token]+jabber.data[token], "Token #{token} doesn't match"
    end
  end
end