// GENERATED CODE - DO NOT MODIFY BY HAND.

part of 'client.g.dart';

final class SimpleTestClient extends DartEdgeHttpClientBase {
  SimpleTestClient({
    required super.baseUri,
    required super.transport,
    super.webSocketTransport,
    super.webTransportTransport,
    super.defaultHeaders = const <String, String>{},
  });

  Future<DartEdgeClientResponseObject<DartEdgeAuthStatusResult>>
  authChangeEmail({required Object? body}) {
    return invoke<DartEdgeAuthStatusResult, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<
        DartEdgeAuthStatusResult,
        Never,
        Never,
        Never,
        Object?
      >(
        method: HttpMethod.post,
        pathTemplate: '/auth/change-email',
        success: DartEdgeClientResponseSpec<DartEdgeAuthStatusResult>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
          decoder: DartEdgeAuthStatusResult.decode,
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<Object?>> authChangePassword({
    required Object? body,
  }) {
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

  Future<DartEdgeClientResponseObject<Object?>> authDeleteUser({
    required Object? body,
  }) {
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

  Future<DartEdgeClientResponseObject<Object?>> authDeleteUserDelete({
    required Object? body,
  }) {
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

  Future<DartEdgeClientResponseObject<Object?>> authDeleteUserCallback() {
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

  Future<DartEdgeClientResponseObject<Object?>> authError() {
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

  Future<DartEdgeClientResponseObject<Object?>> authForgetPassword({
    required Object? body,
  }) {
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

  Future<DartEdgeClientResponseObject<DartEdgeAuthSessionResult>>
  authGetSession() {
    return invoke<DartEdgeAuthSessionResult, Never, Never, Never, Never>(
      DartEdgeClientInvocation<
        DartEdgeAuthSessionResult,
        Never,
        Never,
        Never,
        Never
      >(
        method: HttpMethod.get,
        pathTemplate: '/auth/get-session',
        success: DartEdgeClientResponseSpec<DartEdgeAuthSessionResult>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
          decoder: DartEdgeAuthSessionResult.decode,
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<DartEdgeAuthSessionResult>>
  authGetSessionPost({required Object? body}) {
    return invoke<DartEdgeAuthSessionResult, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<
        DartEdgeAuthSessionResult,
        Never,
        Never,
        Never,
        Object?
      >(
        method: HttpMethod.post,
        pathTemplate: '/auth/get-session',
        success: DartEdgeClientResponseSpec<DartEdgeAuthSessionResult>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
          decoder: DartEdgeAuthSessionResult.decode,
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<Object?>> authListAccounts() {
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

  Future<DartEdgeClientResponseObject<Object?>> authListSessions() {
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

  Future<DartEdgeClientResponseObject<Object?>> authOk() {
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

  Future<DartEdgeClientResponseObject<Object?>> authOpenapiSpec() {
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

  Future<DartEdgeClientResponseObject<Object?>> authResetPassword({
    required Object? body,
  }) {
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

  Future<DartEdgeClientResponseObject<Object?>> authResetPasswordToken() {
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

  Future<DartEdgeClientResponseObject<Object?>> authRevokeOtherSessions({
    required Object? body,
  }) {
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

  Future<DartEdgeClientResponseObject<Object?>> authRevokeSession({
    required Object? body,
  }) {
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

  Future<DartEdgeClientResponseObject<Object?>> authRevokeSessions({
    required Object? body,
  }) {
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

  Future<DartEdgeClientResponseObject<Object?>> authSetPassword({
    required Object? body,
  }) {
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

  Future<DartEdgeClientResponseObject<DartEdgeAuthSignInResult>>
  authSignInEmail({required Object? body}) {
    return invoke<DartEdgeAuthSignInResult, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<
        DartEdgeAuthSignInResult,
        Never,
        Never,
        Never,
        Object?
      >(
        method: HttpMethod.post,
        pathTemplate: '/auth/sign-in/email',
        success: DartEdgeClientResponseSpec<DartEdgeAuthSignInResult>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
          decoder: DartEdgeAuthSignInResult.decode,
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<Object?>> authSignInUsername({
    required Object? body,
  }) {
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

  Future<DartEdgeClientResponseObject<DartEdgeAuthSuccessResult>> authSignOut({
    required Object? body,
  }) {
    return invoke<DartEdgeAuthSuccessResult, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<
        DartEdgeAuthSuccessResult,
        Never,
        Never,
        Never,
        Object?
      >(
        method: HttpMethod.post,
        pathTemplate: '/auth/sign-out',
        success: DartEdgeClientResponseSpec<DartEdgeAuthSuccessResult>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
          decoder: DartEdgeAuthSuccessResult.decode,
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<DartEdgeAuthSignUpResult>>
  authSignUpEmail({required Object? body}) {
    return invoke<DartEdgeAuthSignUpResult, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<
        DartEdgeAuthSignUpResult,
        Never,
        Never,
        Never,
        Object?
      >(
        method: HttpMethod.post,
        pathTemplate: '/auth/sign-up/email',
        success: DartEdgeClientResponseSpec<DartEdgeAuthSignUpResult>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
          decoder: DartEdgeAuthSignUpResult.decode,
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<Object?>> authUnlinkAccount({
    required Object? body,
  }) {
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

  Future<DartEdgeClientResponseObject<DartEdgeAuthStatusResult>>
  authUpdateUser({required Object? body}) {
    return invoke<DartEdgeAuthStatusResult, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<
        DartEdgeAuthStatusResult,
        Never,
        Never,
        Never,
        Object?
      >(
        method: HttpMethod.post,
        pathTemplate: '/auth/update-user',
        success: DartEdgeClientResponseSpec<DartEdgeAuthStatusResult>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
          decoder: DartEdgeAuthStatusResult.decode,
        ),
        body: DartEdgeClientRequestBody<Object?>(
          contentType: 'application/json; charset=utf-8',
          value: body,
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<String>> getRoot() {
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

  Future<DartEdgeClientResponseObject<String>> upload() {
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

  Future<DartEdgeClientResponseObject<String>> getHello() {
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

  Future<DartEdgeClientResponseObject<CreateNoteResponse>> createNote({
    required PublicNotesInsert body,
  }) {
    return invoke<CreateNoteResponse, Never, Never, Never, PublicNotesInsert>(
      DartEdgeClientInvocation<
        CreateNoteResponse,
        Never,
        Never,
        Never,
        PublicNotesInsert
      >(
        method: HttpMethod.post,
        pathTemplate: '/notes',
        success: DartEdgeClientResponseSpec<CreateNoteResponse>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
          schemaId: 'CreateNoteResponse',
          decoder: CreateNoteResponse.decode,
        ),
        body: DartEdgeClientRequestBody<PublicNotesInsert>(
          contentType: 'application/json; charset=utf-8',
          schemaId: 'PublicNotesInsert',
          value: body,
          encoder: (value) => value.toJson(),
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<String>> getGuarded() {
    return invoke<String, Never, Never, Never, Never>(
      DartEdgeClientInvocation<String, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/guarded',
        success: DartEdgeClientResponseSpec<String>(
          status: 200,
          contentType: 'text/plain; charset=utf-8',
        ),
        errors: <DartEdgeClientErrorSpec>[
          DartEdgeClientErrorSpec(status: 401, code: 'unauthorized'),
        ],
      ),
    );
  }
}
