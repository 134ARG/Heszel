#ifndef IROH_HOS_H
#define IROH_HOS_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define IROH_HOS_ABI_VERSION 2u
#define IROH_HOS_SECRET_KEY_LENGTH 32u
#define IROH_HOS_ENDPOINT_ID_CAPACITY 128u

enum IrohHosResult {
    IROH_HOS_OK = 0,
    IROH_HOS_INVALID_ARGUMENT = 1,
    IROH_HOS_START_FAILED = 2,
    IROH_HOS_NOT_RUNNING = 3,
    IROH_HOS_INTERNAL_ERROR = 4,
    IROH_HOS_PANIC = 5,
};

enum IrohHosTunnelState {
    IROH_HOS_STATE_STOPPED = 0,
    IROH_HOS_STATE_STARTING = 1,
    IROH_HOS_STATE_CONNECTING = 2,
    IROH_HOS_STATE_CONNECTED = 3,
    IROH_HOS_STATE_RECONNECTING = 4,
    IROH_HOS_STATE_SUSPENDED = 5,
};

typedef struct IrohHosTunnel IrohHosTunnel;

typedef struct IrohHosStartConfig {
    uint32_t abi_version;
    const char *server_endpoint_id;
    const char *server_relay_url;
    const char *const *server_direct_addresses;
    size_t server_direct_address_count;
    const uint8_t *secret_key;
    size_t secret_key_len;
    const uint8_t *alpn;
    size_t alpn_len;
    uint8_t use_default_relays;
    uint64_t connect_timeout_ms;
    uint64_t reconnect_min_delay_ms;
    uint64_t reconnect_max_delay_ms;
} IrohHosStartConfig;

typedef struct IrohHosTunnelInfo {
    uint32_t state;
    uint16_t local_port;
    uint16_t reserved;
    char local_endpoint_id[IROH_HOS_ENDPOINT_ID_CAPACITY];
} IrohHosTunnelInfo;

uint32_t iroh_hos_abi_version(void);

const char *iroh_hos_version(void);

int32_t iroh_hos_generate_secret_key(uint8_t *output, size_t output_len);

int32_t iroh_hos_endpoint_id_from_secret_key(
    const uint8_t *secret_key,
    size_t secret_key_len,
    char *output,
    size_t output_capacity
);

int32_t iroh_hos_tunnel_start(
    const IrohHosStartConfig *config,
    IrohHosTunnel **output_tunnel,
    IrohHosTunnelInfo *output_info,
    char *error_output,
    size_t error_output_capacity
);

int32_t iroh_hos_tunnel_get_info(
    const IrohHosTunnel *tunnel,
    IrohHosTunnelInfo *output_info
);

int32_t iroh_hos_tunnel_suspend(const IrohHosTunnel *tunnel);

int32_t iroh_hos_tunnel_resume(const IrohHosTunnel *tunnel);

int32_t iroh_hos_tunnel_network_change(const IrohHosTunnel *tunnel);

/* Returns the required buffer size including the trailing NUL. */
size_t iroh_hos_tunnel_last_error(
    const IrohHosTunnel *tunnel,
    char *output,
    size_t output_capacity
);

int32_t iroh_hos_tunnel_stop(const IrohHosTunnel *tunnel);

/* Immediately tears down the local runtime without waiting for QUIC drain acknowledgements. */
int32_t iroh_hos_tunnel_abort(const IrohHosTunnel *tunnel);

/* Stops the tunnel if necessary and releases the opaque handle. */
void iroh_hos_tunnel_free(IrohHosTunnel *tunnel);

#ifdef __cplusplus
}
#endif

#endif
