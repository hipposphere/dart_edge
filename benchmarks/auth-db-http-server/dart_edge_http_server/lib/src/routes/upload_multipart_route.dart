import 'dart:io';

import 'package:dart_edge_auth/dart_edge_auth.dart';
import 'package:dart_edge_auth_db_benchmark_shared/dart_edge_auth_db_benchmark_shared.dart';
import 'package:dart_edge_http_server/dart_edge_http_server.dart';

import '../services.dart';

final class UploadMultipartRoute
    extends HttpRouteDefinition<Services, Object?> {
  @override
  RouteOptions get options => RouteOptions(
    operationId: 'benchmarkUploadMultipart',
    body: RequestBody.multipartFormData(),
    success: ResponseSpec.json(),
    errors: [
      ErrorResponse(status: HttpStatus.badRequest, code: 'invalid_upload'),
      ErrorResponse.unauthorized(code: 'unauthorized'),
    ],
  );

  @override
  Future<Object?> handle(RequestContext<Services> ctx) async {
    final email = ctx.requireAuthIdentity.email;
    if (email == null) {
      return ctx.res.code(HttpStatus.unauthorized).json({
        'error': 'unauthorized',
      });
    }

    final form = await ctx.req.multipart();
    final files = form.filesNamed(benchmarkMultipartFileFieldName).toList();
    final file = files.isEmpty ? null : files.first;
    final title = form.fieldValue(benchmarkMultipartTitleFieldName);

    if (file == null ||
        title != benchmarkMultipartTitleValue ||
        file.filename != benchmarkMultipartFileName) {
      return ctx.res.code(HttpStatus.badRequest).json({
        'error': 'invalid_upload',
      });
    }

    await ctx.services.s3Client.putObjectNativeBytes(
      bucket: ctx.services.s3Bucket,
      key: benchmarkUploadObjectKey(email),
      bytes: file.nativeBytes,
      contentType: file.contentType ?? benchmarkMultipartFileContentType,
    );

    return ctx.res
        .type('application/json; charset=utf-8')
        .send(benchmarkUploadMultipartResponseJson(email));
  }
}
