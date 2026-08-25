import { DashboardView } from '../components/DashboardView'
import { LoginView } from '../components/LoginView'
import { DashboardController } from '../controller/DashboardController'
import { LoginRequest } from '../model/ConnectionModels'

@Entry
@Component
struct Index {
  @State private dashboard: DashboardController = new DashboardController()
  @StorageProp('curScreenSizeString') private curScreenSizeString: string = 'sm'

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext()
    if (context === undefined) {
      this.dashboard.restoringSession = false
      return
    }
    this.dashboard.aboutToAppear(context)
  }

  onPageShow(): void {
    this.dashboard.onPageShow()
  }

  onPageHide(): void {
    this.dashboard.onPageHide()
  }

  aboutToDisappear(): void {
    this.dashboard.aboutToDisappear()
  }

  build() {
    Stack() {
      if (this.dashboard.restoringSession) {
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
      } else if (this.dashboard.session.token.length === 0) {
        LoginView({
          loading: this.dashboard.signingIn,
          errorMessage: this.dashboard.loginError,
          initialConnectionMode: this.dashboard.savedConnectionMode,
          initialServerUrl: this.dashboard.savedServerUrl,
          initialEmail: this.dashboard.savedEmail,
          initialGatewayKey: this.dashboard.savedGatewayKey,
          initialIrohPairingJson: this.dashboard.savedIrohPairingJson,
          onLogin: (request: LoginRequest) => this.dashboard.login(request)
        })
      } else {
        DashboardView({
          systems: this.dashboard.systems,
          selectedId: this.dashboard.selectedId,
          detailState: this.dashboard.detailState,
          loading: this.dashboard.refreshing,
          errorMessage: this.dashboard.dashboardError,
          lastRefresh: this.dashboard.lastRefresh,
          expanded: this.curScreenSizeString === 'lg',
          liveMetrics: this.dashboard.liveMetrics,
          updateWhileScrolling: this.dashboard.updateWhileScrolling,
          realtimeConnected: this.dashboard.realtimeConnected,
          connectionMode: this.dashboard.savedConnectionMode,
          connectionLabel: this.dashboard.connectionLabel(),
          connectionDetail: this.dashboard.connectionDetail(),
          email: this.dashboard.session.email,
          onSelectedIdChange: (id: string) => this.dashboard.selectSystem(id),
          onRefresh: () => this.dashboard.refresh(),
          onLiveMetricsChange: (enabled: boolean) => this.dashboard.setLiveMetrics(enabled),
          onUpdateWhileScrollingChange: (enabled: boolean) =>
            this.dashboard.updateScrollingPreference(enabled),
          onDetailVisibilityChange: (visible: boolean) => this.dashboard.setDetailVisible(visible),
          onDetailScrollingChange: (scrolling: boolean) => this.dashboard.setDetailScrolling(scrolling),
          onGatewayKeyChange: (gatewayKey: string) => this.dashboard.updateGatewayKey(gatewayKey),
          onSignOut: () => this.dashboard.signOut()
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
