"use strict";

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;
const { syncClubMatches, currentSeasonStartYear } = require("./club_matches_sync");
const FOOTBALL_DATA_TOKEN = defineSecret("FOOTBALL_DATA_TOKEN");

function normalizeCode(value) {
  return String(value ?? "")
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]/g, "");
}

function voteMatchId(doc) {
  const data = doc.data() || {};
  if (data.matchId) return String(data.matchId);
  const marker = "__";
  const index = doc.id.indexOf(marker);
  return index >= 0 ? doc.id.slice(index + marker.length) : "";
}

/**
 * Récupère un ancien profil depuis l'application.
 *
 * Sécurité :
 * - l'utilisateur doit être authentifié ;
 * - le nouveau UID provient uniquement de request.auth.uid ;
 * - l'application ne peut donc jamais choisir le compte de destination ;
 * - Firebase Admin réalise le transfert côté serveur.
 */
exports.recoverProfile = onCall(
  {
    region: "europe-west1",
    timeoutSeconds: 120,
    memory: "512MiB",
    enforceAppCheck: false,
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Connexion requise.");
    }

    const newUid = request.auth.uid;
    const code = normalizeCode(request.data?.code);

    if (code.length !== 8) {
      throw new HttpsError(
        "invalid-argument",
        "Le code doit contenir exactement 8 caractères."
      );
    }

    const candidatesSnap = await db
      .collection("users")
      .where("recoveryCode", "==", code)
      .limit(10)
      .get();

    const currentRef = db.collection("users").doc(newUid);
    const currentSnap = await currentRef.get();

    // Si le code appartient déjà au profil connecté, on recharge simplement.
    const currentData = currentSnap.exists ? currentSnap.data() || {} : {};
    if (currentData.recoveryCode === code) {
      return {
        id: newUid,
        name: currentData.name || "Joueur",
        avatar: currentData.avatar || "⚽",
        teamId: currentData.teamId || null,
        isAdmin: currentData.isAdmin === true,
        alreadyRecovered: true,
      };
    }

    const candidates = candidatesSnap.docs.filter((doc) => {
      const data = doc.data() || {};
      return (
        doc.id !== newUid &&
        data.isArchived !== true &&
        !data.migratedTo
      );
    });

    if (candidates.length === 0) {
      throw new HttpsError("not-found", "Code introuvable.");
    }

    if (candidates.length > 1) {
      throw new HttpsError(
        "failed-precondition",
        "Ce code est associé à plusieurs anciens profils."
      );
    }

    const oldDoc = candidates[0];
    const oldUid = oldDoc.id;
    const oldData = oldDoc.data() || {};
    const oldRef = oldDoc.ref;

    if (oldData.migratedTo && oldData.migratedTo !== newUid) {
      throw new HttpsError(
        "failed-precondition",
        "Cet ancien profil a déjà été récupéré sur un autre appareil."
      );
    }

    const [oldVotesSnap, newVotesSnap, teamsSnap] = await Promise.all([
      db.collection("votes").where("userId", "==", oldUid).get(),
      db.collection("votes").where("userId", "==", newUid).get(),
      db.collection("teams").where("memberIds", "array-contains", oldUid).get(),
    ]);

    // Sauvegarde + transfert + suppression des votes dans un seul lot.
    // Coupe du monde : le total reste sous la limite Firestore de 500 écritures.
    const estimatedWrites =
      oldVotesSnap.size * 3 +
      newVotesSnap.size +
      teamsSnap.size * 2 +
      7;
    if (estimatedWrites > 490) {
      throw new HttpsError(
        "resource-exhausted",
        "Trop de données à transférer automatiquement."
      );
    }

    const newData = currentData;
    const existingNewMatches = new Set(
      newVotesSnap.docs.map(voteMatchId).filter(Boolean)
    );

    const teamDocs = new Map(teamsSnap.docs.map((doc) => [doc.id, doc]));
    if (oldData.teamId && !teamDocs.has(String(oldData.teamId))) {
      const directTeam = await db
        .collection("teams")
        .doc(String(oldData.teamId))
        .get();
      if (directTeam.exists) teamDocs.set(directTeam.id, directTeam);
    }

    const migrationId = `${oldUid}__${newUid}__${Date.now()}`;
    const backupRef = db.collection("profileMigrations").doc(migrationId);
    const batch = db.batch();

    batch.set(backupRef, {
      oldUid,
      newUid,
      recoveryCode: code,
      createdAt: FieldValue.serverTimestamp(),
      status: "completed",
    });

    // Sauvegarde séparée pour ne jamais dépasser la limite de 1 Mo d'un document.
    batch.set(backupRef.collection("profiles").doc("old"), oldData);
    batch.set(backupRef.collection("profiles").doc("new-before"), newData);

    for (const oldVoteDoc of oldVotesSnap.docs) {
      batch.set(
        backupRef.collection("oldVotes").doc(oldVoteDoc.id),
        oldVoteDoc.data()
      );
    }
    for (const newVoteDoc of newVotesSnap.docs) {
      batch.set(
        backupRef.collection("newVotesBefore").doc(newVoteDoc.id),
        newVoteDoc.data()
      );
    }
    for (const teamDoc of teamDocs.values()) {
      batch.set(
        backupRef.collection("teamsBefore").doc(teamDoc.id),
        teamDoc.data()
      );
    }

    // Les données historiques viennent de l'ancien profil. Les données liées
    // au nouveau téléphone (token FCM, nouveau code, dates) sont préservées.
    const mergedUser = {
      ...oldData,
      ...newData,
      id: newUid,
      name: oldData.name || newData.name || "Joueur",
      avatar: oldData.avatar || newData.avatar || "⚽",
      teamId: oldData.teamId || newData.teamId || null,
      isAdmin: oldData.isAdmin === true || newData.isAdmin === true,
      recoveryCode: newData.recoveryCode || code,
      recoveryCodeCreatedAt:
        newData.recoveryCodeCreatedAt ||
        oldData.recoveryCodeCreatedAt ||
        FieldValue.serverTimestamp(),
      createdAt: newData.createdAt || oldData.createdAt || FieldValue.serverTimestamp(),
      migratedFrom: oldUid,
      migratedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      isArchived: false,
      migratedTo: FieldValue.delete(),
    };

    batch.set(currentRef, mergedUser, { merge: true });

    let transferredVotes = 0;
    let preservedNewVotes = 0;

    for (const oldVoteDoc of oldVotesSnap.docs) {
      const matchId = voteMatchId(oldVoteDoc);
      if (!matchId) {
        throw new HttpsError(
          "data-loss",
          `Le vote ${oldVoteDoc.id} ne contient aucun matchId.`
        );
      }

      if (!existingNewMatches.has(matchId)) {
        const newVoteRef = db
          .collection("votes")
          .doc(`${newUid}__${matchId}`);

        batch.set(newVoteRef, {
          ...oldVoteDoc.data(),
          userId: newUid,
          matchId,
          migratedFrom: oldVoteDoc.id,
          updatedAt: FieldValue.serverTimestamp(),
        });
        transferredVotes += 1;
      } else {
        preservedNewVotes += 1;
      }

      // Évite le double comptage dans le classement.
      batch.delete(oldVoteDoc.ref);
    }

    for (const teamDoc of teamDocs.values()) {
      const teamData = teamDoc.data() || {};
      const members = Array.isArray(teamData.memberIds)
        ? teamData.memberIds.map(String)
        : [];
      const memberIds = [
        ...new Set(members.filter((uid) => uid !== oldUid).concat(newUid)),
      ];

      const update = {
        memberIds,
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (teamData.createdBy === oldUid) update.createdBy = newUid;
      batch.set(teamDoc.ref, update, { merge: true });
    }

    // L'ancien document est conservé en sauvegarde, mais il ne doit plus
    // apparaître dans les classements ni conserver le même code.
    batch.set(
      oldRef,
      {
        migratedTo: newUid,
        migratedAt: FieldValue.serverTimestamp(),
        teamId: null,
        isArchived: true,
        recoveryCode: FieldValue.delete(),
        recoveryCodeCreatedAt: FieldValue.delete(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    await batch.commit();

    logger.info("Profile recovery completed", {
      oldUid,
      newUid,
      transferredVotes,
      preservedNewVotes,
      teamsUpdated: teamDocs.size,
      migrationId,
    });

    const finalSnap = await currentRef.get();
    const finalData = finalSnap.data() || mergedUser;

    return {
      id: newUid,
      name: finalData.name || "Joueur",
      avatar: finalData.avatar || "⚽",
      teamId: finalData.teamId || null,
      isAdmin: finalData.isAdmin === true,
      transferredVotes,
      preservedNewVotes,
      totalVotes: newVotesSnap.size + transferredVotes,
      teamsUpdated: teamDocs.size,
      migrationId,
    };
  }
);

/**
 * Suppression complète d'un profil invité PRONO4.
 *
 * Apple considère les comptes invités créés automatiquement comme des comptes
 * utilisateur. Cette fonction efface donc le profil, ses pronostics, ses
 * messages, ses présences et son identité Firebase Auth. Les équipes restantes
 * continuent de fonctionner avec un nouveau capitaine si nécessaire.
 */
exports.deleteAccountData = onCall(
  {
    region: "europe-west1",
    timeoutSeconds: 120,
    memory: "512MiB",
    enforceAppCheck: false,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Connexion requise.");
    }

    const userRef = db.collection("users").doc(uid);
    const teamsSnap = await db
      .collection("teams")
      .where("memberIds", "array-contains", uid)
      .get();

    // Nettoie les équipes avant l'effacement du profil.
    for (const teamDoc of teamsSnap.docs) {
      const data = teamDoc.data() || {};
      const remaining = (Array.isArray(data.memberIds) ? data.memberIds : [])
        .map(String)
        .filter((memberUid) => memberUid !== uid);

      if (remaining.length === 0) {
        await Promise.all([
          db.recursiveDelete(teamDoc.ref),
          db.recursiveDelete(db.collection("teamChats").doc(teamDoc.id)),
        ]);
      } else {
        const update = {
          memberIds: remaining,
          updatedAt: FieldValue.serverTimestamp(),
        };
        if (String(data.createdBy || "") === uid) {
          update.createdBy = remaining[0];
        }
        await teamDoc.ref.set(update, { merge: true });
      }
    }

    const [teamChatRefs, matchRoomRefs, userRefs] = await Promise.all([
      db.collection("teamChats").listDocuments(),
      db.collection("matchRooms").listDocuments(),
      db.collection("users").listDocuments(),
    ]);

    const queries = [
      db.collection("votes").where("userId", "==", uid),
      db.collection("reputationVotes").where("voterId", "==", uid),
      db.collection("reputationVotes").where("targetUserId", "==", uid),
      db.collection("support").where("userId", "==", uid),
      db.collection("contentReports").where("reporterId", "==", uid),
      db.collection("contentReports").where("reportedUserId", "==", uid),
      ...teamChatRefs.map((ref) =>
        ref.collection("messages").where("userId", "==", uid)
      ),
      ...matchRoomRefs.map((ref) =>
        ref.collection("messages").where("userId", "==", uid)
      ),
    ];

    const snapshots = await Promise.all(queries.map((query) => query.get()));
    const writer = db.bulkWriter();
    const seen = new Set();
    for (const snapshot of snapshots) {
      for (const doc of snapshot.docs) {
        if (seen.has(doc.ref.path)) continue;
        seen.add(doc.ref.path);
        writer.delete(doc.ref);
      }
    }
    for (const ref of teamChatRefs) {
      writer.delete(ref.collection("presence").doc(uid));
    }
    for (const ref of matchRoomRefs) {
      writer.delete(ref.collection("presence").doc(uid));
    }
    for (const ref of userRefs) {
      writer.delete(db.collection("userBlocks").doc(ref.id).collection("blocked").doc(uid));
    }
    writer.delete(db.collection("goldenBootVotes").doc(uid));
    writer.delete(userRef);
    await writer.close();

    await db
      .recursiveDelete(db.collection("userBlocks").doc(uid))
      .catch(() => null);

    await admin.auth().deleteUser(uid).catch((error) => {
      if (error?.code !== "auth/user-not-found") throw error;
    });

    logger.info("PRONO4 account deleted", {
      uid,
      deletedDocuments: seen.size + 2,
      teamsUpdated: teamsSnap.size,
    });

    return { deleted: true };
  }
);


/**
 * Synchronisation manuelle des calendriers clubs depuis football-data.org.
 * Appelée par l'application uniquement pour un compte administrateur.
 */
exports.syncClubMatchesNow = onCall(
  {
    region: "europe-west1",
    timeoutSeconds: 300,
    memory: "1GiB",
    enforceAppCheck: false,
    secrets: [FOOTBALL_DATA_TOKEN],
  },
  async (request) => {
    if (!request.auth?.uid) {
      throw new HttpsError("unauthenticated", "Connexion requise.");
    }

    const adminSnap = await db.collection("users").doc(request.auth.uid).get();
    if (!adminSnap.exists || adminSnap.data()?.isAdmin !== true) {
      throw new HttpsError("permission-denied", "Accès administrateur requis.");
    }

    // Évite de rappeler l'API plusieurs fois si l'admin rouvre l'écran.
    const syncSnap = await db.collection("system").doc("clubMatchesSync").get();
    const lastSuccess = syncSnap.data()?.lastSuccessAt;
    if (lastSuccess instanceof admin.firestore.Timestamp) {
      const ageMs = Date.now() - lastSuccess.toMillis();
      if (ageMs >= 0 && ageMs < 15 * 60 * 1000) {
        return {
          skipped: true,
          reason: "recent-sync",
          syncedMatches: syncSnap.data()?.matchWrites || 0,
          season: syncSnap.data()?.season || currentSeasonStartYear(),
        };
      }
    }

    try {
      const summary = await syncClubMatches({
        db,
        token: FOOTBALL_DATA_TOKEN.value(),
        season: Number(request.data?.season) || currentSeasonStartYear(),
        source: `admin:${request.auth.uid}`,
      });
      return {
        ...summary,
        syncedMatches: summary.matchWrites,
      };
    } catch (error) {
      logger.error("syncClubMatchesNow failed", error);
      throw new HttpsError(
        "internal",
        String(error?.message || "Synchronisation impossible.")
      );
    }
  }
);

/**
 * Mise à jour automatique plusieurs fois par jour.
 */
exports.syncClubMatchesScheduled = onSchedule(
  {
    schedule: "every 6 hours",
    region: "europe-west1",
    timeZone: "Europe/Paris",
    timeoutSeconds: 300,
    memory: "1GiB",
    secrets: [FOOTBALL_DATA_TOKEN],
  },
  async () => {
    const summary = await syncClubMatches({
      db,
      token: FOOTBALL_DATA_TOKEN.value(),
      season: currentSeasonStartYear(),
      source: "scheduler",
    });
    logger.info("Synchronisation automatique terminée", summary);
  }
);
