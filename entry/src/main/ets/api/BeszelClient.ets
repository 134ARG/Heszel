import { http } from '@kit.NetworkKit'
import {
  BeszelAuthWire,
  BeszelErrorWire,
  BeszelSession,
  BeszelSystemListWire,
  BeszelSystemWire,
  SystemSummary
} from '../model/BeszelModels'

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

  constructor(baseUrl: string) {
    this.baseUrl = BeszelClient.normalizeBaseUrl(baseUrl)
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
            'Content-Type': 'application/json'
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
            'Authorization': token
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
          'Authorization': token
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
