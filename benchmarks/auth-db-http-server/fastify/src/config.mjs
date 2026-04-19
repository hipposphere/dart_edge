export const authSecret = 'benchmark-secret-key-that-is-at-least-32-chars';
export const userCount = 256;
export const userPassword = 'password123456';
export const databaseValue = 'database benchmark value';
export const uploadMultipartPath = '/upload_multipart';
export const s3Region = process.env.BENCHMARK_S3_REGION ?? 'us-east-1';
export const s3Bucket = process.env.BENCHMARK_S3_BUCKET ?? 'benchmark-uploads';
export const s3Endpoint =
  process.env.BENCHMARK_S3_ENDPOINT ?? 'http://127.0.0.1:9321';
export const s3AccessKeyId =
  process.env.BENCHMARK_S3_ACCESS_KEY_ID ?? 'benchmark-access-key';
export const s3SecretAccessKey =
  process.env.BENCHMARK_S3_SECRET_ACCESS_KEY ?? 'benchmark-secret-access-key';
export const multipartTitleFieldName = 'title';
export const multipartTitleValue = 'benchmark upload';
export const multipartFileFieldName = 'upload';
export const multipartFileName = 'payload.bin';
export const multipartFileContentType = 'application/octet-stream';
export const multipartFileSize = Buffer.byteLength(
  'dart-edge-auth-db-benchmark-upload-0123456789\n'.repeat(1024),
);

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

export function uploadMultipartObjectKey(email) {
  return `${email}/${multipartFileName}`;
}

export function uploadMultipartResponse(email) {
  return JSON.stringify({
    email,
    bucket: s3Bucket,
    key: uploadMultipartObjectKey(email),
    title: multipartTitleValue,
    fileName: multipartFileName,
    contentType: multipartFileContentType,
    size: multipartFileSize,
  });
}
