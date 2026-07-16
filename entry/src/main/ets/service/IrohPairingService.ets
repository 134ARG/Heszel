import { common } from '@kit.AbilityKit'
import { scanBarcode, scanCore } from '@kit.ScanKit'
import { IrohPairing } from '../model/ConnectionModels'
import { IrohPairingCodec } from './IrohPairingCodec'

export class IrohPairingService {
  static async scan(context: common.Context): Promise<IrohPairing> {
    try {
      const result = await scanBarcode.startScanForResult(context, {
        scanTypes: [scanCore.ScanType.QR_CODE],
        enableMultiMode: false,
        enableAlbum: true
      })
      return IrohPairingCodec.parse(result.originalValue)
    } catch (error) {
      throw error instanceof Error ? error : new Error('Unable to open the system QR scanner.')
    }
  }

}
