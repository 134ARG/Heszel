export enum ConnectionMode {
  HTTP = 'http',
  IROH = 'iroh'
}

export enum ConnectionPhase {
  STOPPED = 'stopped',
  CONNECTING = 'connecting',
  READY = 'ready',
  DEGRADED = 'degraded',
  RECOVERING = 'recovering',
  OFFLINE = 'offline'
}

export interface IrohPairingWire {
  type: string
  version: number
  displayName?: string
  serverEndpointId: string
  serverRelayUrl?: string
  serverDirectAddresses?: string[]
  alpn?: string
}

export class IrohPairing {
  type: string = 'iroh-heszel-pairing'
  version: number = 1
  displayName: string = ''
  serverEndpointId: string = ''
  serverRelayUrl: string = ''
  serverDirectAddresses: string[] = []
  alpn: string = 'heszel/beszel-tcp/1'

  isUsable(): boolean {
    return this.type === 'iroh-heszel-pairing' && this.version === 1 &&
      this.serverEndpointId.length > 0 && this.alpn.length > 0
  }

  shortEndpointId(): string {
    if (this.serverEndpointId.length <= 18) {
      return this.serverEndpointId
    }
    return `${this.serverEndpointId.slice(0, 10)}…${this.serverEndpointId.slice(-6)}`
  }
}

export class ConnectionProfile {
  mode: ConnectionMode = ConnectionMode.HTTP
  httpBaseUrl: string = ''
  gatewayKey: string = ''
  iroh: IrohPairing = new IrohPairing()

  canConnect(): boolean {
    if (this.mode === ConnectionMode.IROH) {
      return this.iroh.isUsable()
    }
    return this.httpBaseUrl.trim().length > 0
  }
}

export class LoginRequest {
  mode: ConnectionMode = ConnectionMode.HTTP
  serverUrl: string = ''
  gatewayKey: string = ''
  pairing: IrohPairing = new IrohPairing()
  email: string = ''
  password: string = ''

  toConnectionProfile(): ConnectionProfile {
    const profile = new ConnectionProfile()
    profile.mode = this.mode
    profile.httpBaseUrl = this.serverUrl.trim()
    profile.gatewayKey = this.mode === ConnectionMode.HTTP ? this.gatewayKey.trim() : ''
    profile.iroh = this.pairing
    return profile
  }
}
