// Copyright 2015-present 650 Industries. All rights reserved.

public class ExpoNetworkFetchModule: Module {
  private let queue = DispatchQueue(label: "expo.modules.networkfetch.RequestQueue")

  public func definition() -> ModuleDefinition {
    Name("ExpoNetworkFetchModule")

    Events(
      "didReceiveResponseData",
      "didComplete",
      "didFailWithError"
    )

    // swiftlint:disable:next closure_body_length
    Class(NativeResponse.self) {
      Constructor {
        return NativeResponse(dispatchQueue: self.queue)
      }

      AsyncFunction("startStreaming") { (response: NativeResponse) in
        response.startStreaming()
      }.runOnQueue(queue)

      AsyncFunction("cancelStreaming") { (response: NativeResponse, _ reason: String) in
        response.cancelStreaming()
      }.runOnQueue(queue)

      Property("bodyUsed") { (response: NativeResponse) in
        return response.bodyUsed
      }

      Property("headers") { (response: NativeResponse) in
        return response.responseInit?.headers ?? []
      }

      Property("status") { (response: NativeResponse) in
        return response.responseInit?.status ?? -1
      }

      Property("statusText") { (response: NativeResponse) in
        return response.responseInit?.statusText ?? ""
      }

      Property("url") { (response: NativeResponse) in
        return response.responseInit?.url ?? ""
      }

      Property("redirected") { (response: NativeResponse) in
        return response.redirected
      }

      AsyncFunction("arrayBuffer") { (response: NativeResponse, promise: Promise) in
        response.waitFor(states: [.bodyCompleted]) { _ in
          let data = response.ref.finalize()
          promise.resolve(data)
        }
      }.runOnQueue(queue)

      AsyncFunction("text") { (response: NativeResponse, promise: Promise) in
        response.waitFor(states: [.bodyCompleted]) { _ in
          let data = response.ref.finalize()
          let text = String(decoding: data, as: UTF8.self)
          promise.resolve(text)
        }
      }.runOnQueue(queue)
    }

    Class(NativeRequest.self) {
      Constructor { (nativeResponse: NativeResponse) in
        return NativeRequest(response: nativeResponse)
      }

      AsyncFunction("start") { (request: NativeRequest, url: URL, requestInit: NativeRequestInit, requestBody: Data?, promise: Promise) in
        request.ref.start(url: url, requestInit: requestInit, requestBody: requestBody)
        request.response.waitFor(states: [.responseReceived, .errorReceived]) { state in
          if state == .responseReceived {
            promise.resolve()
          } else if state == .errorReceived {
            promise.reject(request.response.error ?? NetworkFetchUnknownException())
          }
        }
      }.runOnQueue(queue)

      AsyncFunction("cancel") { (request: NativeRequest) in
        request.ref.cancel()
      }.runOnQueue(queue)
    }
  }
}
