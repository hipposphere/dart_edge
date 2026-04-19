export const authSecret = 'benchmark-secret-key-that-is-at-least-32-chars';
export const userName = 'Benchmark User';
export const userEmail = 'benchmark.user@example.com';
export const userPassword = 'password123456';
export const flowUserCount = 256;
export const databaseValue = 'database benchmark value';

export function parsePort(args) {
  const portArgument = args.find((argument) => argument.startsWith('--port='));
  if (portArgument === undefined) {
    return 8080;
  }

  return Number.parseInt(portArgument.slice('--port='.length), 10);
}
export function flowUserName(index) {
  return `Benchmark Flow User ${index}`;
}

export function flowUserEmail(index) {
  return `benchmark.flow.${index}@example.com`;
}
