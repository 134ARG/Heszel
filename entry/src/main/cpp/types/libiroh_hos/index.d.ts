export type TunnelState =
  | 'stopped'
  | 'starting'
  | 'connecting'
  | 'connected'
  | 'reconnecting'
  | 'suspended';

export interface TunnelConfig {
  serverEndpointId: string;
  secretKey: ArrayBuffer | Uint8Array;
  serverRelayUrl?: string;
  serverDirectAddresses?: string[];
  alpn?: string;
  useDefaultRelays?: boolean;
  connectTimeoutMs?: number;
  reconnectMinDelayMs?: number;
  reconnectMaxDelayMs?: number;
}

export interface TunnelInfo {
  state: TunnelState;
  localPort: number;
  localEndpointId: string;
}

declare const irohHos: {
  startTunnel: (config: TunnelConfig) => Promise<TunnelInfo>;
  stopTunnel: () => Promise<void>;
  abortTunnel: () => Promise<void>;
  suspendTunnel: () => void;
  resumeTunnel: () => void;
  networkChange: () => void;
  getTunnelInfo: () => TunnelInfo;
  getLastError: () => string;
  generateSecretKey: () => ArrayBuffer;
  endpointId: (secretKey: ArrayBuffer | Uint8Array) => string;
  version: () => string;
  abiVersion: () => number;
};

export default irohHos;
