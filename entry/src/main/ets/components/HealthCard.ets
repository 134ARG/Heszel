import { HealthMetricsState, SensorMetric } from '../model/SystemDetailModels'
import { batteryStateLabel } from './DetailFormatting'
import { DetailCardHeader } from './DetailCardHeader'
import { DetailValueRow } from './DetailValueRow'

@Component
export struct HealthCard {
  @ObjectLink state: HealthMetricsState

  build() {
    Column({ space: 11 }) {
      DetailCardHeader({ title: 'Health' })

      if (this.state.batteryVisible()) {
        DetailValueRow({
          label: batteryStateLabel(this.batteryState()),
          value: `${this.batteryPercent().toFixed(0)}%`,
          warning: this.batteryPercent() < 20
        })
      }
      if (this.state.servicesVisible()) {
        DetailValueRow({
          label: 'Services',
          value: this.state.servicesFailed > 0 ?
            `${this.state.servicesFailed.toFixed(0)} failed of ${this.state.servicesTotal.toFixed(0)}` :
            `${this.state.servicesTotal.toFixed(0)} healthy`,
          warning: this.state.servicesFailed > 0
        })
      }
      ForEach(this.state.sensors, (sensor: SensorMetric) => {
        DetailValueRow({
          label: sensor.name,
          value: `${sensor.temperatureCelsius.toFixed(0)} °C`,
          warning: sensor.temperatureCelsius >= 80
        })
      }, (sensor: SensorMetric) =>
        `${sensor.name}:${sensor.temperatureCelsius.toFixed(0)}:${sensor.temperatureCelsius >= 80}`)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .borderRadius(16)
  }

  private batteryPercent(): number {
    return this.state.batteryPercent
  }

  private batteryState(): number {
    return this.state.batteryState
  }
}
