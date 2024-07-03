// Copyright 2015-present 650 Industries. All rights reserved.

internal class NetworkFetchUnknownException: Exception {
  override var reason: String {
    "Unknown error"
  }
}
