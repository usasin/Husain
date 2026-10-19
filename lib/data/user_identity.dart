import '../models/models.dart';

AppUser userFromProfileData(
  String id,
  Map<String, dynamic> data, {
  AppUser? cached,
  Map<String, dynamic>? pending,
}) {
  final previous = cached?.id == id ? cached : null;
  final patch = pending?['id'] == id ? pending : null;
  return AppUser(
    id: id,
    name: (patch?['name'] ?? data['name'] ?? previous?.name ?? 'Joueur')
        .toString(),
    avatar: (patch?['avatar'] ?? data['avatar'] ?? previous?.avatar ?? '👤')
        .toString(),
    teamId: data['teamId']?.toString(),
    isAdmin: data['isAdmin'] == true,
    recoveryCode: (data['recoveryCode'] ?? previous?.recoveryCode ?? '')
        .toString(),
    acceptChallenges: data['acceptChallenges'] != false,
  );
}

AppUser userWithKnownAvatar(AppUser summary, String? knownAvatar) =>
    knownAvatar == null ? summary : summary.copyWith(avatar: knownAvatar);
