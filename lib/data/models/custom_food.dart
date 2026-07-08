import 'package:isar/isar.dart';

part 'custom_food.g.dart';

@collection
class CustomFood {
  Id id = Isar.autoIncrement;

  @Index(caseSensitive: false)
  late String name;

  late double servingSizeG;
  String servingDescription = '1 serving';

  int caloriesPerServing = 0;
  int proteinGPerServing = 0;
  int carbsGPerServing = 0;
  int fatGPerServing = 0;
  int fiberGPerServing = 0;
  int sodiumMgPerServing = 0;

  String? ingredients;

  // Usage tracking so the quick-add strip can float the foods you log most
  // to the front. Incremented each time the food is logged.
  int useCount = 0;
  DateTime? lastUsedAt;

  DateTime createdAt = DateTime.now();
}
