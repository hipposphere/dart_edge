// GENERATED CODE - DO NOT MODIFY BY HAND.

part of 'client.g.dart';

final class SimpleTestClient extends DartEdgeHttpClientBase {
  SimpleTestClient({
    required super.baseUri,
    required super.transport,
    super.webSocketTransport,
    super.defaultHeaders = const <String, String>{},
  });

  Future<Object?> changeEmail({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/change-email',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> changePassword({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/change-password',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> deleteUser({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/delete-user',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> deleteUserDelete({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.delete,
        pathTemplate: '/auth/delete-user',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> deleteUserCallback() {
    return invoke<Object?, Never, Never, Never, Never>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/auth/delete-user/callback',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
      ),
    );
  }

  Future<Object?> error() {
    return invoke<Object?, Never, Never, Never, Never>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/auth/error',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
      ),
    );
  }

  Future<Object?> forgetPassword({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/forget-password',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> getSession() {
    return invoke<Object?, Never, Never, Never, Never>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/auth/get-session',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
      ),
    );
  }

  Future<Object?> getSessionPost({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/get-session',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> listAccounts() {
    return invoke<Object?, Never, Never, Never, Never>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/auth/list-accounts',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
      ),
    );
  }

  Future<Object?> listSessions() {
    return invoke<Object?, Never, Never, Never, Never>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/auth/list-sessions',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
      ),
    );
  }

  Future<Object?> ok() {
    return invoke<Object?, Never, Never, Never, Never>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/auth/ok',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
      ),
    );
  }

  Future<Object?> openapiSpec() {
    return invoke<Object?, Never, Never, Never, Never>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/auth/reference/openapi.json',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
      ),
    );
  }

  Future<Object?> resetPassword({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/reset-password',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> resetPasswordToken() {
    return invoke<Object?, Never, Never, Never, Never>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/auth/reset-password/<token>',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
      ),
    );
  }

  Future<Object?> revokeOtherSessions({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/revoke-other-sessions',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> revokeSession({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/revoke-session',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> revokeSessions({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/revoke-sessions',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> setPassword({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/set-password',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> signInEmail({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/sign-in/email',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> signInUsername({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/sign-in/username',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> signOut({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/sign-out',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> signUpEmail({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/sign-up/email',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> unlinkAccount({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/unlink-account',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<Object?> updateUser({required Object? body}) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/update-user',
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<String> getRoot() {
    return invoke<String, Never, Never, Never, Never>(
      DartEdgeClientInvocation<String, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/',
        success: DartEdgeClientResponseSpec<String>(
          status: 200,
          contentType: 'text/plain; charset=utf-8',
        ),
      ),
    );
  }

  Future<String> upload() {
    return invoke<String, Never, Never, Never, Never>(
      DartEdgeClientInvocation<String, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/upload',
        success: DartEdgeClientResponseSpec<String>(
          status: 204,
          contentType: 'text/plain; charset=utf-8',
        ),
      ),
    );
  }

  Future<String> getHello() {
    return invoke<String, Never, Never, Never, Never>(
      DartEdgeClientInvocation<String, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/hello',
        success: DartEdgeClientResponseSpec<String>(
          status: 200,
          contentType: 'text/plain; charset=utf-8',
        ),
      ),
    );
  }

  Future<CreateNoteResponse> createNote({required NotesInsert body}) {
    return invoke<CreateNoteResponse, Never, Never, Never, NotesInsert>(
      DartEdgeClientInvocation<
        CreateNoteResponse,
        Never,
        Never,
        Never,
        NotesInsert
      >(
        method: HttpMethod.post,
        pathTemplate: '/notes',
        success: DartEdgeClientResponseSpec<CreateNoteResponse>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
          schemaId: 'CreateNoteResponse',
          decoder: CreateNoteResponse.fromJson,
        ),
        body: DartEdgeClientRequestBody<NotesInsert>(
          contentType: 'application/json; charset=utf-8',
          schemaId: 'NotesInsert',
          value: body,
          encoder: (value) => value.toJson(),
        ),
      ),
    );
  }

  Future<String> getGuarded() {
    return invoke<String, Never, Never, Never, Never>(
      DartEdgeClientInvocation<String, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/guarded',
        success: DartEdgeClientResponseSpec<String>(
          status: 200,
          contentType: 'text/plain; charset=utf-8',
        ),
      ),
    );
  }
}
