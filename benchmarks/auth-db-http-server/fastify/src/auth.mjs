import { betterAuth } from 'better-auth';
import { fromNodeHeaders } from 'better-auth/node';
import { bearer } from 'better-auth/plugins/bearer';

import {
  authSecret,
  flowUserCount,
  flowUserEmail,
  flowUserName,
  userEmail,
  userName,
  userPassword,
} from './config.mjs';

export function createAuth({ baseUrl, database }) {
  return betterAuth({
    secret: authSecret,
    baseURL: baseUrl,
    basePath: '/auth',
    database,
    emailAndPassword: { enabled: true },
    rateLimit: { enabled: false },
    plugins: [bearer()],
  });
}

export async function seedUsers({ auth, baseUrl }) {
  const authContext = await auth.$context;
  await authContext.runMigrations();

  await callAuthJson(auth, baseUrl, '/auth/sign-up/email', {
    method: 'POST',
    body: {
      email: userEmail,
      password: userPassword,
      name: userName,
    },
    headers: { origin: baseUrl },
  });

  for (let index = 0; index < flowUserCount; index += 1) {
    await callAuthJson(auth, baseUrl, '/auth/sign-up/email', {
      method: 'POST',
      body: {
        email: flowUserEmail(index),
        password: userPassword,
        name: flowUserName(index),
      },
      headers: { origin: baseUrl },
    });
  }
}

export async function authenticate({ auth, baseUrl, nodeHeaders }) {
  const response = await auth.handler(
    new Request(`${baseUrl}/auth/get-session`, {
      method: 'GET',
      headers: fromNodeHeaders(nodeHeaders),
    }),
  );

  if (response.status !== 200) {
    return null;
  }

  const body = await response.text();
  if (!body) {
    return null;
  }

  const decoded = JSON.parse(body);
  return typeof decoded?.user?.email === 'string' ? decoded.user.email : null;
}

export async function registerAuthRoutes({ fastify, auth, baseUrl }) {
  fastify.route({
    method: ['DELETE', 'GET', 'HEAD', 'OPTIONS', 'PATCH', 'POST', 'PUT'],
    url: '/auth/*',
    async handler(request, reply) {
      const authResponse = await auth.handler(
        new Request(`${baseUrl}${request.raw.url}`, {
          method: request.method,
          headers: fromNodeHeaders(request.headers),
          body: toRequestBody(request),
        }),
      );

      reply.code(authResponse.status);
      for (const [name, value] of authResponse.headers.entries()) {
        reply.header(name, value);
      }
      reply.send(await authResponse.text());
    },
  });
}

async function callAuthJson(auth, baseUrl, path, { method, body, headers = {} }) {
  const requestHeaders = new Headers(headers);
  if (body !== undefined) {
    requestHeaders.set('content-type', 'application/json');
  }

  const response = await auth.handler(
    new Request(`${baseUrl}${path}`, {
      method,
      headers: requestHeaders,
      body: body === undefined ? undefined : JSON.stringify(body),
    }),
  );

  if (response.status < 200 || response.status >= 300) {
    throw new Error(`${path} returned ${response.status}`);
  }

  const text = await response.text();
  return text ? JSON.parse(text) : null;
}

function toRequestBody(request) {
  if (request.method === 'GET' || request.method === 'HEAD') {
    return undefined;
  }

  if (request.body === undefined || request.body === null) {
    return undefined;
  }

  return typeof request.body === 'string'
    ? request.body
    : JSON.stringify(request.body);
}
