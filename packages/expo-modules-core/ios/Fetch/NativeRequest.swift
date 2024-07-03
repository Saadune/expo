// Copyright 2015-present 650 Industries. All rights reserved.

/**
 A SharedRef for request.
 */
internal final class NativeRequest: SharedRef<ExpoURLSession> {
  internal let response: NativeResponse

  init(response: NativeResponse) {
    self.response = response
    super.init(ExpoURLSession(delegate: self.response))
  }

  func start(url: URL, requestInit: NativeRequestInit, requestBody: Data?) {
    self.ref.start(url: url, requestInit: requestInit, requestBody: requestBody)
  }

  func cancel() {
    self.ref.cancel()
  }
}

/**
 Enum for RequestInit.credentials.
 */
internal enum NativeRequestCredentials: String, Enumerable {
  case include
  case omit
}

/**
 Record for RequestInit.
 */
internal struct NativeRequestInit: Record {
  @Field
  var credentials: NativeRequestCredentials = .include

  @Field
  var headers: [[String]] = []

  @Field
  var method: String = "GET"
}
