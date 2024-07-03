import type { SharedObject } from '../ts-declarations/SharedObject';
export declare class NativeRequest extends SharedObject {
    start(url: string, requestInit: NativeRequestInit, requestBody: Uint8Array | null): Promise<NativeResponse>;
    cancel(): void;
}
export interface NativeRequestInit {
    credentials?: RequestCredentials;
    headers?: [string, string][];
    method?: string;
}
export type NativeResponseEvents = {
    didReceiveResponseData(data: Uint8Array): void;
    didComplete(): void;
    didFailWithError(error: string): void;
};
export declare class NativeResponse extends SharedObject<NativeResponseEvents> {
    readonly bodyUsed: boolean;
    readonly headers: [string, string][];
    readonly status: number;
    readonly statusText: string;
    readonly url: string;
    readonly redirected: boolean;
    startStreaming(): void;
    cancelStreaming(reason: string): void;
    arrayBuffer(): Promise<ArrayBuffer>;
    text(): Promise<string>;
}
//# sourceMappingURL=NativeRequest.d.ts.map