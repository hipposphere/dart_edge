import { databaseValue } from '../config.mjs';

export function registerDatabaseRoute({
  fastify,
  auth,
  baseUrl,
  database,
  authenticate,
}) {
  fastify.get('/bench/db', async (request, reply) => {
    const email = await authenticate({
      auth,
      baseUrl,
      nodeHeaders: request.headers,
    });
    if (email === null) {
      reply.code(401).type('application/json; charset=utf-8');
      return JSON.stringify({ error: 'unauthorized' });
    }

    const row = database
      .prepare('SELECT value FROM benchmark_values WHERE email = ?')
      .get(email);
    if (row?.value !== databaseValue) {
      reply.code(500).type('application/json; charset=utf-8');
      return JSON.stringify({ error: 'benchmark_row_missing' });
    }

    reply.type('application/json; charset=utf-8');
    return JSON.stringify({ email, value: row.value });
  });
}
