import { BeszelClient } from '../api/BeszelClient'
import { BeszelRealtimeClient, BeszelRealtimeMetrics } from '../api/BeszelRealtimeClient'
import { BeszelSession, SystemSummary } from '../model/BeszelModels'

const METRICS_TIMEOUT_MS = 8000

export class SystemRefreshResult {
  systems: SystemSummary[] = []
  metrics: BeszelRealtimeMetrics | null = null
  metricsError: Error | null = null
  refreshedAt: string = ''
}

export class SystemRefreshService {
  async refresh(client: BeszelClient, session: BeszelSession, selectedSystemId: string,
    requestRealtimeMetrics: boolean = true): Promise<SystemRefreshResult> {
    const result = new SystemRefreshResult()
    result.systems = await client.listSystems(session.token)
    const selected = result.systems.find((system: SystemSummary) => system.id === selectedSystemId)
    if (requestRealtimeMetrics && selected !== undefined && selected.isUp()) {
      try {
        result.metrics = await this.requestMetrics(session, selected.id)
        if (result.metrics.info !== undefined) {
          selected.updateCardMetrics(result.metrics.info)
        }
      } catch (error) {
        result.metricsError = error instanceof Error ? error : new Error('Unable to receive realtime metrics.')
      }
    }
    result.refreshedAt = new Date().toLocaleTimeString()
    return result
  }

  private requestMetrics(session: BeszelSession, systemId: string): Promise<BeszelRealtimeMetrics> {
    return new Promise((resolve: (metrics: BeszelRealtimeMetrics) => void, reject: (error: Error) => void) => {
      let realtime: BeszelRealtimeClient | null = null
      let timeout: number = -1
      let complete: boolean = false

      const finish = (metrics: BeszelRealtimeMetrics | null, error: Error | null): void => {
        if (complete) {
          return
        }
        complete = true
        if (timeout >= 0) {
          clearTimeout(timeout)
          timeout = -1
        }
        if (realtime !== null) {
          realtime.disconnect()
          realtime = null
        }
        if (metrics !== null) {
          resolve(metrics)
        } else {
          reject(error ?? new Error('Unable to receive realtime metrics.'))
        }
      }

      realtime = new BeszelRealtimeClient(
        session.baseUrl,
        session.token,
        session.gatewayKey,
        () => {},
        (receivedSystemId: string, metrics: BeszelRealtimeMetrics) => {
          if (receivedSystemId === systemId && metrics.info !== undefined) {
            finish(metrics, null)
          }
        },
        () => {},
        (error: Error) => finish(null, error)
      )
      realtime.setMetricsSystem(systemId)
      realtime.connect()
      timeout = setTimeout(() => {
        finish(null, new Error('Realtime metrics timed out.'))
      }, METRICS_TIMEOUT_MS)
    })
  }
}
