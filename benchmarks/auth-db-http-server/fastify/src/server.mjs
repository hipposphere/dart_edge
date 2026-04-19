import Fastify from 'fastify';
import multipart from '@fastify/multipart';

import {
  authenticate,
  createAuth,
  registerAuthRoutes,
  seedUsers,
} from './auth.mjs';
import { createDatabase } from './database.mjs';
import { createS3Client } from './s3.mjs';
import { registerRoutes } from './routes/index.mjs';

export async function createServer({ port }) {
  const baseUrl = `http://127.0.0.1:${port}`;
  const database = createDatabase();
  const auth = createAuth({ baseUrl, database });
  const s3 = createS3Client();

  await seedUsers({ auth, baseUrl });

  const fastify = Fastify({
    logger: false,
    disableRequestLogging: true,
  });
  await fastify.register(multipart);

  registerRoutes({
    fastify,
    auth,
    baseUrl,
    database,
    authenticate,
    s3,
  });
  await registerAuthRoutes({ fastify, auth, baseUrl });

  await fastify.listen({
    host: '127.0.0.1',
    port,
  });

  return fastify;
}
