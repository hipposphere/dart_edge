import { registerDatabaseRoute } from './database-route.mjs';
import { registerHealthRoute } from './health.mjs';
import { registerRawRoute } from './raw-route.mjs';
import { registerUploadMultipartRoute } from './upload-multipart-route.mjs';

export function registerRoutes(options) {
  registerHealthRoute(options);
  registerRawRoute(options);
  registerDatabaseRoute(options);
  registerUploadMultipartRoute(options);
}
