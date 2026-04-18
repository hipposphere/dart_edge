import {
  databasePath,
  databaseResponseJson,
  databaseValue,
} from '../config.mjs';

export function registerDatabaseRoute({
  fastify,
  auth,
  baseUrl,
  database,
  authenticate,
}) {
  fastify.get(databasePath, async (request, reply) => {
    const email = await authenticate({
      auth,
      baseUrl,
      nodeHeaders: request.headers,
    });
    if (email === null) {
      reply.code(401).header('content-type', 'application/json; charset=utf-8');
      return '{"error":"unauthorized"}';
    }

    const row = database
      .prepare('SELECT value FROM benchmark_values WHERE email = ?')
      .get(email);
    if (row?.value !== databaseValue) {
      reply.code(500).header('content-type', 'application/json; charset=utf-8');
      return '{"error":"benchmark_row_missing"}';
    }

    reply.header('content-type', 'application/json; charset=utf-8');
    return databaseResponseJson(email);
  });
}
