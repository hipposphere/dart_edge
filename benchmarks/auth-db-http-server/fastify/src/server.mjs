import Fastify from 'fastify';

import {
  authenticate,
  createAuth,
  registerAuthRoutes,
  seedUsers,
} from './auth.mjs';
import { createDatabase } from './database.mjs';
import { registerRoutes } from './routes/index.mjs';

export async function createServer({ port }) {
  const baseUrl = `http://127.0.0.1:${port}`;
  const database = createDatabase();
  const auth = createAuth({ baseUrl, database });

  await seedUsers({ auth, baseUrl });

  const fastify = Fastify({
    logger: false,
    disableRequestLogging: true,
  });

  registerRoutes({
    fastify,
    auth,
    baseUrl,
    database,
    authenticate,
  });
  await registerAuthRoutes({ fastify, auth, baseUrl });

  await fastify.listen({
    host: '127.0.0.1',
    port,
  });

  return fastify;
}
