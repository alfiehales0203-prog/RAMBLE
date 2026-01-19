import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'Screens/home_page.dart';
import 'models/audio_note.dart';
import 'models/user_category.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  
  Hive.registerAdapter(AudioNoteAdapter());
  Hive.registerAdapter(UserCategoryAdapter());
  
  await Hive.openBox<AudioNote>('audioNotes');
  await Hive.openBox<UserCategory>('categories');
  
  final categoryBox = Hive.box<UserCategory>('categories');
  if (categoryBox.isEmpty) {
    await categoryBox.add(UserCategory(
      name: 'Shopping List',
      iconName: 'shopping_cart',
      colorValue: 0xFFFF9800,
    ));
    await categoryBox.add(UserCategory(
      name: 'To Do List',
      iconName: 'check_box',
      colorValue: 0xFF2196F3,
    ));
    await categoryBox.add(UserCategory(
      name: 'Ideas',
      iconName: 'lightbulb',
      colorValue: 0xFFFBC02D,
    ));
    await categoryBox.add(UserCategory(
      name: 'Miscellaneous',
      iconName: 'category',
      colorValue: 0xFF9C27B0,
    ));
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ramble',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}