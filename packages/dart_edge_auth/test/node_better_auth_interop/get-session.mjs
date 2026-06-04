import { betterAuth } from 'better-auth';
import { bearer } from 'better-auth/plugins/bearer';
import { Kysely, PostgresDialect } from 'kysely';
import pg from 'pg';

const { Pool } = pg;

const configJson = process.argv[2];
if (!configJson) {
  console.error('Missing get-session config JSON argument.');
  process.exit(64);
}

const config = JSON.parse(configJson);
const pool = new Pool({
  connectionString: config.connectionString,
  max: 1,
});
const database = new Kysely({
  dialect: new PostgresDialect({ pool }),
});

try {
  const auth = betterAuth({
    secret: config.secret,
    baseURL: config.baseUrl,
    basePath: '/auth',
    database: {
      db: database,
      type: 'postgres',
    },
    emailAndPassword: { enabled: true },
    rateLimit: { enabled: false },
    plugins: [bearer()],
  });

  const response = await auth.handler(
    new Request(`${config.baseUrl}/auth/get-session`, {
      method: 'GET',
      headers: {
        cookie: config.sessionCookie,
        origin: config.baseUrl,
      },
    }),
  );
  const body = await response.text();
  if (response.status < 200 || response.status >= 300) {
    throw new Error(`get-session returned ${response.status}: ${body}`);
  }

  const decoded = JSON.parse(body);
  console.log(
    JSON.stringify({
      status: response.status,
      userId: decoded.user?.id,
      email: decoded.user?.email,
      sessionToken: decoded.session?.token,
    }),
  );
} finally {
  await database.destroy();
}
