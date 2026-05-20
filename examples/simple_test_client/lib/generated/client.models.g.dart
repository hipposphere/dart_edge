// GENERATED CODE - DO NOT MODIFY BY HAND.

part of 'client.g.dart';

final class PublicNotesRow implements JsonEncodable {
  const PublicNotesRow({
    required this.id,
    required this.title,
    required this.body,
    required this.ownerId,
    required this.createdAt,
  });

  factory PublicNotesRow.decode(Object? value) {
    return PublicNotesRow.fromJson(readJsonObject(value));
  }

  factory PublicNotesRow.fromJson(Map<String, Object?> json) {
    return PublicNotesRow(
      id: (json['id']! as num).toInt(),
      title: json['title']! as String,
      body: json['body']! as String,
      ownerId: (json['owner_id']! as num).toInt(),
      createdAt: json['created_at']! as String,
    );
  }

  final int id;

  final String title;

  final String body;

  final int ownerId;

  final String createdAt;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'body': body,
      'owner_id': ownerId,
      'created_at': createdAt,
    };
  }
}

final class PublicNotesInsert implements JsonEncodable {
  const PublicNotesInsert({
    this.id,
    required this.title,
    required this.body,
    required this.ownerId,
    this.createdAt,
  });

  factory PublicNotesInsert.decode(Object? value) {
    return PublicNotesInsert.fromJson(readJsonObject(value));
  }

  factory PublicNotesInsert.fromJson(Map<String, Object?> json) {
    return PublicNotesInsert(
      id: json['id'] == null ? null : (json['id'] as num).toInt(),
      title: json['title']! as String,
      body: json['body']! as String,
      ownerId: (json['owner_id']! as num).toInt(),
      createdAt: json['created_at'] == null
          ? null
          : json['created_at'] as String,
    );
  }

  final int? id;

  final String title;

  final String body;

  final int ownerId;

  final String? createdAt;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'body': body,
      'owner_id': ownerId,
      'created_at': createdAt,
    };
  }
}

final class CreateNoteResponse implements JsonEncodable {
  const CreateNoteResponse({required this.notes});

  factory CreateNoteResponse.decode(Object? value) {
    return CreateNoteResponse.fromJson(readJsonObject(value));
  }

  factory CreateNoteResponse.fromJson(Map<String, Object?> json) {
    return CreateNoteResponse(notes: PublicNotesRow.decode(json['notes']!));
  }

  final PublicNotesRow notes;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'notes': notes.toJson()};
  }
}

final class DartEdgeAuthUser implements JsonEncodable {
  const DartEdgeAuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.emailVerified,
    required this.image,
    required this.createdAt,
    required this.updatedAt,
    required this.username,
    required this.displayUsername,
    required this.twoFactorEnabled,
    required this.role,
    required this.banned,
    required this.banReason,
    required this.banExpires,
  });

  factory DartEdgeAuthUser.decode(Object? value) {
    return DartEdgeAuthUser.fromJson(readJsonObject(value));
  }

  factory DartEdgeAuthUser.fromJson(Map<String, Object?> json) {
    return DartEdgeAuthUser(
      id: json['id']! as String,
      name: json['name']! as String,
      email: json['email']! as String,
      emailVerified: json['emailVerified']! as bool,
      image: json['image']! as String,
      createdAt: json['createdAt']! as String,
      updatedAt: json['updatedAt']! as String,
      username: json['username']! as String,
      displayUsername: json['displayUsername']! as String,
      twoFactorEnabled: json['twoFactorEnabled']! as bool,
      role: json['role']! as String,
      banned: json['banned']! as bool,
      banReason: json['banReason']! as String,
      banExpires: json['banExpires']! as String,
    );
  }

  final String id;

  final String? name;

  final String? email;

  final bool emailVerified;

  final String? image;

  final String createdAt;

  final String updatedAt;

  final String? username;

  final String? displayUsername;

  final bool twoFactorEnabled;

  final String? role;

  final bool banned;

  final String? banReason;

  final String? banExpires;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'email': email,
      'emailVerified': emailVerified,
      'image': image,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'username': username,
      'displayUsername': displayUsername,
      'twoFactorEnabled': twoFactorEnabled,
      'role': role,
      'banned': banned,
      'banReason': banReason,
      'banExpires': banExpires,
    };
  }
}

final class DartEdgeAuthSession implements JsonEncodable {
  const DartEdgeAuthSession({
    required this.id,
    required this.expiresAt,
    required this.token,
    required this.createdAt,
    required this.updatedAt,
    required this.ipAddress,
    required this.userAgent,
    required this.userId,
    required this.impersonatedBy,
    required this.activeOrganizationId,
  });

  factory DartEdgeAuthSession.decode(Object? value) {
    return DartEdgeAuthSession.fromJson(readJsonObject(value));
  }

  factory DartEdgeAuthSession.fromJson(Map<String, Object?> json) {
    return DartEdgeAuthSession(
      id: json['id']! as String,
      expiresAt: json['expiresAt']! as String,
      token: json['token']! as String,
      createdAt: json['createdAt']! as String,
      updatedAt: json['updatedAt']! as String,
      ipAddress: json['ipAddress']! as String,
      userAgent: json['userAgent']! as String,
      userId: json['userId']! as String,
      impersonatedBy: json['impersonatedBy']! as String,
      activeOrganizationId: json['activeOrganizationId']! as String,
    );
  }

  final String id;

  final String expiresAt;

  final String token;

  final String createdAt;

  final String updatedAt;

  final String? ipAddress;

  final String? userAgent;

  final String userId;

  final String? impersonatedBy;

  final String? activeOrganizationId;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'expiresAt': expiresAt,
      'token': token,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'ipAddress': ipAddress,
      'userAgent': userAgent,
      'userId': userId,
      'impersonatedBy': impersonatedBy,
      'activeOrganizationId': activeOrganizationId,
    };
  }
}

final class DartEdgeAuthSignUpResult implements JsonEncodable {
  const DartEdgeAuthSignUpResult({required this.token, required this.user});

  factory DartEdgeAuthSignUpResult.decode(Object? value) {
    return DartEdgeAuthSignUpResult.fromJson(readJsonObject(value));
  }

  factory DartEdgeAuthSignUpResult.fromJson(Map<String, Object?> json) {
    return DartEdgeAuthSignUpResult(
      token: json['token']! as String,
      user: DartEdgeAuthUser.decode(json['user']!),
    );
  }

  final String? token;

  final DartEdgeAuthUser user;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'token': token, 'user': user.toJson()};
  }
}

final class DartEdgeAuthSignInResult implements JsonEncodable {
  const DartEdgeAuthSignInResult({
    required this.redirect,
    required this.token,
    required this.url,
    this.user,
    this.twoFactorRedirect,
  });

  factory DartEdgeAuthSignInResult.decode(Object? value) {
    return DartEdgeAuthSignInResult.fromJson(readJsonObject(value));
  }

  factory DartEdgeAuthSignInResult.fromJson(Map<String, Object?> json) {
    return DartEdgeAuthSignInResult(
      redirect: json['redirect']! as bool,
      token: json['token']! as String,
      url: json['url']! as String,
      user: json['user'] == null ? null : DartEdgeAuthUser.decode(json['user']),
      twoFactorRedirect: json['twoFactorRedirect'] == null
          ? null
          : json['twoFactorRedirect'] as bool,
    );
  }

  final bool redirect;

  final String token;

  final String? url;

  final DartEdgeAuthUser? user;

  final bool? twoFactorRedirect;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'redirect': redirect,
      'token': token,
      'url': url,
      'user': user?.toJson(),
      'twoFactorRedirect': twoFactorRedirect,
    };
  }
}

final class DartEdgeAuthSessionResult implements JsonEncodable {
  const DartEdgeAuthSessionResult({required this.session, required this.user});

  factory DartEdgeAuthSessionResult.decode(Object? value) {
    return DartEdgeAuthSessionResult.fromJson(readJsonObject(value));
  }

  factory DartEdgeAuthSessionResult.fromJson(Map<String, Object?> json) {
    return DartEdgeAuthSessionResult(
      session: DartEdgeAuthSession.decode(json['session']!),
      user: DartEdgeAuthUser.decode(json['user']!),
    );
  }

  final DartEdgeAuthSession session;

  final DartEdgeAuthUser user;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{
      'session': session.toJson(),
      'user': user.toJson(),
    };
  }
}

final class DartEdgeAuthStatusResult implements JsonEncodable {
  const DartEdgeAuthStatusResult({required this.status, this.message});

  factory DartEdgeAuthStatusResult.decode(Object? value) {
    return DartEdgeAuthStatusResult.fromJson(readJsonObject(value));
  }

  factory DartEdgeAuthStatusResult.fromJson(Map<String, Object?> json) {
    return DartEdgeAuthStatusResult(
      status: json['status']! as bool,
      message: json['message'] == null ? null : json['message'] as String,
    );
  }

  final bool status;

  final String? message;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'status': status, 'message': message};
  }
}

final class DartEdgeAuthSuccessResult implements JsonEncodable {
  const DartEdgeAuthSuccessResult({required this.success, this.message});

  factory DartEdgeAuthSuccessResult.decode(Object? value) {
    return DartEdgeAuthSuccessResult.fromJson(readJsonObject(value));
  }

  factory DartEdgeAuthSuccessResult.fromJson(Map<String, Object?> json) {
    return DartEdgeAuthSuccessResult(
      success: json['success']! as bool,
      message: json['message'] == null ? null : json['message'] as String,
    );
  }

  final bool success;

  final String? message;

  @override
  Map<String, Object?> toJson() {
    return <String, Object?>{'success': success, 'message': message};
  }
}
