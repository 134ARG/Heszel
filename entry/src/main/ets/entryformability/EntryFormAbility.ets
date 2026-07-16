import { Want } from '@kit.AbilityKit'
import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BeszelClient } from '../api/BeszelClient'
import { BeszelSession } from '../model/BeszelModels'
import { ConnectionMode } from '../model/ConnectionModels'
import { BeszelSystemStatsWire } from '../model/SystemDetailModels'
import { SessionRepository } from '../repository/SessionRepository'
import { WidgetSnapshotRepository } from '../repository/WidgetSnapshotRepository'
import { ConnectionRuntimeService } from '../service/ConnectionRuntimeService'
import { SessionRefreshService } from '../service/SessionRefreshService'
import { SystemRealtimeSample, SystemRefreshResult, SystemRefreshService } from '../service/SystemRefreshService'

const DOMAIN = 0x0000
const TAG = 'HeszelWidget'
const REFRESH_REPLAY_INTERVAL_MS = 1500

interface WidgetEvent {
  event?: string
  page?: string
}

export default class EntryFormAbility extends FormExtensionAbility {
  private refreshInFlight: boolean = false
  private refreshReplayTimer: number = -1
  private refreshReplayTask: Promise<void> | null = null
  private refreshReplayPhase: number = 0

  onAddForm(want: Want): formBindingData.FormBindingData {
    const formId = this.readFormId(want)
    const repository = new WidgetSnapshotRepository(this.context)
    const data = repository.loadSync()
    repository.addForm(formId)
      .catch(() => {})
    return formBindingData.createFormBindingData(data)
  }

  onUpdateForm(formId: string): void {
    new WidgetSnapshotRepository(this.context).updateForm(formId).catch(() => {})
  }

  onFormEvent(formId: string, message: string): void {
    if (formId.length === 0) {
      return
    }
    const event = this.readEvent(message)
    if (event.event === 'page') {
      const page = Number(event.page ?? '0')
      new WidgetSnapshotRepository(this.context).updatePage(formId, Number.isFinite(page) ? page : 0).catch(() => {})
      return
    }
    hilog.info(DOMAIN, TAG, 'Manual card refresh requested.')
    this.refreshSystems().catch((error: Object) => {
      hilog.error(DOMAIN, TAG, 'Manual card refresh failed: %{public}s', this.errorMessage(error))
    })
  }

  onRemoveForm(formId: string): void {
    new WidgetSnapshotRepository(this.context).removeForm(formId).catch(() => {})
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY
  }

  private readFormId(want: Want): string {
    if (want.parameters === undefined) {
      return ''
    }
    const value = want.parameters[formInfo.FormParam.IDENTITY_KEY]
    return value === undefined ? '' : value.toString()
  }

  private readEvent(message: string): WidgetEvent {
    try {
      return JSON.parse(message) as WidgetEvent
    } catch (_) {
      return {}
    }
  }

  private async refreshSystems(): Promise<void> {
    if (this.refreshInFlight) {
      return
    }
    this.refreshInFlight = true
    let connectionRuntime: ConnectionRuntimeService | null = null
    let widgetRepository: WidgetSnapshotRepository | null = null
    let irohOpened: boolean = false
    try {
      const sessionRepository = new SessionRepository(this.context)
      connectionRuntime = new ConnectionRuntimeService(sessionRepository)
      widgetRepository = new WidgetSnapshotRepository(this.context)
      try {
        await widgetRepository.setRefreshing(true, this.refreshReplayPhase)
      } catch (error) {
        hilog.warn(DOMAIN, TAG, 'Unable to publish card refresh state: %{public}s', this.errorMessage(error))
      }
      this.startRefreshReplay(widgetRepository)
      const session = await sessionRepository.load()
      if (!session.canRestore()) {
        hilog.warn(DOMAIN, TAG, 'Manual card refresh has no restorable session.')
        return
      }
      hilog.info(DOMAIN, TAG, 'Manual card refresh is requesting systems.')
      const connection = session.connectionProfile()
      const activeBaseUrl = await connectionRuntime.open(connection)
      irohOpened = connection.mode === ConnectionMode.IROH
      const client = new BeszelClient(activeBaseUrl, connection.gatewayKey)
      const refreshSession = new BeszelSession()
      refreshSession.baseUrl = activeBaseUrl
      refreshSession.email = session.email
      refreshSession.token = session.token
      refreshSession.gatewayKey = connection.gatewayKey
      let result: SystemRefreshResult
      try {
        result = await new SessionRefreshService().execute(
          client,
          refreshSession,
          (activeSession: BeszelSession) => new SystemRefreshService().refreshAll(client, activeSession),
          async (refreshed: BeszelSession) => {
            await sessionRepository.saveSession(refreshed, session.selectedSystemId, connection)
          }
        )
      } catch (error) {
        if (SessionRefreshService.isSessionRejected(error)) {
          await sessionRepository.clearToken()
          await widgetRepository.clearSnapshot()
        }
        throw error instanceof Error ? error : new Error('Unable to refresh the systems widget.')
      }
      const statsBySystem = new Map<string, BeszelSystemStatsWire>()
      result.systemMetrics.forEach((sample: SystemRealtimeSample) => {
        if (sample.metrics.stats !== undefined) {
          statsBySystem.set(sample.systemId, sample.metrics.stats)
        }
      })
      // The final q=0 update publishes this stored snapshot after teardown.
      await widgetRepository.saveSnapshot(result.systems, result.refreshedAt, '', null, statsBySystem, false)
      if (result.metricsError !== null) {
        hilog.warn(DOMAIN, TAG, 'Card list refreshed without realtime metrics: %{public}s',
          this.errorMessage(result.metricsError))
      }
      hilog.info(DOMAIN, TAG, 'Manual card refresh stored %{public}d systems.', result.systems.length)
    } finally {
      await this.stopRefreshReplay()
      if (irohOpened && connectionRuntime !== null) {
        try {
          await connectionRuntime.closeImmediately()
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'Unable to stop the temporary Iroh tunnel: %{public}s', this.errorMessage(error))
        }
      }
      if (widgetRepository !== null) {
        try {
          await widgetRepository.setRefreshing(false)
        } catch (error) {
          hilog.warn(DOMAIN, TAG, 'Unable to clear card refresh state: %{public}s', this.errorMessage(error))
        }
      }
      this.refreshInFlight = false
    }
  }

  private startRefreshReplay(repository: WidgetSnapshotRepository): void {
    if (this.refreshReplayTimer >= 0) {
      clearInterval(this.refreshReplayTimer)
    }
    this.refreshReplayPhase = 0
    this.refreshReplayTimer = setInterval(() => {
      if (this.refreshReplayTask !== null) {
        return
      }
      this.refreshReplayPhase = this.refreshReplayPhase === 0 ? 1 : 0
      const task = repository.setRefreshing(true, this.refreshReplayPhase)
      this.refreshReplayTask = task
      task.then(
        (): void => this.finishRefreshReplay(task),
        (): void => this.finishRefreshReplay(task)
      )
    }, REFRESH_REPLAY_INTERVAL_MS)
  }

  private finishRefreshReplay(task: Promise<void>): void {
    if (this.refreshReplayTask === task) {
      this.refreshReplayTask = null
    }
  }

  private async stopRefreshReplay(): Promise<void> {
    if (this.refreshReplayTimer >= 0) {
      clearInterval(this.refreshReplayTimer)
      this.refreshReplayTimer = -1
    }
    const task = this.refreshReplayTask
    if (task !== null) {
      try {
        await task
      } catch (_) {
        // The final q=0 publication below remains authoritative.
      }
    }
    this.refreshReplayTask = null
    this.refreshReplayPhase = 0
  }

  private errorMessage(error: Object): string {
    return error instanceof Error && error.message.length > 0 ? error.message : 'Unknown error'
  }
}
