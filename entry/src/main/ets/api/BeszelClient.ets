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
import { BeszelSmartDeviceListWire, BeszelSmartDeviceWire } from '../model/SmartModels'

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
  private activeRequests: Set<http.HttpRequest> = new Set<http.HttpRequest>()

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
    const request = this.createRequest()
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
      this.finishRequest(request)
    }
  }

  async refreshSession(token: string, email: string): Promise<BeszelSession> {
    const request = this.createRequest()
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
      this.finishRequest(request)
    }
  }

  async listSystems(token: string): Promise<SystemSummary[]> {
    const request = this.createRequest()
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
      this.finishRequest(request)
    }
  }

  async getSystemDetails(token: string, systemId: string): Promise<BeszelSystemDetailsWire | null> {
    const request = this.createRequest()
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
      this.finishRequest(request)
    }
  }

  async getSystemStatsHistory(token: string, systemId: string,
    limit: number = 60): Promise<BeszelSystemStatsRecordWire[]> {
    return this.getSystemStatsHistoryByType(token, systemId, '1m', limit)
  }

  async getSystemStatsHistoryByType(token: string, systemId: string,
    recordType: string, limit: number = 100): Promise<BeszelSystemStatsRecordWire[]> {
    const request = this.createRequest()
    const filter = encodeURIComponent(`system='${systemId}' && type='${recordType}'`)
    const path = `/api/collections/system_stats/records?page=1&perPage=${limit}&sort=-created&filter=${filter}` +
      '&fields=created,stats&skipTotal=true'
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
      return wire.items.slice().reverse()
    } catch (error) {
      throw this.asError(error, 'Unable to load detailed metrics.')
    } finally {
      this.finishRequest(request)
    }
  }

  async getLatestContainerStats(token: string, systemId: string): Promise<BeszelContainerStatsRecordWire | null> {
    const request = this.createRequest()
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
      this.finishRequest(request)
    }
  }

  async getSmartDevices(token: string, systemId: string): Promise<BeszelSmartDeviceWire[]> {
    const request = this.createRequest()
    const filter = encodeURIComponent(`system="${systemId}"`)
    const fields = 'id,system,name,model,state,capacity,temp,firmware,serial,type,hours,cycles,attributes,updated'
    const path = `/api/collections/smart_devices/records?page=1&perPage=200&sort=name&filter=${filter}` +
      `&fields=${fields}`
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
        throw new BeszelApiError(this.readError(responseText, 'Unable to load disk health.'), response.responseCode)
      }
      const wire = JSON.parse(responseText) as BeszelSmartDeviceListWire
      return wire.items
    } catch (error) {
      throw this.asError(error, 'Unable to load disk health.')
    } finally {
      this.finishRequest(request)
    }
  }

  cancelPendingRequests(): void {
    this.activeRequests.forEach((request: http.HttpRequest) => request.destroy())
    this.activeRequests.clear()
  }

  private createRequest(): http.HttpRequest {
    const request = http.createHttp()
    this.activeRequests.add(request)
    return request
  }

  private finishRequest(request: http.HttpRequest): void {
    if (this.activeRequests.delete(request)) {
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
