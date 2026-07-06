import 'package:isar/isar.dart';

import '../db.dart';
import '../models/soreness_log.dart';

class SorenessRepo {
  SorenessRepo(this._db);
  final Db _db;

  Isar get _isar => _db.isar;

  /// The check-in for a given day, if any.
  Future<SorenessLog?> forDate(DateTime day) {
    final key = SorenessLog.keyFor(day);
    return _isar.sorenessLogs.filter().dateKeyEqualTo(key).findFirst();
  }

  Stream<SorenessLog?> watchForDate(DateTime day) {
    final key = SorenessLog.keyFor(day);
    return _isar.sorenessLogs
        .filter()
        .dateKeyEqualTo(key)
        .watch(fireImmediately: true)
        .map((rows) => rows.isEmpty ? null : rows.first);
  }

  /// Upserts today's check-in (unique index on dateKey replaces).
  Future<void> save(SorenessLog log) async {
    await _isar.writeTxn(() async {
      await _isar.sorenessLogs.put(log);
    });
  }

  /// Most-recent check-in within the last [days] days — used to decide
  /// whether the scheduled day hits muscles that are still sore.
  Future<SorenessLog?> mostRecentSince(DateTime since) async {
    final all =
        await _isar.sorenessLogs.where().sortByCreatedAtDesc().findAll();
    for (final l in all) {
      if (l.createdAt.isAfter(since)) return l;
    }
    return null;
  }
}
