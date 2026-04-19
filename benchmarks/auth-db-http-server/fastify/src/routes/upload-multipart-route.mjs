import { PutObjectCommand } from '@aws-sdk/client-s3';

import {
  multipartFileContentType,
  multipartFileFieldName,
  multipartFileName,
  multipartTitleFieldName,
  multipartTitleValue,
  s3Bucket,
  uploadMultipartObjectKey,
  uploadMultipartPath,
  uploadMultipartResponse,
} from '../config.mjs';

export function registerUploadMultipartRoute({
  fastify,
  auth,
  baseUrl,
  authenticate,
  s3,
}) {
  fastify.post(uploadMultipartPath, async (request, reply) => {
    const email = await authenticate({
      auth,
      baseUrl,
      nodeHeaders: request.headers,
    });
    if (email === null) {
      reply.code(401).type('application/json; charset=utf-8');
      return JSON.stringify({ error: 'unauthorized' });
    }

    let title = null;
    let uploaded = false;

    for await (const part of request.parts()) {
      if (part.type === 'file') {
        if (
          uploaded ||
          part.fieldname !== multipartFileFieldName ||
          title !== multipartTitleValue ||
          part.filename !== multipartFileName
        ) {
          reply.code(400).type('application/json; charset=utf-8');
          return JSON.stringify({ error: 'invalid_upload' });
        }

        const bytes = await part.toBuffer();
        await s3.send(
          new PutObjectCommand({
            Bucket: s3Bucket,
            Key: uploadMultipartObjectKey(email),
            Body: bytes,
            ContentLength: bytes.length,
            ContentType: part.mimetype ?? multipartFileContentType,
          }),
        );
        uploaded = true;
        continue;
      }

      if (part.type === 'field' && part.fieldname === multipartTitleFieldName) {
        title = typeof part.value === 'string' ? part.value : null;
      }
    }

    if (title !== multipartTitleValue || !uploaded) {
      reply.code(400).type('application/json; charset=utf-8');
      return JSON.stringify({ error: 'invalid_upload' });
    }

    reply.type('application/json; charset=utf-8');
    return uploadMultipartResponse(email);
  });
}
