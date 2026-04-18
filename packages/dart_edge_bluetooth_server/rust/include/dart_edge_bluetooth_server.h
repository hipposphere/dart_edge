#ifndef DART_EDGE_BLUETOOTH_SERVER_H_
#define DART_EDGE_BLUETOOTH_SERVER_H_

#include <stdbool.h>
#include <stdint.h>

int32_t dart_edge_bluetooth_server_native_abi_version(void);

bool dart_edge_bluetooth_server_is_supported_platform(void);

int64_t dart_edge_bluetooth_server_create(const char* config_json);

bool dart_edge_bluetooth_server_start(int64_t handle);

bool dart_edge_bluetooth_server_stop(int64_t handle);

void dart_edge_bluetooth_server_dispose(int64_t handle);

char* dart_edge_bluetooth_server_issue_command(
    int64_t handle,
    const char* command_json);

char* dart_edge_bluetooth_server_poll_event(int64_t handle);

char* dart_edge_bluetooth_server_take_last_error(void);

void dart_edge_bluetooth_server_free_string(char* value);

#endif  // DART_EDGE_BLUETOOTH_SERVER_H_
