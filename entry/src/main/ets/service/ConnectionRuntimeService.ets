import iroh from 'libiroh_hos.so'
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

  private async openIroh(profile: ConnectionProfile): Promise<string> {
    if (!profile.iroh.isUsable()) {
      throw new Error('Scan a valid Heszel Iroh pairing QR code first.')
    }

    if (iroh.getTunnelInfo().state !== 'stopped') {
      await iroh.stopTunnel()
      this.irohRunning = false
    }
    const secretKey = await this.loadOrCreateSecretKey()
    try {
      const info = await iroh.startTunnel({
        serverEndpointId: profile.iroh.serverEndpointId,
        serverRelayUrl: profile.iroh.serverRelayUrl.length > 0 ? profile.iroh.serverRelayUrl : undefined,
        serverDirectAddresses: profile.iroh.serverDirectAddresses,
        secretKey: secretKey,
        alpn: profile.iroh.alpn
      })
      if (info.localPort <= 0) {
        throw new Error('Iroh did not provide a local tunnel port.')
      }
      this.irohRunning = true
      return `http://127.0.0.1:${info.localPort}`
    } catch (error) {
      const nativeError = iroh.getLastError()
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
    if (!this.irohRunning && iroh.getTunnelInfo().state === 'stopped') {
      return
    }
    try {
      iroh.suspendTunnel()
      await iroh.stopTunnel()
    } finally {
      this.irohRunning = false
    }
  }

  private async loadOrCreateSecretKey(): Promise<Uint8Array> {
    const stored = await this.repository.loadIrohSecret()
    if (stored.length === IROH_SECRET_BYTES) {
      return stored
    }
    const generated = new Uint8Array(iroh.generateSecretKey())
    if (generated.length !== IROH_SECRET_BYTES) {
      throw new Error('Iroh generated an invalid phone identity key.')
    }
    await this.repository.saveIrohSecret(generated)
    return generated
  }
}
