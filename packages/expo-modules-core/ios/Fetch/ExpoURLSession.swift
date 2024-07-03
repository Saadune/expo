// Copyright 2015-present 650 Industries. All rights reserved.

import React

/**
 An URLSession like class for ExpoNetworkFetch.
 */
internal final class ExpoURLSession: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
  private let delegate: ExpoURLSessionDelegate
  private lazy var urlSession: URLSession = {
    let config = URLSessionConfiguration.default
    config.httpShouldSetCookies = true
    config.httpCookieAcceptPolicy = .always
    config.httpCookieStorage = HTTPCookieStorage.shared
    return URLSession(configuration: config, delegate: self, delegateQueue: nil)
  }()
  private var task: URLSessionDataTask?

  init(delegate: ExpoURLSessionDelegate) {
    self.delegate = delegate
    super.init()
  }

  func start(url: URL, requestInit: NativeRequestInit, requestBody: Data?) {
    var request = URLRequest(url: url)
    request.httpMethod = requestInit.method
    if requestInit.credentials == .include {
      request.httpShouldHandleCookies = true
      if let cookies = HTTPCookieStorage.shared.cookies(for: url) {
        request.allHTTPHeaderFields = HTTPCookie.requestHeaderFields(with: cookies)
      }
    } else {
      request.httpShouldHandleCookies = false
    }
    for tuple in requestInit.headers {
      request.addValue(tuple[1], forHTTPHeaderField: tuple[0])
    }
    if request.allHTTPHeaderFields?["Content-Encoding"] == "gzip", let gzipBody = RCTGzipData(requestBody, -1 /* default */) {
      request.httpBody = gzipBody
      request.setValue(String(gzipBody.count), forHTTPHeaderField: "Content-Length")
    } else {
      request.httpBody = requestBody
    }
    self.task = self.urlSession.dataTask(with: request)
    self.task?.resume()
    self.delegate.urlSessionDidStart(self)
  }

  func cancel() {
    self.task?.cancel()
  }

  // MARK: - URLSessionTaskDelegate/URLSessionDataDelegate implementations

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    self.delegate.urlSession(self, didRedirect: response)
    completionHandler(request)
  }

  func urlSession(
    _ session: URLSession,
    dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    self.delegate.urlSession(self, didReceive: response)
    completionHandler(.allow)
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    self.delegate.urlSession(self, didReceive: data)
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    self.delegate.urlSession(self, didCompleteWithError: error)
  }
}

internal protocol ExpoURLSessionDelegate: AnyObject {
  func urlSessionDidStart(_ session: ExpoURLSession)
  func urlSession(_ session: ExpoURLSession, didReceive response: URLResponse)
  func urlSession(_ session: ExpoURLSession, didReceive data: Data)
  func urlSession(_ session: ExpoURLSession, didRedirect response: URLResponse)
  func urlSession(_ session: ExpoURLSession, didCompleteWithError error: Error?)
}
