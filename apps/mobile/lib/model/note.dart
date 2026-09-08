import 'dart:convert';

class InkPoint {
  const InkPoint(this.x, this.y);
  final double x, y;
}

class InkStroke {
  InkStroke({
    required this.color,
    required this.width,
    required List<InkPoint> points,
  }) : points = List.unmodifiable(points);
  final int color;
  final double width;
  final List<InkPoint> points;
}

class Note {
  Note({
    required this.id,
    this.title = '',
    this.body = '',
    List<InkStroke> strokes = const [],
    this.revision = 0,
    required this.updatedAt,
  }) : strokes = List.unmodifiable(strokes);
  final String id, title, body;
  final List<InkStroke> strokes;
  final int revision;
  final DateTime updatedAt;

  Note copyWith({
    String? title,
    String? body,
    List<InkStroke>? strokes,
    int? revision,
    DateTime? updatedAt,
  }) => Note(
    id: id,
    title: title ?? this.title,
    body: body ?? this.body,
    strokes: strokes ?? this.strokes,
    revision: revision ?? this.revision,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object> toJson() => {
    'format': 1,
    'id': id,
    'title': title,
    'body': body,
    'revision': revision,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'strokes': strokes
        .map(
          (stroke) => {
            'color': stroke.color,
            'width': stroke.width,
            'points': stroke.points.map((point) => [point.x, point.y]).toList(),
          },
        )
        .toList(),
  };

  factory Note.fromJson(Map<String, dynamic> data) {
    if (data['format'] != 1 ||
        data['title'] is! String ||
        data['body'] is! String ||
        data['id'] is! String ||
        data['revision'] is! int ||
        data['updatedAt'] is! int ||
        data['strokes'] is! List) {
      throw const FormatException('Unsupported note data');
    }
    final strokes = (data['strokes'] as List).map((value) {
      final stroke = value as Map<String, dynamic>;
      return InkStroke(
        color: stroke['color'] as int,
        width: (stroke['width'] as num).toDouble(),
        points: (stroke['points'] as List).map((value) {
          final point = value as List;
          if (point.length != 2) {
            throw const FormatException('Invalid ink point');
          }
          return InkPoint(
            (point[0] as num).toDouble(),
            (point[1] as num).toDouble(),
          );
        }).toList(),
      );
    }).toList();
    final result = Note(
      id: data['id'] as String,
      title: data['title'] as String,
      body: data['body'] as String,
      revision: data['revision'] as int,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        data['updatedAt'] as int,
        isUtc: true,
      ),
      strokes: strokes,
    );
    result.validate();
    return result;
  }

  // Reserve metadata growth before accepting a draft, not after the user presses Save.
  bool get fitsStorage =>
      utf8
          .encode(
            jsonEncode({
              ...toJson(),
              'revision': 9007199254740990,
              'updatedAt': 8640000000000000,
            }),
          )
          .length <=
      65520;

  void validate() {
    if (!noteUuid.hasMatch(id) ||
        revision < 0 ||
        revision >= 9007199254740991 ||
        title.length > 200 ||
        body.length > 20000 ||
        strokes.length > 256) {
      throw const FormatException('Note exceeds supported limits');
    }
    var points = 0;
    for (final stroke in strokes) {
      points += stroke.points.length;
      if (stroke.color < 0 ||
          stroke.color > 0xffffffff ||
          !stroke.width.isFinite ||
          stroke.width <= 0 ||
          stroke.width > 50 ||
          stroke.points.isEmpty ||
          stroke.points.length > 512 ||
          points > 2048) {
        throw const FormatException('Ink exceeds supported limits');
      }
      for (final point in stroke.points) {
        if (!point.x.isFinite ||
            !point.y.isFinite ||
            point.x.abs() > 10000 ||
            point.y.abs() > 10000) {
          throw const FormatException('Invalid ink coordinates');
        }
      }
    }
    if (!fitsStorage) {
      throw const FormatException('Encrypted note byte budget exceeded');
    }
  }
}

final noteUuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);
