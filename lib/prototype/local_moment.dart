/// A persisted device-only transaction. Production API shapes stay separate.
class LocalMoment {
  LocalMoment({
    required this.id,
    required this.sender,
    required this.recipient,
    required this.points,
    required this.reason,
    required this.visibility,
    required this.at,
    required this.reactions,
  });
  final String id, sender, recipient, reason, visibility;
  final int points;
  final DateTime at;
  final Map<String, String> reactions;
  factory LocalMoment.fromMap(String id, Map<String, dynamic> map) =>
      LocalMoment(
        id: id,
        sender: map['sender'] as String,
        recipient: map['recipient'] as String,
        points: map['points'] as int,
        reason: map['reason'] as String,
        visibility: map['visibility'] as String,
        at: DateTime.parse(map['at'] as String),
        reactions: Map<String, String>.from(map['reactions'] as Map? ?? {}),
      );
  String get signedPoints => '${points > 0 ? '+' : ''}$points';
}

class LocalActivity {
  const LocalActivity({
    required this.id,
    required this.momentId,
    required this.actor,
    required this.kind,
    required this.at,
    required this.read,
  });
  final String id, momentId, actor, kind;
  final DateTime at;
  final bool read;
}
