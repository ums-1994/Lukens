import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CollaborationService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // TEAMS
  static Future<List<Map<String, dynamic>>> listTeams() async {
    final query = await _db
        .collection('teams')
        .orderBy('createdAt', descending: true)
        .get();
    return query.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  static Stream<List<Map<String, dynamic>>> streamTeams() {
    return _db
        .collection('teams')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  static Future<String> createTeam({required String name, List<String> members = const []}) async {
    final String? ownerUid = _auth.currentUser?.uid;
    final doc = await _db.collection('teams').add({
      'name': name,
      'members': members,
      'ownerUid': ownerUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  // COMMENTS
  static Future<List<Map<String, dynamic>>> listComments({String? teamId}) async {
    Query<Map<String, dynamic>> q = _db
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(50);
    if (teamId != null) {
      q = q.where('teamId', isEqualTo: teamId);
    }
    final snap = await q.get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  static Future<void> addComment({required String text, String? teamId}) async {
    final user = _auth.currentUser;
    await _db.collection('comments').add({
      'text': text,
      'teamId': teamId,
      'author': user?.displayName ?? user?.email ?? 'User',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<List<Map<String, dynamic>>> streamComments({String? teamId}) {
    Query<Map<String, dynamic>> q = _db
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(50);
    if (teamId != null) {
      q = q.where('teamId', isEqualTo: teamId);
    }
    return q.snapshots().map(
          (snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
        );
  }

  // WORKSPACES
  static Future<List<Map<String, dynamic>>> listWorkspaces() async {
    final snap = await _db
        .collection('workspaces')
        .orderBy('updatedAt', descending: true)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  static Future<String> createWorkspace({required String name}) async {
    final doc = await _db.collection('workspaces').add({
      'name': name,
      'files': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  static Stream<List<Map<String, dynamic>>> streamWorkspaces() {
    return _db
        .collection('workspaces')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // NOTIFICATIONS
  static Future<List<Map<String, dynamic>>> listNotifications() async {
    final snap = await _db
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  static Future<void> markNotificationRead(String id, {bool read = true}) async {
    await _db.collection('notifications').doc(id).update({'read': read});
  }

  static Future<void> clearAllNotifications() async {
    final batch = _db.batch();
    final snap = await _db.collection('notifications').get();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  static Stream<List<Map<String, dynamic>>> streamNotifications() {
    return _db
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }
}


