import { BeszelClient } from '../api/BeszelClient'
import {
  BeszelContainerStatsRecordWire,
  BeszelSystemDetailsWire,
  BeszelSystemStatsRecordWire
} from '../model/SystemDetailModels'
import { BeszelSmartDeviceWire } from '../model/SmartModels'
import { SessionRefreshService } from './SessionRefreshService'

export class LoadedSystemDetail {
  details: BeszelSystemDetailsWire | null = null
  statsHistory: BeszelSystemStatsRecordWire[] = []
  containers: BeszelContainerStatsRecordWire | null = null
  smartDevices: BeszelSmartDeviceWire[] | null = null
}

export class SystemDetailLoader {
  async load(client: BeszelClient, token: string, systemId: string): Promise<LoadedSystemDetail> {
    const responses = await Promise.all([
      client.getSystemDetails(token, systemId),
      this.getStatsHistoryWithRetry(client, token, systemId),
      this.getOptionalContainerStats(client, token, systemId),
      this.getOptionalSmartDevices(client, token, systemId)
    ])
    const result = new LoadedSystemDetail()
    result.details = responses[0] as BeszelSystemDetailsWire | null
    result.statsHistory = responses[1] as BeszelSystemStatsRecordWire[]
    result.containers = responses[2] as BeszelContainerStatsRecordWire | null
    result.smartDevices = responses[3] as BeszelSmartDeviceWire[] | null
    return result
  }

  private async getStatsHistoryWithRetry(client: BeszelClient, token: string,
    systemId: string): Promise<BeszelSystemStatsRecordWire[]> {
    try {
      return await client.getSystemStatsHistory(token, systemId)
    } catch (error) {
      if (SessionRefreshService.isAccessRejected(error)) {
        throw error instanceof Error ? error : new Error('System history access was rejected.')
      }
      await new Promise<void>((resolve: () => void): void => {
        setTimeout(resolve, 5000)
      })
      return client.getSystemStatsHistory(token, systemId)
    }
  }

  private async getOptionalContainerStats(client: BeszelClient, token: string,
    systemId: string): Promise<BeszelContainerStatsRecordWire | null> {
    try {
      return await client.getLatestContainerStats(token, systemId)
    } catch (error) {
      if (SessionRefreshService.isAccessRejected(error)) {
        throw error instanceof Error ? error : new Error('Container metrics access was rejected.')
      }
      return null
    }
  }

  private async getOptionalSmartDevices(client: BeszelClient, token: string,
    systemId: string): Promise<BeszelSmartDeviceWire[] | null> {
    try {
      return await client.getSmartDevices(token, systemId)
    } catch (error) {
      if (SessionRefreshService.isAccessRejected(error)) {
        throw error instanceof Error ? error : new Error('Disk health access was rejected.')
      }
      return null
    }
  }
}
