// Copyright 2015-present 650 Industries. All rights reserved.

package expo.modules.networkfetch

import expo.modules.kotlin.sharedobjects.SharedRef
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.IOException
import java.net.URL

internal class NativeRequest(client: OkHttpClient) : SharedRef<OkHttpClient>(client), Callback {
  fun sendRequest(url: URL) {
    val request = Request.Builder()
      .url(url)
      .get()
      .build()
    this.ref.newCall(request).enqueue(this)
  }

  override fun onResponse(call: Call, response: Response) {
    response.use {
      if (!response.isSuccessful) {
        emit("didFailWithError", "Failed request - status[${response.code}")
        return
      }
      val stream = response.body?.source() ?: return
      while (!stream.exhausted()) {
        val byteArray = stream.buffer.readByteArray()
        emit("didReceiveResponseData", byteArray)
      }
      emit("didComplete")
    }
  }

  override fun onFailure(call: Call, e: IOException) {
    emit("didFailWithError", e.message)
  }
}
