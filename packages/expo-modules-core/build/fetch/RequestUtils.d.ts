import { ReadableStream } from 'web-streams-polyfill';
/**
 * convert a ReadableStream to a Uint8Array
 */
export declare function convertReadableStreamToUint8ArrayAsync(stream: ReadableStream<Uint8Array>): Promise<Uint8Array>;
/**
 * Convert FormData to string
 *
 * `uri` is not supported for React Native's FormData.
 * `blob` is not supported for standard FormData.
 */
export declare function convertFormData(formData: FormData): {
    body: string;
    boundary: string;
};
/**
 * Normalize a BodyInit object to a Uint8Array for NativeRequest
 */
export declare function normalizeBodyInitAsync(body: BodyInit | null | undefined): Promise<Uint8Array | null>;
/**
 * Normalize a HeadersInit object to an array of key-value tuple for NativeRequest.
 */
export declare function normalizeHeadersInit(headers: HeadersInit | null | undefined): [string, string][];
//# sourceMappingURL=RequestUtils.d.ts.map