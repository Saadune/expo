// Copyright 2015-present 650 Industries. All rights reserved.

package expo.modules.networkfetch

import android.util.Log
import expo.modules.kotlin.sharedobjects.SharedRef
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import okhttp3.Call
import okhttp3.Callback
import okhttp3.Response
import okio.BufferedSource
import java.io.IOException
import java.nio.ByteBuffer

internal class NativeResponse(private val coroutineScope: CoroutineScope) :
  SharedRef<ResponseSink>(ResponseSink()), Callback {
  var state: ResponseState = ResponseState.INITIALIZED
    get() = synchronized(this) { field }
    private set(value) {
      synchronized(this) {
        field = value
      }
      this.stateChangeOnceListeners.removeAll { it(value) }
    }
  private val stateChangeOnceListeners: MutableList<StateChangeListener> = mutableListOf()

  var responseInit: NativeResponseInit? = null
    private set
  var error: Exception? = null
    private set

  val bodyUsed: Boolean
    get() = this.ref.bodyUsed

  fun startStreaming() {
    checkState(listOf(ResponseState.RESPONSE_RECEIVED, ResponseState.BODY_COMPLETED))
    val queuedData = this.ref.finalize()
    emit("didReceiveResponseData", queuedData)
    if (this.state == ResponseState.RESPONSE_RECEIVED) {
      this.state = ResponseState.BODY_STREAMING_STARTED
    } else if (this.state == ResponseState.BODY_COMPLETED) {
      emit("didComplete")
    }
  }

  fun cancelStreaming() {
    checkState(listOf(ResponseState.BODY_STREAMING_STARTED))
    this.state = ResponseState.BODY_STREAMING_CANCELLED
  }

  fun emitRequestCancelled() {
    this.error = NetworkFetchRequestCancelledException()
    this.state = ResponseState.ERROR_RECEIVED
  }

  fun waitForStates(states: List<ResponseState>, callback: (ResponseState) -> Unit) {
    if (states.contains(this.state)) {
      callback(this.state)
      return
    }
    this.stateChangeOnceListeners.add { newState ->
      if (states.contains(newState)) {
        callback(newState)
        return@add true
      }
      return@add false
    }
  }

  //region Callback implementations

  override fun onFailure(call: Call, e: IOException) {
    if (!checkState(
        listOf(
          ResponseState.STARTED,
          ResponseState.RESPONSE_RECEIVED,
          ResponseState.BODY_STREAMING_STARTED,
          ResponseState.BODY_STREAMING_CANCELLED
        )
      )
    ) {
      return
    }

    if (this.state == ResponseState.BODY_STREAMING_STARTED) {
      emit("didFailWithError", e)
    }
    this.error = e
    this.state = ResponseState.ERROR_RECEIVED
  }

  override fun onResponse(call: Call, response: Response) {
    this.responseInit = createResponseInit(response)
    this.state = ResponseState.RESPONSE_RECEIVED

    this.coroutineScope.launch(Dispatchers.IO) {
      val stream = response.body?.source() ?: return@launch
      pumpResponseBodyStream(stream)
      response.close()

      if (this@NativeResponse.state == ResponseState.BODY_STREAMING_STARTED) {
        emit("didComplete")
      }
      this@NativeResponse.state = ResponseState.BODY_COMPLETED
    }
  }

  //endregion Callback implementations

  //region Internals

  private fun checkState(validStates: List<ResponseState>): Boolean {
    if (validStates.contains(this.state)) {
      return true
    }

    val validStatesString = validStates.joinToString(",") { it.intValue.toString() }
    Log.w(TAG, "Invalid state - currentState[${state.intValue}] validStates[$validStatesString]")
    return false
  }

  private fun createResponseInit(response: Response): NativeResponseInit {
    val status = response.code
    val statusText = response.message
    val headers = response.headers.map { header ->
      header.first to header.second
    }
    val redirected = response.isRedirect
    val url = response.request.url.toString()
    return NativeResponseInit(
      headers = headers,
      status = status,
      statusText = statusText,
      url = url,
      redirected = redirected
    )
  }

  private fun pumpResponseBodyStream(stream: BufferedSource) {
    while (!stream.exhausted()) {
      if (!checkState(
          listOf(
            ResponseState.RESPONSE_RECEIVED,
            ResponseState.BODY_STREAMING_STARTED,
            ResponseState.BODY_STREAMING_CANCELLED
          )
        )
      ) {
        break
      }
      if (this.state == ResponseState.RESPONSE_RECEIVED) {
        ref.appendBufferBody(stream.buffer.readByteArray())
      } else if (this.state == ResponseState.BODY_STREAMING_STARTED) {
        emit("didReceiveResponseData", stream.buffer.readByteArray())
      } else {
        break
      }
    }
  }

  //endregion Internals

  companion object {
    private val TAG = NativeResponse::class.java.simpleName
  }
}

private typealias StateChangeListener = (ResponseState) -> Boolean

internal class ResponseSink {
  private val bodyQueue: MutableList<ByteArray> = mutableListOf()
  private var isFinalized = false
  var bodyUsed = false
    private set

  internal fun appendBufferBody(data: ByteArray) {
    bodyUsed = true
    bodyQueue.add(data)
  }

  fun finalize(): ByteArray {
    val size = bodyQueue.sumOf { it.size }
    val byteBuffer = ByteBuffer.allocate(size)
    for (byteArray in bodyQueue) {
      byteBuffer.put(byteArray)
    }
    bodyQueue.clear()
    bodyUsed = true
    isFinalized = true
    return byteBuffer.array()
  }
}

internal enum class ResponseState(val intValue: Int) {
  INITIALIZED(0),
  STARTED(1),
  RESPONSE_RECEIVED(2),
  BODY_COMPLETED(3),
  BODY_STREAMING_STARTED(4),
  BODY_STREAMING_CANCELLED(5),
  ERROR_RECEIVED(6)
}

internal data class NativeResponseInit(
  val headers: List<Pair<String, String>>,
  val status: Int,
  val statusText: String,
  val url: String,
  val redirected: Boolean
)
