import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:timewise_application/core/services/services.dart';

final isarProvider = Provider<Isar>((ref) {
  return DatabaseService.instance;
});
