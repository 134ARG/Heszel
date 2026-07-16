import { BeszelClient } from '../api/BeszelClient'
import { BeszelRealtimeClient, BeszelRealtimeMetrics } from '../api/BeszelRealtimeClient'
import { BeszelSession, SystemSummary } from '../model/BeszelModels'

const METRICS_TIMEOUT_MS = 8000

export class SystemRealtimeSample {
  systemId: string = ''
  metrics: BeszelRealtimeMetrics = {}
}

class RealtimeBatchResult {
  samples: SystemRealtimeSample[] = []
  error: Error | null = null
}

export class SystemRefreshResult {
  systems: SystemSummary[] = []
  metrics: BeszelRealtimeMetrics | null = null
  systemMetrics: SystemRealtimeSample[] = []
  metricsError: Error | null = null
  refreshedAt: string = ''
}

export class SystemRefreshService {
  private cancelled: boolean = false
  private cancelMetricsRequest: (() => void) | null = null

  async refresh(client: BeszelClient, session: BeszelSession, selectedSystemId: string,
    requestRealtimeMetrics: boolean = true): Promise<SystemRefreshResult> {
    const result = new SystemRefreshResult()
    result.systems = await client.listSystems(session.token)
    if (this.cancelled) {
      throw new Error('Refresh cancelled.')
    }
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

  async refreshAll(client: BeszelClient, session: BeszelSession): Promise<SystemRefreshResult> {
    const result = new SystemRefreshResult()
    result.systems = await client.listSystems(session.token)
    if (this.cancelled) {
      throw new Error('Refresh cancelled.')
    }

    const onlineIds = result.systems
      .filter((system: SystemSummary) => system.isUp())
      .map((system: SystemSummary) => system.id)
    if (onlineIds.length > 0) {
      const batch = await this.requestMetricsBatch(session, onlineIds)
      result.systemMetrics = batch.samples
      result.metricsError = batch.error
      result.systemMetrics.forEach((sample: SystemRealtimeSample) => {
        const system = result.systems.find((candidate: SystemSummary) => candidate.id === sample.systemId)
        if (system !== undefined && sample.metrics.info !== undefined) {
          system.updateCardMetrics(sample.metrics.info)
        }
      })
    }
    result.refreshedAt = new Date().toLocaleTimeString()
    return result
  }

  cancel(): void {
    this.cancelled = true
    const cancel = this.cancelMetricsRequest
    this.cancelMetricsRequest = null
    if (cancel !== null) {
      cancel()
    }
  }

  private async requestMetrics(session: BeszelSession, systemId: string): Promise<BeszelRealtimeMetrics> {
    const batch = await this.requestMetricsBatch(session, [systemId])
    const sample = batch.samples.find((candidate: SystemRealtimeSample) => candidate.systemId === systemId)
    if (sample !== undefined) {
      return sample.metrics
    }
    throw batch.error ?? new Error('Unable to receive realtime metrics.')
  }

  private requestMetricsBatch(session: BeszelSession, systemIds: string[]): Promise<RealtimeBatchResult> {
    return new Promise((resolve: (result: RealtimeBatchResult) => void, reject: (error: Error) => void) => {
      let realtime: BeszelRealtimeClient | null = null
      let timeout: number = -1
      let complete: boolean = false
      let cancel: (() => void) | null = null
      const pending = new Set<string>(systemIds)
      const received = new Map<string, SystemRealtimeSample>()

      const finish = (error: Error | null, cancelled: boolean = false): void => {
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
        if (cancel !== null && this.cancelMetricsRequest === cancel) {
          this.cancelMetricsRequest = null
        }
        if (cancelled) {
          reject(error ?? new Error('Refresh cancelled.'))
          return
        }
        const result = new RealtimeBatchResult()
        received.forEach((sample: SystemRealtimeSample) => result.samples.push(sample))
        result.error = error
        resolve(result)
      }

      cancel = () => finish(new Error('Refresh cancelled.'), true)
      this.cancelMetricsRequest = cancel

      realtime = new BeszelRealtimeClient(
        session.baseUrl,
        session.token,
        session.gatewayKey,
        () => {},
        (receivedSystemId: string, metrics: BeszelRealtimeMetrics) => {
          if (!pending.has(receivedSystemId) ||
            (metrics.info === undefined && metrics.stats === undefined)) {
            return
          }
          const sample = new SystemRealtimeSample()
          sample.systemId = receivedSystemId
          sample.metrics = metrics
          received.set(receivedSystemId, sample)
          pending.delete(receivedSystemId)
          if (pending.size === 0) {
            finish(null)
          }
        },
        () => {},
        (error: Error) => finish(error)
      )
      realtime.setMetricsSystems(systemIds)
      realtime.connect()
      timeout = setTimeout(() => {
        finish(new Error(`Realtime metrics timed out for ${pending.size} system(s).`))
      }, METRICS_TIMEOUT_MS)
    })
  }
}
