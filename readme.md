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
# Keys have to be strings, no support for symbols
Grac::Client.new("uri" => "http://localhost:12345/v1")

# Defaults
Grac::Client.new("
  scheme"          => "https",
  "host"           => "localhost",
  "port"           => 80,
  "path"           => "/",
  "connecttimeout" => 0.1,
  "timeout"        => 15,
  "params"         => {},
  "headers"        => { "User-Agent" => Grac v1.0.0 }
)
```

### Path traversing
```ruby
client = Grac::Client.new

client.uri
# => "http://localhost:80/"

# Any valid Ruby method name that is not defined to append to the uri can be used
client.something.uri
# => "http://localhost:80/something"

# For non-valid Ruby method names which should be appended var can be used, e.g. numbers
client.var(1).uri
# => "http://localhost:80/1"

# Any setting can be overwritten later on
client.cookies!.uri
# => "http://localhost:80/cookies"

client.set("path" => "abc").uri
# => "http://localhost:80/abc"

# Templates can be used following the same logic as in the [Addressable](https://github.com/sporkmonger/addressable) gem
client.set!("path" => "/{version}/{one,two,three}/{id}")

client.expand("version" => "v1").uri
# => "http://localhost:80/v1//"

client.partial_expand("one" => "1", "three" => 3).uri
# => "http://localhost:80/{v1}/1{two}3/{id}"
```

Note:
Calling the methods without `!` at the end will result in initializing a new instance of the client.
This is useful for reuse of a client instance which is already initialized to a specific path.
Calling methods with `!` at the end, e.g. `var!(value)` will result in overwriting the path of the
current instance.


## Bugs and Contribution
For bugs and feature requests open an issue on Github. For code contributions fork the repo, make your changes and create a pull request.

### License
[LICENSE](LICENSE)
