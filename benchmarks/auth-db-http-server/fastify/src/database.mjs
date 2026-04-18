import { mkdirSync, rmSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { fileURLToPath } from 'node:url';

import {
  databaseValue,
  flowUserCount,
  flowUserEmail,
  userEmail,
} from './config.mjs';

export function createDatabase() {
  const databasePath = fileURLToPath(
    new URL('../var/benchmark.sqlite', import.meta.url),
  );
  mkdirSync(fileURLToPath(new URL('../var/', import.meta.url)), {
    recursive: true,
  });
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
    .run(userEmail, databaseValue);

  for (let index = 0; index < flowUserCount; index += 1) {
    database
      .prepare('INSERT INTO benchmark_values (email, value) VALUES (?, ?)')
      .run(flowUserEmail(index), databaseValue);
  }

  return database;
}
