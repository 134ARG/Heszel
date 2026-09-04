import { HealthMetricsState, HumidityMetric, SensorMetric } from '../model/SystemDetailModels'
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
struct HumidityRow {
  @ObjectLink humidity: HumidityMetric

  build() {
    DetailValueRow({
      label: this.humidity.name,
      value: `${this.humidity.relativeHumidityPercent.toFixed(1)}% RH`
    })
  }
}

@Component
export struct HealthCard {
  @ObjectLink state: HealthMetricsState
  onOpenHistory: () => void = () => {}

  build() {
    Column({ space: 11 }) {
      DetailCardHeader({
        title: $r('app.string.health'),
        showAction: this.state.historyVisible(),
        actionLabel: $r('app.string.history_chart'),
        onAction: () => this.onOpenHistory()
      })

      if (this.state.batteryVisible()) {
        DetailValueRow({
          label: this.batteryStateLabel(),
          value: `${this.batteryPercent().toFixed(0)}%`,
          warning: this.batteryPercent() < 20
        })
      }
      if (this.state.humidityAvailable && this.state.sensorsAvailable) {
        Text($r('app.string.temperature'))
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
      }
      if (this.state.sensorsAvailable) {
        ForEach(this.state.sensors, (sensor: SensorMetric) => {
          SensorRow({ sensor: sensor })
        }, (sensor: SensorMetric) => sensor.name)
      }
      if (this.state.humidityAvailable) {
        Text($r('app.string.humidity'))
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
        ForEach(this.state.humidities, (humidity: HumidityMetric) => {
          HumidityRow({ humidity: humidity })
        }, (humidity: HumidityMetric) => humidity.name)
      }
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
