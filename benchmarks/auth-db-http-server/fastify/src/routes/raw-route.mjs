import { rawPath, rawResponseJson } from '../config.mjs';

export function registerRawRoute({
  fastify,
  auth,
  baseUrl,
  authenticate,
}) {
  fastify.get(rawPath, async (request, reply) => {
    const email = await authenticate({
      auth,
      baseUrl,
      nodeHeaders: request.headers,
    });
    if (email === null) {
      reply.code(401).header('content-type', 'application/json; charset=utf-8');
      return '{"error":"unauthorized"}';
    }

    reply.header('content-type', 'application/json; charset=utf-8');
    return rawResponseJson(email);
  });
}
