import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //CREATE player
  Future<void> addPlayer(String teamId, Map<String, dynamic> playerData) async {
    final playersRef = _firestore.collection('team_rosters').doc(teamId).collection('players');
    await playersRef.add(playerData);
  }

  // READ players
  Stream<QuerySnapshot> getPlayers(String teamId) {
    return _firestore
        .collection('team_rosters')
        .doc(teamId)
        .collection('players')
        .snapshots();
  }

  //UPDATE player
  Future<void> updatePlayer(String teamId, String playerId, Map<String, dynamic> updatedData) async {
    final playerRef = _firestore
        .collection('team_rosters')
        .doc(teamId)
        .collection('players')
        .doc(playerId);
    await playerRef.update(updatedData);
  }

  //DELETE player
  Future<void> deletePlayer(String teamId, String playerId) async {
    final playerRef = _firestore
        .collection('team_rosters')
        .doc(teamId)
        .collection('players')
        .doc(playerId);
    await playerRef.delete();
  }
}
