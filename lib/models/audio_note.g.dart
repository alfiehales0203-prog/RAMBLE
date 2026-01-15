// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_note.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AudioNoteAdapter extends TypeAdapter<AudioNote> {
  @override
  final int typeId = 0;

  @override
  AudioNote read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AudioNote(
      filename: fields[0] as String,
      transcription: fields[1] as String?,
      category: fields[2] as String?,
      timestamp: fields[3] as DateTime,
      isTranscribed: fields[4] as bool,
      audioFilePath: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AudioNote obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.filename)
      ..writeByte(1)
      ..write(obj.transcription)
      ..writeByte(2)
      ..write(obj.category)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.isTranscribed)
      ..writeByte(5)
      ..write(obj.audioFilePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioNoteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
