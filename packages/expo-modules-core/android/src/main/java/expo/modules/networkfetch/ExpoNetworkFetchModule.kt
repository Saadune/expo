// Copyright 2015-present 650 Industries. All rights reserved.

package expo.modules.networkfetch

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import okhttp3.OkHttpClient
import java.net.URL
import java.util.concurrent.TimeUnit

@Suppress("unused")
class ExpoNetworkFetchModule : Module() {
  private val client = OkHttpClient.Builder()
    .connectTimeout(1000, TimeUnit.MILLISECONDS)
//    .readTimeout(100, TimeUnit.MILLISECONDS)
    .build()

  override fun definition() = ModuleDefinition {
    Name("ExpoNetworkFetchModule")

    Events(
      "didReceiveResponseData",
      "didComplete",
      "didFailWithError"
    )

    Class(NativeRequest::class) {
      Constructor {
        return@Constructor NativeRequest(client)
      }

      AsyncFunction("sendRequestAsync") { nativeRequest: NativeRequest, url: URL ->
        nativeRequest.sendRequest(url)
      }
    }
  }
}
