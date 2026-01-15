import 'package:hive/hive.dart';

part 'user_category.g.dart';

@HiveType(typeId: 1)
class UserCategory extends HiveObject {
  @HiveField(0)
  String name;
  
  @HiveField(1)
  String iconName;
  
  @HiveField(2)
  int colorValue;
  
  UserCategory({
    required this.name,
    required this.iconName,
    required this.colorValue,
  });
}