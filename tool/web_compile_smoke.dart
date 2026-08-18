// ignore_for_file: depend_on_referenced_packages

import 'dart:typed_data';

import 'package:dart_edge_core/dart_edge_core.dart';

void main() {
  final lease = BinaryPayloadLease.fromBytes(Uint8List.fromList([1, 2, 3]));
  lease.close();
}
