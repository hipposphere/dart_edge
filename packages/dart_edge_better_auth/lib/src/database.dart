import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dart_edge_better_auth/generated/better_auth_tables.g.dart';
import 'package:dart_edge_sql/dart_edge_sql.dart';

import 'config.dart';
import 'error.dart';
import 'gateway/better_auth_gateways.dart';
import 'models.dart';
import 'password.dart';

part 'store/admin_store.dart';
part 'store/credentials_store.dart';
part 'store/model_mappers.dart';
part 'store/session_store.dart';
part 'store/session_persistence_store.dart';
part 'store/sql_store.dart';
part 'store/user_creation_store.dart';
part 'store/user_lookup_store.dart';
part 'store/user_ban_store.dart';
part 'store/user_listing_store.dart';
part 'store/user_password_store.dart';
part 'store/user_profile_store.dart';
part 'store/user_role_store.dart';
part 'store/validation_store.dart';

final class BetterAuthStore {
  BetterAuthStore({required this.pool, required this.options});

  final SqlPool pool;
  final BetterAuthOptions options;
  late final BetterAuthGateways gateways = BetterAuthGateways(this);
}
