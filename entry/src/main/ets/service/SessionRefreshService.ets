import { BeszelApiError, BeszelClient } from '../api/BeszelClient'
import { BeszelSession } from '../model/BeszelModels'

export class BeszelSessionRejectedError extends Error {
  constructor(message: string) {
    super(message)
  }
}

export class SessionRefreshService {
  async execute<T>(client: BeszelClient, session: BeszelSession,
    operation: (activeSession: BeszelSession) => Promise<T>,
    onSessionRefreshed: (refreshedSession: BeszelSession) => Promise<void>): Promise<T> {
    try {
      return await operation(session)
    } catch (error) {
      if (!SessionRefreshService.isAccessRejected(error)) {
        throw this.asError(error, 'The authenticated Beszel request failed.')
      }
    }

    const refreshed = await this.refresh(client, session)
    await onSessionRefreshed(refreshed)
    try {
      return await operation(refreshed)
    } catch (error) {
      if (SessionRefreshService.isAccessRejected(error)) {
        throw new BeszelSessionRejectedError(this.message(error, 'The Beszel session was rejected.'))
      }
      throw this.asError(error, 'The authenticated Beszel request failed after refreshing the session.')
    }
  }

  async refresh(client: BeszelClient, session: BeszelSession): Promise<BeszelSession> {
    try {
      return await client.refreshSession(session.token, session.email)
    } catch (error) {
      if (SessionRefreshService.refreshWasRejected(error)) {
        throw new BeszelSessionRejectedError(this.message(error, 'The saved Beszel session is no longer valid.'))
      }
      throw this.asError(error, 'Unable to refresh the saved Beszel session.')
    }
  }

  static isSessionRejected(error: Object): boolean {
    return error instanceof BeszelSessionRejectedError
  }

  static isAccessRejected(error: Object): boolean {
    return error instanceof BeszelApiError && (error.responseCode === 401 || error.responseCode === 403)
  }

  private static refreshWasRejected(error: Object): boolean {
    return error instanceof BeszelApiError &&
      (error.responseCode === 400 || error.responseCode === 401 || error.responseCode === 403)
  }

  private message(error: Object, fallback: string): string {
    return error instanceof Error && error.message.length > 0 ? error.message : fallback
  }

  private asError(error: Object, fallback: string): Error {
    return error instanceof Error ? error : new Error(fallback)
  }
}
