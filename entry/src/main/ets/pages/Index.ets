import { BeszelApiError, BeszelClient } from '../api/BeszelClient'
import { DashboardView } from '../components/DashboardView'
import { LoginView } from '../components/LoginView'
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
  @State private expanded: boolean = false
  @State private restoringSession: boolean = true
  @State private savedServerUrl: string = ''
  @State private savedEmail: string = ''
  private client: BeszelClient | null = null
  private sessionRepository: SessionRepository | null = null
  private pollTimer: number = -1
  private refreshInFlight: boolean = false
  private manualRefreshPending: boolean = false
  private sessionRefreshPending: boolean = false

  aboutToAppear(): void {
    this.restoreSession()
  }

  onPageShow(): void {
    if (this.session.token.length > 0) {
      this.startPolling()
      this.refreshSystems(false)
    }
  }

  onPageHide(): void {
    this.stopPolling()
  }

  aboutToDisappear(): void {
    this.stopPolling()
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
          systems: this.systems,
          selectedId: $selectedId,
          loading: this.refreshing,
          errorMessage: this.dashboardError,
          lastRefresh: this.lastRefresh,
          expanded: this.expanded,
          onRefresh: () => {
            this.refreshSystems(true)
          },
          onSignOut: () => {
            this.signOut()
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
      this.startPolling()
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

  private startPolling(): void {
    this.stopPolling()
    this.pollTimer = setInterval(() => {
      this.refreshSystems(false)
    }, 15000)
  }

  private stopPolling(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer)
      this.pollTimer = -1
    }
  }

  private async signOut(): Promise<void> {
    this.stopPolling()
    if (this.sessionRepository !== null) {
      try {
        await this.sessionRepository.clearToken()
      } catch (_) {
        this.dashboardError = 'Unable to remove the protected session token. Please try again.'
        this.startPolling()
        return
      }
    }
    this.client = null
    this.session = new BeszelSession()
    this.sessionRefreshPending = false
    this.systems = []
    this.selectedId = ''
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
      }
      if (this.session.token.length > 0) {
        this.startPolling()
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
    this.stopPolling()
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
