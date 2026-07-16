import iroh, { TunnelConfig, TunnelInfo } from 'libiroh_hos.so'
import { ConnectionMode, ConnectionProfile } from '../model/ConnectionModels'
import { SessionRepository } from '../repository/SessionRepository'

const IROH_SECRET_BYTES = 32

export class ConnectionRuntimeService {
  private readonly repository: SessionRepository
  private irohRunning: boolean = false
  private openTask: Promise<string> | null = null
  private closeTask: Promise<void> | null = null

  constructor(repository: SessionRepository) {
    this.repository = repository
  }

  async open(profile: ConnectionProfile): Promise<string> {
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
    const task = this.openIroh(profile)
    this.openTask = task
    try {
      return await task
    } finally {
      if (this.openTask === task) {
        this.openTask = null
      }
    }
  }

  async close(): Promise<void> {
    await this.closeWithMode(false)
  }

  async closeImmediately(): Promise<void> {
    await this.closeWithMode(true)
  }

  private async closeWithMode(immediate: boolean): Promise<void> {
    if (this.closeTask !== null) {
      await this.closeTask
      return
    }
    const task = this.closeIroh(immediate)
    this.closeTask = task
    try {
      await task
    } finally {
      if (this.closeTask === task) {
        this.closeTask = null
      }
    }
  }

  private async openIroh(profile: ConnectionProfile): Promise<string> {
    if (!profile.iroh.isUsable()) {
      throw new Error('Scan a valid Heszel Iroh pairing QR code first.')
    }

    const currentInfo: TunnelInfo = iroh.getTunnelInfo()
    if (currentInfo.state !== 'stopped') {
      await iroh.stopTunnel()
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
      const info: TunnelInfo = await iroh.startTunnel(config)
      if (info.localPort <= 0) {
        throw new Error('Iroh did not provide a local tunnel port.')
      }
      this.irohRunning = true
      return `http://127.0.0.1:${info.localPort}`
    } catch (error) {
      const nativeError: string = iroh.getLastError()
      if (nativeError.length > 0) {
        throw new Error(nativeError)
      }
      throw error instanceof Error ? error : new Error('Unable to start the Iroh tunnel.')
    }
  }

  private async closeIroh(immediate: boolean): Promise<void> {
    if (this.openTask !== null) {
      try {
        await this.openTask
      } catch (_) {
        // A failed open has no live tunnel to preserve.
      }
    }
    const currentInfo: TunnelInfo = iroh.getTunnelInfo()
    if (!this.irohRunning && currentInfo.state === 'stopped') {
      return
    }
    try {
      if (immediate) {
        await iroh.abortTunnel()
      } else {
        iroh.suspendTunnel()
        await iroh.stopTunnel()
      }
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
}
