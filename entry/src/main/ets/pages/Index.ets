import { BeszelClient } from '../api/BeszelClient'
import {
  BeszelRealtimeClient,
  BeszelRealtimeMetrics,
  BeszelSystemRealtimeEvent
} from '../api/BeszelRealtimeClient'
import { DashboardView } from '../components/DashboardView'
import { LoginView } from '../components/LoginView'
import { BeszelSession, SystemSummary } from '../model/BeszelModels'
import {
  BeszelContainerStatsRecordWire,
  BeszelSystemDetailsWire,
  BeszelSystemStatsRecordWire,
  SystemDetailState
} from '../model/SystemDetailModels'
import { SessionRepository, StoredSession } from '../repository/SessionRepository'
import { WidgetSnapshotRepository } from '../repository/WidgetSnapshotRepository'
import { SessionRefreshService } from '../service/SessionRefreshService'
import { SystemRefreshService } from '../service/SystemRefreshService'

const DETAIL_CACHE_LIMIT = 10
const SELECTION_PERSIST_DELAY_MS = 750

interface LoadedSystemDetail {
  details: BeszelSystemDetailsWire | null
  stats: BeszelSystemStatsRecordWire | null
  containers: BeszelContainerStatsRecordWire | null
}

@Entry
@Component
struct Index {
  @State private session: BeszelSession = new BeszelSession()
  @State private systems: SystemSummary[] = []
  @State @Watch('onSelectedIdChanged') private selectedId: string = ''
  @State private signingIn: boolean = false
  @State private refreshing: boolean = false
  @State private loginError: string = ''
  @State private dashboardError: string = ''
  @State private lastRefresh: string = ''
  @StorageProp('curScreenSizeString') private curScreenSizeString: string = 'sm'
  @State @Watch('onDetailContextChanged') private detailVisible: boolean = false
  @State private detailState: SystemDetailState = new SystemDetailState()
  @State @Watch('onLiveMetricsChanged') private liveMetrics: boolean = false
  @State private updateWhileScrolling: boolean = false
  @State private realtimeConnected: boolean = false
  @State private restoringSession: boolean = true
  @State private savedServerUrl: string = ''
  @State private savedEmail: string = ''
  @State private savedGatewayKey: string = ''
  private client: BeszelClient | null = null
  private realtimeClient: BeszelRealtimeClient | null = null
  private sessionRepository: SessionRepository | null = null
  private widgetRepository: WidgetSnapshotRepository | null = null
  private pageVisible: boolean = false
  private detailScrolling: boolean = false
  private refreshInFlight: boolean = false
  private manualRefreshPending: boolean = false
  private sessionRefreshPending: boolean = false
  private detailStates: Map<string, SystemDetailState> = new Map<string, SystemDetailState>()
  private selectionPersistTimer: number = -1
  private selectionPersistTask: Promise<void> | null = null
  private pendingSelectedId: string = ''
  private lastPersistedSelectedId: string = ''
  private sessionRefreshService: SessionRefreshService = new SessionRefreshService()
  private manualRefreshService: SystemRefreshService | null = null
  private pendingGatewayClient: BeszelClient | null = null
  private dataGeneration: number = 0
  private detailLoadSequence: number = 0
  private detailLoadTokens: Map<string, number> = new Map<string, number>()

  aboutToAppear(): void {
    this.restoreSession()
  }

  onPageShow(): void {
    this.pageVisible = true
    if (this.session.token.length > 0) {
      this.resumeData()
    }
  }

  onPageHide(): void {
    this.pageVisible = false
    this.flushSelectedId()
    this.invalidateDataWork()
    this.stopRealtime()
  }

  aboutToDisappear(): void {
    this.pageVisible = false
    this.invalidateDataWork()
    this.stopRealtime()
  }

  build() {
    Stack() {
      if (this.restoringSession) {
        Column({ space: 14 }) {
          LoadingProgress()
            .width(36)
            .height(36)
            .color($r('app.color.action'))
          Text($r('app.string.restoring_heszel'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('app.color.surface_header'))
      } else if (this.session.token.length === 0) {
        LoginView({
          loading: this.signingIn,
          errorMessage: this.loginError,
          initialServerUrl: this.savedServerUrl,
          initialEmail: this.savedEmail,
          initialGatewayKey: this.savedGatewayKey,
          onLogin: (serverUrl: string, email: string, password: string, gatewayKey: string) => {
            this.login(serverUrl, email, password, gatewayKey)
          }
        })
      } else {
        DashboardView({
          systems: $systems,
          selectedId: $selectedId,
          detailState: this.detailState,
          loading: this.refreshing,
          errorMessage: this.dashboardError,
          lastRefresh: this.lastRefresh,
          expanded: this.curScreenSizeString === 'lg',
          liveMetrics: this.liveMetrics,
          updateWhileScrolling: this.updateWhileScrolling,
          realtimeConnected: this.realtimeConnected,
          baseUrl: this.session.baseUrl,
          email: this.session.email,
          onRefresh: () => {
            this.handleManualRefresh()
          },
          onLiveMetricsChange: (enabled: boolean) => {
            this.liveMetrics = enabled
          },
          onUpdateWhileScrollingChange: (enabled: boolean) => {
            this.updateScrollingPreference(enabled)
          },
          onDetailVisibilityChange: (visible: boolean) => {
            this.detailVisible = visible
            if (!visible) {
              this.detailScrolling = false
            }
          },
          onDetailScrollingChange: (scrolling: boolean) => {
            this.detailScrolling = scrolling
          },
          onGatewayKeyChange: (gatewayKey: string) => {
            this.updateGatewayKey(gatewayKey)
          },
          onSignOut: () => {
            this.signOut()
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }

  private async login(serverUrl: string, email: string, password: string, gatewayKey: string): Promise<void> {
    this.loginError = ''
    if (serverUrl.trim().length === 0 || email.trim().length === 0 || password.length === 0) {
      this.loginError = this.localized('error_enter_credentials', 'Enter the hub address, email, and password.')
      return
    }

    this.signingIn = true
    const generation = this.dataGeneration
    let client: BeszelClient | null = null
    try {
      const loginClient = new BeszelClient(serverUrl, gatewayKey)
      client = loginClient
      this.client = loginClient
      const session = await loginClient.login(email, password)
      if (!this.isDataWorkCurrent(generation)) {
        if (this.client === loginClient) {
          this.client = null
        }
        return
      }
      this.session = session
      this.sessionRefreshPending = false
      this.savedServerUrl = session.baseUrl
      this.savedEmail = session.email
      this.savedGatewayKey = session.gatewayKey
      this.systems = []
      this.selectedId = ''
      this.clearDetailStates()
      await this.persistSession(session)
      if (!this.isDataWorkCurrent(generation)) {
        return
      }
      await this.refreshSystems(true)
      if (this.pageVisible && this.session.token.length > 0) {
        this.startRealtime()
      }
    } catch (error) {
      if (!this.isDataWorkCurrent(generation)) {
        if (client !== null && this.client === client) {
          this.client = null
        }
        return
      }
      if (client !== null && this.client === client) {
        this.client = null
      }
      this.loginError = this.describeError(error,
        this.localized('error_connect_beszel', 'Unable to connect to Beszel.'))
    } finally {
      this.signingIn = false
    }
  }

  private async refreshSystems(showLoading: boolean, retryPendingSession: boolean = true): Promise<void> {
    const client = this.client
    if (client === null || this.session.token.length === 0) {
      return
    }
    const generation = this.dataGeneration
    if (this.refreshInFlight) {
      if (showLoading) {
        this.manualRefreshPending = true
        this.refreshing = true
      }
      return
    }

    this.refreshInFlight = true
    if (showLoading) {
      this.refreshing = true
    }
    this.dashboardError = ''
    try {
      if (retryPendingSession && this.sessionRefreshPending) {
        const sessionReady = await this.retrySessionRefresh(generation)
        if (!sessionReady) {
          return
        }
      }

      const incomingSystems = await this.executeAuthenticated(
        (activeSession: BeszelSession) => client.listSystems(activeSession.token),
        generation
      )
      if (!this.isDataWorkCurrent(generation)) {
        return
      }
      const systems = this.reconcileSystems(incomingSystems)
      this.systems = systems
      if (systems.length > 0 && !systems.some((system: SystemSummary) => system.id === this.selectedId)) {
        this.selectedId = systems[0].id
      }
      this.lastRefresh = new Date().toLocaleTimeString()
      await this.publishWidgetSnapshot()
      if (this.realtimeClient !== null && !this.realtimeConnected) {
        this.realtimeClient.retryNow()
      }
    } catch (error) {
      if (!this.isDataWorkCurrent(generation)) {
        return
      }
      if (this.isSessionRejected(error)) {
        await this.expireSavedSession()
        return
      }
      this.dashboardError = this.describeError(error,
        this.localized('error_refresh_systems', 'Unable to refresh systems.'))
    } finally {
      if (this.isDataWorkCurrent(generation)) {
        this.refreshInFlight = false
        if (this.manualRefreshPending && this.client !== null && this.session.token.length > 0) {
          this.manualRefreshPending = false
          await this.performManualRefresh()
        } else {
          this.manualRefreshPending = false
          this.refreshing = false
        }
      }
    }
  }

  private reconcileSystems(incoming: SystemSummary[]): SystemSummary[] {
    const existingById = new Map<string, SystemSummary>()
    this.systems.forEach((system: SystemSummary) => {
      existingById.set(system.id, system)
    })

    const reconciled: SystemSummary[] = []
    incoming.forEach((fresh: SystemSummary) => {
      const existing = existingById.get(fresh.id)
      if (existing === undefined) {
        reconciled.push(fresh)
        return
      }

      existing.updateFrom(fresh)
      reconciled.push(existing)
    })
    return reconciled
  }

  private async resumeData(): Promise<void> {
    await this.refreshSystems(false)
    if (this.pageVisible && this.detailIsVisible()) {
      this.loadSelectedDetail()
    }
    if (this.pageVisible && this.session.token.length > 0) {
      this.startRealtime()
    }
  }

  private startRealtime(): void {
    if (!this.pageVisible || this.session.token.length === 0) {
      return
    }
    this.stopRealtime()
    this.realtimeClient = new BeszelRealtimeClient(
      this.session.baseUrl,
      this.session.token,
      this.session.gatewayKey,
      (event: BeszelSystemRealtimeEvent) => this.handleSystemRealtimeEvent(event),
      (systemId: string, metrics: BeszelRealtimeMetrics) => this.handleRealtimeMetrics(systemId, metrics),
      (connected: boolean) => {
        this.realtimeConnected = connected
        if (connected) {
          this.dashboardError = ''
        }
      },
      (error: Error) => {
        if (this.pageVisible && this.session.token.length > 0) {
          this.dashboardError = this.localized(
            'error_refresh_available', `${error.message} Refresh remains available.`, error.message)
        }
      }
    )
    this.realtimeClient.connect()
    this.syncMetricSubscription()
  }

  private stopRealtime(): void {
    if (this.realtimeClient !== null) {
      this.realtimeClient.disconnect()
      this.realtimeClient = null
    }
    this.realtimeConnected = false
  }

  private handleSystemRealtimeEvent(event: BeszelSystemRealtimeEvent): void {
    if (event.action === 'delete') {
      this.systems = this.systems.filter((system: SystemSummary) => system.id !== event.record.id)
      this.detailStates.delete(event.record.id)
    } else if (event.action === 'create' || event.action === 'update') {
      const fresh = SystemSummary.fromWire(event.record)
      const existing = this.systems.find((system: SystemSummary) => system.id === fresh.id)
      if (existing === undefined) {
        const next = this.systems.slice()
        next.push(fresh)
        this.systems = this.sortSystems(next)
      } else {
        existing.updateFrom(fresh)
        this.systems = this.systems.slice()
      }
    } else {
      return
    }

    if (this.systems.length > 0 && !this.systems.some((system: SystemSummary) => system.id === this.selectedId)) {
      this.selectedId = this.systems[0].id
    } else if (this.systems.length === 0) {
      this.selectedId = ''
    }
    this.lastRefresh = new Date().toLocaleTimeString()
  }

  private sortSystems(systems: SystemSummary[]): SystemSummary[] {
    systems.sort((left: SystemSummary, right: SystemSummary) => {
      if (left.isUp() !== right.isUp()) {
        return left.isUp() ? 1 : -1
      }
      return left.name.localeCompare(right.name)
    })
    return systems
  }

  private handleRealtimeMetrics(systemId: string, metrics: BeszelRealtimeMetrics): void {
    if (this.detailScrolling && !this.updateWhileScrolling) {
      return
    }
    const system = this.systems.find((candidate: SystemSummary) => candidate.id === systemId)
    if (system !== undefined && metrics.info !== undefined) {
      system.updateCardMetrics(metrics.info)
    }

    const detail = this.detailStates.get(systemId)
    if (detail !== undefined) {
      detail.applyRealtime(metrics.info, metrics.stats, metrics.container)
    }

  }

  private handleManualRefresh(): void {
    if (this.client === null || this.session.token.length === 0) {
      return
    }
    if (this.refreshInFlight) {
      this.manualRefreshPending = true
      this.refreshing = true
      return
    }
    this.performManualRefresh()
  }

  private async performManualRefresh(): Promise<void> {
    const client = this.client
    if (client === null || this.session.token.length === 0) {
      return
    }
    const generation = this.dataGeneration
    const refreshService = new SystemRefreshService()
    this.manualRefreshService = refreshService
    this.refreshInFlight = true
    this.refreshing = true
    this.dashboardError = ''
    const requestedSystemId = this.selectedId
    try {
      if (this.sessionRefreshPending) {
        const sessionReady = await this.retrySessionRefresh(generation)
        if (!sessionReady || this.client === null) {
          return
        }
      }
      const alreadyReceivingMetrics = this.liveMetrics && this.realtimeConnected && this.detailIsVisible()
      const result = await this.executeAuthenticated(
        (activeSession: BeszelSession) => refreshService.refresh(
          client,
          activeSession,
          requestedSystemId,
          !alreadyReceivingMetrics
        ),
        generation
      )
      if (!this.isDataWorkCurrent(generation)) {
        return
      }
      this.systems = this.reconcileSystems(result.systems)
      if (this.systems.length > 0 &&
        !this.systems.some((system: SystemSummary) => system.id === this.selectedId)) {
        this.selectedId = this.systems[0].id
      }
      if (result.metrics !== null) {
        const detail = this.detailStates.get(requestedSystemId)
        if (detail !== undefined) {
          detail.applyRealtime(result.metrics.info, result.metrics.stats, result.metrics.container)
        }
      }
      this.lastRefresh = result.refreshedAt
      await this.publishWidgetSnapshot()
      if (result.metricsError !== null) {
        this.dashboardError = this.localized(
          'error_refresh_metrics_partial',
          'Systems refreshed, but fresh realtime metrics were unavailable.'
        )
      }
      if (this.realtimeClient !== null && !this.realtimeConnected) {
        this.realtimeClient.retryNow()
      }
    } catch (error) {
      if (!this.isDataWorkCurrent(generation)) {
        return
      }
      if (this.isSessionRejected(error)) {
        await this.expireSavedSession()
        return
      }
      this.dashboardError = this.describeError(error,
        this.localized('error_refresh_systems', 'Unable to refresh systems.'))
    } finally {
      if (this.manualRefreshService === refreshService) {
        this.manualRefreshService = null
      }
      if (this.isDataWorkCurrent(generation)) {
        this.refreshInFlight = false
        if (this.manualRefreshPending && this.client !== null && this.session.token.length > 0) {
          this.manualRefreshPending = false
          await this.performManualRefresh()
        } else {
          this.manualRefreshPending = false
          this.refreshing = false
        }
      }
    }
  }

  private detailIsVisible(): boolean {
    return this.detailVisible && this.selectedId.length > 0
  }

  private syncMetricSubscription(): void {
    if (this.realtimeClient === null) {
      return
    }
    if (this.liveMetrics && this.detailIsVisible()) {
      this.realtimeClient.setMetricsSystem(this.selectedId)
    } else {
      this.realtimeClient.setMetricsSystem('')
    }
  }

  private onLiveMetricsChanged(): void {
    this.syncMetricSubscription()
  }

  private onDetailContextChanged(): void {
    if (this.detailIsVisible()) {
      this.loadSelectedDetail()
    }
    this.syncMetricSubscription()
  }

  private async signOut(): Promise<void> {
    await this.flushSelectedId()
    this.invalidateDataWork()
    this.stopRealtime()
    if (this.sessionRepository !== null) {
      try {
        await this.sessionRepository.clearToken()
      } catch (_) {
        this.dashboardError = this.localized(
          'error_remove_token', 'Unable to remove the protected session token. Please try again.')
        if (this.pageVisible && this.session.token.length > 0) {
          this.startRealtime()
        }
        return
      }
    }
    this.client = null
    this.session = new BeszelSession()
    this.sessionRefreshPending = false
    this.systems = []
    this.selectedId = ''
    this.clearDetailStates()
    this.detailVisible = false
    this.liveMetrics = false
    this.dashboardError = ''
    this.lastRefresh = ''
    await this.clearWidgetSnapshot()
  }

  private async restoreSession(): Promise<void> {
    const generation = this.dataGeneration
    try {
      const context = this.getUIContext().getHostContext()
      if (context === undefined) {
        return
      }
      this.sessionRepository = new SessionRepository(context)
      this.widgetRepository = new WidgetSnapshotRepository(context)
      const stored = await this.sessionRepository.load()
      if (!this.isDataWorkCurrent(generation)) {
        return
      }
      this.savedServerUrl = stored.baseUrl
      this.savedEmail = stored.email
      this.savedGatewayKey = stored.gatewayKey
      this.updateWhileScrolling = stored.updateWhileScrolling
      this.lastPersistedSelectedId = stored.selectedSystemId
      this.selectedId = stored.selectedSystemId
      if (!stored.canRestore()) {
        return
      }

      this.client = new BeszelClient(stored.baseUrl, stored.gatewayKey)
      this.session = this.toSession(stored)
      this.sessionRefreshPending = true

      const sessionReady = await this.retrySessionRefresh(generation)
      if (sessionReady) {
        await this.refreshSystems(true, false)
        if (this.pageVisible && this.session.token.length > 0) {
          this.startRealtime()
        }
      }
    } catch (error) {
      this.loginError = this.describeError(error,
        this.localized('error_restore_session', 'Unable to restore the saved session.'))
    } finally {
      this.restoringSession = false
    }
  }

  private async persistSession(session: BeszelSession): Promise<void> {
    if (this.sessionRepository === null) {
      return
    }
    try {
      await this.sessionRepository.saveSession(session, this.selectedId)
      this.pendingSelectedId = this.selectedId
      this.lastPersistedSelectedId = this.selectedId
    } catch (_) {
      this.dashboardError = this.localized(
        'error_save_session', 'Signed in, but HarmonyOS could not save this session.')
    }
  }

  private async updateScrollingPreference(enabled: boolean): Promise<void> {
    const previous = this.updateWhileScrolling
    this.updateWhileScrolling = enabled
    if (this.sessionRepository === null) {
      return
    }
    try {
      await this.sessionRepository.saveUpdateWhileScrolling(enabled)
    } catch (_) {
      if (this.updateWhileScrolling === enabled) {
        this.updateWhileScrolling = previous
      }
      this.dashboardError = this.localized(
        'error_save_settings', 'Unable to save the scrolling update preference.')
    }
  }

  private async updateGatewayKey(value: string): Promise<void> {
    const gatewayKey = value.trim()
    if (gatewayKey === this.session.gatewayKey || this.sessionRepository === null || this.session.token.length === 0) {
      return
    }

    const generation = this.dataGeneration
    this.refreshing = true
    this.dashboardError = ''
    const client = new BeszelClient(this.session.baseUrl, gatewayKey)
    this.pendingGatewayClient = client
    try {
      const incomingSystems = await client.listSystems(this.session.token)
      if (!this.isDataWorkCurrent(generation)) {
        return
      }
      await this.sessionRepository.saveGatewayKey(gatewayKey)
      if (!this.isDataWorkCurrent(generation)) {
        return
      }

      this.stopRealtime()
      const session = new BeszelSession()
      session.baseUrl = this.session.baseUrl
      session.email = this.session.email
      session.token = this.session.token
      session.gatewayKey = gatewayKey
      this.session = session
      this.client = client
      this.savedGatewayKey = gatewayKey
      this.systems = this.reconcileSystems(incomingSystems)
      this.lastRefresh = new Date().toLocaleTimeString()
      await this.publishWidgetSnapshot()
      if (this.pageVisible) {
        this.startRealtime()
      }
    } catch (error) {
      if (!this.isDataWorkCurrent(generation)) {
        return
      }
      this.dashboardError = this.describeError(error,
        this.localized('error_gateway_rejected', 'The nginx gateway rejected this key.'))
    } finally {
      if (this.pendingGatewayClient === client) {
        this.pendingGatewayClient = null
      }
      if (this.isDataWorkCurrent(generation)) {
        this.refreshing = false
      }
    }
  }

  private onSelectedIdChanged(): void {
    this.selectDetailState()
    this.scheduleSelectedIdPersistence()
    this.syncMetricSubscription()
  }

  private scheduleSelectedIdPersistence(): void {
    this.pendingSelectedId = this.selectedId
    if (this.selectionPersistTimer >= 0) {
      clearTimeout(this.selectionPersistTimer)
      this.selectionPersistTimer = -1
    }
    if (this.pendingSelectedId === this.lastPersistedSelectedId) {
      return
    }
    this.selectionPersistTimer = setTimeout(() => {
      this.selectionPersistTimer = -1
      this.flushSelectedId()
    }, SELECTION_PERSIST_DELAY_MS)
  }

  private async flushSelectedId(): Promise<void> {
    if (this.selectionPersistTimer >= 0) {
      clearTimeout(this.selectionPersistTimer)
      this.selectionPersistTimer = -1
    }
    if (this.selectionPersistTask !== null) {
      await this.selectionPersistTask
      if (this.pendingSelectedId !== this.lastPersistedSelectedId) {
        await this.flushSelectedId()
      }
      return
    }
    if (this.sessionRepository === null || this.pendingSelectedId === this.lastPersistedSelectedId) {
      return
    }
    const repository = this.sessionRepository
    this.selectionPersistTask = this.persistPendingSelectedIds(repository)
    await this.selectionPersistTask
    this.selectionPersistTask = null
  }

  private async persistPendingSelectedIds(repository: SessionRepository): Promise<void> {
    try {
      while (this.pendingSelectedId !== this.lastPersistedSelectedId) {
        const id = this.pendingSelectedId
        await repository.saveSelectedSystem(id)
        this.lastPersistedSelectedId = id
      }
    } catch (_) {
      // Selection persistence is convenient but should never interrupt telemetry.
    }
  }

  private selectDetailState(): void {
    if (this.selectedId.length === 0) {
      this.detailState = new SystemDetailState()
      return
    }
    let state = this.detailStates.get(this.selectedId)
    if (state === undefined) {
      state = new SystemDetailState(this.selectedId)
    } else {
      this.detailStates.delete(this.selectedId)
    }
    this.detailStates.set(this.selectedId, state)
    this.trimDetailCache()
    const system = this.systems.find((candidate: SystemSummary) => candidate.id === this.selectedId)
    if (system !== undefined) {
      state.applySummary(system)
    }
    this.detailState = state
    if (this.detailVisible) {
      this.loadSelectedDetail()
    }
  }

  private clearDetailStates(): void {
    this.detailLoadTokens.clear()
    this.detailStates.clear()
    this.detailState = new SystemDetailState()
  }

  private trimDetailCache(): void {
    while (this.detailStates.size > DETAIL_CACHE_LIMIT) {
      const oldestId = this.detailStates.keys().next().value as string
      this.detailStates.delete(oldestId)
    }
  }

  private async loadSelectedDetail(): Promise<void> {
    const client = this.client
    const state = this.detailState
    if (!this.pageVisible || !this.detailVisible || client === null || this.session.token.length === 0 ||
      state.systemId.length === 0 || state.loading || state.loaded) {
      return
    }

    const generation = this.dataGeneration
    const loadToken = ++this.detailLoadSequence
    this.detailLoadTokens.set(state.systemId, loadToken)
    state.loading = true
    state.errorMessage = ''
    try {
      const loaded = await this.executeAuthenticated(async (activeSession: BeszelSession) => {
        const detailsRequest = client.getSystemDetails(activeSession.token, state.systemId)
        const statsRequest = client.getLatestSystemStats(activeSession.token, state.systemId)
        const containersRequest = this.getOptionalContainerStats(client, activeSession.token, state.systemId)
        const responses = await Promise.all([
          detailsRequest,
          statsRequest,
          containersRequest
        ])
        const details = responses[0] as BeszelSystemDetailsWire | null
        const stats = responses[1] as BeszelSystemStatsRecordWire | null
        const containers = responses[2] as BeszelContainerStatsRecordWire | null
        const result: LoadedSystemDetail = {
          details: details,
          stats: stats,
          containers: containers
        }
        return result
      }, generation)
      if (!this.isDataWorkCurrent(generation) || this.detailLoadTokens.get(state.systemId) !== loadToken) {
        return
      }
      state.applyHardware(loaded.details)
      state.initializeCapabilities(loaded.stats?.stats, loaded.containers?.stats)
      if (loaded.stats !== null && loaded.stats.stats !== undefined && loaded.stats.stats !== null) {
        state.applyMetrics(loaded.stats.stats, loaded.containers?.stats)
      } else if (loaded.containers?.stats !== undefined && loaded.containers.stats !== null) {
        state.applyContainers(loaded.containers.stats)
      }
      state.loaded = true
    } catch (error) {
      if (!this.isDataWorkCurrent(generation) || this.detailLoadTokens.get(state.systemId) !== loadToken) {
        return
      }
      if (this.isSessionRejected(error)) {
        await this.expireSavedSession()
        return
      }
      state.errorMessage = this.describeError(error,
        this.localized('error_load_detail', 'Unable to load detailed system data.'))
    } finally {
      if (this.detailLoadTokens.get(state.systemId) === loadToken) {
        this.detailLoadTokens.delete(state.systemId)
        state.loading = false
      }
    }
  }

  private async getOptionalContainerStats(client: BeszelClient, token: string,
    systemId: string): Promise<BeszelContainerStatsRecordWire | null> {
    try {
      return await client.getLatestContainerStats(token, systemId)
    } catch (error) {
      if (SessionRefreshService.isAccessRejected(error)) {
        throw error instanceof Error ? error : new Error('Container metrics access was rejected.')
      }
      return null
    }
  }

  private isSessionRejected(error: Object): boolean {
    return SessionRefreshService.isSessionRejected(error)
  }

  private async retrySessionRefresh(generation: number = this.dataGeneration): Promise<boolean> {
    if (this.client === null || !this.sessionRefreshPending) {
      return true
    }

    try {
      const refreshed = await this.sessionRefreshService.refresh(this.client, this.session)
      if (!this.isDataWorkCurrent(generation)) {
        return false
      }
      this.session = refreshed
      this.sessionRefreshPending = false
      await this.persistSession(refreshed)
      if (!this.isDataWorkCurrent(generation)) {
        return false
      }
      return true
    } catch (error) {
      if (!this.isDataWorkCurrent(generation)) {
        return false
      }
      if (this.isSessionRejected(error)) {
        await this.expireSavedSession()
        return false
      }

      this.dashboardError = this.localized(
        'error_network_saved_session',
        'Beszel is unreachable. Your saved session is safe; connect Tailscale or restore networking, then retry.')
      return false
    }
  }

  private async executeAuthenticated<T>(operation: (activeSession: BeszelSession) => Promise<T>,
    generation: number = this.dataGeneration): Promise<T> {
    const client = this.client
    if (client === null || this.session.token.length === 0 || !this.isDataWorkCurrent(generation)) {
      throw new Error('No active Beszel session.')
    }
    const result = await this.sessionRefreshService.execute(
      client,
      this.session,
      operation,
      async (refreshed: BeszelSession) => {
        if (this.client !== client || this.session.token.length === 0 || !this.isDataWorkCurrent(generation)) {
          throw new Error('The active Beszel session changed during refresh.')
        }
        const restartRealtime = this.pageVisible && this.realtimeClient !== null
        if (restartRealtime) {
          this.stopRealtime()
        }
        this.session = refreshed
        this.sessionRefreshPending = false
        await this.persistSession(refreshed)
        if (!this.isDataWorkCurrent(generation)) {
          throw new Error('The active Beszel session changed while it was being saved.')
        }
        if (restartRealtime) {
          this.startRealtime()
        }
      }
    )
    if (!this.isDataWorkCurrent(generation)) {
      throw new Error('The Beszel request completed after its lifecycle ended.')
    }
    return result
  }

  private isDataWorkCurrent(generation: number): boolean {
    return generation === this.dataGeneration
  }

  private invalidateDataWork(): void {
    this.dataGeneration += 1
    this.client?.cancelPendingRequests()
    this.pendingGatewayClient?.cancelPendingRequests()
    this.pendingGatewayClient = null
    this.manualRefreshService?.cancel()
    this.manualRefreshService = null
    this.refreshInFlight = false
    this.manualRefreshPending = false
    this.refreshing = false
    this.detailScrolling = false
    this.detailLoadTokens.clear()
    this.detailStates.forEach((state: SystemDetailState) => {
      state.loading = false
    })
  }

  private async expireSavedSession(): Promise<void> {
    this.invalidateDataWork()
    this.stopRealtime()
    if (this.sessionRepository !== null) {
      try {
        await this.sessionRepository.clearToken()
      } catch (_) {
        // The rejected in-memory token is still discarded for this process.
      }
    }
    this.client = null
    this.session = new BeszelSession()
    this.sessionRefreshPending = false
    this.systems = []
    this.clearDetailStates()
    this.detailVisible = false
    this.liveMetrics = false
    this.dashboardError = ''
    this.lastRefresh = ''
    this.loginError = this.localized(
      'error_session_rejected', 'Your saved session was rejected by Beszel. Sign in again.')
    await this.clearWidgetSnapshot()
  }

  private async publishWidgetSnapshot(): Promise<void> {
    if (this.widgetRepository === null) {
      return
    }
    try {
      await this.widgetRepository.saveSnapshot(this.systems, this.lastRefresh)
    } catch (_) {
      // A launcher card is supplementary and must never interrupt dashboard telemetry.
    }
  }

  private async clearWidgetSnapshot(): Promise<void> {
    if (this.widgetRepository === null) {
      return
    }
    try {
      await this.widgetRepository.clearSnapshot()
    } catch (_) {
      // Sign-out and session rejection must continue even when no card host is available.
    }
  }

  private toSession(stored: StoredSession): BeszelSession {
    const session = new BeszelSession()
    session.baseUrl = stored.baseUrl
    session.email = stored.email
    session.token = stored.token
    session.gatewayKey = stored.gatewayKey
    return session
  }

  private describeError(error: Object, fallback: string): string {
    if (error instanceof Error && error.message.length > 0) {
      return error.message
    }
    return fallback
  }

  private localized(name: string, fallback: string, ...args: Array<string | number>): string {
    try {
      const context = this.getUIContext().getHostContext()
      return context?.resourceManager.getStringByNameSync(name, ...args) ?? fallback
    } catch (_) {
      return fallback
    }
  }
}
