import iroh, { TunnelConfig, TunnelInfo } from 'libiroh_hos.so'
import { connection } from '@kit.NetworkKit'
import { ConnectionMode, ConnectionProfile } from '../model/ConnectionModels'
import { SessionRepository } from '../repository/SessionRepository'

const IROH_SECRET_BYTES = 32

export class ConnectionRuntimeService {
  private readonly repository: SessionRepository
  private irohRunning: boolean = false
  private openTask: Promise<string> | null = null
  private closeTask: Promise<void> | null = null
  private networkMonitor: connection.NetConnection | null = null
  // unregister requires the exact callback instance passed to register.
  private monitorRegisterCallback: () => void = () => {}

  constructor(repository: SessionRepository) {
    this.repository = repository
  }

  async open(profile: ConnectionProfile, connectTimeoutMs?: number): Promise<string> {
    if (profile.mode === ConnectionMode.HTTP) {
      if (profile.httpBaseUrl.trim().length === 0) {
        throw new Error('Enter the Beszel hub address.')
      }
      return profile.httpBaseUrl.trim()
    }
    if (this.closeTask !== null) {
      await this.closeTask
    }
    if (this.openTask !== null) {
      return this.openTask
    }
    const task = this.openIroh(profile, connectTimeoutMs)
    this.openTask = task
    try {
      return await task
    } finally {
      if (this.openTask === task) {
        this.openTask = null
      }
    }
  }

  // Tunnels are always torn down with abort: a monitoring client never carries
  // state worth a QUIC drain, and graceful stops hang on broken networks.
  async close(): Promise<void> {
    if (this.closeTask !== null) {
      await this.closeTask
      return
    }
    const task = this.closeIroh()
    this.closeTask = task
    try {
      await task
    } finally {
      if (this.closeTask === task) {
        this.closeTask = null
      }
    }
  }

  private async openIroh(profile: ConnectionProfile, connectTimeoutMs?: number): Promise<string> {
    if (!profile.iroh.isUsable()) {
      throw new Error('Scan a valid Heszel Iroh pairing QR code first.')
    }

    if (iroh.getTunnelInfo().state !== 'stopped') {
      await iroh.abortTunnel()
      this.irohRunning = false
    }
    const secretKey = await this.loadOrCreateSecretKey()
    try {
      const config: TunnelConfig = {
        serverEndpointId: profile.iroh.serverEndpointId,
        serverDirectAddresses: profile.iroh.serverDirectAddresses,
        secretKey: secretKey,
        alpn: profile.iroh.alpn
      }
      if (profile.iroh.serverRelayUrl.length > 0) {
        config.serverRelayUrl = profile.iroh.serverRelayUrl
      }
      if (connectTimeoutMs !== undefined) {
        config.connectTimeoutMs = connectTimeoutMs
      }
      const info: TunnelInfo = await iroh.startTunnel(config)
      if (info.localPort <= 0) {
        try {
          await iroh.abortTunnel()
        } catch (_) {
          // A start without a local port leaves nothing worth preserving.
        }
        throw new Error('Iroh did not provide a local tunnel port.')
      }
      this.irohRunning = true
      this.startNetworkMonitor()
      return `http://127.0.0.1:${info.localPort}`
    } catch (error) {
      const nativeError: string = iroh.getLastError()
      if (nativeError.length > 0) {
        throw new Error(nativeError)
      }
      throw error instanceof Error ? error : new Error('Unable to start the Iroh tunnel.')
    }
  }

  private async closeIroh(): Promise<void> {
    if (this.openTask !== null) {
      try {
        await this.openTask
      } catch (_) {
        // A failed open has no live tunnel to preserve.
      }
    }
    // The subscription follows the tunnel: stop it before tearing down so a
    // backgrounded app has no network listener left to wake it.
    this.stopNetworkMonitor()
    if (!this.irohRunning && iroh.getTunnelInfo().state === 'stopped') {
      return
    }
    try {
      await iroh.abortTunnel()
    } finally {
      this.irohRunning = false
    }
  }

  private async loadOrCreateSecretKey(): Promise<Uint8Array> {
    const stored = await this.repository.loadIrohSecret()
    if (stored.length === IROH_SECRET_BYTES) {
      return stored
    }
    const generatedBuffer: ArrayBuffer = iroh.generateSecretKey()
    const generated = new Uint8Array(generatedBuffer)
    if (generated.length !== IROH_SECRET_BYTES) {
      throw new Error('Iroh generated an invalid phone identity key.')
    }
    await this.repository.saveIrohSecret(generated)
    return generated
  }

  // Tell the native tunnel to repath when the device network changes. The
  // command is a no-op without a live tunnel, but it synchronously takes the
  // native tunnel lock, so it must be skipped while a start is still pending.
  private startNetworkMonitor(): void {
    if (this.networkMonitor !== null) {
      return
    }
    try {
      const monitor = connection.createNetConnection()
      const changed = (): void => this.notifyNetworkChange()
      monitor.on('netAvailable', changed)
      monitor.on('netLost', changed)
      monitor.on('netCapabilitiesChange', changed)
      monitor.register(this.monitorRegisterCallback)
      this.networkMonitor = monitor
    } catch (_) {
      // Without monitor callbacks the tunnel still recovers via its own reconnect timers.
    }
  }

  private stopNetworkMonitor(): void {
    const monitor = this.networkMonitor
    if (monitor === null) {
      return
    }
    this.networkMonitor = null
    try {
      // unregister deactivates the whole connection; event callbacks stop with it.
      monitor.unregister(this.monitorRegisterCallback)
    } catch (_) {
      // A stale subscription dies with the process regardless.
    }
  }

  private notifyNetworkChange(): void {
    if (this.openTask !== null) {
      return
    }
    try {
      iroh.networkChange()
    } catch (_) {
      // A failed command on an already-dead tunnel needs no handling.
    }
  }
}
