import { NetworkFetchError } from './FetchErrors';
import { FetchResponse } from './FetchResponse';
import { NativeRequest, NativeRequestInit, NativeResponse } from './NativeRequest';
import { convertFormData, normalizeBodyInitAsync, normalizeHeadersInit } from './RequestUtils';
import type { FetchRequestInit } from './fetch.types';
import { requireNativeModule } from '../requireNativeModule';

const NetworkFetchModule = requireNativeModule('ExpoNetworkFetchModule');

export async function fetch(url: string, init?: FetchRequestInit): Promise<FetchResponse> {
  const response = new NetworkFetchModule.NativeResponse() as NativeResponse;
  const request = new NetworkFetchModule.NativeRequest(response) as NativeRequest;

  const headers = normalizeHeadersInit(init?.headers);

  let requestBody: Uint8Array | null;
  if (init?.body instanceof FormData) {
    const { body, boundary } = convertFormData(init?.body);
    headers.push(['Content-Type', `multipart/form-data; boundary=${boundary}`]);
    const encoder = new TextEncoder();
    requestBody = encoder.encode(body);
  } else {
    requestBody = await normalizeBodyInitAsync(init?.body);
  }

  const nativeRequestInit: NativeRequestInit = {
    credentials: init?.credentials ?? 'include',
    headers,
    method: init?.method ?? 'GET',
  };

  if (init?.signal && init.signal.aborted) {
    throw new NetworkFetchError('The operation was aborted.');
  }
  const abortHandler = () => {
    request.cancel();
  };
  init?.signal?.addEventListener('abort', abortHandler);
  try {
    await request.start(url, nativeRequestInit, requestBody);
  } catch (e: unknown) {
    if (e instanceof Error) {
      throw NetworkFetchError.createFromError(e);
    } else {
      throw new NetworkFetchError(String(e));
    }
  } finally {
    init?.signal?.removeEventListener('abort', abortHandler);
  }
  return new FetchResponse(response);
}
