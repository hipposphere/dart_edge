import { S3Client } from '@aws-sdk/client-s3';

import {
  s3AccessKeyId,
  s3Endpoint,
  s3Region,
  s3SecretAccessKey,
} from './config.mjs';

export function createS3Client() {
  return new S3Client({
    region: s3Region,
    endpoint: s3Endpoint,
    forcePathStyle: true,
    credentials: {
      accessKeyId: s3AccessKeyId,
      secretAccessKey: s3SecretAccessKey,
    },
  });
}
