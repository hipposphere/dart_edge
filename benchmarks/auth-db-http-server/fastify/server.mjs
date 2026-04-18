import { mkdirSync, rmSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { fileURLToPath } from 'node:url';

import { betterAuth } from 'better-auth';
import { fromNodeHeaders } from 'better-auth/node';
import { bearer } from 'better-auth/plugins/bearer';
import Fastify from 'fastify';

const benchmarkAuthSecret =
  'benchmark-secret-key-that-is-at-least-32-chars';
const benchmarkUserName = 'Benchmark User';
const benchmarkUserEmail = 'benchmark.user@example.com';
const benchmarkUserPassword = 'password123456';
const benchmarkFlowUserCount = 32;
const benchmarkAuthPath = '/auth';
const benchmarkHealthBody = 'ok';
const benchmarkRawValue = 'raw benchmark value';
const benchmarkDatabaseValue = 'database benchmark value';

const port = parsePort(process.argv.slice(2));
const baseUrl = `http://127.0.0.1:${port}`;
const databasePath = fileURLToPath(new URL('./var/benchmark.sqlite', import.meta.url));

mkdirSync(fileURLToPath(new URL('./var/', import.meta.url)), { recursive: true });
rmSync(databasePath, { force: true });

const database = new DatabaseSync(databasePath);
database.exec(`
  CREATE TABLE benchmark_values (
    email TEXT PRIMARY KEY,
    value TEXT NOT NULL
  );
`);
database
  .prepare('INSERT INTO benchmark_values (email, value) VALUES (?, ?)')
  .run(benchmarkUserEmail, benchmarkDatabaseValue);
for (let index = 0; index < benchmarkFlowUserCount; index += 1) {
  database
    .prepare('INSERT INTO benchmark_values (email, value) VALUES (?, ?)')
    .run(benchmarkFlowUserEmail(index), benchmarkDatabaseValue);
}

const auth = betterAuth({
  secret: benchmarkAuthSecret,
  baseURL: baseUrl,
  basePath: benchmarkAuthPath,
  database,
  emailAndPassword: { enabled: true },
  rateLimit: { enabled: false },
  plugins: [bearer()],
});

const authContext = await auth.$context;
await authContext.runMigrations();
await callAuthJson('/auth/sign-up/email', {
  method: 'POST',
  body: {
    email: benchmarkUserEmail,
    password: benchmarkUserPassword,
    name: benchmarkUserName,
  },
  headers: { origin: baseUrl },
});
for (let index = 0; index < benchmarkFlowUserCount; index += 1) {
  await callAuthJson('/auth/sign-up/email', {
    method: 'POST',
    body: {
      email: benchmarkFlowUserEmail(index),
      password: benchmarkUserPassword,
      name: benchmarkFlowUserName(index),
    },
    headers: { origin: baseUrl },
  });
}

const fastify = Fastify({
  logger: false,
  disableRequestLogging: true,
});

fastify.get('/healthz', async (_, reply) => {
  reply.header('content-type', 'text/plain; charset=utf-8');
  return benchmarkHealthBody;
});

fastify.get('/bench/raw', async (request, reply) => {
  const email = await authenticate(request.headers);
  if (email === null) {
    reply.code(401).header('content-type', 'application/json; charset=utf-8');
    return '{"error":"unauthorized"}';
  }

  reply.header('content-type', 'application/json; charset=utf-8');
  return benchmarkRawResponseJson(email);
});

fastify.get('/bench/db', async (request, reply) => {
  const email = await authenticate(request.headers);
  if (email === null) {
    reply.code(401).header('content-type', 'application/json; charset=utf-8');
    return '{"error":"unauthorized"}';
  }

  const row = database
    .prepare('SELECT value FROM benchmark_values WHERE email = ?')
    .get(email);
  if (row?.value !== benchmarkDatabaseValue) {
    reply.code(500).header('content-type', 'application/json; charset=utf-8');
    return '{"error":"benchmark_row_missing"}';
  }

  reply.header('content-type', 'application/json; charset=utf-8');
  return benchmarkDatabaseResponseJson(email);
});

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

await fastify.listen({
  host: '127.0.0.1',
  port,
});

async function authenticate(nodeHeaders) {
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

async function callAuthJson(path, { method, body, headers = {} }) {
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

function benchmarkRawResponseJson(email) {
  return `{"email":"${email}","value":"${benchmarkRawValue}"}`;
}

function benchmarkDatabaseResponseJson(email) {
  return `{"email":"${email}","value":"${benchmarkDatabaseValue}"}`;
}

function parsePort(args) {
  const portArgument = args.find((argument) => argument.startsWith('--port='));
  if (portArgument === undefined) {
    return 8080;
  }

  return Number.parseInt(portArgument.slice('--port='.length), 10);
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

function benchmarkFlowUserName(index) {
  return `Benchmark Flow User ${index}`;
}

function benchmarkFlowUserEmail(index) {
  return `benchmark.flow.${index}@example.com`;
}
