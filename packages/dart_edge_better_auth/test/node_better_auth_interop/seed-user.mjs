import { betterAuth } from 'better-auth';
import { Kysely, PostgresDialect } from 'kysely';
import pg from 'pg';

const { Pool } = pg;

const config = JSON.parse(process.argv[2] ?? '{}');
const pool = new Pool({ connectionString: config.connectionString, max: 1 });
const database = new Kysely({ dialect: new PostgresDialect({ pool }) });

try {
  const auth = betterAuth({
    secret: config.secret,
    baseURL: config.baseUrl,
    basePath: '/auth',
    database: { db: database, type: 'postgres' },
    emailAndPassword: { enabled: true },
    rateLimit: { enabled: false }
  });

  const context = await auth.$context;
  await context.runMigrations();

  const response = await auth.handler(
    new Request(`${config.baseUrl}/auth/sign-up/email`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', origin: config.baseUrl },
      body: JSON.stringify({
        email: config.email,
        password: config.password,
        name: config.name
      })
    })
  );
  const body = await response.text();
  if (!response.ok) {
    throw new Error(`sign-up returned ${response.status}: ${body}`);
  }
  const decoded = JSON.parse(body);
  console.log(JSON.stringify({
    userId: decoded.user?.id,
    email: decoded.user?.email,
    hasToken: typeof decoded.token === 'string'
  }));
} finally {
  await database.destroy();
}
