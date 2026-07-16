import { IrohPairing, IrohPairingWire } from '../model/ConnectionModels'

export class IrohPairingCodec {
  static parse(raw: string): IrohPairing {
    let wire: IrohPairingWire
    try {
      wire = JSON.parse(raw) as IrohPairingWire
    } catch (_) {
      throw new Error('This QR code does not contain a valid Iroh pairing.')
    }

    if (wire.type !== 'iroh-heszel-pairing' || wire.version !== 1 ||
      typeof wire.serverEndpointId !== 'string' || wire.serverEndpointId.trim().length === 0) {
      throw new Error('This is not a supported Heszel Iroh pairing QR code.')
    }

    const pairing = new IrohPairing()
    pairing.displayName = typeof wire.displayName === 'string' ? wire.displayName.trim() : ''
    pairing.serverEndpointId = wire.serverEndpointId.trim()
    pairing.serverRelayUrl = typeof wire.serverRelayUrl === 'string' ? wire.serverRelayUrl.trim() : ''
    pairing.alpn = typeof wire.alpn === 'string' && wire.alpn.trim().length > 0 ?
      wire.alpn.trim() : 'heszel/beszel-tcp/1'
    pairing.serverDirectAddresses = []
    if (Array.isArray(wire.serverDirectAddresses)) {
      wire.serverDirectAddresses.forEach((address: string) => {
        if (typeof address === 'string' && address.trim().length > 0) {
          pairing.serverDirectAddresses.push(address.trim())
        }
      })
    }
    return pairing
  }

  static stringify(pairing: IrohPairing): string {
    if (!pairing.isUsable()) {
      return ''
    }
    const wire: IrohPairingWire = {
      type: pairing.type,
      version: pairing.version,
      displayName: pairing.displayName,
      serverEndpointId: pairing.serverEndpointId,
      serverRelayUrl: pairing.serverRelayUrl,
      serverDirectAddresses: pairing.serverDirectAddresses,
      alpn: pairing.alpn
    }
    return JSON.stringify(wire)
  }
}
