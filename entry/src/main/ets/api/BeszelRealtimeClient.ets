import { BusinessError } from '@kit.BasicServicesKit'
import { http } from '@kit.NetworkKit'
import { util } from '@kit.ArkTS'
import { BeszelSystemInfoWire, BeszelSystemWire } from '../model/BeszelModels'

export interface BeszelSystemRealtimeEvent {
  action: string
  record: BeszelSystemWire
}

export interface BeszelRealtimeMetrics {
  info?: BeszelSystemInfoWire
}

class RealtimeSubscriptionBody {
  clientId: string = ''
  subscriptions: string[] = []
}

class RealtimeSystemQuery {
  system: string = ''
}

class RealtimeTopicOptions {
  query: RealtimeSystemQuery = new RealtimeSystemQuery()
}

class SseMessage {
  id: string = ''
  event: string = ''
  data: string = ''
}

export class BeszelRealtimeClient {
  private readonly baseUrl: string
  private readonly token: string
  private readonly onSystemEvent: (event: BeszelSystemRealtimeEvent) => void
  private readonly onMetrics: (systemId: string, metrics: BeszelRealtimeMetrics) => void
  private readonly onConnectionChanged: (connected: boolean) => void
  private readonly onError: (error: Error) => void
  private stream: http.HttpRequest | null = null
  private decoder: util.TextDecoder = util.TextDecoder.create('utf-8')
  private buffer: string = ''
  private clientId: string = ''
  private metricsSystemId: string = ''
  private reconnectTimer: number = -1
  private generation: number = 0
  private shouldConnect: boolean = false
  private submitInFlight: boolean = false
  private submitPending: boolean = false

  constructor(
    baseUrl: string,
    token: string,
    onSystemEvent: (event: BeszelSystemRealtimeEvent) => void,
    onMetrics: (systemId: string, metrics: BeszelRealtimeMetrics) => void,
    onConnectionChanged: (connected: boolean) => void,
    onError: (error: Error) => void
  ) {
    this.baseUrl = baseUrl
    this.token = token
    this.onSystemEvent = onSystemEvent
    this.onMetrics = onMetrics
    this.onConnectionChanged = onConnectionChanged
    this.onError = onError
  }

  connect(): void {
    if (this.shouldConnect) {
      return
    }
    this.shouldConnect = true
    this.connectStream()
  }

  disconnect(): void {
    this.shouldConnect = false
    this.metricsSystemId = ''
    this.clientId = ''
    this.buffer = ''
    this.submitPending = false
    this.generation += 1
    if (this.reconnectTimer >= 0) {
      clearTimeout(this.reconnectTimer)
      this.reconnectTimer = -1
    }
    if (this.stream !== null) {
      this.stream.destroy()
      this.stream = null
    }
    this.onConnectionChanged(false)
  }

  setMetricsSystem(systemId: string): void {
    if (this.metricsSystemId === systemId) {
      return
    }
    this.metricsSystemId = systemId
    this.submitSubscriptions()
  }

  private connectStream(): void {
    if (!this.shouldConnect) {
      return
    }

    this.generation += 1
    const currentGeneration = this.generation
    this.clientId = ''
    this.buffer = ''
    this.decoder = util.TextDecoder.create('utf-8')
    if (this.stream !== null) {
      this.stream.destroy()
    }

    const request = http.createHttp()
    this.stream = request
    request.on('dataReceive', (data: ArrayBuffer) => {
      if (currentGeneration !== this.generation) {
        return
      }
      const chunk = this.decoder.decodeToString(new Uint8Array(data), { stream: true })
      this.consumeChunk(chunk)
    })
    request.on('dataEnd', () => {
      this.handleStreamEnd(currentGeneration)
    })

    request.requestInStream(`${this.baseUrl}/api/realtime`, {
      method: http.RequestMethod.GET,
      header: {
        'Accept': 'text/event-stream',
        'Cache-Control': 'no-cache'
      },
      connectTimeout: 15000,
      readTimeout: 310000
    }, (error: BusinessError, responseCode: number) => {
      if (currentGeneration !== this.generation) {
        return
      }
      if (error) {
        this.handleStreamFailure(currentGeneration, new Error(error.message))
        return
      }
      if (responseCode < 200 || responseCode >= 300) {
        this.handleStreamFailure(currentGeneration, new Error(`Realtime connection failed (${responseCode}).`))
      }
    })
  }

  private consumeChunk(chunk: string): void {
    this.buffer = (this.buffer + chunk).replace(/\r\n/g, '\n')
    let separator = this.buffer.indexOf('\n\n')
    while (separator >= 0) {
      const block = this.buffer.slice(0, separator)
      this.buffer = this.buffer.slice(separator + 2)
      this.consumeMessage(this.parseMessage(block))
      separator = this.buffer.indexOf('\n\n')
    }
  }

  private parseMessage(block: string): SseMessage {
    const message = new SseMessage()
    const dataLines: string[] = []
    block.split('\n').forEach((line: string) => {
      if (line.startsWith('id:')) {
        message.id = line.slice(3).trim()
      } else if (line.startsWith('event:')) {
        message.event = line.slice(6).trim()
      } else if (line.startsWith('data:')) {
        dataLines.push(line.slice(5).trimStart())
      }
    })
    message.data = dataLines.join('\n')
    return message
  }

  private consumeMessage(message: SseMessage): void {
    if (message.event === 'PB_CONNECT') {
      this.clientId = message.id
      this.submitSubscriptions()
      return
    }
    if (message.event.startsWith('systems/')) {
      try {
        this.onSystemEvent(JSON.parse(message.data) as BeszelSystemRealtimeEvent)
      } catch (_) {
        this.onError(new Error('Beszel sent an invalid system update.'))
      }
      return
    }
    if (message.event.startsWith('rt_metrics')) {
      try {
        this.onMetrics(this.systemIdFromMetricsTopic(message.event), JSON.parse(message.data) as BeszelRealtimeMetrics)
      } catch (_) {
        this.onError(new Error('Beszel sent invalid realtime metrics.'))
      }
    }
  }

  private systemIdFromMetricsTopic(topic: string): string {
    const marker = 'options='
    const markerIndex = topic.indexOf(marker)
    if (markerIndex < 0) {
      return this.metricsSystemId
    }
    const encoded = topic.slice(markerIndex + marker.length).split('&')[0]
    const options = JSON.parse(decodeURIComponent(encoded)) as RealtimeTopicOptions
    return options.query.system
  }

  private topics(): string[] {
    const topics: string[] = ['systems/*']
    if (this.metricsSystemId.length > 0) {
      const options = new RealtimeTopicOptions()
      options.query.system = this.metricsSystemId
      topics.push(`rt_metrics?options=${encodeURIComponent(JSON.stringify(options))}`)
    }
    return topics
  }

  private async submitSubscriptions(): Promise<void> {
    if (!this.shouldConnect || this.clientId.length === 0) {
      return
    }
    if (this.submitInFlight) {
      this.submitPending = true
      return
    }

    this.submitInFlight = true
    const submittedClientId = this.clientId
    const request = http.createHttp()
    const body = new RealtimeSubscriptionBody()
    body.clientId = this.clientId
    body.subscriptions = this.topics()
    try {
      const response = await request.request(`${this.baseUrl}/api/realtime`, {
        method: http.RequestMethod.POST,
        header: {
          'Accept': 'application/json',
          'Authorization': this.token,
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify(body),
        connectTimeout: 15000,
        readTimeout: 15000
      })
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new Error(`Realtime subscription failed (${response.responseCode}).`)
      }
      if (this.shouldConnect && this.clientId === submittedClientId) {
        this.onConnectionChanged(true)
      }
    } catch (error) {
      if (this.shouldConnect && this.clientId === submittedClientId) {
        this.onConnectionChanged(false)
        this.onError(error instanceof Error ? error : new Error('Unable to update realtime subscriptions.'))
        if (this.stream !== null) {
          this.stream.destroy()
        }
      }
    } finally {
      request.destroy()
      this.submitInFlight = false
      if (this.submitPending) {
        this.submitPending = false
        this.submitSubscriptions()
      }
    }
  }

  private handleStreamFailure(generation: number, error: Error): void {
    if (generation !== this.generation) {
      return
    }
    this.onError(error)
    this.handleStreamEnd(generation)
  }

  private handleStreamEnd(generation: number): void {
    if (generation !== this.generation) {
      return
    }
    this.generation += 1
    this.clientId = ''
    if (this.stream !== null) {
      this.stream.destroy()
      this.stream = null
    }
    this.onConnectionChanged(false)
    if (this.shouldConnect && this.reconnectTimer < 0) {
      this.reconnectTimer = setTimeout(() => {
        this.reconnectTimer = -1
        this.connectStream()
      }, 2000)
    }
  }
}
