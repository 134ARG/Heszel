import { SystemSummary } from '../model/BeszelModels'
import { SensorMetric, SystemDetailState } from '../model/SystemDetailModels'
import { batteryStateLabel } from './DetailFormatting'
import { DetailValueRow } from './DetailValueRow'

@Component
export struct HealthCard {
  @ObjectLink detail: SystemDetailState
  @ObjectLink system: SystemSummary

  build() {
    Column({ space: 11 }) {
      Text('Health')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      if (this.batteryPercent() > 0) {
        DetailValueRow({
          label: batteryStateLabel(this.batteryState()),
          value: `${this.batteryPercent().toFixed(0)}%`,
          warning: this.batteryPercent() < 20
        })
      }
      if (this.system.servicesTotal > 0) {
        DetailValueRow({
          label: 'Services',
          value: this.system.servicesFailed > 0 ?
            `${this.system.servicesFailed.toFixed(0)} failed of ${this.system.servicesTotal.toFixed(0)}` :
            `${this.system.servicesTotal.toFixed(0)} healthy`,
          warning: this.system.servicesFailed > 0
        })
      }
      ForEach(this.detail.metrics.sensors, (sensor: SensorMetric) => {
        DetailValueRow({
          label: sensor.name,
          value: `${sensor.temperatureCelsius.toFixed(0)} °C`,
          warning: sensor.temperatureCelsius >= 80
        })
      }, (sensor: SensorMetric) => sensor.name)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
  }

  private batteryPercent(): number {
    return this.detail.metrics.batteryPercent > 0 ? this.detail.metrics.batteryPercent : this.system.batteryPercent
  }

  private batteryState(): number {
    return this.detail.metrics.batteryPercent > 0 ? this.detail.metrics.batteryState : this.system.batteryState
  }
}
