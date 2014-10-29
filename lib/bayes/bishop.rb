#
# This module is a port to the Ruby language of the Reverend Bayesian classifier distributed
# as part of the Divmod project (which is Copyright 2003 Amir Bakhtiar <amir@divmod.org>
#
# This Ruby port is Copyright 2005 Matt Mower <self@mattmower.com> and is free software;
# you can distribute it and/or modify it under the terms of version 2.1 of the GNU
# Lesser General Public License as published by the Free Software Foundation.
#

require 'yaml'
require 'stemmer'

module Bishop

  #
  # As at v1.8 Ruby's YAML persists Hashes using special processing rather
  # than by dumping it's instance variables, hence no instance variables
  # in a Hash subclass get dumped either.
  #
  class BayesData
  
    attr_accessor :token_count, :train_count, :name
    attr_reader :training, :data, :pool
  
    def initialize( name = '', pool = nil )
      @name = name
      @training = []
      @pool = pool
      @data = Hash.new( 0.0 )
      self.token_count = 0
      self.train_count = 0
    end
    
    def trained_on?( item )
      self.training.include? item
    end
    
    def to_s
      "<BayesDict: #{self.name.nil? || self.name.empty? ? 'noname' : self.name}, #{self.token_count} tokens>"
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
  
    attr_accessor :dirty, :train_count, :pools, :tokenizer, :data_class, :corpus, :cache, :combiner
    attr_reader :data_class, :stop_words
  
    def initialize( tokenizer = SimpleTokenizer, data_class = BayesData, &combiner )
      @tokenizer = tokenizer.new
      @combiner = combiner || Proc.new { |probs,ignore| Bishop.robinson( probs, ignore ) }
      @data_class = data_class
      @pools = {}
      @corpus = new_pool( '__Corpus__' )
      @pools['__Corpus__'] = @corpus
      @train_count = 0
      @dirty = true
      @stop_words = []
    end
    
    def commit
      self.save
    end
    
    def dirty?
      self.dirty
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
      self.dirty = true
      self.pools[ pool_name ] ||= @data_class.new( pool_name )
    end
   
    def remove_pool( pool_name )
      self.pools.delete( pool_name ) 
    end 

    def rename_pool( pool_name, new_name )
      self.pools[new_name] = self.pools[pool_name]
      self.pools[new_name].name = new_name
      self.pools.delete( pool_name )
      self.dirty = true
    end

    # Merge the contents of the source pool into the destination
    # destination pool.
    def merge_pools( dest_name, source_name )
      dest_pool = self.pools[dest_name]
      self.pools[source_name].data.each do |token,count|
        if dest_pool.data.has_key?( token )
          dest_pool.data[token] += count
        else
          dest_pool.data[token] = count
          dest_pool.token_count += 1
        end
      end
      self.dirty = true  
    end
  
    # Return an array of token counts for the specified pool.
    def pool_data( pool_name )
      self.pools[pool_name].data.to_a
    end

    # Return an array of tokens trained in the specified pool.  
    def pool_tokens( pool_name )
      self.pools[pool_name].data.keys
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
      { :pools => self.pools, :train_count => self.train_count, :stop_words => self.stop_words }.to_yaml
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
      @corpus = self.pools['__Corpus__']
      
      @train_count = data[:train_count]
      @stop_words = data[:stop_words]
      
      self.dirty = true
    end
    
    def pool_names
      self.pools.keys.sort.reject { |name| name == '__Corpus__' }
	end
  
    # Create a cache of the metrics for each pool.
    def build_cache
      self.cache = {}
      
      self.pools.each do |name,pool|
        unless name == '__Corpus__'
        
          pool_count = pool.token_count
          them_count = [ 1, self.corpus.token_count - pool_count ].max
          cache_dict = self.cache[ name ] ||= @data_class.new( name )
          
          self.corpus.data.each do |token,tot_count|
            this_count = pool.data[token]

            unless this_count == 0.0
              other_count = tot_count - this_count
              
              if pool_count > 0
                good_metric = [ 1.0, other_count / pool_count ].min
              else
                good_metric = 1.0
              end
            
              bad_metric = [ 1.0, this_count / them_count ].min
            
              f = bad_metric / ( good_metric + bad_metric )
              
              if ( f - 0.5 ).abs >= 0.1
                cache_dict.data[token] = [ 0.0001, [ 0.9999, f ].min ].max
              end  
            end
          end
        end
      end
    end    

    # Get the probabilities for each pool, recreating the cached information if
    # any token information for any of the pools has changed.
    def pool_probs
      if self.dirty?
        self.build_cache
        self.dirty = false
      end    
      self.cache
    end
    
    # Create a token array from the specified input.
    def get_tokens( input )
      self.tokenizer.tokenize( input, self.stop_words )
    end
    
    # For each word trained in the pool, collect it's occurrence data in the pool into a sorted array.
    def get_probs( pool, words )
      words.find_all { |word| pool.data.has_key? word }.map { |word| [word,pool.data[word]] }.sort
    end
    
    def train( pool_name, item, uid = nil )
      tokens = get_tokens( item )
      pool = new_pool( pool_name )
      train_( pool, tokens )
      self.corpus.train_count += 1
      pool.train_count += 1
      if uid
        pool.training.push( uid )
      end    
      self.dirty = true
    end
    
    def train_( pool, tokens )
      wc = 0
      tokens.each do |token|
        pool.data[token] += 1
        self.corpus.data[token] += 1
        wc += 1
      end
      pool.token_count += wc
      self.corpus.token_count += wc
    end
    
    def untrain( pool_name, item, uid = nil )
      tokens = get_tokens( item )
      pool = new_pool( pool_name )
      untrain_( pool, tokens )
      self.corpus.train_count += 1
      pool.train_count += 1
      if uid
        pool.training.delete( uid )
      end    
      self.dirty = true  
    end
    
    def untrain_( pool, tokens )
      tokens.each do |token|
        if pool.data.has_key? token
          if pool.data[token] == 1
            pool.data.delete( token )
          else
            pool.data[token] -= 1
          end
          pool.token_count -= 1        
        end
        
        if self.corpus.data.has_key? token
          if self.corpus.data[token] == 1
            self.corpus.data.delete( token )
          else
            self.corpus.data[token] -= 1
          end
          self.corpus.token_count -= 1
        end        
      end
    end
    
    def trained_on?( msg )
      self.cache.values.any? { |v| v.trained_on? msg }
    end
      
    # Call this method to classify a "message".  The return value will be
    # an array containing tuples (pool, probability) for each pool which
    # is a likely match for the message.
    def guess( msg )
      tokens = get_tokens( msg )
      res = {}
      
      pool_probs.each do |pool_name,pool|
        p = get_probs( pool, tokens )
        if p.length != 0
          res[pool_name] = self.combiner.call( p, pool_name )
        end    
      end
      
      res.sort
    end

    private :train_, :untrain_
  end
  
  def self.robinson( probs, ignore )
    nth = 1.0/probs.length
    what_is_p = 1.0 - probs.map { |p| 1.0 - p[1] }.inject( 1.0 ) { |s,v| s * v } ** nth
    what_is_q = 1.0 - probs.map { |p| p[1] }.inject { |s,v| s * v } ** nth
    what_is_s = ( what_is_p - what_is_q ) / ( what_is_p + what_is_q )
    ( 1 + what_is_s ) / 2
  end
   
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