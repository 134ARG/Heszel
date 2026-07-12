import { BeszelApiError, BeszelClient } from '../api/BeszelClient'
import {
  BeszelRealtimeClient,
  BeszelRealtimeMetrics,
  BeszelSystemRealtimeEvent
} from '../api/BeszelRealtimeClient'
import { DashboardView } from '../components/DashboardView'
import { LoginView } from '../components/LoginView'
import { SettingsView } from '../components/SettingsView'
import { BeszelSession, SystemSummary } from '../model/BeszelModels'
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
  @State @Watch('onDetailContextChanged') private expanded: boolean = false
  @State @Watch('onDetailContextChanged') private settingsVisible: boolean = false
  @State @Watch('onDetailContextChanged') private compactDetailVisible: boolean = false
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
      } else if (this.settingsVisible) {
        SettingsView({
          baseUrl: this.session.baseUrl,
          email: this.session.email,
          expanded: this.expanded,
          errorMessage: this.dashboardError,
          onBack: () => {
            this.settingsVisible = false
          },
          onSignOut: () => {
            this.signOut()
          }
        })
      } else {
        DashboardView({
          systems: $systems,
          selectedId: $selectedId,
          compactDetailVisible: $compactDetailVisible,
          loading: this.refreshing,
          errorMessage: this.dashboardError,
          lastRefresh: this.lastRefresh,
          expanded: this.expanded,
          liveMetrics: this.liveMetrics,
          realtimeConnected: this.realtimeConnected,
          onRefresh: () => {
            this.handleManualRefresh()
          },
          onOpenSettings: () => {
            this.settingsVisible = true
          },
          onLiveMetricsChange: (enabled: boolean) => {
            this.liveMetrics = enabled
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldArea: Area, newArea: Area) => {
      this.expanded = Number(newArea.width) >= 600
    })
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
      this.compactDetailVisible = false
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
    if (metrics.info === undefined) {
      return
    }
    const system = this.systems.find((candidate: SystemSummary) => candidate.id === systemId)
    if (system === undefined) {
      return
    }

    system.updateMetrics(metrics.info)
    this.systems = this.systems.slice()
    this.lastRefresh = new Date().toLocaleTimeString()

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
    return !this.settingsVisible && this.selectedId.length > 0 && (this.expanded || this.compactDetailVisible)
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
    this.compactDetailVisible = false
    this.liveMetrics = false
    this.settingsVisible = false
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
    this.compactDetailVisible = false
    this.liveMetrics = false
    this.settingsVisible = false
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
