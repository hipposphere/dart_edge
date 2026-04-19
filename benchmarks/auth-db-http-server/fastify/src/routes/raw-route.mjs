export function registerRawRoute({
  fastify,
  auth,
  baseUrl,
  authenticate,
}) {
  fastify.get('/bench/raw', async (request, reply) => {
    const email = await authenticate({
      auth,
      baseUrl,
      nodeHeaders: request.headers,
    });
    if (email === null) {
      reply.code(401).type('application/json; charset=utf-8');
      return JSON.stringify({ error: 'unauthorized' });
    }

    reply.type('application/json; charset=utf-8');
    return JSON.stringify({ email, value: 'raw benchmark value' });
  });
}
