import { common } from '@kit.AbilityKit'
import { preferences } from '@kit.ArkData'
import { util } from '@kit.ArkTS'
import { asset } from '@kit.AssetStoreKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { BeszelSession } from '../model/BeszelModels'

const PREFERENCES_NAME = 'heszel_session'
const KEY_BASE_URL = 'base_url'
const KEY_EMAIL = 'email'
const KEY_SELECTED_SYSTEM = 'selected_system'
const KEY_UPDATE_WHILE_SCROLLING = 'update_while_scrolling'
const TOKEN_ALIAS = 'heszel.beszel.auth-token'
const GATEWAY_KEY_ALIAS = 'heszel.gateway.header-key'
const ASSET_NOT_FOUND = 24000002

export class StoredSession {
  baseUrl: string = ''
  email: string = ''
  token: string = ''
  gatewayKey: string = ''
  selectedSystemId: string = ''
  updateWhileScrolling: boolean = false

  canRestore(): boolean {
    return this.baseUrl.length > 0 && this.email.length > 0 && this.token.length > 0
  }
}

export class SessionRepository {
  private readonly context: common.Context
  private store: preferences.Preferences | null = null
  private readonly encoder: util.TextEncoder = util.TextEncoder.create('utf-8')
  private readonly decoder: util.TextDecoder = util.TextDecoder.create('utf-8')

  constructor(context: common.Context) {
    this.context = context
  }

  async load(): Promise<StoredSession> {
    try {
      const stored = new StoredSession()
      const store = await this.getStore()
      stored.baseUrl = await store.get(KEY_BASE_URL, '') as string
      stored.email = await store.get(KEY_EMAIL, '') as string
      stored.selectedSystemId = await store.get(KEY_SELECTED_SYSTEM, '') as string
      stored.updateWhileScrolling = await store.get(KEY_UPDATE_WHILE_SCROLLING, false) as boolean
      stored.token = await this.readToken()
      stored.gatewayKey = await this.readSecret(GATEWAY_KEY_ALIAS)
      return stored
    } catch (error) {
      throw this.storageError(error, 'Unable to load the saved Heszel session.')
    }
  }

  async saveSession(session: BeszelSession, selectedSystemId: string): Promise<void> {
    try {
      const store = await this.getStore()
      await store.put(KEY_BASE_URL, session.baseUrl)
      await store.put(KEY_EMAIL, session.email)
      await store.put(KEY_SELECTED_SYSTEM, selectedSystemId)
      await store.flush()
      await this.replaceToken(session.token)
      await this.replaceSecret(GATEWAY_KEY_ALIAS, session.gatewayKey)
    } catch (error) {
      throw this.storageError(error, 'Unable to save the Heszel session.')
    }
  }

  async saveSelectedSystem(id: string): Promise<void> {
    try {
      const store = await this.getStore()
      await store.put(KEY_SELECTED_SYSTEM, id)
      await store.flush()
    } catch (error) {
      throw this.storageError(error, 'Unable to save the selected system.')
    }
  }

  async saveGatewayKey(gatewayKey: string): Promise<void> {
    await this.replaceSecret(GATEWAY_KEY_ALIAS, gatewayKey.trim())
  }

  async saveUpdateWhileScrolling(enabled: boolean): Promise<void> {
    try {
      const store = await this.getStore()
      await store.put(KEY_UPDATE_WHILE_SCROLLING, enabled)
      await store.flush()
    } catch (error) {
      throw this.storageError(error, 'Unable to save the scrolling update preference.')
    }
  }

  async clearToken(): Promise<void> {
    await this.clearSecret(TOKEN_ALIAS)
  }

  private async clearSecret(alias: string): Promise<void> {
    const query = this.secretQuery(alias, false)
    try {
      await asset.remove(query)
    } catch (error) {
      const businessError = error as BusinessError
      if (businessError.code !== ASSET_NOT_FOUND) {
        throw new Error(businessError.message)
      }
    }
  }

  private async getStore(): Promise<preferences.Preferences> {
    if (this.store === null) {
      try {
        this.store = await preferences.getPreferences(this.context, PREFERENCES_NAME)
      } catch (error) {
        throw this.storageError(error, 'Unable to open Heszel preferences.')
      }
    }
    return this.store
  }

  private async readToken(): Promise<string> {
    return this.readSecret(TOKEN_ALIAS)
  }

  private async readSecret(alias: string): Promise<string> {
    try {
      const results = await asset.query(this.secretQuery(alias, true))
      if (results.length === 0) {
        return ''
      }
      const secret = results[0].get(asset.Tag.SECRET)
      if (!(secret instanceof Uint8Array)) {
        return ''
      }
      return this.decoder.decodeToString(secret)
    } catch (error) {
      const businessError = error as BusinessError
      if (businessError.code === ASSET_NOT_FOUND) {
        return ''
      }
      throw new Error(businessError.message)
    }
  }

  private async replaceToken(token: string): Promise<void> {
    await this.replaceSecret(TOKEN_ALIAS, token)
  }

  private async replaceSecret(alias: string, secret: string): Promise<void> {
    try {
      await this.clearSecret(alias)
      if (secret.length === 0) {
        return
      }
      const attributes: asset.AssetMap = new Map<asset.Tag, asset.Value>()
      attributes.set(asset.Tag.ALIAS, this.encoder.encodeInto(alias))
      attributes.set(asset.Tag.SECRET, this.encoder.encodeInto(secret))
      attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED)
      await asset.add(attributes)
    } catch (error) {
      throw this.storageError(error, 'Unable to protect a Heszel secret.')
    }
  }

  private secretQuery(alias: string, includeSecret: boolean): asset.AssetMap {
    const query: asset.AssetMap = new Map<asset.Tag, asset.Value>()
    query.set(asset.Tag.ALIAS, this.encoder.encodeInto(alias))
    if (includeSecret) {
      query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
      query.set(asset.Tag.RETURN_LIMIT, 1)
    }
    return query
  }

  private storageError(error: Object, fallback: string): Error {
    if (error instanceof Error && error.message.length > 0) {
      return error
    }
    return new Error(fallback)
  }
}
