import { HealthMetricsState, SensorMetric } from '../model/SystemDetailModels'
import { DetailCardHeader } from './DetailCardHeader'
import { DetailValueRow } from './DetailValueRow'

@Component
struct SensorRow {
  @ObjectLink sensor: SensorMetric

  build() {
    DetailValueRow({
      label: this.sensor.name,
      value: `${this.sensor.temperatureCelsius.toFixed(0)} °C`,
      warning: this.sensor.temperatureCelsius >= 80
    })
  }
}

@Component
export struct HealthCard {
  @ObjectLink state: HealthMetricsState

  build() {
    Column({ space: 11 }) {
      DetailCardHeader({ title: $r('app.string.health') })

      if (this.state.batteryVisible()) {
        DetailValueRow({
          label: this.batteryStateLabel(),
          value: `${this.batteryPercent().toFixed(0)}%`,
          warning: this.batteryPercent() < 20
        })
      }
      ForEach(this.state.sensors, (sensor: SensorMetric) => {
        SensorRow({ sensor: sensor })
      }, (sensor: SensorMetric) => sensor.name)
    }
    .width('100%')
    .padding(18)
    .backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') })
    .borderRadius(16)
  }

  private batteryPercent(): number {
    return this.state.batteryPercent
  }

  private batteryState(): number {
    return this.state.batteryState
  }

  private batteryStateLabel(): ResourceStr {
    switch (this.batteryState()) {
      case 1:
        return $r('app.string.battery_charging')
      case 2:
        return $r('app.string.battery_discharging')
      case 3:
        return $r('app.string.battery_full')
      default:
        return $r('app.string.battery')
    }
  }
}
