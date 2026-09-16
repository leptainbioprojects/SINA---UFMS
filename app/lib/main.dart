import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';

void main() => runApp(const AssistiveMapApp());

class AssistiveMapApp extends StatelessWidget {
  const AssistiveMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF17324D);
    return MaterialApp(
      title: 'Mapa Assistivo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF087F8C)),
        scaffoldBackgroundColor: const Color(0xFFF4F7F5),
        fontFamily: 'Arial',
        appBarTheme: const AppBarTheme(
          backgroundColor: ink,
          foregroundColor: Colors.white,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const MapHomePage(),
    );
  }
}

class MapHomePage extends StatefulWidget {
  const MapHomePage({super.key});

  @override
  State<MapHomePage> createState() => _MapHomePageState();
}

class _MapHomePageState extends State<MapHomePage> {
  static const String _campusMapAsset = 'assets/mapa_cidade_universitaria.pdf';

  String get _apiBaseUrl => defaultTargetPlatform == TargetPlatform.android
      ? 'http://10.0.2.2:8080'
      : 'http://127.0.0.1:8080';

  int _selectedFloor = 1;
  String _selectedAccessibility = 'Todos';
  String _destination = 'Recepção';
  String _search = '';
  String _routeSummary = 'Rota recomendada\n4 min  -  180 m  -  sem escadas';
  bool _loadingRoute = false;
  final _searchController = TextEditingController();
  final destinations = const <String, String>{
    'Recepção': 'reception',
    'Banheiro acessível': 'accessible_bathroom',
    'Auditório': 'auditorium',
    'Elevador': 'elevator',
  };

  List<String> get _filteredDestinations => destinations.keys
      .where((name) => name.toLowerCase().contains(_search.toLowerCase()))
      .toList();

  Future<void> _requestRoute() async {
    setState(() => _loadingRoute = true);
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/routes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'destination_id': destinations[_destination],
          'accessibility': switch (_selectedAccessibility) {
            'Cadeira de rodas' => 'wheelchair',
            'Baixa visão' => 'low_vision',
            'Mobilidade reduzida' => 'reduced_mobility',
            _ => 'all',
          },
        }),
      );
      if (response.statusCode != 200) throw Exception('Rota indisponível');
      final route = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        _routeSummary =
            'Rota recomendada\n${route['duration_minutes']} min  -  ${route['distance_meters']} m  -  ${route['floor_changes'] == 0 ? 'sem escadas' : '${route['floor_changes']} troca de andar'}';
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Inicie a API em $_apiBaseUrl')));
      }
    } finally {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  Future<void> _openUfmsMap() async {
    try {
      final byteData = await rootBundle.load(_campusMapAsset);
      final tempFile = File(
        '${Directory.systemTemp.path}/mapa_cidade_universitaria.pdf',
      );
      await tempFile.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );

      final result = await OpenFile.open(tempFile.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Não foi possível abrir o mapa da Cidade Universitária',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Adicione o PDF em assets/mapa_cidade_universitaria.pdf',
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mapa Assistivo',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Configurações de acessibilidade',
            onPressed: () {},
            icon: const Icon(Icons.accessibility_new),
          ),
          IconButton(
            tooltip: 'Abrir mapa da Cidade Universitária',
            onPressed: _openUfmsMap,
            icon: const Icon(Icons.map_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: isWide ? _wideLayout() : _compactLayout(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _wideLayout() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(flex: 3, child: _mapPanel()),
      const SizedBox(width: 20),
      Expanded(flex: 2, child: _routePanel()),
    ],
  );

  Widget _compactLayout() => Column(
    children: [_mapPanel(), const SizedBox(height: 20), _routePanel()],
  );

  Widget _mapPanel() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Centro Cultural Aurora',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Explore o prédio e encontre o melhor caminho para você.',
            style: TextStyle(color: Color(0xFF5E6B75)),
          ),
          const SizedBox(height: 20),
          _floorSelector(),
          const SizedBox(height: 16),
          SizedBox(height: 420, child: _FloorMap(floor: _selectedFloor)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: const [
              _Legend(color: Color(0xFF087F8C), label: 'Rota acessível'),
              _Legend(color: Color(0xFFE9B949), label: 'Destino'),
              _Legend(color: Color(0xFFB8C4C8), label: 'Área não mapeada'),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _floorSelector() => SegmentedButton<int>(
    segments: const [
      ButtonSegment(
        value: 0,
        label: Text('Térreo'),
        icon: Icon(Icons.layers_outlined),
      ),
      ButtonSegment(
        value: 1,
        label: Text('1º andar'),
        icon: Icon(Icons.layers),
      ),
      ButtonSegment(
        value: 2,
        label: Text('2º andar'),
        icon: Icon(Icons.layers_outlined),
      ),
    ],
    selected: {_selectedFloor},
    onSelectionChanged: (selection) =>
        setState(() => _selectedFloor = selection.first),
  );

  Widget _routePanel() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Planejar trajeto',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value),
            decoration: InputDecoration(
              labelText: 'Buscar local',
              hintText: 'Ex.: banheiro, auditório...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _filteredDestinations.contains(_destination)
                ? _destination
                : null,
            decoration: const InputDecoration(
              labelText: 'Quero chegar em',
              prefixIcon: Icon(Icons.place_outlined),
            ),
            items: _filteredDestinations
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) =>
                setState(() => _destination = value ?? _destination),
          ),
          const SizedBox(height: 20),
          const Text(
            'Prioridade de acessibilidade',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children:
                [
                      'Todos',
                      'Cadeira de rodas',
                      'Baixa visão',
                      'Mobilidade reduzida',
                    ]
                    .map(
                      (label) => ChoiceChip(
                        label: Text(label),
                        selected: _selectedAccessibility == label,
                        onSelected: (_) =>
                            setState(() => _selectedAccessibility = label),
                      ),
                    )
                    .toList(),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE4F2F0),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.route, color: Color(0xFF087F8C)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _routeSummary,
                    style: const TextStyle(
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loadingRoute ? null : _requestRoute,
              icon: _loadingRoute
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.navigation),
              label: Text(_loadingRoute ? 'Calculando...' : 'Calcular rota'),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Recursos do prédio',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const _Resource(
            icon: Icons.elevator,
            label: 'Elevadores',
            detail: '2 disponíveis',
          ),
          const _Resource(
            icon: Icons.wc,
            label: 'Banheiros acessíveis',
            detail: 'Em todos os andares',
          ),
          const _Resource(
            icon: Icons.sign_language,
            label: 'Atendimento em Libras',
            detail: 'Recepção, térreo',
          ),
        ],
      ),
    ),
  );
}

class _FloorMap extends StatelessWidget {
  const _FloorMap({required this.floor});
  final int floor;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: CustomPaint(
      painter: _MapPainter(floor: floor),
      child: const SizedBox.expand(),
    ),
  );
}

class _MapPainter extends CustomPainter {
  const _MapPainter({required this.floor});
  final int floor;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFE8EEEB),
    );
    final room = Paint()..color = Colors.white;
    final wall = Paint()
      ..color = const Color(0xFF8FA1A4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final route = Paint()
      ..color = const Color(0xFF087F8C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final plan = Rect.fromLTWH(
      size.width * .08,
      size.height * .1,
      size.width * .84,
      size.height * .78,
    );
    canvas.drawRect(plan, room);
    for (final x in [.34, .64]) {
      canvas.drawLine(
        Offset(size.width * x, plan.top),
        Offset(size.width * x, plan.bottom),
        wall,
      );
    }
    canvas.drawLine(
      Offset(plan.left, size.height * .53),
      Offset(plan.right, size.height * .53),
      wall,
    );
    canvas.drawLine(
      Offset(size.width * .34, size.height * .25),
      Offset(size.width * .64, size.height * .25),
      wall,
    );
    final path = Path()
      ..moveTo(size.width * .16, size.height * .72)
      ..lineTo(size.width * .28, size.height * .72)
      ..lineTo(size.width * .28, size.height * .4)
      ..lineTo(size.width * .57, size.height * .4)
      ..lineTo(size.width * .57, size.height * .2)
      ..lineTo(size.width * .78, size.height * .2);
    canvas.drawPath(path, route);
    canvas.drawCircle(
      Offset(size.width * .78, size.height * .2),
      13,
      Paint()..color = const Color(0xFFE9B949),
    );
    canvas.drawCircle(
      Offset(size.width * .16, size.height * .72),
      9,
      Paint()..color = const Color(0xFF17324D),
    );
    _label(canvas, 'Recepção', Offset(size.width * .1, size.height * .78));
    _label(
      canvas,
      floor == 0 ? 'Entrada principal' : 'Sala multiuso',
      Offset(size.width * .68, size.height * .14),
    );
    _label(canvas, 'Elevador', Offset(size.width * .4, size.height * .62));
  }

  void _label(Canvas canvas, String text, Offset offset) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF17324D),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    painter.layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.floor != floor;
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF5E6B75)),
      ),
    ],
  );
}

class _Resource extends StatelessWidget {
  const _Resource({
    required this.icon,
    required this.label,
    required this.detail,
  });
  final IconData icon;
  final String label;
  final String detail;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: const Color(0xFF087F8C)),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(detail),
  );
}
