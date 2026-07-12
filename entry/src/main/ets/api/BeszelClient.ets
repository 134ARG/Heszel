import { http } from '@kit.NetworkKit'
import {
  BeszelAuthWire,
  BeszelErrorWire,
  BeszelSession,
  BeszelSystemListWire,
  BeszelSystemWire,
  SystemSummary
} from '../model/BeszelModels'
import {
  BeszelContainerStatsListWire,
  BeszelContainerStatsRecordWire,
  BeszelSystemDetailsWire,
  BeszelSystemStatsListWire,
  BeszelSystemStatsRecordWire
} from '../model/SystemDetailModels'

interface LoginBody {
  identity: string
  password: string
}

export class BeszelApiError extends Error {
  readonly responseCode: number

  constructor(message: string, responseCode: number) {
    super(message)
    this.responseCode = responseCode
  }
}

export class BeszelClient {
  private readonly baseUrl: string
  private readonly gatewayKey: string

  constructor(baseUrl: string, gatewayKey: string = '') {
    this.baseUrl = BeszelClient.normalizeBaseUrl(baseUrl)
    this.gatewayKey = gatewayKey.trim()
  }

  static normalizeBaseUrl(value: string): string {
    let normalized = value.trim()
    while (normalized.endsWith('/')) {
      normalized = normalized.slice(0, normalized.length - 1)
    }
    if (!normalized.startsWith('https://') && !normalized.startsWith('http://')) {
      throw new Error('Server URL must start with https:// or http://.')
    }
    return normalized
  }

  async login(email: string, password: string): Promise<BeszelSession> {
    const request = http.createHttp()
    const body: LoginBody = {
      identity: email.trim(),
      password: password
    }

    try {
      const response = await request.request(
        `${this.baseUrl}/api/collections/users/auth-with-password`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'X-Heszel-Key': this.gatewayKey
          },
          extraData: JSON.stringify(body),
          connectTimeout: 15000,
          readTimeout: 15000
        }
      )
      const responseText = response.result.toString()
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new BeszelApiError(
          this.readError(responseText, 'Sign-in failed. Check the server and credentials.'),
          response.responseCode
        )
      }

      const auth = JSON.parse(responseText) as BeszelAuthWire
      if (auth.token.length === 0) {
        throw new Error('Beszel returned an empty authentication token.')
      }

      const session = new BeszelSession()
      session.baseUrl = this.baseUrl
      session.token = auth.token
      session.email = email.trim()
      session.gatewayKey = this.gatewayKey
      return session
    } catch (error) {
      throw this.asError(error, 'Unable to reach the Beszel hub.')
    } finally {
      request.destroy()
    }
  }

  async refreshSession(token: string, email: string): Promise<BeszelSession> {
    const request = http.createHttp()
    try {
      const response = await request.request(
        `${this.baseUrl}/api/collections/users/auth-refresh`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Accept': 'application/json',
            'Authorization': token,
            'X-Heszel-Key': this.gatewayKey
          },
          connectTimeout: 15000,
          readTimeout: 15000
        }
      )
      const responseText = response.result.toString()
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new BeszelApiError(
          this.readError(responseText, 'The saved Beszel session is no longer valid.'),
          response.responseCode
        )
      }

      const auth = JSON.parse(responseText) as BeszelAuthWire
      if (auth.token.length === 0) {
        throw new Error('Beszel returned an empty refreshed token.')
      }

      const session = new BeszelSession()
      session.baseUrl = this.baseUrl
      session.token = auth.token
      session.email = email
      session.gatewayKey = this.gatewayKey
      return session
    } catch (error) {
      throw this.asError(error, 'Unable to refresh the saved Beszel session.')
    } finally {
      request.destroy()
    }
  }

  async listSystems(token: string): Promise<SystemSummary[]> {
    const request = http.createHttp()
    const path = '/api/collections/systems/records' +
      '?page=1&perPage=500&sort=name&fields=id%2Cname%2Chost%2Cstatus%2Cinfo%2Cupdated'

    try {
      const response = await request.request(`${this.baseUrl}${path}`, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json',
          'Authorization': token,
          'X-Heszel-Key': this.gatewayKey
        },
        connectTimeout: 15000,
        readTimeout: 15000
      })
      const responseText = response.result.toString()
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new BeszelApiError(
          this.readError(responseText, 'Unable to load systems from Beszel.'),
          response.responseCode
        )
      }

      const wire = JSON.parse(responseText) as BeszelSystemListWire
      const systems: SystemSummary[] = []
      wire.items.forEach((record: BeszelSystemWire) => {
        systems.push(SystemSummary.fromWire(record))
      })
      systems.sort((left: SystemSummary, right: SystemSummary) => {
        if (left.isUp() !== right.isUp()) {
          return left.isUp() ? 1 : -1
        }
        return left.name.localeCompare(right.name)
      })
      return systems
    } catch (error) {
      throw this.asError(error, 'Unable to load systems from Beszel.')
    } finally {
      request.destroy()
    }
  }

  async getSystemDetails(token: string, systemId: string): Promise<BeszelSystemDetailsWire | null> {
    const request = http.createHttp()
    const fields = 'id,hostname,kernel,cores,threads,cpu,os,os_name,arch,memory,podman,updated'
    try {
      const response = await request.request(
        `${this.baseUrl}/api/collections/system_details/records/${encodeURIComponent(systemId)}?fields=${fields}`,
        {
          method: http.RequestMethod.GET,
          header: {
            'Accept': 'application/json',
            'Authorization': token,
            'X-Heszel-Key': this.gatewayKey
          },
          connectTimeout: 15000,
          readTimeout: 15000
        }
      )
      if (response.responseCode === 404) {
        return null
      }
      const responseText = response.result.toString()
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new BeszelApiError(this.readError(responseText, 'Unable to load system details.'), response.responseCode)
      }
      return JSON.parse(responseText) as BeszelSystemDetailsWire
    } catch (error) {
      throw this.asError(error, 'Unable to load system details.')
    } finally {
      request.destroy()
    }
  }

  async getLatestSystemStats(token: string, systemId: string): Promise<BeszelSystemStatsRecordWire | null> {
    const request = http.createHttp()
    const filter = encodeURIComponent(`system="${systemId}"`)
    const path = `/api/collections/system_stats/records?page=1&perPage=1&sort=-created&filter=${filter}&fields=created,stats`
    try {
      const response = await request.request(`${this.baseUrl}${path}`, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json',
          'Authorization': token,
          'X-Heszel-Key': this.gatewayKey
        },
        connectTimeout: 15000,
        readTimeout: 15000
      })
      const responseText = response.result.toString()
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new BeszelApiError(this.readError(responseText, 'Unable to load detailed metrics.'), response.responseCode)
      }
      const wire = JSON.parse(responseText) as BeszelSystemStatsListWire
      return wire.items.length > 0 ? wire.items[0] : null
    } catch (error) {
      throw this.asError(error, 'Unable to load detailed metrics.')
    } finally {
      request.destroy()
    }
  }

  async getLatestContainerStats(token: string, systemId: string): Promise<BeszelContainerStatsRecordWire | null> {
    const request = http.createHttp()
    const filter = encodeURIComponent(`system="${systemId}"`)
    const path = `/api/collections/container_stats/records?page=1&perPage=1&sort=-created&filter=${filter}&fields=created,stats`
    try {
      const response = await request.request(`${this.baseUrl}${path}`, {
        method: http.RequestMethod.GET,
        header: {
          'Accept': 'application/json',
          'Authorization': token,
          'X-Heszel-Key': this.gatewayKey
        },
        connectTimeout: 15000,
        readTimeout: 15000
      })
      const responseText = response.result.toString()
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new BeszelApiError(this.readError(responseText, 'Unable to load container metrics.'), response.responseCode)
      }
      const wire = JSON.parse(responseText) as BeszelContainerStatsListWire
      return wire.items.length > 0 ? wire.items[0] : null
    } catch (error) {
      throw this.asError(error, 'Unable to load container metrics.')
    } finally {
      request.destroy()
    }
  }

  private readError(responseText: string, fallback: string): string {
    try {
      const error = JSON.parse(responseText) as BeszelErrorWire
      return error.message ?? fallback
    } catch (_) {
      return fallback
    }
  }

  private asError(error: Object, fallback: string): Error {
    if (error instanceof Error && error.message.length > 0) {
      return error
    }
    return new Error(fallback)
  }
}
