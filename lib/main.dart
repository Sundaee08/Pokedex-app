import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());



const testMode = '';



// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class Pokemon {
  final int id;
  final String name;
  final int height;
  final int weight;
  final String? imageUrl;
  final List<String> types;
  final List<String> abilities;
  final List<String> moves;
  final Map<String, int> stats;

  const Pokemon({
    required this.id,
    required this.name,
    required this.height,
    required this.weight,
    required this.imageUrl,
    required this.types,
    required this.abilities,
    required this.moves,
    required this.stats,
  });

  // Turns the decoded JSON map into a Pokemon object.
  // Throws FormatException if required fields are missing or the wrong type.
  factory Pokemon.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final height = json['height'];
    final weight = json['weight'];

    if (id is! int || name is! String || height is! int || weight is! int) {
      throw const FormatException('Missing or invalid Pokemon fields.');
    }

    // Sprite: prefer the HOME artwork, fall back to the normal sprite.
    String? imageUrl;
    final sprites = json['sprites'];
    if (sprites is Map) {
      final other = sprites['other'];
      final home = other is Map ? other['home'] : null;
      final homeImage = home is Map ? home['front_default'] : null;
      final frontImage = sprites['front_default'];
      if (homeImage is String) {
        imageUrl = homeImage;
      } else if (frontImage is String) {
        imageUrl = frontImage;
      }
    }

    // Stats are stored by name, so the order of the list doesn't matter.
    final stats = <String, int>{};
    final rawStats = json['stats'];
    if (rawStats is List) {
      for (final s in rawStats) {
        if (s is! Map) continue;
        final stat = s['stat'];
        final statName = stat is Map ? stat['name'] : null;
        final value = s['base_stat'];
        if (statName is String && value is int) {
          stats[statName] = value;
        }
      }
    }

    return Pokemon(
      id: id,
      name: name,
      height: height,
      weight: weight,
      imageUrl: imageUrl,
      types: _names(json['types'], 'type'),
      abilities: _names(json['abilities'], 'ability'),
      moves: _names(json['moves'], 'move'),
      stats: stats,
    );
  }

  // Helper: pulls out ["name"] from lists shaped like
  // [{ "type": { "name": "electric" } }, ...]
  static List<String> _names(dynamic list, String key) {
    if (list is! List) return [];
    final result = <String>[];
    for (final item in list) {
      if (item is! Map) continue;
      final inner = item[key];
      final name = inner is Map ? inner['name'] : null;
      if (name is String) result.add(name);
    }
    return result;
  }
}
// Service naay error handler when the API is right akoang pagsabot rasad 

class ApiException implements Exception {
  final int statusCode;
  const ApiException(this.statusCode);
}

Future<Pokemon> fetchPokemon(String name) async {
  final url = Uri.parse(
    'https://pokeapi.co/api/v2/pokemon/${Uri.encodeComponent(name)}',
  );

  final response = await http.get(url).timeout(const Duration(seconds: 10));

  if (response.statusCode != 200) {
    throw ApiException(response.statusCode);
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Unexpected response format.');
  }

  return Pokemon.fromJson(decoded);
}
// UI ni
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pokedex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Colors.black,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
        dividerColor: Colors.black,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.black26,
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.zero),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: Colors.black, width: 2),
          ),
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController controller = TextEditingController();
  Pokemon? pokemon;
  String? error;
  bool loading = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final name = controller.text.trim().toLowerCase();

    if (name.isEmpty || loading) return;

    setState(() {
      loading = true;
      error = null;
      pokemon = null;
    });

    Pokemon? result;
    String? message;

    try {
      result = await fetchPokemon(name);
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        message = 'Pokemon "$name" was not found. Check the spelling.';
      } else {
        message = 'The server returned an error (${e.statusCode}). Try again later.';
      }
    } on TimeoutException {
      message = 'The request took too long. Try again.';
    } catch (_) {
      message = 'No connection. Check your internet and try again.';
    }

    if (!mounted) return;

    setState(() {
      pokemon = result;
      error = message;
      loading = false;
    });
  }

  Widget sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget tag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(border: Border.all(color: Colors.black)),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget statRow(Pokemon p, String label, String statName) {
    final value = p.stats[statName] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text(label)),
          SizedBox(width: 36, child: Text('$value')),
          Expanded(
            child: LinearProgressIndicator(
              value: (value / 255).clamp(0.0, 1.0),
              minHeight: 6,
              color: Colors.black,
              backgroundColor: Colors.black12,
            ),
          ),
        ],
      ),
    );
  }

  Widget details(Pokemon p) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                      child: p.imageUrl == null
                          ? const Center(child: Text('No image'))
                          : Image.network(
                              p.imageUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) =>
                                  const Center(child: Text('No image')),
                            ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('#${p.id}', style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 16),
                          Text('Height: ${p.height}'),
                          Text('Weight: ${p.weight}'),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 40),
                sectionTitle('Types'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: p.types.map(tag).toList(),
                ),
                sectionTitle('Stats'),
                statRow(p, 'HP', 'hp'),
                statRow(p, 'Attack', 'attack'),
                statRow(p, 'Defense', 'defense'),
                statRow(p, 'Speed', 'speed'),
                statRow(p, 'Special Attack', 'special-attack'),
                statRow(p, 'Special Defense', 'special-defense'),
                sectionTitle('Abilities'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: p.abilities.map(tag).toList(),
                ),
                sectionTitle('Moves'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: p.moves.map(tag).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget body() {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.black));
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (pokemon == null) {
      return const Center(
        child: Text('Search for a Pokemon', style: TextStyle(color: Colors.black54)),
      );
    }
    return details(pokemon!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'POKEDEX',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 3),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 250,
                    height: 40,
                    child: TextField(
                      controller: controller,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => search(),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        hintText: 'Pokemon name or ID',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: loading ? null : search,
                      child: const Text('Search'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body()),
          ],
        ),
      ),
    );
  }
}




