import { Want } from '@kit.AbilityKit'
import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { BeszelClient } from '../api/BeszelClient'
import { BeszelSession } from '../model/BeszelModels'
import { SessionRepository } from '../repository/SessionRepository'
import { WidgetSnapshotRepository } from '../repository/WidgetSnapshotRepository'
import { SessionRefreshService } from '../service/SessionRefreshService'
import { SystemRefreshResult, SystemRefreshService } from '../service/SystemRefreshService'

const DOMAIN = 0x0000
const TAG = 'HeszelWidget'

interface WidgetEvent {
  event?: string
  page?: string
  systemId?: string
}

export default class EntryFormAbility extends FormExtensionAbility {
  private refreshInFlight: boolean = false

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
    this.refreshSystems(event.systemId ?? '').catch((error: Object) => {
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

  private async refreshSystems(systemId: string): Promise<void> {
    if (this.refreshInFlight) {
      return
    }
    this.refreshInFlight = true
    try {
      const sessionRepository = new SessionRepository(this.context)
      const widgetRepository = new WidgetSnapshotRepository(this.context)
      const session = await sessionRepository.load()
      if (!session.canRestore()) {
        hilog.warn(DOMAIN, TAG, 'Manual card refresh has no restorable session.')
        return
      }
      hilog.info(DOMAIN, TAG, 'Manual card refresh is requesting systems.')
      const client = new BeszelClient(session.baseUrl, session.gatewayKey)
      const refreshSession = new BeszelSession()
      refreshSession.baseUrl = session.baseUrl
      refreshSession.email = session.email
      refreshSession.token = session.token
      refreshSession.gatewayKey = session.gatewayKey
      let result: SystemRefreshResult
      try {
        result = await new SessionRefreshService().execute(
          client,
          refreshSession,
          (activeSession: BeszelSession) => new SystemRefreshService().refresh(client, activeSession, systemId),
          async (refreshed: BeszelSession) => {
            await sessionRepository.saveSession(refreshed, session.selectedSystemId)
          }
        )
      } catch (error) {
        if (SessionRefreshService.isSessionRejected(error)) {
          await sessionRepository.clearToken()
          await widgetRepository.clearSnapshot()
        }
        throw error instanceof Error ? error : new Error('Unable to refresh the systems widget.')
      }
      await widgetRepository.saveSnapshot(result.systems, result.refreshedAt)
      if (result.metricsError !== null) {
        hilog.warn(DOMAIN, TAG, 'Card list refreshed without realtime metrics: %{public}s',
          this.errorMessage(result.metricsError))
      }
      hilog.info(DOMAIN, TAG, 'Manual card refresh published %{public}d systems.', result.systems.length)
    } finally {
      this.refreshInFlight = false
    }
  }

  private errorMessage(error: Object): string {
    return error instanceof Error && error.message.length > 0 ? error.message : 'Unknown error'
  }
}
