# Grac

[![Travis Build state](https://api.travis-ci.org/Barzahlen/grac.svg)](https://travis-ci.org/Barzahlen/grac) [![Code Climate](https://codeclimate.com/github/Barzahlen/grac/badges/gpa.svg)](https://codeclimate.com/github/Barzahlen/grac) [![RubyDoc](https://img.shields.io/badge/ruby-doc-green.svg)](http://rubydoc.info/github/Barzahlen/grac)

Grac is a generic REST client for JSON APIs. It's based on [Typhoeus](https://github.com/typhoeus/typhoeus), so it uses [libcurl](http://curl.haxx.se/) to execute requests.

Grac was designed for a microservice environment and is supposed to make most  processing before using a JSON response unnecessary, while not requiring service-specific client libraries.

## Example

Loading GeoIP information for `github.com`:

```ruby
require 'grac'
# => true
geoip_client = Grac::Client.new('http://freegeoip.net/json', timeout: 5)
# => #<Grac::Client:0x000000037f0848 @uri="http://freegeoip.net/json", @options={:connecttimeout=>0.1, :timeout=>15, :params=>{}, :headers=>{"User-Agent"=>"Grac v2.X.X","Content-Type"=>"application/json;charset=utf-8"}, :postprocessing=>{}}>
geoip_client.path('/{host}', host: 'github.com').get
# => {"ip"=>"8.8.8.8", "country_code"=>"US", "country_name"=>"United States", "region_code"=>"CA", "region_name"=>"California", "city"=>"Mountain View", "zip_code"=>"94040", "time_zone"=>"America/Los_Angeles", "latitude"=>37.3845, "longitude"=>-122.0881, "metro_code"=>807}
```

This initializes Grac with a base URL and a timeout, makes a GET request to `http://freegeoip.net/json/github.com`, and returns the parsed response.

Status codes indicating a failure raise an exception:

```ruby
geoip_client.path('/does/not/exist').get
# Grac::Exception::NotFound: GET 'http://freegeoip.net/json/does/not/exist' failed with content: 404 page not found
# [...]
```

[Response post processing](#response-post-processing) allows specifying Ruby blocks processing certain fields before they're returned. The blocks are specified by a regular expression matching field names. The following converts `latitude` and `longitude` fields to integers (scroll to the right to see the two fields):

```ruby
client = geoip_client.set(postprocessing: { '\A(latitude|longitude)\z' => -> (v) { v.to_i } })
#  => #<Grac::Client:0x00000003d06378 @uri="http://freegeoip.net/json", @options={:connecttimeout=>0.1, :timeout=>5, :params=>{}, :headers=>{"User-Agent"=>"Grac v2.X.X","Content-Type"=>"application/json;charset=utf-8"}, :postprocessing=>{"\\A(latitude|longitude)\\z"=>#<Proc:0x00000003d06530@(irb):18 (lambda)>}}>
client.path('/github.com').get
# => {"ip"=>"192.30.252.128", "country_code"=>"US", "country_name"=>"United States", "region_code"=>"CA", "region_name"=>"California", "city"=>"San Francisco", "zip_code"=>"94107", "time_zone"=>"America/Los_Angeles", "latitude"=>37, "longitude"=>-122, "metro_code"=>807}
```

## Getting started

1. add the Gem to the Gemfile

        gem 'grac'

2. Require the Gem at any point before using it
3. Use it!

## Usage

### Initializing

```ruby
Grac::Client.new("http://localhost:12345/v1", options)
```

`options` are optional.

Available options (shown are the default values):

```ruby
{
  connecttimeout: 0.1,  # in seconds
  timeout:        15,   # in seconds
  params:         {},   # default query parameters to be attached to the URL
  headers:        { "User-Agent" => "Grac v2.X.X", "Content-Type" => "application/json;charset=utf-8" },
  postprocessing: {},   # see below
  middleware:     []    # see below
}
```

You can always later override these options and get a new client object:

```ruby
client_with_per_page_param = client.set(params: { per_page: 20 })
```

The original `client` object is not modified.

### Making requests

You usually set the resource path using the `path` method and then make the request using one of the request methods, and depending on the method, passing a request body. If there's a response, it's parsed and returned:

```ruby
user = client.path("/v1/users").post(name: 'Hans', phone: '12345')
# => {"id" => 1, "name" => "Hans", "phone" => "12345"}
```

This results in a request to `/v1/users` with the JSON request body `{"name": "Hans", "phone": "12345"}`.

You can optionally pass **query parameters**:

```ruby
client.path("/v1/users").get(page: '2')
```

This results in a request to `/v1/users?page=2`.

You can also provide **path parameters**:

```ruby
user = client.path("/v1/users/{id}", id: '34').get
```

This results in a request to `/v1/users/34`.

Both, path and query parameters, are **escaped** using percent-encoding, if necessary. Nevertheless, if your application processes untrusted input, validate that input _before_ using it in your application and passing it to Grac. Escaping parameters is just a mitigation that can prevent URL injection under certain circumstances. Note that this mitigation can only work if you use Grac's parameter functionality, but _can not work_ if you build the URL string yourself.

#### Available request methods

* `get(query_params)`
* `delete(query_params)`
* `post(request_body, query_params)`
* `put(request_body, query_params)`
* `patch(request_body, query_params)`

#### Responses

For most **success** status codes (`2xx`, except `204` and `205`), Grac tries to parse the response as JSON if the response Content-Type contains `application/json`. For other content types, Grac returns the response as String and doesn't attempt to parse it. For a `204` or `205` response, the return value is undefined (it's currently `true`, but this might change in the future).

When a **failure** occurs, one of these exceptions will be raised:

* Status 400: `Grac::Exception::BadRequest`
* Status 403: `Grac::Exception::Forbidden`
* Status 404: `Grac::Exception::NotFound`
* Status 409: `Grac::Exception::Conflict`
* All other status codes: `ServiceError` - this includes all unknown status codes, even 3xx codes. See [issue #4](https://github.com/Barzahlen/grac/issues/4) for ideas on improving this.
* `InvalidContent` - JSON parsing for a success status failed, server response indicates success.
* `ErrorWithInvalidContent` - JSON parsing for an error status failed.
* `RequestFailed` - The request failed, there's no response from the server.
    * `ServiceTimeout` - A subclass of `RequestFailed` - the request failed due to a timeout (like waiting for the connection or for the response).

Responses with error status codes (4xx and 5xx) are expected to have JSON content, regardless of their content type (that's different for success responses). If they don't Grac raises a `ErrorWithInvalidContent` exception. This allows making the assumption when handling a `Grac::ClientException` that the exception's `#body` method contains a parsed JSON response.

### Chaining

Grac allows you to override options and append to the URI by chaining calls to `set` resp. `path`.

```ruby
client = Grac::Client.new("http://localhost:80", timeout: 1)
# => #<Grac::Client:0x00000003d3dd50 @uri="http://localhost:80", @options={:connecttimeout=>0.1, :timeout=>1, :params=>{}, :headers=>{"User-Agent"=>"Grac v2.X.X","Content-Type"=>"application/json;charset=utf-8"}, :postprocessing=>{}}>
client.set(timeout: 20).path("/v1/users").get(per_page: 1000)
# => [...]
```

This first creates a client with a timeout of 1 second. The second command does a slow HTTP request, so it sets a timeout, a path and does the request. When using `path` or `get`, the original client is never modified, but a new client with the modified options is created and returned.

You can use chaining and we'd recommend using it at least for different resource paths, but you can also do a single request without any chaining:

```ruby
Grac::Client.new("http://freegeoip.net/json/github.com", timeout: 1).get
# => {"ip"=>"192.30.252.131", "country_code"=>"US", "country_name"=>"United States", "region_code"=>"CA", "region_name"=>"California", "city"=>"San Francisco", "zip_code"=>"94107", "time_zone"=>"America/Los_Angeles", "latitude"=>37.7697, "longitude"=>-122.3933, "metro_code"=>807}
```

You can access a client's full URI (without query parameters):

```ruby
Grac::Client.new("http://freegeoip.net/json").path("/github.com").uri
 => "http://freegeoip.net/json/github.com"
```

### Middleware

Sometimes it may be necessary to programmatically set a specific value on the request.
An example would be an `Authorization` header with a signature depending on host, path, http method, etc.
While this could be calculated before making the request it is just convenient to have it done
automatically with each request.

For this purpose a class can be added as middleware which accepts at least one parameter during
initialization and has a call method accepting the parameters as shown in the example below.
The first parameter will always be the request object, i.e. the instance of `Grac` or another middleware
already wrapped around it. Additional configuration can be provided to the middleware by accepting
additional parameters. These will be passed along during the request when initializing the middleware.


```ruby
class MW
  def initialize(request, *settings)
    @request  = request
    @settings = settings
  end

  def call(opts, request_uri, method, params, body)
    # your code here
    # opts        - Hash of the options currently set on the grac object
    # request_uri - uri returned by grac
    # method      - http method (lower case)
    # params      - hash of all params for this request
    # body        - serialized body

    result = @request.call(opts, request_uri, method, params, body)

    # your code for working on the response here
    return result
  end
end

# Configuring Middleware
Grac::Client.new("http://localhost:80", middleware: [MW])

# Configuring Middleware with additional parameters
Grac::Client.new("http://localhost:80", middleware: [[MW, "abc"]])
```

Multiple middlewares can be added and they are wrapped in the order they were added, the first one
being the first one which is called and the last one to return in the middleware stack.
The middlware can't modify the original parameters it receives (they're frozen), but it can return new values (or some of the original ones if it only needs to modify some of the parameters). The return values are then passed to the next middleware or, if the middleware is the last one, used for the actual request.
The request will then return a `Grac::Response` object which can be used to execute some actions after
the actual request. An example for this is checking a response signature.

### Response post processing

Response post processing allows processing specific fields before they're returned. This is useful if you regularly use some data types that can't be represented natively in JSON, e.g. arbitrary-precision decimal numbers.

You specificy a regular expression to be matched against property names to select certain properties. These properties are then processed by a given lambda by calling it with the property's value.

Here's an example with a regular expression matching all property names ending in `amount`:

```ruby
client = Grac::Client.new(
  "http://localhost:80",
  postprocessing: {
    "amount$" => ->(value){ BigDecimal.new(value.to_s) }
  }
)
```

With the configuration above, Grac will convert the following JSON response:

```json
{
  "amount": "123.12",
  "fee_amount": "12.12"
}
```

Into this Ruby Hash:

```ruby
# => {
#      "amount"     => #<BigDecimal,'0.12312E3',18(18)>,
#      "fee_amount" => #<BigDecimal,'0.1212E2',18(18)>
#    }
```

**Note:**
Postprocessing recursively runs through all of the data.
This may have significant influence on performance depending on size and depth of the result.

## Limitations

* 3xx status codes (i.e. redirects) are not yet supported.
* Not all error response codes have proper exceptions, see [issue #4](https://github.com/Barzahlen/grac/issues/4).

## Bugs and Contribution
For bugs and feature requests open an issue on Github. For code contributions fork the repo, make your changes and create a pull request.

### License

[LICENSE](LICENSE) (MIT)
