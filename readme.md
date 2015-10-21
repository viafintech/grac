# Grac

![Travis Build state](https://api.travis-ci.org/Barzahlen/grac.svg)

Grac is a very generic REST API client.
It allows moving along path structures and making basic HTTP requests.
Grac was built for talking to JSON based REST APIs.

## Getting started

1. add the Gem to the Gemfile

        gem 'grac'

2. Require the Gem at any point before using it
3. Use it!

## Examples

### Initializing
```ruby
Grac::Client.new("http://localhost:12345/v1")

# Defaults
{
  :connecttimeout => 0.1,
  :timeout        => 15,
  :params         => {},
  :headers        => { "User-Agent" => "Grac v2.0.0" },
  :postprocessing => {}
}
```

### Path traversing
```ruby
client = Grac::Client.new("localhost:80")

client.uri
# => "localhost:80"

client = Grac::Client.new("http://localhost:80")
# use the path method to append to the uri
client.path('/something').uri
# => "localhost:80/something"

# variables can be added dynamically - not that this only refers to the currently added path!
client.path('/v{version}/something_else', :version => 2).uri
# => "localhost:80/v2/something_else"

# Any setting can be overwritten later on
client.set(:timeout => 5)
```

Note:
Calling path will result in initializing a new instance of the the client.
The same applies when calling set: a new instance will be created and the old object remains unchanged.

### Data post processing
Sometimes you may want to do some changes on the data for each entry before continuing
By setting regex keys and lambda values in postprocessing this can be achieved.
The regex will be matched against the hash keys in the response and if it matches, the lambda will be called

```ruby
client = Grac::Client.new(
  "http://localhost:80",
  :postprocessing => {
    "amount$" => ->(value){ BigDecimal.new(value.to_s) }
  }
)

# Response hash:
# {
#   "amount" => "123.12"
#   "fee_amount" => "12.12"
# }
client.get
# => {
#      "amount"     => #<BigDecimal,'0.12312E3',18(18)>,
#      "fee_amount" => #<BigDecimal,'0.1212E2',18(18)>
#    }
```

Note:
Postprocessing recursively runs through all of the data.
This may have significant influence on performance depending on the size and depth of the result.

## Bugs and Contribution
For bugs and feature requests open an issue on Github. For code contributions fork the repo, make your changes and create a pull request.

### License
[LICENSE](LICENSE)
