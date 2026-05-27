import { betterAuth } from 'better-auth';
import { bearer } from 'better-auth/plugins/bearer';
import { Kysely, PostgresDialect } from 'kysely';
import pg from 'pg';

const { Pool } = pg;

const configJson = process.argv[2];
if (!configJson) {
  console.error('Missing seed config JSON argument.');
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

  const context = await auth.$context;
  await context.runMigrations();

  const response = await auth.handler(
    new Request(`${config.baseUrl}/auth/sign-up/email`, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        origin: config.baseUrl,
      },
      body: JSON.stringify({
        email: config.email,
        password: config.password,
        name: config.name,
      }),
    }),
  );
  const body = await response.text();
  if (response.status < 200 || response.status >= 300) {
    throw new Error(`sign-up returned ${response.status}: ${body}`);
  }

  const decoded = JSON.parse(body);
  console.log(
    JSON.stringify({
      status: response.status,
      userId: decoded.user?.id,
      email: decoded.user?.email,
      hasToken: typeof decoded.token === 'string' && decoded.token.length > 0,
    }),
  );
} finally {
  await database.destroy();
}
