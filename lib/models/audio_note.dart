import 'package:hive/hive.dart';

part 'audio_note.g.dart';  // This line is CRITICAL!

@HiveType(typeId: 0)
class AudioNote extends HiveObject {
  @HiveField(0)
  String filename;
  
  @HiveField(1)
  String? transcription;
  
  @HiveField(2)
  String? category;
  
  @HiveField(3)
  DateTime timestamp;
  
  @HiveField(4)
  bool isTranscribed;
  
  @HiveField(5)
  String? audioFilePath;
  
  AudioNote({
    required this.filename,
    this.transcription,
    this.category,
    required this.timestamp,
    this.isTranscribed = false,
    this.audioFilePath,
  });
}