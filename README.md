# Introduction
This is a Naive Bayes classifier that can be used to categorize text based on trained "pools".
Training counts how often each word is used, except for any specified stop words.
The Bayes::Bishop.guess method tokenizes the message and then calculates for each pool the probability that the message is the same "classification" as that pool.
For example, you could train the system with one pool of "spam" email and one pool of "non-spam" email.  Then you could ask the guess method which pool each incoming message belongs to.

# Usage
1. Create a Bishop::Bayes object:

	b = Bishop::Bayes.new

2. Train with multiple pools of text:

	b.train('pool1')  
	b.train('pool2')  
	b.train('pool3')  
       
3. Call the guess method with a message to categorize:

	guesses = b.guess('This is a sentence')
       
   The return value is a hash where the keys are pool names and the values are the probability
   that the message belongs to that pool.  

# Features
* Stop words may be specified

	b.add_stop_words(an_array_words)  
	b.add_stop_word('word')  
       
* You can include the default stop words list  
  
	b.load_default_stop_words  
       
* You can choose between the default tokenizer, a stemming tokenizer, or a custom tokenizer

	b = Bishop::Bayes.new
	b = Bishop::Bayes.new(Bishop::StemmingTokenizer)
	b = Bishop::Bayes.new(CustomTokenizer)

