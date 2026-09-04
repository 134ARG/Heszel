import { DashboardView } from '../components/DashboardView'
import { DashboardController } from '../controller/DashboardController'

@Entry
@Component
struct Index {
  @State private dashboard: DashboardController = new DashboardController()
  @StorageProp('curScreenSizeString') private curScreenSizeString: string = 'sm'
  @StorageProp('curWindowWidthVp') private curWindowWidthVp: number = 0

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
      } else {
        DashboardView({
          controller: this.dashboard,
          expanded: this.curScreenSizeString === 'lg',
          windowWidthVp: this.curWindowWidthVp
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
