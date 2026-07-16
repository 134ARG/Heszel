#include <algorithm>
#include <array>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

#include <napi/native_api.h>

#include "iroh_hos.h"

namespace {

constexpr const char *DEFAULT_ALPN = "heszel/beszel-tcp/1";
constexpr size_t ERROR_CAPACITY = 1024;

std::mutex gTunnelMutex;
IrohHosTunnel *gTunnel = nullptr;

struct CleanupRegistration {
    napi_env env = nullptr;
};

std::vector<CleanupRegistration *> gCleanupRegistrations;

struct StartWork {
    napi_env env = nullptr;
    napi_deferred deferred = nullptr;
    napi_async_work work = nullptr;
    std::string serverEndpointId;
    std::string serverRelayUrl;
    std::vector<std::string> directAddresses;
    std::array<uint8_t, IROH_HOS_SECRET_KEY_LENGTH> secretKey{};
    std::string alpn = DEFAULT_ALPN;
    bool useDefaultRelays = true;
    uint64_t connectTimeoutMs = 15000;
    uint64_t reconnectMinDelayMs = 250;
    uint64_t reconnectMaxDelayMs = 5000;
    IrohHosTunnelInfo info{};
    int32_t result = IROH_HOS_OK;
    std::array<char, ERROR_CAPACITY> error{};
};

struct StopWork {
    napi_env env = nullptr;
    napi_deferred deferred = nullptr;
    napi_async_work work = nullptr;
    int32_t result = IROH_HOS_OK;
};

bool NapiOk(napi_env env, napi_status status, const char *operation) {
    if (status == napi_ok) {
        return true;
    }
    napi_throw_error(env, nullptr, operation);
    return false;
}

napi_value Undefined(napi_env env) {
    napi_value value = nullptr;
    napi_get_undefined(env, &value);
    return value;
}

bool GetRequiredProperty(napi_env env, napi_value object, const char *name, napi_value *value) {
    bool hasProperty = false;
    if (!NapiOk(env, napi_has_named_property(env, object, name, &hasProperty), "Failed to inspect tunnel config")) {
        return false;
    }
    if (!hasProperty) {
        std::string message = std::string("Missing required tunnel config property: ") + name;
        napi_throw_type_error(env, nullptr, message.c_str());
        return false;
    }
    return NapiOk(env, napi_get_named_property(env, object, name, value), "Failed to read tunnel config");
}

bool GetOptionalProperty(napi_env env, napi_value object, const char *name, napi_value *value, bool *present) {
    if (!NapiOk(env, napi_has_named_property(env, object, name, present), "Failed to inspect tunnel config")) {
        return false;
    }
    if (!*present) {
        return true;
    }
    return NapiOk(env, napi_get_named_property(env, object, name, value), "Failed to read tunnel config");
}

bool ReadString(napi_env env, napi_value value, const char *name, std::string *output) {
    napi_valuetype type = napi_undefined;
    if (!NapiOk(env, napi_typeof(env, value, &type), "Failed to inspect string value")) {
        return false;
    }
    if (type != napi_string) {
        std::string message = std::string(name) + " must be a string";
        napi_throw_type_error(env, nullptr, message.c_str());
        return false;
    }
    size_t length = 0;
    if (!NapiOk(env, napi_get_value_string_utf8(env, value, nullptr, 0, &length), "Failed to size string")) {
        return false;
    }
    std::vector<char> buffer(length + 1, 0);
    if (!NapiOk(
            env,
            napi_get_value_string_utf8(env, value, buffer.data(), buffer.size(), &length),
            "Failed to read string")) {
        return false;
    }
    output->assign(buffer.data(), length);
    return true;
}

bool ReadOptionalString(
    napi_env env,
    napi_value object,
    const char *name,
    std::string *output
) {
    napi_value value = nullptr;
    bool present = false;
    if (!GetOptionalProperty(env, object, name, &value, &present)) {
        return false;
    }
    if (!present) {
        return true;
    }
    return ReadString(env, value, name, output);
}

bool ReadOptionalBool(napi_env env, napi_value object, const char *name, bool *output) {
    napi_value value = nullptr;
    bool present = false;
    if (!GetOptionalProperty(env, object, name, &value, &present)) {
        return false;
    }
    if (!present) {
        return true;
    }
    napi_valuetype type = napi_undefined;
    if (!NapiOk(env, napi_typeof(env, value, &type), "Failed to inspect boolean value")) {
        return false;
    }
    if (type != napi_boolean) {
        std::string message = std::string(name) + " must be a boolean";
        napi_throw_type_error(env, nullptr, message.c_str());
        return false;
    }
    return NapiOk(env, napi_get_value_bool(env, value, output), "Failed to read boolean");
}

bool ReadOptionalUint64(napi_env env, napi_value object, const char *name, uint64_t *output) {
    napi_value value = nullptr;
    bool present = false;
    if (!GetOptionalProperty(env, object, name, &value, &present)) {
        return false;
    }
    if (!present) {
        return true;
    }
    napi_valuetype type = napi_undefined;
    if (!NapiOk(env, napi_typeof(env, value, &type), "Failed to inspect number value")) {
        return false;
    }
    if (type != napi_number) {
        std::string message = std::string(name) + " must be a number";
        napi_throw_type_error(env, nullptr, message.c_str());
        return false;
    }
    double number = 0;
    if (!NapiOk(env, napi_get_value_double(env, value, &number), "Failed to read number")) {
        return false;
    }
    if (number < 0 || number > static_cast<double>(UINT64_MAX)) {
        std::string message = std::string(name) + " is outside the supported range";
        napi_throw_range_error(env, nullptr, message.c_str());
        return false;
    }
    *output = static_cast<uint64_t>(number);
    return true;
}

bool ReadSecretKey(
    napi_env env,
    napi_value value,
    std::array<uint8_t, IROH_HOS_SECRET_KEY_LENGTH> *output
) {
    void *data = nullptr;
    size_t length = 0;
    bool isArrayBuffer = false;
    if (!NapiOk(env, napi_is_arraybuffer(env, value, &isArrayBuffer), "Failed to inspect secret key")) {
        return false;
    }
    if (isArrayBuffer) {
        if (!NapiOk(env, napi_get_arraybuffer_info(env, value, &data, &length), "Failed to read secret key")) {
            return false;
        }
    } else {
        bool isTypedArray = false;
        if (!NapiOk(env, napi_is_typedarray(env, value, &isTypedArray), "Failed to inspect secret key")) {
            return false;
        }
        if (!isTypedArray) {
            napi_throw_type_error(env, nullptr, "secretKey must be an ArrayBuffer or Uint8Array");
            return false;
        }
        napi_typedarray_type arrayType = napi_uint8_array;
        napi_value arrayBuffer = nullptr;
        size_t byteOffset = 0;
        if (!NapiOk(
                env,
                napi_get_typedarray_info(
                    env,
                    value,
                    &arrayType,
                    &length,
                    &data,
                    &arrayBuffer,
                    &byteOffset),
                "Failed to read secret key")) {
            return false;
        }
        if (arrayType != napi_uint8_array && arrayType != napi_uint8_clamped_array) {
            napi_throw_type_error(env, nullptr, "secretKey typed array must contain bytes");
            return false;
        }
    }
    if (data == nullptr || length != IROH_HOS_SECRET_KEY_LENGTH) {
        napi_throw_range_error(env, nullptr, "secretKey must contain exactly 32 bytes");
        return false;
    }
    std::memcpy(output->data(), data, output->size());
    return true;
}

bool ReadStringArray(
    napi_env env,
    napi_value object,
    const char *name,
    std::vector<std::string> *output
) {
    napi_value value = nullptr;
    bool present = false;
    if (!GetOptionalProperty(env, object, name, &value, &present)) {
        return false;
    }
    if (!present) {
        return true;
    }
    bool isArray = false;
    if (!NapiOk(env, napi_is_array(env, value, &isArray), "Failed to inspect direct addresses")) {
        return false;
    }
    if (!isArray) {
        napi_throw_type_error(env, nullptr, "serverDirectAddresses must be an array of strings");
        return false;
    }
    uint32_t length = 0;
    if (!NapiOk(env, napi_get_array_length(env, value, &length), "Failed to size direct addresses")) {
        return false;
    }
    output->reserve(length);
    for (uint32_t index = 0; index < length; ++index) {
        napi_value element = nullptr;
        if (!NapiOk(env, napi_get_element(env, value, index, &element), "Failed to read direct address")) {
            return false;
        }
        std::string address;
        if (!ReadString(env, element, "serverDirectAddresses entry", &address)) {
            return false;
        }
        output->push_back(std::move(address));
    }
    return true;
}

bool ParseStartConfig(napi_env env, napi_value value, StartWork *work) {
    napi_valuetype type = napi_undefined;
    if (!NapiOk(env, napi_typeof(env, value, &type), "Failed to inspect tunnel config")) {
        return false;
    }
    if (type != napi_object) {
        napi_throw_type_error(env, nullptr, "startTunnel requires a TunnelConfig object");
        return false;
    }

    napi_value property = nullptr;
    if (!GetRequiredProperty(env, value, "serverEndpointId", &property) ||
        !ReadString(env, property, "serverEndpointId", &work->serverEndpointId)) {
        return false;
    }
    if (work->serverEndpointId.empty()) {
        napi_throw_range_error(env, nullptr, "serverEndpointId must not be empty");
        return false;
    }
    if (!GetRequiredProperty(env, value, "secretKey", &property) ||
        !ReadSecretKey(env, property, &work->secretKey)) {
        return false;
    }
    return ReadOptionalString(env, value, "serverRelayUrl", &work->serverRelayUrl) &&
        ReadStringArray(env, value, "serverDirectAddresses", &work->directAddresses) &&
        ReadOptionalString(env, value, "alpn", &work->alpn) &&
        ReadOptionalBool(env, value, "useDefaultRelays", &work->useDefaultRelays) &&
        ReadOptionalUint64(env, value, "connectTimeoutMs", &work->connectTimeoutMs) &&
        ReadOptionalUint64(env, value, "reconnectMinDelayMs", &work->reconnectMinDelayMs) &&
        ReadOptionalUint64(env, value, "reconnectMaxDelayMs", &work->reconnectMaxDelayMs);
}

const char *StateName(uint32_t state) {
    switch (state) {
        case IROH_HOS_STATE_STARTING:
            return "starting";
        case IROH_HOS_STATE_CONNECTING:
            return "connecting";
        case IROH_HOS_STATE_CONNECTED:
            return "connected";
        case IROH_HOS_STATE_RECONNECTING:
            return "reconnecting";
        case IROH_HOS_STATE_SUSPENDED:
            return "suspended";
        case IROH_HOS_STATE_STOPPED:
        default:
            return "stopped";
    }
}

napi_value TunnelInfoValue(napi_env env, const IrohHosTunnelInfo &info) {
    napi_value result = nullptr;
    napi_value state = nullptr;
    napi_value port = nullptr;
    napi_value endpointId = nullptr;
    napi_create_object(env, &result);
    napi_create_string_utf8(env, StateName(info.state), NAPI_AUTO_LENGTH, &state);
    napi_create_uint32(env, info.local_port, &port);
    napi_create_string_utf8(env, info.local_endpoint_id, NAPI_AUTO_LENGTH, &endpointId);
    napi_set_named_property(env, result, "state", state);
    napi_set_named_property(env, result, "localPort", port);
    napi_set_named_property(env, result, "localEndpointId", endpointId);
    return result;
}

napi_value ErrorValue(napi_env env, const char *message) {
    napi_value text = nullptr;
    napi_value error = nullptr;
    napi_create_string_utf8(env, message, NAPI_AUTO_LENGTH, &text);
    napi_create_error(env, nullptr, text, &error);
    return error;
}

void ExecuteStart(napi_env, void *data) {
    auto *work = static_cast<StartWork *>(data);
    std::vector<const char *> directAddressPointers;
    directAddressPointers.reserve(work->directAddresses.size());
    for (const std::string &address : work->directAddresses) {
        directAddressPointers.push_back(address.c_str());
    }

    IrohHosStartConfig config{};
    config.abi_version = IROH_HOS_ABI_VERSION;
    config.server_endpoint_id = work->serverEndpointId.c_str();
    config.server_relay_url = work->serverRelayUrl.empty() ? nullptr : work->serverRelayUrl.c_str();
    config.server_direct_addresses = directAddressPointers.empty() ? nullptr : directAddressPointers.data();
    config.server_direct_address_count = directAddressPointers.size();
    config.secret_key = work->secretKey.data();
    config.secret_key_len = work->secretKey.size();
    config.alpn = reinterpret_cast<const uint8_t *>(work->alpn.data());
    config.alpn_len = work->alpn.size();
    config.use_default_relays = work->useDefaultRelays ? 1 : 0;
    config.connect_timeout_ms = work->connectTimeoutMs;
    config.reconnect_min_delay_ms = work->reconnectMinDelayMs;
    config.reconnect_max_delay_ms = work->reconnectMaxDelayMs;

    std::lock_guard<std::mutex> lock(gTunnelMutex);
    if (gTunnel != nullptr) {
        work->result = iroh_hos_tunnel_get_info(gTunnel, &work->info);
        return;
    }
    IrohHosTunnel *tunnel = nullptr;
    work->result = iroh_hos_tunnel_start(
        &config,
        &tunnel,
        &work->info,
        work->error.data(),
        work->error.size());
    if (work->result == IROH_HOS_OK) {
        gTunnel = tunnel;
    }
}

void CompleteStart(napi_env env, napi_status status, void *data) {
    auto *work = static_cast<StartWork *>(data);
    if (status == napi_ok && work->result == IROH_HOS_OK) {
        napi_resolve_deferred(env, work->deferred, TunnelInfoValue(env, work->info));
    } else {
        const char *message = work->error[0] == '\0' ? "Failed to start Iroh tunnel" : work->error.data();
        napi_reject_deferred(env, work->deferred, ErrorValue(env, message));
    }
    napi_delete_async_work(env, work->work);
    delete work;
}

napi_value StartTunnel(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    if (!NapiOk(env, napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr), "Failed to read startTunnel arguments")) {
        return nullptr;
    }
    if (argc != 1) {
        napi_throw_type_error(env, nullptr, "startTunnel requires exactly one TunnelConfig argument");
        return nullptr;
    }

    auto *work = new StartWork();
    work->env = env;
    if (!ParseStartConfig(env, argv[0], work)) {
        delete work;
        return nullptr;
    }

    napi_value promise = nullptr;
    napi_value resourceName = nullptr;
    napi_create_string_utf8(env, "IrohHosStartTunnel", NAPI_AUTO_LENGTH, &resourceName);
    if (!NapiOk(env, napi_create_promise(env, &work->deferred, &promise), "Failed to create startTunnel promise") ||
        !NapiOk(
            env,
            napi_create_async_work(
                env,
                nullptr,
                resourceName,
                ExecuteStart,
                CompleteStart,
                work,
                &work->work),
            "Failed to create startTunnel work") ||
        !NapiOk(env, napi_queue_async_work(env, work->work), "Failed to queue startTunnel work")) {
        if (work->work != nullptr) {
            napi_delete_async_work(env, work->work);
        }
        delete work;
        return nullptr;
    }
    return promise;
}

void ExecuteStop(napi_env, void *data) {
    auto *work = static_cast<StopWork *>(data);
    std::lock_guard<std::mutex> lock(gTunnelMutex);
    if (gTunnel == nullptr) {
        return;
    }
    work->result = iroh_hos_tunnel_stop(gTunnel);
    iroh_hos_tunnel_free(gTunnel);
    gTunnel = nullptr;
}

void CompleteStop(napi_env env, napi_status status, void *data) {
    auto *work = static_cast<StopWork *>(data);
    if (status == napi_ok && work->result == IROH_HOS_OK) {
        napi_resolve_deferred(env, work->deferred, Undefined(env));
    } else {
        napi_reject_deferred(env, work->deferred, ErrorValue(env, "Failed to stop Iroh tunnel"));
    }
    napi_delete_async_work(env, work->work);
    delete work;
}

napi_value StopTunnel(napi_env env, napi_callback_info) {
    auto *work = new StopWork();
    work->env = env;
    napi_value promise = nullptr;
    napi_value resourceName = nullptr;
    napi_create_string_utf8(env, "IrohHosStopTunnel", NAPI_AUTO_LENGTH, &resourceName);
    if (!NapiOk(env, napi_create_promise(env, &work->deferred, &promise), "Failed to create stopTunnel promise") ||
        !NapiOk(
            env,
            napi_create_async_work(
                env,
                nullptr,
                resourceName,
                ExecuteStop,
                CompleteStop,
                work,
                &work->work),
            "Failed to create stopTunnel work") ||
        !NapiOk(env, napi_queue_async_work(env, work->work), "Failed to queue stopTunnel work")) {
        if (work->work != nullptr) {
            napi_delete_async_work(env, work->work);
        }
        delete work;
        return nullptr;
    }
    return promise;
}

using TunnelCommand = int32_t (*)(const IrohHosTunnel *);

napi_value RunTunnelCommand(napi_env env, TunnelCommand command) {
    std::lock_guard<std::mutex> lock(gTunnelMutex);
    if (gTunnel == nullptr) {
        return Undefined(env);
    }
    int32_t result = command(gTunnel);
    if (result != IROH_HOS_OK) {
        napi_throw_error(env, nullptr, "Iroh tunnel command failed");
        return nullptr;
    }
    return Undefined(env);
}

napi_value SuspendTunnel(napi_env env, napi_callback_info) {
    return RunTunnelCommand(env, iroh_hos_tunnel_suspend);
}

napi_value ResumeTunnel(napi_env env, napi_callback_info) {
    return RunTunnelCommand(env, iroh_hos_tunnel_resume);
}

napi_value NetworkChange(napi_env env, napi_callback_info) {
    return RunTunnelCommand(env, iroh_hos_tunnel_network_change);
}

napi_value GetTunnelInfo(napi_env env, napi_callback_info) {
    IrohHosTunnelInfo info{};
    std::lock_guard<std::mutex> lock(gTunnelMutex);
    if (gTunnel != nullptr) {
        int32_t result = iroh_hos_tunnel_get_info(gTunnel, &info);
        if (result != IROH_HOS_OK) {
            napi_throw_error(env, nullptr, "Failed to read Iroh tunnel state");
            return nullptr;
        }
    }
    return TunnelInfoValue(env, info);
}

napi_value GetLastError(napi_env env, napi_callback_info) {
    std::array<char, ERROR_CAPACITY> error{};
    std::lock_guard<std::mutex> lock(gTunnelMutex);
    if (gTunnel != nullptr) {
        iroh_hos_tunnel_last_error(gTunnel, error.data(), error.size());
    }
    napi_value result = nullptr;
    napi_create_string_utf8(env, error.data(), NAPI_AUTO_LENGTH, &result);
    return result;
}

napi_value GenerateSecretKey(napi_env env, napi_callback_info) {
    napi_value arrayBuffer = nullptr;
    void *data = nullptr;
    if (!NapiOk(
            env,
            napi_create_arraybuffer(env, IROH_HOS_SECRET_KEY_LENGTH, &data, &arrayBuffer),
            "Failed to allocate secret key")) {
        return nullptr;
    }
    if (iroh_hos_generate_secret_key(
            static_cast<uint8_t *>(data),
            IROH_HOS_SECRET_KEY_LENGTH) != IROH_HOS_OK) {
        napi_throw_error(env, nullptr, "Failed to generate Iroh secret key");
        return nullptr;
    }
    return arrayBuffer;
}

napi_value EndpointIdFromSecretKey(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1] = {nullptr};
    if (!NapiOk(env, napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr), "Failed to read endpointId arguments")) {
        return nullptr;
    }
    if (argc != 1) {
        napi_throw_type_error(env, nullptr, "endpointId requires one 32-byte secret key");
        return nullptr;
    }
    std::array<uint8_t, IROH_HOS_SECRET_KEY_LENGTH> key{};
    if (!ReadSecretKey(env, argv[0], &key)) {
        return nullptr;
    }
    std::array<char, IROH_HOS_ENDPOINT_ID_CAPACITY> endpointId{};
    if (iroh_hos_endpoint_id_from_secret_key(
            key.data(),
            key.size(),
            endpointId.data(),
            endpointId.size()) != IROH_HOS_OK) {
        napi_throw_error(env, nullptr, "Failed to derive Iroh endpoint ID");
        return nullptr;
    }
    napi_value result = nullptr;
    napi_create_string_utf8(env, endpointId.data(), NAPI_AUTO_LENGTH, &result);
    return result;
}

napi_value Version(napi_env env, napi_callback_info) {
    napi_value result = nullptr;
    napi_create_string_utf8(env, iroh_hos_version(), NAPI_AUTO_LENGTH, &result);
    return result;
}

napi_value AbiVersion(napi_env env, napi_callback_info) {
    napi_value result = nullptr;
    napi_create_uint32(env, iroh_hos_abi_version(), &result);
    return result;
}

void Cleanup(void *data) {
    auto *registration = static_cast<CleanupRegistration *>(data);
    std::lock_guard<std::mutex> lock(gTunnelMutex);
    gCleanupRegistrations.erase(
        std::remove(gCleanupRegistrations.begin(), gCleanupRegistrations.end(), registration),
        gCleanupRegistrations.end());
    delete registration;
    if (!gCleanupRegistrations.empty()) {
        return;
    }
    if (gTunnel != nullptr) {
        iroh_hos_tunnel_free(gTunnel);
        gTunnel = nullptr;
    }
}

napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor properties[] = {
        {"startTunnel", nullptr, StartTunnel, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"stopTunnel", nullptr, StopTunnel, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"suspendTunnel", nullptr, SuspendTunnel, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"resumeTunnel", nullptr, ResumeTunnel, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"networkChange", nullptr, NetworkChange, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getTunnelInfo", nullptr, GetTunnelInfo, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getLastError", nullptr, GetLastError, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"generateSecretKey", nullptr, GenerateSecretKey, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"endpointId", nullptr, EndpointIdFromSecretKey, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"version", nullptr, Version, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"abiVersion", nullptr, AbiVersion, nullptr, nullptr, nullptr, napi_default, nullptr},
    };
    napi_define_properties(env, exports, sizeof(properties) / sizeof(properties[0]), properties);
    CleanupRegistration *registration = nullptr;
    {
        std::lock_guard<std::mutex> lock(gTunnelMutex);
        const auto existing = std::find_if(
            gCleanupRegistrations.begin(),
            gCleanupRegistrations.end(),
            [env](const CleanupRegistration *candidate) { return candidate->env == env; });
        if (existing == gCleanupRegistrations.end()) {
            registration = new CleanupRegistration{env};
            gCleanupRegistrations.push_back(registration);
        }
    }
    if (registration != nullptr &&
        !NapiOk(
            env,
            napi_add_env_cleanup_hook(env, Cleanup, registration),
            "Failed to register Iroh environment cleanup")) {
        std::lock_guard<std::mutex> lock(gTunnelMutex);
        gCleanupRegistrations.erase(
            std::remove(gCleanupRegistrations.begin(), gCleanupRegistrations.end(), registration),
            gCleanupRegistrations.end());
        delete registration;
    }
    return exports;
}

} // namespace

static napi_module gModule = {
    NAPI_MODULE_VERSION,
    0,
    nullptr,
    Init,
    "iroh_hos",
    nullptr,
    {nullptr, nullptr, nullptr, nullptr},
};

extern "C" __attribute__((constructor)) void RegisterIrohHosModule() {
    napi_module_register(&gModule);
}
