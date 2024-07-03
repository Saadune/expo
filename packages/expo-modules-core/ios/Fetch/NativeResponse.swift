// Copyright 2015-present 650 Industries. All rights reserved.

/**
 A SharedRef for response.
 */
internal final class NativeResponse: SharedRef<ResponseSink>, ExpoURLSessionDelegate {
  private let dispatchQueue: DispatchQueue

  private(set) var state: ResponseState = .intialized {
    didSet {
      dispatchQueue.async { [weak self] in
        guard let self else {
          return
        }
        self.stateChangeOnceListeners.removeAll { $0(self.state) == true }
      }
    }
  }
  private typealias StateChangeListener = (ResponseState) -> Bool
  private var stateChangeOnceListeners: [StateChangeListener] = []

  private(set) var responseInit: NativeResponseInit?
  private(set) var redirected = false
  private(set) var error: Error?

  var bodyUsed: Bool {
    return self.ref.bodyUsed
  }

  init(dispatchQueue: DispatchQueue) {
    self.dispatchQueue = dispatchQueue
    super.init(ResponseSink())
  }

  func startStreaming() {
    checkState([.responseReceived])
    state = .bodyStreamingStarted
    let queuedData = self.ref.finalize()
    emit(event: "didReceiveResponseData", arguments: queuedData)
  }

  func cancelStreaming() {
    checkState([.bodyStreamingStarted])
    state = .bodyStreamingCancelled
  }

  /**
   Waits for given states and when it meets the requirement, executes the callback.
   */
  func waitFor(states: [ResponseState], callback: @escaping (ResponseState) -> Void) {
    if states.contains(state) {
      callback(state)
      return
    }
    dispatchQueue.async { [weak self] () in
      guard let self else {
        return
      }
      self.stateChangeOnceListeners.append { newState in
        if states.contains(newState) {
          callback(newState)
          return true
        }
        return false
      }
    }
  }

  /**
   Check valid state machine
   */
  @discardableResult
  private func checkState(_ validStates: [ResponseState]) -> Bool {
    if validStates.contains(self.state) {
      return true
    }

    let validStatesString = validStates.map { "\($0.rawValue)" }.joined(separator: ",")
    NSLog("Invalid state - currentState[\(self.state.rawValue)] validStates[\(validStatesString)]")
    return false
  }

  /**
   Factory of NativeResponseInit
   */
  private static func createResponseInit(response: URLResponse) -> NativeResponseInit? {
    guard let httpResponse = response as? HTTPURLResponse else {
      NSLog("Invalid response type")
      return nil
    }

    let status = httpResponse.statusCode
    let statusText = HTTPURLResponse.localizedString(forStatusCode: status)
    let headers = httpResponse.allHeaderFields.reduce(into: [[String]]()) { result, header in
      if let key = header.key as? String, let value = header.value as? String {
        result.append([key, value])
      }
    }
    let url = httpResponse.url?.absoluteString ?? ""
    return NativeResponseInit(
      headers: headers, status: status, statusText: statusText, url: url
    )
  }

  // MARK: - ExpoURLSessionDelegate implementations

  func urlSessionDidStart(_ session: ExpoURLSession) {
    checkState([.intialized])
    self.state = .started
  }

  func urlSession(_ session: ExpoURLSession, didReceive response: URLResponse) {
    checkState([.started])
    self.responseInit = Self.createResponseInit(response: response)
    self.state = .responseReceived
  }

  func urlSession(_ session: ExpoURLSession, didReceive data: Data) {
    if !checkState([.responseReceived, .bodyStreamingStarted, .bodyStreamingCancelled]) {
      return
    }
    switch state {
    case .responseReceived:
      self.ref.appendBufferBody(data: data)
    case .bodyStreamingStarted:
      emit(event: "didReceiveResponseData", arguments: data)
    case .bodyStreamingCancelled:
      break

    // Invalid states
    case .intialized: break
    case .started: break
    case .bodyCompleted: break
    case .errorReceived: break
    }
  }

  func urlSession(_ session: ExpoURLSession, didRedirect response: URLResponse) {
    self.redirected = true
  }

  func urlSession(_ session: ExpoURLSession, didCompleteWithError error: (any Error)?) {
    if !checkState([.started, .responseReceived, .bodyStreamingStarted, .bodyStreamingCancelled]) {
      return
    }
    switch state {
    case .started:
      break
    case .responseReceived:
      break
    case .bodyStreamingStarted:
      if let error {
        emit(event: "didFailWithError", arguments: error.localizedDescription)
      } else {
        emit(event: "didComplete")
      }
    case .bodyStreamingCancelled:
      break

    // Invalid states
    case .intialized: break
    case .bodyCompleted: break
    case .errorReceived: break
    }

    if let error {
      self.error = error
      state = .errorReceived
    } else {
      state = .bodyCompleted
    }
  }
}

/**
 A data structure to store response body chunks
 */
internal final class ResponseSink {
  private var bodyQueue: [Data] = []
  private var isFinalized = false
  private(set) var bodyUsed = false

  fileprivate func appendBufferBody(data: Data) {
    bodyUsed = true
    bodyQueue.append(data)
  }

  func finalize() -> Data {
    let size = bodyQueue.reduce(0) { $0 + $1.count }
    var result = Data(capacity: size)
    while !bodyQueue.isEmpty {
      let data = bodyQueue.removeFirst()
      result.append(data)
    }
    bodyUsed = true
    isFinalized = true
    return result
  }
}

/**
 States represent for native response.
 */
internal enum ResponseState: Int {
  case intialized = 0
  case started
  case responseReceived
  case bodyCompleted
  case bodyStreamingStarted
  case bodyStreamingCancelled
  case errorReceived
}

/**
 Native data for ResponseInit.
 */
internal struct NativeResponseInit {
  let headers: [[String]]
  let status: Int
  let statusText: String
  let url: String
}
