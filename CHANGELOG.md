## 3.2.0

* Improve JSON parsing performance by using [oj](https://github.com/ohler55/oj) gem instead of the builtin `json` library

## 3.1.1

* Further improvement on regexp object creation to reduce memory allocation

## 3.1.0

* Improvement on regexp object creation to reduce memory allocation

## 3.0.0

* Updates gem dependencies with breaking dependency resolution changes

## 2.4.0

* Grac now raises an exception on receiving only a partial response. This can happen when typhoeus times out while not having received the entire response.

## 2.3.0

* Grac now expects error responses to contain JSON and will raise an `ErrorWithInvalidContent` exception if they don't, even if the content type indicates another content type. Success responses with non-JSON content type are still supported. In most cases, that allows making assumptions about the exception's body message. See #13.

## Before 2.3.0

Not available, see commits.
