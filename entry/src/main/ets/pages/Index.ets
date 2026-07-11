import { BeszelClient } from '../api/BeszelClient'
import { DashboardView } from '../components/DashboardView'
import { LoginView } from '../components/LoginView'
import { BeszelSession, SystemSummary } from '../model/BeszelModels'

@Entry
@Component
struct Index {
  @State private session: BeszelSession = new BeszelSession()
  @State private systems: SystemSummary[] = []
  @State private selectedId: string = ''
  @State private signingIn: boolean = false
  @State private refreshing: boolean = false
  @State private loginError: string = ''
  @State private dashboardError: string = ''
  @State private lastRefresh: string = ''
  @State private expanded: boolean = false
  private client: BeszelClient | null = null
  private pollTimer: number = -1
  private refreshInFlight: boolean = false

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
      if (this.session.token.length === 0) {
        LoginView({
          loading: this.signingIn,
          errorMessage: this.loginError,
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
      this.systems = []
      this.selectedId = ''
      await this.refreshSystems(true)
      this.startPolling()
    } catch (error) {
      this.loginError = this.describeError(error, 'Unable to connect to Beszel.')
    } finally {
      this.signingIn = false
    }
  }

  private async refreshSystems(showLoading: boolean): Promise<void> {
    if (this.client === null || this.session.token.length === 0 || this.refreshInFlight) {
      return
    }

    this.refreshInFlight = true
    if (showLoading) {
      this.refreshing = true
    }
    this.dashboardError = ''
    try {
      const systems = await this.client.listSystems(this.session.token)
      this.systems = systems
      if (systems.length > 0 && !systems.some((system: SystemSummary) => system.id === this.selectedId)) {
        this.selectedId = systems[0].id
      }
      this.lastRefresh = new Date().toLocaleTimeString()
    } catch (error) {
      this.dashboardError = this.describeError(error, 'Unable to refresh systems.')
    } finally {
      this.refreshInFlight = false
      this.refreshing = false
    }
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

  private signOut(): void {
    this.stopPolling()
    this.client = null
    this.session = new BeszelSession()
    this.systems = []
    this.selectedId = ''
    this.dashboardError = ''
    this.lastRefresh = ''
  }

  private describeError(error: Object, fallback: string): string {
    if (error instanceof Error && error.message.length > 0) {
      return error.message
    }
    return fallback
  }
}
