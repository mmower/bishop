# This is a Naive Bayes classifier that can be used to categorize text based on trained "pools".
# 
# == Usage
# 1. Create a Bishop::Bayes object:
#    <tt>b = Bishop::Bayes.new</tt>
# 2. Train with multiple pools of text:
#    <tt>b.train('pool1')</tt>
#    <tt>b.train('pool2')</tt>
#    <tt>b.train('pool3')</tt>
# 3. Call the guess method with a message to categorize:
#    <tt>guesses = b.guess('This is a sentence')</tt>
#    The return value is a hash where the keys are pool names and the values are the probability
#    that the message belongs to that pool.  
#
# == Features
# * Stop words may be specified
#    <tt>b.add_stop_words(an_array_words)</tt>
#    <tt>b.add_stop_word('word')</tt>
# * You can include the default stop words list    
#    <tt>b.load_default_stop_words</tt>
# * You can choose between the default tokenizer, a stemming tokenizer, or a custom tokenizer
#    <tt>b = Bishop::Bayes.new</tt>
#    <tt>b = Bishop::Bayes.new(Bishop::StemmingTokenizer)</tt>
#    <tt>b = Bishop::Bayes.new(CustomTokenizer)</tt>
#    
#    <tt></tt>
#    
# Copyright 2014, Maymount Enterprises, Ltd. <richard@maymount.com> 
#
# It is a port to the Ruby language of the Divmod project (which is Copyright 2003 Amir Bakhtiar <amir@divmod.org> 
# and based on the Ruby port, Copyright 2005 by Matt Mower <self@mattmower.com> 
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser Public License for more details.
#
# You should have received a copy of the GNU Lesser Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# 

require 'yaml'
require 'stemmer'
require 'json'

module Bishop

  #
  # As at v1.8 Ruby's YAML persists Hashes using special processing rather
  # than by dumping it's instance variables, hence no instance variables
  # in a Hash subclass get dumped either.
  #
  
  class BayesPool
  
    attr_accessor :token_count # sum of token counts in the pool
    attr_accessor :train_count # number of times train has been called for this pool
    attr_reader :data # hash that contains probabilities
  
    def initialize
      @data = Hash.new( 0.0 )
      @token_count = 0
      @train_count = 0
    end
    
    def to_s
      "<BayesPool: #{@token_count} tokens>"
    end
    
    def to_a
      @data.to_a
    end
  
    def tokens
      @data.keys
    end
    
    def num_tokens
      @data.length
    end
    
    def add_token token, count = 1
      if @data.has_key?(token)
        @data[token] = @data[token] + count
      else
        @data[token] = count
      end
      
      @token_count = @token_count + count
    end
    
    def merge(other_pool)
      other_pool.data.each { |token,count| add_token(token,count) }
    end
    
    def remove_token token, count = 1
      @data[token] -= count
      @data.delete(token) if @data[token] < 1
      @token_count = @token_count - count
    end
  end
  
  # A tokenizer class which splits words removing non word characters except hyphens.
  class SimpleTokenizer
    def tokenize( item, stop_words=[] )
      item.split( /\s+/ ).map do |i|
        i.split( /\-/ ).map { |token| token.downcase.gsub( /\W/, "" ) }.join( "-" )
      end.reject { |t| t == "" || t == "-" || stop_words.detect { |w| w == t } }
    end
  end
  
  # A tokenizer which, having split words, reduces them to porter stemmed tokens
  class StemmingTokenizer < SimpleTokenizer
    def tokenize( item, stop_words=[] )
      super( item, stop_words ).map { |word| word.stem }
    end
  end
  
  class Bayes
  
    attr_accessor :tokenizer # instance of Tokenizer that handles tokenization
    attr_accessor :combiner # usually anonymous block 
    attr_accessor :pools # hash, key = pool name, value = BayesPool class
    # TODO make pools private and set up setter/getter
    attr_reader :stop_words # array containing stop words

    @dirty = true # set to true for any changes, false when pool_probs is called
    @corpus_data = nil # __Corpus__ pool, created when corpus method called
    @cache = nil # hash of BayesPool objects that contain probabilities instead of counts
  
    def initialize( tokenizer = SimpleTokenizer, &combiner )
      @tokenizer = tokenizer.new
      @combiner = combiner || Proc.new { |probs,ignore| Bishop.robinson( probs, ignore ) }
      @pools = {}
      @cache = {} # created by calling build_cache, contains raw probabilities
      @corpus_data = nil # created when corpus method is called, contains token totals
      @dirty = true # indicates that cache and corpus_data are invalid
      @stop_words = []
    end
    
    def to_json
      h = { :tokenizer => @tokenizer.class.name,
        :stop_words => @stop_words.join(',')
      }
      pools = {}
      @pools.each do |pool_name,pool|
        data = pool.data
        sorted_data = data.sort do |a,b|
          if a[1] == b[1]
            a[0] <=> b[0]
          else
            a[1] <=> b[1]
          end
        end
        pools[pool_name] = {
          :token_count => pool.token_count,
          :train_count => pool.train_count,
          :data => sorted_data.to_h
        }
      end
      h[:pools] = pools
      JSON.pretty_generate(h)
    end
    
    # Add each of the specified stop words
    def add_stop_words( words )
      words.each { |word| add_stop_word word }
    end
    
    # Add the specified stop word
    def add_stop_word( word )
      @stop_words << word.downcase unless @stop_words.include? word
    end
    
    # Load stopwords from the specified YAML formatted file
    def load_stop_words( source )
      File.open( source ) { |f| add_stop_words( YAML.load( f ) ) }
    end
    
    # Load the default stop word list included with Bishop
    def load_default_stop_words
      load_stop_words( File.join( File.dirname( __FILE__ ), 'stopwords.yml' ) )
    end
    
    # Create a new, empty, pool without training.
    def new_pool( pool_name )
      @dirty = true
      @pools[ pool_name ] ||= BayesPool.new
    end
    
    def find_pool(pool_name)
      @pools[ pool_name ]
    end
    
    def remove_pool( pool_name )
      @dirty = true
      @pools.delete( pool_name ) 
    end 

    def rename_pool( pool_name, new_name )
      @pools[new_name] = @pools[pool_name]
      @pools.delete( pool_name )
      @dirty = true
    end

    # Merge the contents of the source pool into the destination
    # destination pool.
    def merge_pools( dest_name, source_name )
      @pools[dest_name].merge(@pools[source_name])
      @dirty = true  
    end
  
    # Create a representation of the state of the classifier which can
    # be reloaded later.  This does not include the tokenizer, data class,
    # or combiner functions which must be reinitialized each time the
    # classifier is created.
    def save( file = 'bayesdata.yml' )
      File.open( file, 'w' ) { |f| f << export }
    end
    
    # Define the YAML representation of the state of the classifier (possibly this
    # should just be an override of the to_yaml method generated by the YAML module).
    def export
      { :pools => @pools, :train_count => @train_count, :stop_words => @stop_words }.to_yaml
    end
  
    def load( file = 'bayesdata.yml' )
      begin
        File.open( file ) { |f| load_data( f ) }
      rescue Errno::ENOENT
        # File does not exist
      end
    end
    
    def load_data( source )
      data = YAML.load( source )
      
      @pools = data[:pools]
      @pools.each { |pool_name,pool| pool.data.default = 0.0 }
      
      @stop_words = data[:stop_words]
      
      @dirty = true
    end
    
    def pool_names
      @pools.keys.sort
	  end

    def train( pool_name, item )
      tokens = item.is_a?(String) ? get_tokens( item ) : item
      pool = new_pool( pool_name )
      train_( pool, tokens )
      pool.train_count += 1
      @dirty = true
    end
    
    def untrain( pool_name, item )
      pool = find_pool( pool_name )
      return if !pool
      tokens = get_tokens( item )
      untrain_( pool, tokens )
      pool.train_count -= 1
      @dirty = true  
    end

    def trained_on?( token )
      build_cache if @dirty
      @cache.values.any? { |v| v.trained_on? token }
    end
      
    # Call this method to classify a "message".  The return value will be
    # an array containing tuples (pool, probability) for each pool which
    # is a likely match for the message.
    def guess( msg )
      tokens = get_tokens( msg )
      res = {}
      
      build_cache if dirty?
      
      @cache.each do |pool_name,pool|
        p = get_probs( pool, tokens )
        if p.length != 0
          res[pool_name] = @combiner.call( p, pool_name )
        end    
      end
      
      h = Hash.new
      res.sort.each { |a| h[a[0]] = a[1]}
      h
    end
    
    #
    # Private Methods
    #
      
    private :train_, :untrain_, :get_probs, :corpus, :build_cache, :dirty?
    
    def dirty? # TODO Make private?
      @dirty
    end
    
    def train_( pool, tokens )
      tokens.each { |token| pool.add_token(token) }
    end
    
    def untrain_( pool, tokens )
      tokens.each do |token|
        pool.remove_token(token)
      end
    end
    
    def corpus
      return @corpus_data if @corpus_data
      
      @corpus_data = BayesPool.new
      
      @pools.each do |pool_name, pool| 
        @corpus_data.merge(pool)       
      end
      
      @corpus_data
    end
    
    # Create a cache of the metrics for each pool.
    def build_cache
      @cache = {}
      
      return @cache if corpus.token_count == 0.0

      @pools.each do |pool_name,pool|
        if pool.token_count > 0
          cache_dict = @cache[ pool_name ] ||= BayesPool.new
          
          them_count = [ 1, corpus.token_count - pool.token_count ].max  # tokens in other pools

          corpus.data.each do |token,corpus_count|
            if pool.data.has_key?(token)
              
              # number of references in other pools
              other_count = corpus_count - pool.data[token] 
              
              # prob token is not in this pool
              good_metric = [ 1.0, Float(other_count) / Float(pool.token_count) ].min 
            
              # prob token is in a different pool
              # NOTE Must explicitly cast to Floats or else it does integration division, and the result is zero
              bad_metric = [ 1.0, Float(pool.data[token]) / Float(them_count) ].min 
            
              f = bad_metric / ( good_metric + bad_metric )

              if ( f - 0.5 ).abs >= 0.1
                cache_dict.data[token] = [ 0.0001, [ 0.9999, f ].min ].max
              end  
            end
          end
        end
      end
      @dirty = false
      @cache
    end    
    
    # Create a token array from the specified input.
    # TODO Should this be private?
    def get_tokens( input )
      @tokenizer.tokenize( input, @stop_words )
    end
    
    # For each word trained in the pool, collect it's occurrence data in the pool into a sorted array.
    def get_probs( pool, words )
      words.find_all { |word| pool.data.has_key? word }.map { |word| [word,pool.data[word]] }.sort
    end
    

  end
  
  # default "combiner" set in initialize
  # ignore is truly ignored
  def self.robinson( probs, ignore )
    nth = 1.0/probs.length
    what_is_p = 1.0 - probs.map { |p| 1.0 - p[1] }.inject( 1.0 ) { |s,v| s * v } ** nth
    what_is_q = 1.0 - probs.map { |p| p[1] }.inject { |s,v| s * v } ** nth
    what_is_s = ( what_is_p - what_is_q ) / ( what_is_p + what_is_q )
    ( 1 + what_is_s ) / 2
  end
   
  # not used
  def self.robinson_fisher( probs, ignore )
    n = probs.length
    
    begin
      h = chi2p( -2.0 * Math.log( probs.map { |p| p[1] }.inject( 1.0 ) { |s,v| s*v } ), 2*n )
    rescue
      h = 0.0
    end

    begin      
      s = chi2p( -2.0 * Math.log( probs.map { |p| 1.0 - p[1] }.inject( 1.0 ) { |s,v| s*v } ), 2*n )
    rescue
      s = 0.0
    end
    
    ( 1 + h - s ) / 2
  end
  
  def self.chi2p( chi, df )
    m = chi / 2
    sum = term = Math.exp( -m )
    (1 .. df/2).each do |i|
      term *= m/i
      sum += term
    end
    [1.0, sum].min
  end
  
end