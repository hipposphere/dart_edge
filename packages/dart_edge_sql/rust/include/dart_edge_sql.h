#ifndef DART_EDGE_SQL_H_
#define DART_EDGE_SQL_H_

#include <stdbool.h>
#include <stdint.h>

int32_t dart_edge_sql_native_abi_version(void);

int64_t dart_edge_sql_open_postgres_pool(const char *connection_string);
int64_t dart_edge_sql_open_postgres_pool_with_max_sessions(
    const char *connection_string,
    int32_t max_sessions);
int64_t dart_edge_sql_open_sqlite_pool(const char *path, int32_t max_sessions);
int64_t dart_edge_sql_open_sqlite_in_memory_pool(int32_t max_sessions);
void dart_edge_sql_close_pool(int64_t handle);
void dart_edge_sql_close_all_pools(void);

char *dart_edge_sql_execute_pool(int64_t handle, const char *statement_json);

int64_t dart_edge_sql_begin_transaction(int64_t pool_handle);
char *dart_edge_sql_execute_transaction(int64_t handle, const char *statement_json);
bool dart_edge_sql_commit_transaction(int64_t handle);
void dart_edge_sql_rollback_transaction(int64_t handle);

char *dart_edge_sql_take_last_error(void);
void dart_edge_sql_free_string(char *value);

#endif
