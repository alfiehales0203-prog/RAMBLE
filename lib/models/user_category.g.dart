// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_category.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserCategoryAdapter extends TypeAdapter<UserCategory> {
  @override
  final int typeId = 1;

  @override
  UserCategory read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserCategory(
      name: fields[0] as String,
      iconName: fields[1] as String,
      colorValue: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, UserCategory obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.iconName)
      ..writeByte(2)
      ..write(obj.colorValue);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserCategoryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
