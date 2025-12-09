import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timewise_application/core/constants/app_constants.dart';
import 'package:timewise_application/features/dashboard/data/models/models.dart';

class DatabaseService {
  static Isar? _isar;

  static Future<Isar> initialize() async {
    if (_isar != null) return _isar!;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [ProjectModelSchema, TaskModelSchema],
      directory: dir.path,
      name: AppConstants.isarDbName,
    );

    return _isar!;
  }

  static Isar get instance {
    if (_isar == null) {
      throw Exception('Database not initialized. Call initialize() first.');
    }
    return _isar!;
  }

  static Future<void> close() async {
    await _isar?.close();
    _isar = null;
  }
}
