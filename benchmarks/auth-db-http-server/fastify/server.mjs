import { parsePort } from './src/config.mjs';
import { createServer } from './src/server.mjs';

const port = parsePort(process.argv.slice(2));
await createServer({ port });
