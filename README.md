# Visit::Counter

TODO: Write a gem description

## Installation

Add this line to your application's Gemfile:

    gem 'visit-counter'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install visit-counter

## Usage

a. the default storage engine is redis. If you have a global $redis for your redis connection, we default to using that. Otherwise, in an initializer you should define it by:

    VisitCounter::Store::RedisStore.redis = {host: "your_redis_host", port: port}

b. in the class you wish to have a visit counter simply declare
    include VisitCounter
from this moment on, you can use the incr_counter(:counter_name), nullify_counter(:counter_name) and read_counter(:counter_name) methods
You can also do something like this:

    class Foo < ActiveRecord::Base
       include VisitCounter
       cached_counter :counter_name
    end

this will override the counter_name method to read the live counter (from both database and the NoSQL storage) and add a increase_counter_name method for upping the counter by 1 (in the NoSQL and/or persist to DB when needed)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
