# This is a Naive Bayes classifier that can be used to categorize text based on trained "pools".
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

  class BayesPool #:nodoc:
    include Enumerable
    
    # Sum of token counts in the pool
    attr_reader :token_count 
    
    # Number of times train has been called for this pool
    attr_accessor :train_count 
    
    # Hash that contains counts for all tokens
    attr_reader :data 
  
    def initialize
      @data = Hash.new( 0.0 )
      @token_count = 0
      @train_count = 0
    end
    
    # Iterate through the tokens in the pool
    def each
      @data.each
    end
    
    def to_s
      "<BayesPool: #{@token_count} tokens>"
    end
    
    # Convert the pool into an array of the format [['token1',count1],['token2',count2],...]
    def to_a
      @data.to_a
    end
  
    # Return all of the tokens in the pool
    def tokens
      @data.keys.sort
    end
    
    # Return the number of tokens in the pool
    def num_tokens
      @data.length
    end
    
    # Add a token to the pool, incrementing its count value, and updating the token_value
    def add_token token, count = 1
      if @data.has_key?(token)
        @data[token] = @data[token] + count
      else
        @data[token] = count
      end
      
      @token_count = @token_count + count
    end

    # Set the count for a the specified token
    def []= token, count
      add_token(token,count)
    end
    
    # Get the count for the specified token
    def [] token
      @data[token]
    end
    
    # Merge another pool into the current pool
    def merge(other_pool)
      other_pool.data.each { |token,count| add_token(token,count) }
    end
    
    # Decrement the token count and remove the token if the count is 0
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
  
    # instance of Tokenizer that handles tokenization
    attr_accessor :tokenizer 
    
    # Block called to combine probabilities.  Set to Bishop.robinson by default
    attr_accessor :combiner 
    
    # An array containing stop words that the tokenizer will ignore
    attr_reader :stop_words 

    @dirty = true # set to true for any changes, false when pool_probs is called
    @corpus_data = nil # __Corpus__ pool, created when corpus method called
    @cache = nil # hash of BayesPool objects that contain probabilities instead of counts
  
    # tokenizer is the name of the class that will separate the input into tokens. 
    # See SimpleTokenizer and StemmingTokenizer for more information.
    # Combiner defaults to a block that calls Bishop.robinson
    def initialize( tokenizer = SimpleTokenizer, &combiner )
      @tokenizer = tokenizer.new
      @combiner = combiner || Proc.new { |probs,ignore| Bishop.robinson( probs, ignore ) }
      @pools = {} # hash, key = pool name, value = BayesPool class
      @cache = {} # created by calling build_cache, contains raw probabilities
      @corpus_data = nil # created when corpus method is called, contains token totals
      @dirty = true # indicates that cache and corpus_data are invalid
      @stop_words = []
    end

    
    #
    # == POOLS
    # 
    
    # Get the pool specified by name
    def pool pool_name
      @pools[pool_name]
    end
    
    # Get a list of pools
    def pool_names
      @pools.keys.sort
	  end
    
    # Create a new, empty, pool without training.
    def new_pool( pool_name )
      @dirty = true
      @pools[ pool_name ] ||= BayesPool.new
    end
    
    # Remove the given pool
    def remove_pool( pool_name )
      @dirty = true
      @pools.delete( pool_name ) 
    end 

    # Rename the given pool
    def rename_pool( pool_name, new_name )
      @pools[new_name] = @pools[pool_name]
      @pools.delete( pool_name )
      @dirty = true
    end

    # Merge the contents of the source pool into the destination destination pool.
    def merge_pools( dest_name, source_name )
      @pools[dest_name].merge(@pools[source_name])
      @dirty = true  
    end
    
    #
    # == STOP WORDS
    #
  
    # Add an array of stop words
    def add_stop_words( words )
      words.each { |word| add_stop_word word if !word.empty? }
    end
    
    # Add the specified stop word
    def add_stop_word( word )
      @stop_words << word.downcase if !@stop_words.include?(word.downcase)
    end
    
    # Load stopwords from the specified YAML formatted file
    def load_stop_words( source )
      File.open( source ) { |f| add_stop_words( YAML.load( f ) ) }
    end
    
    # Load the default stop word list included with Bishop
    def load_default_stop_words
      load_stop_words( File.join( File.dirname( __FILE__ ), 'stopwords.yml' ) )
    end
    
    #
    # EXPORT & IMPORT STATE
    #

    # Get a hash that represents the current state, excluding tokenizer and combiner
    def export
      h = { 
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
      h
    end
    
    # Gets the current state in YAML format
    def to_yaml
      export.to_yaml
    end
    
    # Gets the current state in JSON format
    def to_json
      JSON.pretty_generate(export)
    end
    
    # Save the current state to a YAML file, default = 'bayesdata.yml'
    def save_yaml( file = 'bayesdata.yml' )
      File.open( file, 'w' ) { |f| f << to_yaml }
    end
    
    # Load the current state from a YAML file, default = 'bayesdata.yml'
    def load_yaml( file = 'bayesdata.yml' )
      begin
        File.open( file ) { |f| load_data( f ) }
      rescue Errno::ENOENT
        # File does not exist
      end
    end
    
    #
    # TRAIN & GUESS
    #
    
    # Train the specified pool with the given input.  
    # If the input is a string it is passed through the configured Tokenizer.
    # Otherwise, if it is an array it is just added.
    def train( pool_name, input )
      tokens = input.is_a?(String) ? get_tokens( input ) : input
      pool = new_pool( pool_name )
      train_( pool, tokens )
      pool.train_count += 1
      @dirty = true
    end
    
    # Remove the input from the given pool
    # If the input is a string it is passed through the configured Tokenizer.
    # Otherwise, if it is an array it is just added.
    def untrain( pool_name, input )
      pool = find_pool( pool_name )
      return if !pool
      tokens = input.is_a?(String) ? get_tokens( input ) : input
      untrain_( pool, tokens )
      pool.train_count -= 1
      @dirty = true  
    end

    # Returns true if the specified token has been trained for any pool
    def trained_on?( token )
      build_cache if @dirty
      @cache.values.any? { |v| v.trained_on? token }
    end
      
    # Call this method to classify a "message".  The return value will be
    # a hash, with the pool name is the key and the probability is the value, for each pool which
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
      res.sort.each { |a| h[a[0]] = a[1] }
      h
    end
    
    #
    # Private Methods
    #
      
    def load_data( source )
      data = YAML.load( source )
      data[:pools].each do |pool_name,pool_data|
        pool = new_pool(pool_name)
        pool.train_count = pool_data[:train_count]
        pool_data[:data].each do |token,value|
          pool.add_token(token,value)
        end
      end
      
      add_stop_words(data[:stop_words].split(','))
      
      @dirty = true
    end
    
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
    def get_tokens( input )
      @tokenizer.tokenize( input, @stop_words )
    end
    
    # For each word trained in the pool, collect it's occurrence data in the pool into a sorted array.
    def get_probs( pool, words )
      words.find_all { |word| pool.data.has_key? word }.map { |word| [word,pool.data[word]] }.sort
    end
    
    private :train_, :untrain_, :get_probs, :corpus, :build_cache, :dirty?, :get_tokens, :get_probs, :export, :load_data

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
   
  # Alternative combiner
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
  
  def self.chi2p( chi, df ) #:nodoc:
    m = chi / 2
    sum = term = Math.exp( -m )
    (1 .. df/2).each do |i|
      term *= m/i
      sum += term
    end
    [1.0, sum].min
  end
end