export function registerHealthRoute({ fastify }) {
  fastify.get('/healthz', async (_, reply) => {
    reply.type('text/plain; charset=utf-8');
    return 'ok';
  });
}
