import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/level.dart';
import '../theme/colors.dart';
import '../providers/game_state.dart';
import '../providers/audio_provider.dart';
import 'cyber_card.dart';

enum EditorTool { drone, box, target, obstacle, energyCell }

class SandboxEditorScreen extends ConsumerStatefulWidget {
  const SandboxEditorScreen({super.key});

  @override
  ConsumerState<SandboxEditorScreen> createState() => _SandboxEditorScreenState();
}

class _SandboxEditorScreenState extends ConsumerState<SandboxEditorScreen> {
  int _gridWidth = 6;
  int _gridHeight = 6;
  String _title = "CUSTOM SECTOR";
  String _description = "Locate reactor fuel core and return to docking pad.";
  String _hint = "Program takeoff, land to pickup, navigate high obstacles, and land on target.";
  int _initialBattery = 30;
  int _star3Target = 10;

  int _startX = 0;
  int _startY = 5;
  Direction _startDirection = Direction.north;

  int _boxX = 3;
  int _boxY = 3;

  int _targetX = 5;
  int _targetY = 0;

  // Key format: "x,y"
  final Map<String, int> _obstacleHeights = {};
  final Map<String, int> _energyCellCharges = {};

  EditorTool _selectedTool = EditorTool.drone;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _hintController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final editingLevel = ref.read(editingSandboxLevelProvider);
    if (editingLevel != null) {
      _gridWidth = editingLevel.gridWidth;
      _gridHeight = editingLevel.gridHeight;
      _title = editingLevel.title;
      _description = editingLevel.description;
      _hint = editingLevel.hint ?? "";
      _initialBattery = editingLevel.initialBattery;
      _star3Target = editingLevel.star3Target;
      _startX = editingLevel.startX;
      _startY = editingLevel.startY;
      _startDirection = editingLevel.startDirection;
      _boxX = editingLevel.boxX;
      _boxY = editingLevel.boxY;
      _targetX = editingLevel.targetX;
      _targetY = editingLevel.targetY;
      for (final obs in editingLevel.obstacles) {
        _obstacleHeights['${obs.x},${obs.y}'] = obs.height;
      }
      for (final cell in editingLevel.energyCells) {
        _energyCellCharges['${cell.x},${cell.y}'] = cell.charge;
      }
    }
    _titleController.text = _title;
    _descriptionController.text = _description;
    _hintController.text = _hint;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _hintController.dispose();
    super.dispose();
  }

  void _playClick() {
    ref.read(audioControllerProvider).playClick();
  }

  void _changeGridSize(int newSize) {
    setState(() {
      _gridWidth = newSize;
      _gridHeight = newSize;
      
      // Clamp coordinates to new bounds
      _startX = _startX.clamp(0, newSize - 1);
      _startY = _startY.clamp(0, newSize - 1);
      _boxX = _boxX.clamp(0, newSize - 1);
      _boxY = _boxY.clamp(0, newSize - 1);
      _targetX = _targetX.clamp(0, newSize - 1);
      _targetY = _targetY.clamp(0, newSize - 1);

      // Clean up outside elements
      _obstacleHeights.removeWhere((key, val) {
        final pts = key.split(',');
        final x = int.parse(pts[0]);
        final y = int.parse(pts[1]);
        return x >= newSize || y >= newSize;
      });

      _energyCellCharges.removeWhere((key, val) {
        final pts = key.split(',');
        final x = int.parse(pts[0]);
        final y = int.parse(pts[1]);
        return x >= newSize || y >= newSize;
      });
    });
  }

  void _handleCellTap(int x, int y) {
    setState(() {
      switch (_selectedTool) {
        case EditorTool.drone:
          if (_startX == x && _startY == y) {
            // Rotate direction
            _startDirection = Direction.values[(_startDirection.index + 1) % 4];
          } else {
            // Remove obstacles or energy cells here
            _obstacleHeights.remove('$x,$y');
            _energyCellCharges.remove('$x,$y');
            _startX = x;
            _startY = y;
          }
          break;

        case EditorTool.box:
          _obstacleHeights.remove('$x,$y');
          _energyCellCharges.remove('$x,$y');
          _boxX = x;
          _boxY = y;
          break;

        case EditorTool.target:
          _obstacleHeights.remove('$x,$y');
          _energyCellCharges.remove('$x,$y');
          _targetX = x;
          _targetY = y;
          break;

        case EditorTool.obstacle:
          // Cannot place on drone start, box, or target
          if ((x == _startX && y == _startY) || (x == _boxX && y == _boxY) || (x == _targetX && y == _targetY)) {
            break;
          }
          _energyCellCharges.remove('$x,$y');
          final key = '$x,$y';
          final curHeight = _obstacleHeights[key] ?? 0;
          if (curHeight >= 3) {
            _obstacleHeights.remove(key);
          } else {
            _obstacleHeights[key] = curHeight + 1;
          }
          break;

        case EditorTool.energyCell:
          if ((x == _startX && y == _startY) || (x == _boxX && y == _boxY) || (x == _targetX && y == _targetY)) {
            break;
          }
          _obstacleHeights.remove('$x,$y');
          final key = '$x,$y';
          final curCharge = _energyCellCharges[key] ?? 0;
          if (curCharge == 0) {
            _energyCellCharges[key] = 5;
          } else if (curCharge == 5) {
            _energyCellCharges[key] = 10;
          } else {
            _energyCellCharges.remove(key);
          }
          break;
      }
    });
  }

  bool _validateMap(bool showBanner) {
    // Check overlapping primary assets
    final startOverlapBox = _startX == _boxX && _startY == _boxY;
    final startOverlapTarget = _startX == _targetX && _startY == _targetY;
    final boxOverlapTarget = _boxX == _targetX && _boxY == _targetY;

    if (startOverlapBox || startOverlapTarget || boxOverlapTarget) {
      if (showBanner) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: CyberTheme.neonPink,
            content: Text(
              'VALIDATION FAILURE: Primary components (Start, Box, Target Pad) cannot overlap.',
              style: CyberTheme.fontCode(color: Colors.black, size: 13.0).copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
      return false;
    }
    return true;
  }

  Level _compileLevel() {
    final editingLevel = ref.read(editingSandboxLevelProvider);
    final String levelId = editingLevel?.id ?? 'S${DateTime.now().millisecondsSinceEpoch}';

    final List<Obstacle> obsList = [];
    _obstacleHeights.forEach((key, height) {
      final pts = key.split(',');
      obsList.add(Obstacle(
        x: int.parse(pts[0]),
        y: int.parse(pts[1]),
        height: height,
      ));
    });

    final List<EnergyCell> cellList = [];
    _energyCellCharges.forEach((key, charge) {
      final pts = key.split(',');
      cellList.add(EnergyCell(
        x: int.parse(pts[0]),
        y: int.parse(pts[1]),
        height: 1, // default altitude 1 to collect
        charge: charge,
      ));
    });

    return Level(
      id: levelId,
      title: _titleController.text.trim().isEmpty ? "CUSTOM MISSION" : _titleController.text.trim().toUpperCase(),
      description: _descriptionController.text.trim().isEmpty ? "No description." : _descriptionController.text.trim(),
      hint: _hintController.text.trim().isEmpty ? null : _hintController.text.trim(),
      gridWidth: _gridWidth,
      gridHeight: _gridHeight,
      startX: _startX,
      startY: _startY,
      startDirection: _startDirection,
      boxX: _boxX,
      boxY: _boxY,
      targetX: _targetX,
      targetY: _targetY,
      initialBattery: _initialBattery,
      obstacles: obsList,
      energyCells: cellList,
      star3Target: _star3Target,
    );
  }

  Future<void> _save() async {
    _playClick();
    if (!_validateMap(true)) return;

    final level = _compileLevel();
    await ref.read(sandboxLevelsProvider.notifier).saveLevel(level);
    ref.read(editingSandboxLevelProvider.notifier).setLevel(null);
    ref.read(appScreenProvider.notifier).toScreen(AppScreen.home);
  }

  Future<void> _test() async {
    _playClick();
    if (!_validateMap(true)) return;

    final level = _compileLevel();
    await ref.read(sandboxLevelsProvider.notifier).saveLevel(level);
    ref.read(editingSandboxLevelProvider.notifier).setLevel(null);
    
    // Set as current level, clear simulation and program, and transition to game screen
    ref.read(currentLevelProvider.notifier).setLevel(level);
    ref.read(gameStateProvider.notifier).clearProgram();
    ref.read(gameStateProvider.notifier).resetSimulation();
    ref.read(gameModeProvider.notifier).setMode(GameMode.sandbox);
    ref.read(appScreenProvider.notifier).toScreen(AppScreen.game);
  }

  void _cancel() {
    _playClick();
    ref.read(editingSandboxLevelProvider.notifier).setLevel(null);
    ref.read(appScreenProvider.notifier).toScreen(AppScreen.home);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isLandscape = size.width > size.height && size.width > 700;

    Widget header = Row(
      children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.token_outlined, color: CyberTheme.neonCyan, size: 24.0),
                const SizedBox(width: 8.0),
                Text(
                  'GRID PROTOCOL ARCHITECT',
                  style: CyberTheme.fontHeading(size: 18.0, color: CyberTheme.neonCyan),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16.0),
        InkWell(
          onTap: _cancel,
          child: CyberCard(
            borderColor: CyberTheme.textMuted.withValues(alpha: 0.5),
            backgroundColor: Colors.transparent,
            borderWidth: 1.0,
            chamferSize: 6.0,
            showAccents: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'CANCEL',
                style: CyberTheme.fontCode(size: 11.0, color: CyberTheme.textMuted),
              ),
            ),
          ),
        ),
      ],
    );

    Widget gridSection = Column(
      children: [
        // Grid size segmented bar
        CyberCard(
          borderColor: CyberTheme.borderTranslucent,
          backgroundColor: const Color(0xFF121424),
          borderWidth: 1.0,
          chamferSize: 6.0,
          showAccents: false,
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [5, 6, 8].map((s) {
                final isSel = _gridWidth == s;
                return InkWell(
                  onTap: () {
                    _playClick();
                    _changeGridSize(s);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: isSel ? CyberTheme.neonCyan.withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(
                        color: isSel ? CyberTheme.neonCyan.withValues(alpha: 0.4) : Colors.transparent,
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      '${s}X$s',
                      style: CyberTheme.fontCode(
                        size: 12.0,
                        color: isSel ? CyberTheme.neonCyan : CyberTheme.textMuted,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16.0),

        // Grid Arena
        AspectRatio(
          aspectRatio: 1.0,
          child: CyberCard(
            borderColor: CyberTheme.borderTranslucent,
            backgroundColor: CyberTheme.gridBg,
            borderWidth: 1.5,
            chamferSize: 12.0,
            showAccents: true,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridWidth,
                  crossAxisSpacing: 6.0,
                  mainAxisSpacing: 6.0,
                ),
                itemCount: _gridWidth * _gridHeight,
                itemBuilder: (context, index) {
                  final x = index % _gridWidth;
                  final y = index ~/ _gridWidth;
                  final key = '$x,$y';

                  final isStart = _startX == x && _startY == y;
                  final isBox = _boxX == x && _boxY == y;
                  final isTarget = _targetX == x && _targetY == y;
                  final obsHeight = _obstacleHeights[key] ?? 0;
                  final cellCharge = _energyCellCharges[key] ?? 0;

                  Widget? cellContent;
                  Color cellBorder = CyberTheme.borderTranslucent;
                  Color cellBg = Colors.transparent;

                  if (isStart) {
                    cellBorder = CyberTheme.neonCyan;
                    cellBg = CyberTheme.neonCyan.withValues(alpha: 0.15);
                    IconData dirIcon = Icons.keyboard_arrow_up_rounded;
                    if (_startDirection == Direction.east) dirIcon = Icons.keyboard_arrow_right_rounded;
                    if (_startDirection == Direction.south) dirIcon = Icons.keyboard_arrow_down_rounded;
                    if (_startDirection == Direction.west) dirIcon = Icons.keyboard_arrow_left_rounded;
                    cellContent = Icon(dirIcon, color: CyberTheme.neonCyan, size: _gridWidth > 6 ? 20.0 : 26.0);
                  } else if (isBox) {
                    cellBorder = CyberTheme.neonGreen;
                    cellBg = CyberTheme.neonGreen.withValues(alpha: 0.15);
                    cellContent = Icon(Icons.unarchive_rounded, color: CyberTheme.neonGreen, size: _gridWidth > 6 ? 18.0 : 24.0);
                  } else if (isTarget) {
                    cellBorder = CyberTheme.neonPink;
                    cellBg = CyberTheme.neonPink.withValues(alpha: 0.15);
                    cellContent = Icon(Icons.adjust_rounded, color: CyberTheme.neonPink, size: _gridWidth > 6 ? 18.0 : 24.0);
                  } else if (obsHeight > 0) {
                    cellBorder = CyberTheme.neonPurple;
                    cellBg = CyberTheme.neonPurple.withValues(alpha: 0.2);
                    cellContent = Center(
                      child: Text(
                        '${obsHeight}m',
                        style: CyberTheme.fontHeading(size: _gridWidth > 6 ? 12.0 : 16.0, color: Colors.purple[200]!),
                      ),
                    );
                  } else if (cellCharge > 0) {
                    cellBorder = CyberTheme.neonYellow;
                    cellBg = CyberTheme.neonYellow.withValues(alpha: 0.1);
                    cellContent = Center(
                      child: Icon(
                        Icons.bolt,
                        color: CyberTheme.neonYellow,
                        size: _gridWidth > 6 ? 16.0 : 22.0,
                      ),
                    );
                  }

                  return InkWell(
                    onTap: () => _handleCellTap(x, y),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cellBg,
                        border: Border.all(color: cellBorder, width: cellContent != null ? 1.5 : 1.0),
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Stack(
                        children: [
                          if (cellContent != null) Positioned.fill(child: cellContent),
                          Positioned(
                            top: 2.0,
                            left: 3.0,
                            child: Text(
                              '($x,$y)',
                              style: CyberTheme.fontCode(size: _gridWidth > 6 ? 7.0 : 8.5, color: CyberTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );

    Widget toolTab(EditorTool tool, String label, IconData icon, Color color) {
      final isSel = _selectedTool == tool;
      return Expanded(
        child: InkWell(
          onTap: () {
            _playClick();
            setState(() {
              _selectedTool = tool;
            });
          },
          child: CyberCard(
            borderColor: isSel ? color : CyberTheme.borderTranslucent,
            backgroundColor: isSel ? color.withValues(alpha: 0.15) : Colors.transparent,
            borderWidth: 1.0,
            chamferSize: 5.0,
            showAccents: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: isSel ? color : CyberTheme.textMuted, size: 18.0),
                  const SizedBox(height: 3.0),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: CyberTheme.fontCode(
                        size: 9.5,
                        color: isSel ? color : CyberTheme.textMuted,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget configSection = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tool selectors
          Text(
            'CANVAS PALETTE TOOLS',
            style: CyberTheme.fontCode(size: 11.5, color: CyberTheme.textMuted).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6.0),
          Row(
            children: [
              toolTab(EditorTool.drone, 'DRONE', Icons.navigation_rounded, CyberTheme.neonCyan),
              const SizedBox(width: 4.0),
              toolTab(EditorTool.box, 'CARGO', Icons.unarchive_rounded, CyberTheme.neonGreen),
              const SizedBox(width: 4.0),
              toolTab(EditorTool.target, 'TARGET', Icons.adjust_rounded, CyberTheme.neonPink),
              const SizedBox(width: 4.0),
              toolTab(EditorTool.obstacle, 'TOWER', Icons.layers_rounded, CyberTheme.neonPurple),
              const SizedBox(width: 4.0),
              toolTab(EditorTool.energyCell, 'POWER', Icons.bolt, CyberTheme.neonYellow),
            ],
          ),
          const SizedBox(height: 16.0),

          // Metadata Inputs
          Text(
            'SECTOR CONFIG DATA',
            style: CyberTheme.fontCode(size: 11.5, color: CyberTheme.textMuted).copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),

          // Title
          TextField(
            controller: _titleController,
            style: CyberTheme.fontBody(size: 14.0),
            decoration: InputDecoration(
              labelText: 'MISSION TITLE',
              labelStyle: CyberTheme.fontCode(size: 12.0, color: CyberTheme.neonCyan),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: CyberTheme.borderTranslucent),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: CyberTheme.neonCyan),
              ),
            ),
          ),
          const SizedBox(height: 12.0),

          // Description
          TextField(
            controller: _descriptionController,
            style: CyberTheme.fontBody(size: 13.0),
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'MISSION BRIEFING',
              labelStyle: CyberTheme.fontCode(size: 12.0, color: CyberTheme.neonCyan),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: CyberTheme.borderTranslucent),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: CyberTheme.neonCyan),
              ),
            ),
          ),
          const SizedBox(height: 12.0),

          // Hint
          TextField(
            controller: _hintController,
            style: CyberTheme.fontBody(size: 13.0),
            decoration: InputDecoration(
              labelText: 'HINT BEACON GUIDANCE',
              labelStyle: CyberTheme.fontCode(size: 12.0, color: CyberTheme.neonCyan),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: CyberTheme.borderTranslucent),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: CyberTheme.neonCyan),
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // Constraints Row
          Row(
            children: [
              // Battery
              Expanded(
                child: CyberCard(
                  borderColor: CyberTheme.borderTranslucent,
                  backgroundColor: Colors.black12,
                  borderWidth: 1.0,
                  chamferSize: 8.0,
                  showAccents: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'START BATTERY: $_initialBattery',
                          style: CyberTheme.fontCode(size: 10.5, color: CyberTheme.textMuted).copyWith(fontWeight: FontWeight.bold),
                        ),
                        Slider(
                          value: _initialBattery.toDouble(),
                          min: 10,
                          max: 100,
                          divisions: 18,
                          activeColor: CyberTheme.neonGreen,
                          inactiveColor: Colors.white10,
                          onChanged: (v) {
                            setState(() {
                              _initialBattery = v.round();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              // Stars limit
              Expanded(
                child: CyberCard(
                  borderColor: CyberTheme.borderTranslucent,
                  backgroundColor: Colors.black12,
                  borderWidth: 1.0,
                  chamferSize: 8.0,
                  showAccents: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '3-STAR BLOCKS: $_star3Target',
                          style: CyberTheme.fontCode(size: 10.5, color: CyberTheme.textMuted).copyWith(fontWeight: FontWeight.bold),
                        ),
                        Slider(
                          value: _star3Target.toDouble(),
                          min: 3,
                          max: 30,
                          divisions: 27,
                          activeColor: CyberTheme.neonYellow,
                          inactiveColor: Colors.white10,
                          onChanged: (v) {
                            setState(() {
                              _star3Target = v.round();
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20.0),

          // Save / Test buttons
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _test,
                  child: CyberCard(
                    borderColor: CyberTheme.neonGreen,
                    backgroundColor: CyberTheme.neonGreen.withValues(alpha: 0.1),
                    borderWidth: 1.2,
                    chamferSize: 8.0,
                    showAccents: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.science_rounded, color: CyberTheme.neonGreen, size: 16.0),
                          const SizedBox(width: 6.0),
                          Text(
                            'COMPILE & TEST',
                            style: CyberTheme.fontCode(size: 12.0, color: CyberTheme.neonGreen).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: InkWell(
                  onTap: _save,
                  child: CyberCard(
                    borderColor: CyberTheme.neonCyan,
                    backgroundColor: CyberTheme.neonCyan,
                    borderWidth: 0.0,
                    chamferSize: 8.0,
                    showAccents: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.save_rounded, color: CyberTheme.darkBg, size: 16.0),
                          const SizedBox(width: 6.0),
                          Text(
                            'SAVE PROTOCOL',
                            style: CyberTheme.fontCode(size: 12.0, color: CyberTheme.darkBg).copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: CyberTheme.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              header,
              const SizedBox(height: 16.0),
              Expanded(
                child: isLandscape
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(flex: 11, child: SingleChildScrollView(child: gridSection)),
                          const SizedBox(width: 24.0),
                          Expanded(flex: 13, child: configSection),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: SingleChildScrollView(child: gridSection)),
                          const SizedBox(height: 16.0),
                          Expanded(child: configSection),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
