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
  authChangeEmail({
    required Object? body,
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
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
        abortTrigger: abortTrigger,
        timeout: timeout,
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
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/change-password',
        abortTrigger: abortTrigger,
        timeout: timeout,
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
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/delete-user',
        abortTrigger: abortTrigger,
        timeout: timeout,
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
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.delete,
        pathTemplate: '/auth/delete-user',
        abortTrigger: abortTrigger,
        timeout: timeout,
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

  Future<DartEdgeClientResponseObject<Object?>> authDeleteUserCallback({
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Never>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/auth/delete-user/callback',
        abortTrigger: abortTrigger,
        timeout: timeout,
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<Object?>> authError({
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Never>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/auth/error',
        abortTrigger: abortTrigger,
        timeout: timeout,
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<Object?>> authForgetPassword({
    required Object? body,
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/forget-password',
        abortTrigger: abortTrigger,
        timeout: timeout,
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
  authGetSession({Future<void>? abortTrigger, Duration? timeout}) {
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
        abortTrigger: abortTrigger,
        timeout: timeout,
        success: DartEdgeClientResponseSpec<DartEdgeAuthSessionResult>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
          decoder: DartEdgeAuthSessionResult.decode,
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<DartEdgeAuthSessionResult>>
  authGetSessionPost({
    required Object? body,
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
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
        abortTrigger: abortTrigger,
        timeout: timeout,
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

  Future<DartEdgeClientResponseObject<Object?>> authListAccounts({
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Never>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/auth/list-accounts',
        abortTrigger: abortTrigger,
        timeout: timeout,
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<Object?>> authListSessions({
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Never>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/auth/list-sessions',
        abortTrigger: abortTrigger,
        timeout: timeout,
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<Object?>> authOk({
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Never>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/auth/ok',
        abortTrigger: abortTrigger,
        timeout: timeout,
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<Object?>> authOpenapiSpec({
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Never>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/auth/reference/openapi.json',
        abortTrigger: abortTrigger,
        timeout: timeout,
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<Object?>> authResetPassword({
    required Object? body,
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/reset-password',
        abortTrigger: abortTrigger,
        timeout: timeout,
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

  Future<DartEdgeClientResponseObject<Object?>> authResetPasswordToken({
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Never>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/auth/reset-password/<token>',
        abortTrigger: abortTrigger,
        timeout: timeout,
        success: DartEdgeClientResponseSpec<Object?>(
          status: 200,
          contentType: 'application/json; charset=utf-8',
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<Object?>> authRevokeOtherSessions({
    required Object? body,
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/revoke-other-sessions',
        abortTrigger: abortTrigger,
        timeout: timeout,
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
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/revoke-session',
        abortTrigger: abortTrigger,
        timeout: timeout,
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
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/revoke-sessions',
        abortTrigger: abortTrigger,
        timeout: timeout,
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
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/set-password',
        abortTrigger: abortTrigger,
        timeout: timeout,
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
  authSignInEmail({
    required Object? body,
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
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
        abortTrigger: abortTrigger,
        timeout: timeout,
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
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/sign-in/username',
        abortTrigger: abortTrigger,
        timeout: timeout,
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
    Future<void>? abortTrigger,
    Duration? timeout,
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
        abortTrigger: abortTrigger,
        timeout: timeout,
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
  authSignUpEmail({
    required Object? body,
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
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
        abortTrigger: abortTrigger,
        timeout: timeout,
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
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<Object?, Never, Never, Never, Object?>(
      DartEdgeClientInvocation<Object?, Never, Never, Never, Object?>(
        method: HttpMethod.post,
        pathTemplate: '/auth/unlink-account',
        abortTrigger: abortTrigger,
        timeout: timeout,
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
  authUpdateUser({
    required Object? body,
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
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
        abortTrigger: abortTrigger,
        timeout: timeout,
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

  Future<DartEdgeClientResponseObject<String>> getRoot({
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<String, Never, Never, Never, Never>(
      DartEdgeClientInvocation<String, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/',
        abortTrigger: abortTrigger,
        timeout: timeout,
        success: DartEdgeClientResponseSpec<String>(
          status: 200,
          contentType: 'text/plain; charset=utf-8',
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<String>> upload({
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<String, Never, Never, Never, Never>(
      DartEdgeClientInvocation<String, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/upload',
        abortTrigger: abortTrigger,
        timeout: timeout,
        success: DartEdgeClientResponseSpec<String>(
          status: 204,
          contentType: 'text/plain; charset=utf-8',
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<String>> getHello({
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<String, Never, Never, Never, Never>(
      DartEdgeClientInvocation<String, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/hello',
        abortTrigger: abortTrigger,
        timeout: timeout,
        success: DartEdgeClientResponseSpec<String>(
          status: 200,
          contentType: 'text/plain; charset=utf-8',
        ),
      ),
    );
  }

  Future<DartEdgeClientResponseObject<CreateNoteResponse>> createNote({
    required PublicNotesInsert body,
    Future<void>? abortTrigger,
    Duration? timeout,
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
        abortTrigger: abortTrigger,
        timeout: timeout,
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

  Future<DartEdgeClientResponseObject<String>> getGuarded({
    Future<void>? abortTrigger,
    Duration? timeout,
  }) {
    return invoke<String, Never, Never, Never, Never>(
      DartEdgeClientInvocation<String, Never, Never, Never, Never>(
        method: HttpMethod.get,
        pathTemplate: '/guarded',
        abortTrigger: abortTrigger,
        timeout: timeout,
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
