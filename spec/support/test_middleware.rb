class TestMiddleware
  def initialize(request, *params)
    @request = request
    @params  = params
  end

  def chain(request)
    @request = request
    return self
  end

  def call(opts, request_uri, method, params, body)
    return @request.call(opts, request_uri, method, params, body)
  end
end
