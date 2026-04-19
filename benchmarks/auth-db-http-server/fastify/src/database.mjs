import { mkdirSync, rmSync } from 'node:fs';
import { DatabaseSync } from 'node:sqlite';
import { fileURLToPath } from 'node:url';

import {
  databaseValue,
  userCount,
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
  for (let index = 0; index < userCount; index += 1) {
    database
      .prepare('INSERT INTO benchmark_values (email, value) VALUES (?, ?)')
      .run(userEmail(index), databaseValue);
  }

  return database;
}
