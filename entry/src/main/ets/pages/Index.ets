import { BeszelApiError, BeszelClient } from '../api/BeszelClient'
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
  @State private realtimeConnected: boolean = false
  @State private restoringSession: boolean = true
  @State private savedServerUrl: string = ''
  @State private savedEmail: string = ''
  private client: BeszelClient | null = null
  private realtimeClient: BeszelRealtimeClient | null = null
  private sessionRepository: SessionRepository | null = null
  private pageVisible: boolean = false
  private refreshInFlight: boolean = false
  private manualRefreshPending: boolean = false
  private metricRefreshPending: boolean = false
  private metricRefreshTimer: number = -1
  private sessionRefreshPending: boolean = false
  private detailStates: Map<string, SystemDetailState> = new Map<string, SystemDetailState>()

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
    this.stopRealtime()
  }

  aboutToDisappear(): void {
    this.pageVisible = false
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
          Text('Restoring Heszel…')
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
          onLogin: (serverUrl: string, email: string, password: string) => {
            this.login(serverUrl, email, password)
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
          realtimeConnected: this.realtimeConnected,
          baseUrl: this.session.baseUrl,
          email: this.session.email,
          onRefresh: () => {
            this.handleManualRefresh()
          },
          onLiveMetricsChange: (enabled: boolean) => {
            this.liveMetrics = enabled
          },
          onDetailVisibilityChange: (visible: boolean) => {
            this.detailVisible = visible
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

  private async login(serverUrl: string, email: string, password: string): Promise<void> {
    this.loginError = ''
    if (serverUrl.trim().length === 0 || email.trim().length === 0 || password.length === 0) {
      this.loginError = 'Enter the hub address, email, and password.'
      return
    }

    this.signingIn = true
    try {
      const client = new BeszelClient(serverUrl)
      const session = await client.login(email, password)
      this.client = client
      this.session = session
      this.sessionRefreshPending = false
      this.savedServerUrl = session.baseUrl
      this.savedEmail = session.email
      this.systems = []
      this.selectedId = ''
      this.clearDetailStates()
      await this.persistSession(session)
      await this.refreshSystems(true)
      if (this.pageVisible && this.session.token.length > 0) {
        this.startRealtime()
      }
    } catch (error) {
      this.loginError = this.describeError(error, 'Unable to connect to Beszel.')
    } finally {
      this.signingIn = false
    }
  }

  private async refreshSystems(showLoading: boolean, retryPendingSession: boolean = true): Promise<void> {
    if (this.client === null || this.session.token.length === 0) {
      return
    }
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
        const sessionReady = await this.retrySessionRefresh()
        if (!sessionReady) {
          return
        }
      }

      const incomingSystems = await this.client.listSystems(this.session.token)
      const systems = this.reconcileSystems(incomingSystems)
      this.systems = systems
      if (systems.length > 0 && !systems.some((system: SystemSummary) => system.id === this.selectedId)) {
        this.selectedId = systems[0].id
      }
      this.lastRefresh = new Date().toLocaleTimeString()
    } catch (error) {
      if (this.isSessionRejected(error)) {
        await this.expireSavedSession()
        return
      }
      this.dashboardError = this.describeError(error, 'Unable to refresh systems.')
    } finally {
      this.refreshInFlight = false
      if (this.manualRefreshPending && this.client !== null && this.session.token.length > 0) {
        this.manualRefreshPending = false
        await this.refreshSystems(true)
      } else {
        this.manualRefreshPending = false
        this.refreshing = false
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
          this.dashboardError = `${error.message} Refresh remains available.`
        }
      }
    )
    this.realtimeClient.connect()
    this.syncMetricSubscription()
  }

  private stopRealtime(): void {
    this.cancelMetricRefresh()
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
    const system = this.systems.find((candidate: SystemSummary) => candidate.id === systemId)
    if (system !== undefined && metrics.info !== undefined) {
      system.updateMetrics(metrics.info)
    }

    const detail = this.detailStates.get(systemId)
    if (detail !== undefined) {
      if (metrics.stats !== undefined) {
        detail.applyMetrics(metrics.stats, metrics.container, '', true)
      } else if (metrics.container !== undefined && metrics.container !== null) {
        detail.applyContainers(metrics.container)
      }
    }

    if (this.metricRefreshPending && systemId === this.selectedId) {
      this.cancelMetricRefresh()
      this.refreshing = false
      this.syncMetricSubscription()
    }
  }

  private handleManualRefresh(): void {
    const selected = this.systems.find((system: SystemSummary) => system.id === this.selectedId)
    if (!this.detailIsVisible() || selected === undefined || !selected.isUp() ||
      this.realtimeClient === null || !this.realtimeConnected) {
      this.refreshSystems(true)
      return
    }

    this.dashboardError = ''
    this.metricRefreshPending = true
    this.refreshing = true
    this.syncMetricSubscription()
    this.metricRefreshTimer = setTimeout(() => {
      if (!this.metricRefreshPending) {
        return
      }
      this.cancelMetricRefresh()
      this.syncMetricSubscription()
      this.refreshSystems(true)
    }, 8000)
  }

  private cancelMetricRefresh(): void {
    this.metricRefreshPending = false
    if (this.metricRefreshTimer >= 0) {
      clearTimeout(this.metricRefreshTimer)
      this.metricRefreshTimer = -1
    }
  }

  private detailIsVisible(): boolean {
    return this.detailVisible && this.selectedId.length > 0
  }

  private syncMetricSubscription(): void {
    if (this.realtimeClient === null) {
      return
    }
    if ((this.liveMetrics && this.detailIsVisible()) || this.metricRefreshPending) {
      this.realtimeClient.setMetricsSystem(this.selectedId)
    } else {
      this.realtimeClient.setMetricsSystem('')
    }
  }

  private onLiveMetricsChanged(): void {
    this.syncMetricSubscription()
  }

  private onDetailContextChanged(): void {
    if (!this.detailIsVisible() && this.metricRefreshPending) {
      this.cancelMetricRefresh()
      this.refreshing = false
    }
    if (this.detailIsVisible()) {
      this.loadSelectedDetail()
    }
    this.syncMetricSubscription()
  }

  private async signOut(): Promise<void> {
    this.stopRealtime()
    if (this.sessionRepository !== null) {
      try {
        await this.sessionRepository.clearToken()
      } catch (_) {
        this.dashboardError = 'Unable to remove the protected session token. Please try again.'
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
  }

  private async restoreSession(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext()
      if (context === undefined) {
        return
      }
      this.sessionRepository = new SessionRepository(context)
      const stored = await this.sessionRepository.load()
      this.savedServerUrl = stored.baseUrl
      this.savedEmail = stored.email
      this.selectedId = stored.selectedSystemId
      if (!stored.canRestore()) {
        return
      }

      this.client = new BeszelClient(stored.baseUrl)
      this.session = this.toSession(stored)
      this.sessionRefreshPending = true

      const sessionReady = await this.retrySessionRefresh()
      if (sessionReady) {
        await this.refreshSystems(true, false)
        if (this.pageVisible && this.session.token.length > 0) {
          this.startRealtime()
        }
      }
    } catch (error) {
      this.loginError = this.describeError(error, 'Unable to restore the saved session.')
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
    } catch (_) {
      this.dashboardError = 'Signed in, but HarmonyOS could not save this session.'
    }
  }

  private onSelectedIdChanged(): void {
    this.selectDetailState()
    this.persistSelectedId()
    if (this.metricRefreshPending) {
      this.cancelMetricRefresh()
      this.refreshing = false
    }
    this.syncMetricSubscription()
  }

  private async persistSelectedId(): Promise<void> {
    if (this.sessionRepository === null) {
      return
    }
    try {
      await this.sessionRepository.saveSelectedSystem(this.selectedId)
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
      this.detailStates.set(this.selectedId, state)
    }
    this.detailState = state
    if (this.detailVisible) {
      this.loadSelectedDetail()
    }
  }

  private clearDetailStates(): void {
    this.detailStates.clear()
    this.detailState = new SystemDetailState()
  }

  private async loadSelectedDetail(): Promise<void> {
    const client = this.client
    const state = this.detailState
    if (!this.detailVisible || client === null || this.session.token.length === 0 ||
      state.systemId.length === 0 || state.loading || state.loaded) {
      return
    }

    const requestStarted = Date.now()
    state.loading = true
    state.errorMessage = ''
    try {
      const details: BeszelSystemDetailsWire | null =
        await client.getSystemDetails(this.session.token, state.systemId)
      state.applyHardware(details)

      const stats: BeszelSystemStatsRecordWire | null =
        await client.getLatestSystemStats(this.session.token, state.systemId)
      const containers: BeszelContainerStatsRecordWire | null =
        await client.getLatestContainerStats(this.session.token, state.systemId)
      if (state.lastRealtimeAt <= requestStarted && stats !== null &&
        stats.stats !== undefined && stats.stats !== null) {
        state.applyMetrics(stats.stats, containers?.stats, stats.created ?? '')
      } else if (state.lastRealtimeAt <= requestStarted &&
        containers?.stats !== undefined && containers.stats !== null) {
        state.applyContainers(containers.stats)
      }
      state.loaded = true
    } catch (error) {
      if (this.isSessionRejected(error)) {
        await this.expireSavedSession()
        return
      }
      state.errorMessage = this.describeError(error, 'Unable to load detailed system data.')
    } finally {
      state.loading = false
    }
  }

  private isSessionRejected(error: Object): boolean {
    return error instanceof BeszelApiError &&
      (error.responseCode === 400 || error.responseCode === 401 || error.responseCode === 403)
  }

  private async retrySessionRefresh(): Promise<boolean> {
    if (this.client === null || !this.sessionRefreshPending) {
      return true
    }

    try {
      const refreshed = await this.client.refreshSession(this.session.token, this.session.email)
      this.session = refreshed
      this.sessionRefreshPending = false
      await this.persistSession(refreshed)
      return true
    } catch (error) {
      if (this.isSessionRejected(error)) {
        await this.expireSavedSession()
        return false
      }

      this.dashboardError =
        'Beszel is unreachable. Your saved session is safe; connect Tailscale or restore networking, then retry.'
      return false
    }
  }

  private async expireSavedSession(): Promise<void> {
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
    this.loginError = 'Your saved session was rejected by Beszel. Sign in again.'
  }

  private toSession(stored: StoredSession): BeszelSession {
    const session = new BeszelSession()
    session.baseUrl = stored.baseUrl
    session.email = stored.email
    session.token = stored.token
    return session
  }

  private describeError(error: Object, fallback: string): string {
    if (error instanceof Error && error.message.length > 0) {
      return error.message
    }
    return fallback
  }
}
