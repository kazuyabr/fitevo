import 'package:isar/isar.dart';

part 'food_combo.g.dart';

/// A saved bundle of staple foods the user eats together — e.g. their daily
/// stack: creatine + 1 scoop whey + 150ml milk + 1 banana. Logging a combo
/// logs every item in one tap.
///
/// Items reference [CustomFood]s by id (not a macro snapshot) so editing a
/// staple's nutrition keeps every combo that uses it up to date. A referenced
/// food that's since been deleted is simply skipped when logging.
@collection
class FoodCombo {
  Id id = Isar.autoIncrement;

  @Index(caseSensitive: false)
  late String name;

  List<ComboItem> items = [];

  DateTime createdAt = DateTime.now();
}

/// One line in a [FoodCombo]: which saved food, and how many servings.
@embedded
class ComboItem {
  int customFoodId = 0;
  double servings = 1.0;
}
