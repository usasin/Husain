import '../models/models.dart';

// Ranking snapshots deliberately omit the photo. Live team documents own it.
AppTeam teamWithLiveImage(AppTeam snapshot, AppTeam? liveTeam) {
  if (liveTeam == null || liveTeam.id != snapshot.id) return snapshot;
  return snapshot.copyWith(imageB64: liveTeam.imageB64);
}
