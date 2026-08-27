const formStorage = new LocalStorage()

@Entry(formStorage)
@Component
struct SystemsCard {
  @LocalStorageProp('s') private summary: string = 'Open Heszel to load systems'
  @LocalStorageProp('r') private updated: string = 'No cached data'
  @LocalStorageProp('c') private count: string = '0'
  @LocalStorageProp('p') private page: string = '0'
  @LocalStorageProp('n') private name: string = ''
  @LocalStorageProp('h') private host: string = ''
  @LocalStorageProp('u') private up: string = '0'
  @LocalStorageProp('a') private cpu: string = '0'
  @LocalStorageProp('m') private memory: string = '0'
  @LocalStorageProp('d') private disk: string = '0'
  @LocalStorageProp('t') private temperature: string = '--'
  @LocalStorageProp('v') private uptime: string = 'Uptime --'
  @LocalStorageProp('l') private load: string = '--  --  --'
  @LocalStorageProp('nd') private networkDown: string = '--'
  @LocalStorageProp('nu') private networkUp: string = '--'
  @LocalStorageProp('dr') private diskRead: string = '--'
  @LocalStorageProp('dw') private diskWrite: string = '--'
  @LocalStorageProp('q') private refreshing: string = '0'

  build() {
    Column() {
      if (this.count === '0') {
        this.emptyPage()
      } else {
        this.systemPage()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.surface'))
  }

  @Builder
  private emptyPage() {
    Column({ space: 8 }) {
      Text('Heszel')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text(this.summary)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
      Text(this.updated)
        .fontSize(10)
        .fontColor($r('app.color.text_tertiary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => this.openHeszel())
  }

  @Builder
  private systemPage() {
    Column() {
      Row({ space: 8 }) {
        Text('●')
          .fontSize(10)
          .fontColor(this.up === '1' ? $r('app.color.status_up') : $r('app.color.status_down'))
        Column({ space: 1 }) {
          Text(this.name)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.host)
            .fontSize(10)
            .fontColor($r('app.color.text_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Column({ space: 1 }) {
          Text(this.temperature)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Text(this.uptime)
            .fontSize(9)
            .fontColor($r('app.color.text_tertiary'))
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .onClick(() => this.openHeszel())

      Divider()
        .color($r('app.color.divider'))
        .margin({ top: 6, bottom: 4 })

      Row({ space: 9 }) {
        Column() {
          Row({ space: 7 }) {
            Text('CPU')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_label'))
              .width(34)
            Stack({ alignContent: Alignment.Start }) {
              Row()
                .width('100%')
                .height(8)
                .borderRadius(4)
                .backgroundColor($r('app.color.progress_track'))
              Row()
                .width(`${this.cpu}%`)
                .height(8)
                .borderRadius(4)
                .backgroundColor($r('app.color.metric_cpu'))
            }
            .layoutWeight(1)
            .height(8)
            Text(`${this.cpu}%`)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .textAlign(TextAlign.End)
              .width(36)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .layoutWeight(1)

          Row({ space: 7 }) {
            Text('RAM')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_label'))
              .width(34)
            Stack({ alignContent: Alignment.Start }) {
              Row()
                .width('100%')
                .height(8)
                .borderRadius(4)
                .backgroundColor($r('app.color.progress_track'))
              Row()
                .width(`${this.memory}%`)
                .height(8)
                .borderRadius(4)
                .backgroundColor($r('app.color.metric_memory'))
            }
            .layoutWeight(1)
            .height(8)
            Text(`${this.memory}%`)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .textAlign(TextAlign.End)
              .width(36)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .layoutWeight(1)

          Row({ space: 7 }) {
            Text('DISK')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_label'))
              .width(34)
            Stack({ alignContent: Alignment.Start }) {
              Row()
                .width('100%')
                .height(8)
                .borderRadius(4)
                .backgroundColor($r('app.color.progress_track'))
              Row()
                .width(`${this.disk}%`)
                .height(8)
                .borderRadius(4)
                .backgroundColor($r('app.color.metric_disk'))
            }
            .layoutWeight(1)
            .height(8)
            Text(`${this.disk}%`)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
              .textAlign(TextAlign.End)
              .width(36)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .layoutWeight(1)
        }
        .layoutWeight(5)
        .height('100%')

        Row()
          .width(1)
          .height('72%')
          .backgroundColor($r('app.color.divider'))

        Row({ space: 7 }) {
          Column({ space: 2 }) {
            Text('NETWORK')
              .fontSize(9)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_label'))
            Text(`↓ ${this.networkDown}`)
              .fontSize(10)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
            Text(`↑ ${this.networkUp}`)
              .fontSize(10)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Row()
            .width(1)
            .height('72%')
            .backgroundColor($r('app.color.divider'))

          Column({ space: 2 }) {
            Text('DISK I/O')
              .fontSize(9)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_label'))
            Text(`R ${this.diskRead}`)
              .fontSize(10)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
            Text(`W ${this.diskWrite}`)
              .fontSize(10)
              .fontColor($r('app.color.text_primary'))
              .maxLines(1)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(4)
        .height('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(VerticalAlign.Center)

      Row() {
        // Card frameworks cap animations at ~1s and forbid loops, so the busy state
        // is a static dimmed glyph driven purely by form data.
        Text('↻')
          .fontSize(22)
          .fontColor($r('app.color.action'))
          .opacity(this.refreshing === '1' ? 0.35 : 1)
          .textAlign(TextAlign.Center)
          .width(34)
          .height(28)
          .onClick(() => this.refreshCard())

        Text(`${this.updated}  ·  ${this.load}`)
          .fontSize(9)
          .fontColor($r('app.color.text_secondary'))
          .maxLines(1)
          .layoutWeight(1)

        Row() {
          Text('‹')
            .fontSize(24)
            .fontColor(this.pageNumber() > 0 ? $r('app.color.action') : $r('app.color.text_tertiary'))
            .textAlign(TextAlign.Center)
            .width(32)
            .height(28)
            .opacity(this.pageNumber() > 0 ? 1 : 0.35)
            .onClick(() => this.changePage(this.pageNumber() - 1))
          Text(`${this.pageNumber() + 1}/${this.count}`)
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
            .textAlign(TextAlign.Center)
            .width(36)
          Text('›')
            .fontSize(24)
            .fontColor(this.hasNext() ? $r('app.color.action') : $r('app.color.text_tertiary'))
            .textAlign(TextAlign.Center)
            .width(32)
            .height(28)
            .opacity(this.hasNext() ? 1 : 0.35)
            .onClick(() => this.changePage(this.pageNumber() + 1))
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height(28)
      .margin({ top: 1 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 6 })
  }

  private openHeszel(): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility'
    })
  }

  private refreshCard(): void {
    // The extension deduplicates concurrent refreshes; gating here would wedge
    // the card forever whenever an extension dies before publishing q=0.
    this.refreshing = '1'
    postCardAction(this, {
      action: 'message',
      params: {
        event: 'refresh'
      }
    })
  }

  private changePage(page: number): void {
    if (page < 0 || page >= this.countNumber()) {
      return
    }
    postCardAction(this, {
      action: 'message',
      params: {
        event: 'page',
        page: page.toString()
      }
    })
  }

  private pageNumber(): number {
    const page = Number(this.page)
    return Number.isFinite(page) ? Math.max(0, Math.floor(page)) : 0
  }

  private countNumber(): number {
    const count = Number(this.count)
    return Number.isFinite(count) ? Math.max(0, Math.floor(count)) : 0
  }

  private hasNext(): boolean {
    return this.pageNumber() + 1 < this.countNumber()
  }
}
