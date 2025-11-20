import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ----------------------------
  // Base URLs
  // ----------------------------
  final String sportsDbBaseUrl =
      "https://www.thesportsdb.com/api/v1/json/657478";

  final String fetchNBAGamesUrl =
      "https://us-central1-courtvision-c400e.cloudfunctions.net/fetchNBAGames";

  final String getPlayerStatsUrl =
      "https://us-central1-courtvision-c400e.cloudfunctions.net/getPlayerStats";

  static const bool ENABLE_SPORTSRADAR = false;

  // ----------------------------
  // Fetch Today’s Games
  // ----------------------------
  Future<List<dynamic>> fetchTodayGames() async {
    if (!ENABLE_SPORTSRADAR) {
      return [];
    }

    final now = DateTime.now().toUtc();
    final date = DateFormat('yyyy-MM-dd').format(now);
    final url = Uri.parse("$fetchNBAGamesUrl?date=$date");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['disabled'] == true) {
          return [];
        }
        return data['games'] ?? [];
      } else {
        throw Exception("Cloud Function returned ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error loading games: $e");
    }
  }

  // ----------------------------
  // Refresh Games
  // ----------------------------
  Future<void> refreshNBAGames() async {
    if (!ENABLE_SPORTSRADAR) return;

    try {
      final response = await http.get(Uri.parse(fetchNBAGamesUrl));
      if (response.statusCode != 200) {
        throw Exception("Failed to refresh games: ${response.statusCode}");
      }
    } catch (e) {
      rethrow;
    }
  }

  // ----------------------------
  // Search NBA Players using SportsDB + Filtering
  // ----------------------------
  Future<List<dynamic>> searchNBAPlayers(String name) async {
    final uri = Uri.parse("$sportsDbBaseUrl/searchplayers.php?p=$name");

    try {
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception("Search failed: ${response.statusCode}");
      }

      final data = json.decode(response.body);
      final List players = data['player'] ?? [];

      final filtered = players.where((p) {
        final pos = (p['strPosition'] ?? "").toLowerCase();
        final team = (p['strTeam'] ?? "").toLowerCase();
        final desc = (p['strDescriptionEN'] ?? "").toLowerCase();
        final sport = (p['strSport'] ?? "").toLowerCase();
        final league = (p['strLeague'] ?? "").toLowerCase();

        final basketballPositions = [
          "pg", "sg", "sf", "pf", "c",
          "point guard",
          "shooting guard",
          "small forward",
          "power forward",
          "center",
        ];

        final isPositionMatch =
            basketballPositions.any((x) => pos.contains(x));

        final isRetired =
            team.contains("_retired basketball");

        final bannedRoles = [
          "coach",
          "assistant",
          "manager",
          "gm",
          "trainer",
          "president",
          "owner",
        ];

        final isBadRole = bannedRoles.any((x) => pos.contains(x));

        final bannedSports = [
          "soccer","football","baseball",
          "rugby","cricket","hockey","mma", "boxing",
          "tennis","golf","swimming", "cycling", "athletics",
          "wrestling","volleyball","badminton", "handball", "fencing",
          "table tennis","equestrian", "sailing", "rowing",
          "skiing","skating","curling", "luge", "bobsleigh", "biathlon",
          "motorsport","nascar","formula 1", "indycar", "moto gp",
          "esports","dota","league of legends", "overwatch", "csgo", "valorant",
          "chess", "poker", "snooker", "bowling", "archery", "squash", "taekwondo",
          "judo", "karate", "surfing", "climbing", "triathlon", "pentathlon", "wushu", 
          "sambo", "sepaktakraw", "kabaddi", "billiards", "paddle", "padel", "softball",
        ];

        final mentionsOtherSport =
            bannedSports.any((x) => sport.contains(x) || desc.contains(x));

        final bannedLeagues = [
          "euro","acb","lba","cba","pba",
          "bsleague","liga endesa", "liga acb","serie a basket",
          "chinese basketball association","philippine basketball association",
          "euroleague","eurocup","basketball champions league", "fiba europe cup",
          "vtb united league","adriatic league","liga a",
          "greek basket league","turkish basketball super league", "italian legabasket serie a",
          "israeli basketball premier league","ligat ha'al", "liga leumit",
          "monaco basketball league","russian basketball super league", "liga nacional de basquet",
        ];

        final isBadLeague =
            bannedLeagues.any((x) => league.contains(x));

        final badTeams = [
          "madrid","barcelona","anadolu","olympiacos",
          "panathinaikos","milano","maccabi","monaco",
          "cska", "zenit","fenerbahce","valencia",
          "bayern","zalgiris","asvel","baskonia", "partizan",
          "olimpia","burgos","granada","manresa", "bilbao",
          "pamesa","estudiantes","murcia","badalona", "burgos",
          "virtus","fortitudo","trento","brescia", "venezia",
          "olimpija","cibona","cedevita","zadar", "spartak",
          "lokomotiv","krasnye krylia","nizhny novgorod", "avtodor", "khimki",
        ];

        final isBadTeam =
            badTeams.any((x) => team.contains(x));

        return (isPositionMatch || isRetired) &&
            !mentionsOtherSport &&
            !isBadRole &&
            !isBadTeam &&
            !isBadLeague;
      }).toList();

      return filtered;
    } catch (e) {
      rethrow;
    }
  }

  // ----------------------------
  // Get Stats Using Cloud Function
  // ----------------------------
  Future<Map<String, dynamic>?> getPlayerStats({
    required String playerId,
    required String nbaId,
  }) async {
    if (nbaId.isEmpty) return null;

    final uri = Uri.parse("$getPlayerStatsUrl?id=$playerId&nbaId=$nbaId");

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // ----------------------------
  // Load all players (SportsDB → Firestore)
  // ----------------------------
  Future<List<dynamic>> fetchAllNBAPlayers({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final snap = await _firestore.collection('nba_players').get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((doc) => doc.data()).toList();
      }
    }

    final teamsUrl =
        Uri.parse("$sportsDbBaseUrl/search_all_teams.php?l=NBA");

    final teamsRes = await http.get(teamsUrl);
    if (teamsRes.statusCode != 200) {
      throw Exception("Failed to load NBA teams");
    }

    final teams = json.decode(teamsRes.body)['teams'] ?? [];
    final List allPlayers = [];

    for (var team in teams) {
      final teamId = team['idTeam'];

      await Future.delayed(const Duration(milliseconds: 700));

      final playersRes = await http.get(
        Uri.parse("$sportsDbBaseUrl/lookup_all_players.php?id=$teamId"),
      );

      if (playersRes.statusCode == 200) {
        final players = json.decode(playersRes.body)['player'] ?? [];

        for (var p in players) {
          if ((p['strSport'] ?? '').toLowerCase() == 'basketball') {
            await _firestore
                .collection('nba_players')
                .doc(p['idPlayer'])
                .set(p, SetOptions(merge: true));

            allPlayers.add(p);
          }
        }
      }
    }

    return allPlayers;
  }

  // ----------------------------
  // Fetch Roster
  // ----------------------------
  Future<List<dynamic>> fetchTeamRoster(String teamId) async {
    final url =
        Uri.parse("$sportsDbBaseUrl/lookup_all_players.php?id=$teamId");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final players = data['player'] ?? [];

        return players
            .where((p) =>
                p['strSport']?.toLowerCase() == 'basketball')
            .toList();
      } else {
        throw Exception("Failed roster request");
      }
    } catch (e) {
      throw Exception("Failed to load roster: $e");
    }
  }

  // ----------------------------
  // Player Details (Local Firestore first, SportsDB fallback)
  // ----------------------------
  Future<Map<String, dynamic>> fetchPlayerDetails(String playerId) async {
    try {
      final local = await _firestore
          .collection("nba_players")
          .doc(playerId)
          .get();

      if (local.exists) {
        return local.data()!;
      }
    } catch (_) {}

    final url = Uri.parse(
        "$sportsDbBaseUrl/lookupplayer.php?id=$playerId");

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final players = data['players'];

        if (players != null && players.isNotEmpty) {
          return players.first;
        }
      }

      throw Exception("Player not found");
    } catch (e) {
      throw Exception("Error loading player details: $e");
    }
  }

  Future<String?> fetchOfficialPlayerPhoto(String playerName) async {
  final endpoint =
      "https://us-central1-courtvision-c400e.cloudfunctions.net/playerPhoto?name=${Uri.encodeComponent(playerName)}";
  try {
    final resp = await http.get(Uri.parse(endpoint));
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return data["image"] as String?;
    }
  } catch (e) {
    print("Error fetching official photo: $e");
  }
  return null;
}
}
