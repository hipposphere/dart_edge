#ifndef DART_EDGE_SIP_H_
#define DART_EDGE_SIP_H_

#include <stdbool.h>
#include <stdint.h>

int32_t dart_edge_sip_native_abi_version(void);

int64_t dart_edge_sip_create(const char* config_json);

bool dart_edge_sip_start(int64_t handle);

bool dart_edge_sip_stop(int64_t handle);

void dart_edge_sip_dispose(int64_t handle);

char* dart_edge_sip_issue_command(int64_t handle, const char* command_json);

char* dart_edge_sip_poll_event(int64_t handle);

char* dart_edge_sip_take_last_error(void);

void dart_edge_sip_free_string(char* value);

#endif  // DART_EDGE_SIP_H_
