part of 'app_provider.dart';

class _AccountState {
  Map<String, dynamic>? pending;
  final Map<String, String> avatars = {};
  final Map<String, Future<String>> avatarRequests = {};
  bool busy = false;
  static const pendingKey = 'prono4_pending_profile_v1';
}

extension AccountConnections on AppProvider {
  bool get socialAuthBusy => _account.busy;
  bool get hasConnectedAccount =>
      (_currentUser == null || _currentUser!.id == firebaseUid) &&
      (_auth.currentUser?.providerData.any(
            (p) => p.providerId == 'google.com' || p.providerId == 'apple.com',
          ) ??
          false);
  bool isProviderLinked(String id) =>
      hasConnectedAccount &&
      (_auth.currentUser?.providerData.any((p) => p.providerId == id) ?? false);
  String? get connectedDisplayName => _auth.currentUser?.displayName;
  String? get connectedPhotoUrl => _auth.currentUser?.photoURL;
  String? knownProfileAvatar(String uid) => _account.avatars[uid];

  Future<void> _restoreAndSyncProfile() async {
    var user = _currentUser;
    final uid = firebaseUid;
    if (user == null || uid == null) return;
    if (user.id.startsWith('local_')) {
      user = AppUser(
        id: uid,
        name: user.name,
        avatar: user.avatar,
        teamId: user.teamId,
        recoveryCode: user.recoveryCode,
        acceptChallenges: user.acceptChallenges,
      );
      _currentUser = user;
      if (_account.pending != null) _account.pending!['id'] = uid;
    }
    if (user.id != uid) return;
    try {
      final ref = _db.collection('users').doc(uid);
      final snap = await ref.get().timeout(const Duration(seconds: 8));
      var data = snap.data();
      if (data == null) {
        data = {
          'id': uid,
          'name': user.name,
          'avatar': user.avatar,
          'teamId': user.teamId,
          'recoveryCode': user.recoveryCode.isEmpty
              ? _newRecoveryCode()
              : user.recoveryCode,
          'acceptChallenges': user.acceptChallenges,
          'createdAt': FieldValue.serverTimestamp(),
        };
        await ref.set(data).timeout(const Duration(seconds: 8));
      }
      final patch = _account.pending == null
          ? null
          : Map<String, dynamic>.from(_account.pending!);
      if (patch?['id'] == uid && await _flushPendingProfile()) {
        data = {...data, ...patch!};
      }
      var next = userFromProfileData(
        uid,
        data,
        cached: user,
        pending: _account.pending,
      );
      if (next.recoveryCode.isEmpty) {
        next = next.copyWith(recoveryCode: _newRecoveryCode());
        await ref.set({
          'recoveryCode': next.recoveryCode,
          'recoveryCodeCreatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      _currentUser = next;
      _account.avatars[uid] = next.avatar;
      _users = [..._users.where((u) => u.id != uid), next];
      _patchPrecomputedIdentity([next]);
      await _cacheCurrentUser();
      _notifyAccountChange();
    } catch (_) {
      await _cacheCurrentUser();
    }
  }

  Future<bool> _flushPendingProfile() async {
    final patch = _account.pending;
    if (patch == null) return true;
    if (patch['id'] != firebaseUid) return false;
    try {
      await _db.collection('users').doc(firebaseUid).set({
        if (patch.containsKey('name')) 'name': patch['name'],
        if (patch.containsKey('avatar')) 'avatar': patch['avatar'],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 10));
      if (identical(patch, _account.pending)) {
        _account.pending = null;
        await (await SharedPreferences.getInstance()).remove(
          _AccountState.pendingKey,
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _loadConnectedProfile() async {
    final uid = firebaseUid;
    if (uid == null) return;
    final previous = _currentUser;
    // Never replace a cached profile just because authentication restored
    // another UID. Explicit account changes clear the previous profile first.
    if (previous != null && previous.id != uid) return;
    final snap = await _db
        .collection('users')
        .doc(uid)
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 10));
    if (!snap.exists && previous?.id == uid) return;
    _currentUser = snap.exists ? _userFromDoc(snap) : null;
    _adminMode = _currentUser?.isAdmin ?? false;
    final prefs = await SharedPreferences.getInstance();
    if (_currentUser == null) {
      await prefs.remove(AppProvider._kCachedUserKey);
    } else {
      await _cacheCurrentUser();
    }
  }

  Future<bool> refreshConnectedProfile() async {
    await _loadConnectedProfile();
    _listenScopedIdentity(force: true);
    _listenScopedVotes(force: true);
    _notifyAccountChange();
    return _currentUser != null;
  }

  Future<SocialAuthResult> connectSocial(
    String providerId, {
    bool useExistingAccount = false,
  }) async {
    if (_account.busy) return const SocialAuthResult(SocialAuthStatus.canceled);
    _account.busy = true;
    _notifyAccountChange();
    try {
      await _ensureSignedIn();
      final hadProfile = _currentUser != null;
      if (hadProfile) await _restoreAndSyncProfile();
      final legacyProfile = hadProfile && _currentUser?.id != firebaseUid;
      if (legacyProfile && !useExistingAccount) {
        // Refus fermé : la collection users est encore lisible par les autres
        // utilisateurs connectés, y compris recoveryCode. Ne JAMAIS utiliser
        // ce code public pour délivrer un custom token Firebase.
        // Il faut d'abord déplacer/faire tourner les secrets côté serveur.
        return const SocialAuthResult(SocialAuthStatus.failed,
            code: 'legacy-link-requires-secure-recovery');
      }
      if (hadProfile &&
          !useExistingAccount &&
          (!await _flushPendingProfile() ||
              !(await _db.collection('users').doc(firebaseUid).get()).exists)) {
        return const SocialAuthResult(SocialAuthStatus.failed,
            code: 'profile-sync-pending');
      }
      // If this credential belongs to somebody else, Firebase reports a
      // conflict. We do not merge accounts or change the profile documents.
      final linkUid = firebaseUid;
      final result = await SocialAuthService(auth: _auth).connect(
        providerId,
        hasProfile: hadProfile,
        useExistingAccount: useExistingAccount,
      );
      if (result.status != SocialAuthStatus.connected) return result;
      if (firebaseUid == linkUid && hadProfile && !useExistingAccount) {
        await _saveCloudPreferences();
      } else {
        await _clearPreviousAccountState();
        _currentUser = null;
        _adminMode = false;
        await (await SharedPreferences.getInstance())
            .remove(AppProvider._kCachedUserKey);
        _votes.clear();
        _exactPredictions.clear();
        _voteUpdatedAt.clear();
        _scopedVoteKeys.clear();
        _rebuildVoteCounts();
        await _loadConnectedProfile();
        await _loadBlockedUsersFromCloud();
      }
      _listenScopedIdentity(force: true);
      _listenScopedVotes(force: true);
      _listenReputationVotes(force: true);
      await _cacheCurrentUser();
      return result;
    } on fb_auth.FirebaseAuthException catch (e) {
      return SocialAuthResult(SocialAuthStatus.failed, code: e.code);
    } catch (_) {
      return const SocialAuthResult(
        SocialAuthStatus.failed,
        code: 'network-request-failed',
      );
    } finally {
      _account.busy = false;
      _notifyAccountChange();
    }
  }

  Future<void> _clearPreviousAccountState() async {
    for (final subscription in [
      _usersSub,
      _teamsSub,
      _votesSub,
      _reputationVotesSub
    ]) {
      await subscription?.cancel();
    }
    _usersSub = null;
    _teamsSub = null;
    _votesSub = null;
    _reputationVotesSub = null;
    _reputationVotes.clear();
    _halftimeChangedMatchIds.clear();
    _favoriteClubCodes.clear();
    _blockedUserIds.clear();
    _enabledCompetitionIds = kCompetitions.map((c) => c.id).toSet();
    _voteRemindersEnabled = false;
    _halftimeAlertsEnabled = false;
    _voteReminderScope = 'duels';
    _scheduledReminderCount = 0;
    try {
      await NotificationService.instance.cancelAllVoteReminders();
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('prono4_favorite_clubs_v1', []);
    await prefs.setStringList(AppProvider._kBlockedUsersKey, []);
    await prefs.setStringList(
        'prono4_enabled_competitions_v1', _enabledCompetitionIds.toList());
    await prefs.setBool(AppProvider._kVoteRemindersKey, false);
    await prefs.setBool(AppProvider._kHalftimeAlertsKey, false);
    await prefs.setString(AppProvider._kVoteReminderScopeKey, 'duels');
  }

  /// Ferme seulement la session sur cet appareil. Aucune suppression distante.
  /// Un profil sans Google/Apple doit avoir un code de récupération lisible
  /// avant de quitter sa session : sinon le retour pourrait être impossible.
  Future<String?> signOutCurrentAccount() async {
    if (_account.busy) return 'Une opération de compte est en cours.';
    final profile = _currentUser;
    if (profile == null) return null;
    final linked = hasConnectedAccount;
    if (!linked &&
        !RegExp(r'^[A-Za-z0-9]{8}$').hasMatch(profile.recoveryCode.trim())) {
      return 'Associe d’abord Google ou Apple, ou récupère ton code avant de te déconnecter.';
    }
    _account.busy = true;
    _notifyAccountChange();
    try {
      // Ne supprime aucun document Firebase, profil, point ou pronostic.
      // La préférence liée au compte a déjà été enregistrée lors du lien.
      if (linked) await _saveCloudPreferences();
      await MessagingService.instance.disconnectThisDevice();
      await _auth.signOut();
      await _clearPreviousAccountState();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppProvider._kCachedUserKey);
      await prefs.remove(_AccountState.pendingKey);
      _account.pending = null;
      _account.avatars.clear();
      _account.avatarRequests.clear();
      _currentUser = null;
      _adminMode = false;
      _users.clear();
      _teams.clear();
      _votes.clear();
      _exactPredictions.clear();
      _voteUpdatedAt.clear();
      _scopedVoteKeys.clear();
      _rebuildVoteCounts();
      _rankingDataLoaded = false;
      _rankingDataLoading = false;
      _teamDirectoryLoaded = false;
      _teamDirectoryLoading = false;
      _goldenBootDataLoaded = false;
      _goldenBootDataLoading = false;
      _identityScopeSignature = '';
      _liveVoteScopeSignature = '';
      _pendingTeamJoinRequestStreams.clear();
      // RootGate observe currentUser == null et affiche l'écran d'accueil.
      return null;
    } catch (e) {
      debugPrint('PRONO4 signOutCurrentAccount: $e');
      return 'Déconnexion interrompue. Réessaie.';
    } finally {
      _account.busy = false;
      _notifyAccountChange();
    }
  }

  Future<String> profileAvatar(String uid, String fallback) {
    final known = _account.avatars[uid];
    if (known != null) return Future.value(known);
    return _account.avatarRequests.putIfAbsent(uid, () async {
      try {
        final doc = await _db
            .collection('users')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 8));
        final raw = doc.data()?['avatar'];
        if (raw is! String || raw.isEmpty) return fallback;
        _account.avatars[uid] = raw;
        return raw;
      } catch (_) {
        _account.avatarRequests.remove(uid);
        return fallback;
      }
    });
  }

  Future<String?> _updateProfile({String? name, String? avatar}) async {
    final previous = _currentUser;
    if (previous == null) return null;
    final next = previous.copyWith(
      name: name == null || name.trim().isEmpty ? null : name.trim(),
      avatar: avatar,
    );
    _currentUser = next;
    _account.avatars[next.id] = next.avatar;
    _account.avatarRequests.remove(next.id);
    _users = [..._users.where((u) => u.id != next.id), next];
    _patchPrecomputedIdentity([next]);
    _account.pending = {
      if (_account.pending?['id'] == next.id) ..._account.pending!,
      'id': next.id,
      if (name != null) 'name': next.name,
      if (avatar != null) 'avatar': next.avatar,
    };
    await (await SharedPreferences.getInstance()).setString(
      _AccountState.pendingKey,
      jsonEncode(_account.pending),
    );
    await _cacheCurrentUser();
    _notifyAccountChange();
    return await _flushPendingProfile() ? null : 'profile-sync-pending';
  }

  Future<void> _saveCloudPreferences() async {
    if (!hasConnectedAccount || firebaseUid == null) return;
    try {
      await _db.collection('userSettings').doc(firebaseUid).set({
        'favoriteClubCodes': _favoriteClubCodes.toList(),
        'enabledCompetitionIds': _enabledCompetitionIds.toList(),
        'knownCompetitionIds': kCompetitions.map((c) => c.id).toList(),
        'blockedUserIds': _blockedUserIds.toList(),
        'voteRemindersEnabled': _voteRemindersEnabled,
        'voteReminderScope': _voteReminderScope,
        'halftimeAlertsEnabled': _halftimeAlertsEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<void> _restoreCloudPreferences(Map<String, dynamic>? settings) async {
    if (!hasConnectedAccount || settings == null) return;
    final favorites = settings['favoriteClubCodes'];
    final competitions = settings['enabledCompetitionIds'];
    if (favorites is List) {
      _favoriteClubCodes = favorites.map((e) => e.toString()).toSet();
    }
    if (competitions is List) {
      final known = settings['knownCompetitionIds'];
      final enabled = restoreCompetitionSelection(
          competitions.map((e) => e.toString()),
          knownCatalog: known is List ? known.map((e) => e.toString()) : null);
      if (enabled.isNotEmpty) _enabledCompetitionIds = enabled;
    }
    if (settings.containsKey('voteRemindersEnabled')) {
      _voteRemindersEnabled = settings['voteRemindersEnabled'] == true;
    }
    if (settings.containsKey('halftimeAlertsEnabled')) {
      _halftimeAlertsEnabled = settings['halftimeAlertsEnabled'] == true;
    }
    if (settings.containsKey('voteReminderScope')) {
      _voteReminderScope = const {
        'duels',
        'favorites',
        'all',
      }.contains(settings['voteReminderScope'])
          ? settings['voteReminderScope'] as String
          : 'duels';
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'prono4_favorite_clubs_v1',
      _favoriteClubCodes.toList(),
    );
    await prefs.setStringList(
      'prono4_enabled_competitions_v1',
      _enabledCompetitionIds.toList(),
    );
    await prefs.setStringList('prono4_known_competitions_v1',
        kCompetitions.map((c) => c.id).toList());
    await prefs.setBool(AppProvider._kVoteRemindersKey, _voteRemindersEnabled);
    await prefs.setBool(
        AppProvider._kHalftimeAlertsKey, _halftimeAlertsEnabled);
    await prefs.setString(
        AppProvider._kVoteReminderScopeKey, _voteReminderScope);
  }
}
