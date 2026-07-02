import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Per-day offline notepad stored in SharedPreferences.
/// Key: 'quick_notes_{dateKey}' → JSON list of strings.
class QuickNoteStore {
  static const _prefix = 'quick_notes_';
  static String _key(String dateKey) => '$_prefix$dateKey';

  static Future<List<String>> load(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(dateKey));
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(String dateKey, List<String> notes) async {
    final prefs = await SharedPreferences.getInstance();
    if (notes.isEmpty) {
      await prefs.remove(_key(dateKey));
    } else {
      await prefs.setString(_key(dateKey), jsonEncode(notes));
    }
  }

  static Future<void> addNote(String dateKey, String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    final notes = await load(dateKey);
    notes.add(t);
    await _save(dateKey, notes);
  }

  static Future<void> removeAt(String dateKey, int index) async {
    final notes = await load(dateKey);
    if (index >= 0 && index < notes.length) {
      notes.removeAt(index);
      await _save(dateKey, notes);
    }
  }

  static Future<void> clear(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(dateKey));
  }
}
