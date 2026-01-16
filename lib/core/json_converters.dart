import 'dart:convert';
import 'dart:typed_data';

import 'package:json_annotation/json_annotation.dart';

class Uint8ListBase64Converter implements JsonConverter<Uint8List?, String?> {
  const Uint8ListBase64Converter();

  @override
  Uint8List? fromJson(String? json) {
    if (json == null) return null;
    return base64Decode(json);
  }

  @override
  String? toJson(Uint8List? object) {
    if (object == null) return null;
    return base64Encode(object);
  }
}

class Uint8ListListConverter
    implements JsonConverter<List<Uint8List>?, List<dynamic>?> {
  const Uint8ListListConverter();

  @override
  List<Uint8List>? fromJson(List<dynamic>? json) {
    if (json == null) return null;
    return json.map((e) => base64Decode(e as String)).toList();
  }

  @override
  List<String>? toJson(List<Uint8List>? object) {
    if (object == null) return null;
    return object.map((e) => base64Encode(e)).toList();
  }
}
