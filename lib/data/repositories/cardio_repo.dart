import 'package:isar/isar.dart';

import '../db.dart';
import '../models/cardio_session.dart';

class CardioRepo {
  CardioRepo(this._db);
  final Db _db;

  Isar get _isar => _db.isar;

  Future<CardioSession> add(CardioSession s) async {
    await _isar.writeTxn(() async {
      await _isar.cardioSessions.put(s);
    });
    return s;
  }

  Future<void> delete(int id) async {
    await _isar.writeTxn(() async {
      await _isar.cardioSessions.delete(id);
    });
  }

  Future<List<CardioSession>> onDate(DateTime day) async {
    final key = CardioSession.keyFor(day);
    return _isar.cardioSessions
        .filter()
        .dateKeyEqualTo(key)
        .sortByStartedAtDesc()
        .findAll();
  }

  Stream<List<CardioSession>> watchOnDate(DateTime day) {
    final key = CardioSession.keyFor(day);
    return _isar.cardioSessions
        .filter()
        .dateKeyEqualTo(key)
        .sortByStartedAtDesc()
        .watch(fireImmediately: true);
  }

  Stream<List<CardioSession>> watchAll() {
    return _isar.cardioSessions
        .where()
        .sortByStartedAtDesc()
        .watch(fireImmediately: true);
  }

  Future<List<CardioSession>> all() {
    return _isar.cardioSessions.where().sortByStartedAtDesc().findAll();
  }
}
