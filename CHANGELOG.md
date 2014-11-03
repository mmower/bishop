# Revisions
##0.5.0
* Lots of refactoring, cleanup, making methods private, etc.
* Added tests
* Removed uid from train/untrain - couldn't think of a good use case, and the logic didn't seem right since the system doesn't keep track of which call to train created a token the untrain option would blindly remove them.
* Changed BayesData to BayesPool since that seems more explanatory
* Moved some pool manipulation functions into BayesPool for better encapsulation
* Add to_json method
* Removed data_class from Bayes initializer since I couldn't think of a reason to make that configurable
* Create corpus in build cache instead of maintaining it in parallel