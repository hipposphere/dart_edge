import { healthBody, healthPath } from '../config.mjs';

export function registerHealthRoute({ fastify }) {
  fastify.get(healthPath, async (_, reply) => {
    reply.header('content-type', 'text/plain; charset=utf-8');
    return healthBody;
  });
}
