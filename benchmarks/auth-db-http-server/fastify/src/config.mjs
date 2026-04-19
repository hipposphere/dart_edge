export const authSecret = 'benchmark-secret-key-that-is-at-least-32-chars';
export const userCount = 256;
export const userPassword = 'password123456';
export const databaseValue = 'database benchmark value';

export function parsePort(args) {
  const portArgument = args.find((argument) => argument.startsWith('--port='));
  if (portArgument === undefined) {
    return 8080;
  }

  return Number.parseInt(portArgument.slice('--port='.length), 10);
}

export function userName(index) {
  return `Benchmark User ${index}`;
}

export function userEmail(index) {
  return `benchmark.user-${index}@example.com`;
}
