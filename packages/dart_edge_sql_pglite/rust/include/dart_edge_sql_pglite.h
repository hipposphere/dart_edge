#ifndef DART_EDGE_SQL_PGLITE_H_
#define DART_EDGE_SQL_PGLITE_H_

#include <stdbool.h>
#include <stdint.h>

int32_t dart_edge_sql_pglite_native_abi_version(void);

int64_t dart_edge_sql_pglite_open_temporary(void);
int64_t dart_edge_sql_pglite_open_temporary_with_extensions(const char *extensions);
int64_t dart_edge_sql_pglite_open_persistent(const char *path);
int64_t dart_edge_sql_pglite_open_persistent_with_extensions(
    const char *path,
    const char *extensions);
char *dart_edge_sql_pglite_connection_string(int64_t handle);
bool dart_edge_sql_pglite_close(int64_t handle);

char *dart_edge_sql_pglite_take_last_error(void);
void dart_edge_sql_pglite_free_string(char *value);

#endif
