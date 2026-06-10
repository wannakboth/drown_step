import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/program_block.dart';
import '../providers/game_state.dart';
import '../theme/colors.dart';

class CommandPanel extends ConsumerStatefulWidget {
  const CommandPanel({super.key});

  @override
  ConsumerState<CommandPanel> createState() => _CommandPanelState();
}

class _CommandPanelState extends ConsumerState<CommandPanel> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(gameStateProvider);
    final notifier = ref.read(gameStateProvider.notifier);
    final isRunning = state.status == GameStatus.running;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: CyberTheme.cardBg,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: CyberTheme.borderTranslucent,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CMD CONSOLE',
                style: CyberTheme.fontSubheading(size: 13.5, color: CyberTheme.textMain),
              ),
              Row(
                children: [
                  // Speed segmented pill selector
                  Container(
                    padding: const EdgeInsets.all(3.0),
                    decoration: BoxDecoration(
                      color: CyberTheme.darkBg,
                      borderRadius: BorderRadius.circular(100.0),
                      border: Border.all(color: CyberTheme.borderTranslucent, width: 1.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSpeedSegment(1.0, '1X'),
                        _buildSpeedSegment(2.0, '2X'),
                        _buildSpeedSegment(4.0, '4X'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  // Reset button
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20.0),
                    color: CyberTheme.textMuted,
                    hoverColor: CyberTheme.neonPink.withValues(alpha: 0.1),
                    tooltip: 'Reset Simulation',
                    onPressed: () {
                      notifier.resetSimulation();
                    },
                  ),
                  // RUN/PAUSE button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRunning ? CyberTheme.neonPink : CyberTheme.neonCyan,
                      foregroundColor: CyberTheme.darkBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      elevation: 0,
                    ),
                    icon: Icon(isRunning ? Icons.pause : Icons.play_arrow, size: 18.0),
                    label: Text(
                      isRunning ? 'PAUSE' : 'RUN',
                      style: CyberTheme.fontCode(size: 11, color: CyberTheme.darkBg).copyWith(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      if (isRunning) {
                        notifier.pauseSimulation();
                      } else {
                        notifier.runSimulation();
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12.0),
          Container(height: 1.0, color: CyberTheme.borderTranslucent),
          const SizedBox(height: 12.0),

          // 2. Body of the panel: Palette vs Workspace split
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Toolbox palette column (left)
                SizedBox(
                  width: 155.0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BLOCK PALETTE',
                        style: CyberTheme.fontCode(size: 9.0, color: CyberTheme.textMuted),
                      ),
                      const SizedBox(height: 8.0),
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildCategoryHeader('ACTIONS'),
                              _buildPaletteItem(
                                ProgramBlock(id: '', type: BlockType.action, action: ActionType.takeoff),
                                const Color(0xFF0EA5E9),
                                'TAKEOFF',
                                Icons.flight_takeoff,
                              ),
                              _buildPaletteItem(
                                ProgramBlock(id: '', type: BlockType.action, action: ActionType.land),
                                const Color(0xFF0EA5E9),
                                'LAND',
                                Icons.flight_land,
                              ),
                              _buildPaletteItem(
                                ProgramBlock(id: '', type: BlockType.action, action: ActionType.forward),
                                const Color(0xFF0EA5E9),
                                'MOVE FWD',
                                Icons.arrow_upward,
                              ),
                              _buildPaletteItem(
                                ProgramBlock(id: '', type: BlockType.action, action: ActionType.rotateLeft),
                                const Color(0xFF0EA5E9),
                                'TURN LEFT',
                                Icons.rotate_left,
                              ),
                              _buildPaletteItem(
                                ProgramBlock(id: '', type: BlockType.action, action: ActionType.rotateRight),
                                const Color(0xFF0EA5E9),
                                'TURN RIGHT',
                                Icons.rotate_right,
                              ),
                              _buildPaletteItem(
                                ProgramBlock(id: '', type: BlockType.action, action: ActionType.ascend),
                                const Color(0xFF0EA5E9),
                                'ASCEND',
                                Icons.keyboard_double_arrow_up,
                              ),
                              _buildPaletteItem(
                                ProgramBlock(id: '', type: BlockType.action, action: ActionType.descend),
                                const Color(0xFF0EA5E9),
                                'DESCEND',
                                Icons.keyboard_double_arrow_down,
                              ),
                              
                              const SizedBox(height: 10.0),
                              _buildCategoryHeader('CONTROL FLOW'),
                              _buildPaletteItem(
                                ProgramBlock(id: '', type: BlockType.repeat),
                                const Color(0xFF8B5CF6),
                                'REPEAT N',
                                Icons.loop,
                              ),
                              _buildPaletteItem(
                                ProgramBlock(id: '', type: BlockType.whileLoop),
                                const Color(0xFF6D28D9),
                                'WHILE COND',
                                Icons.autorenew,
                              ),
                              _buildPaletteItem(
                                ProgramBlock(id: '', type: BlockType.ifElse),
                                const Color(0xFFF59E0B),
                                'IF / ELSE',
                                Icons.alt_route,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Vertical Divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: Container(width: 1.0, color: CyberTheme.borderTranslucent),
                ),

                // Canvas Workspace Column (right)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CODING WORKSPACE',
                            style: CyberTheme.fontCode(size: 9.0, color: CyberTheme.textMuted),
                          ),
                          Row(
                            children: [
                              Text(
                                '${state.totalBlockCount} BLOCKS',
                                style: CyberTheme.fontCode(size: 9.0, color: CyberTheme.textMuted),
                              ),
                              const SizedBox(width: 12.0),
                              InkWell(
                                onTap: isRunning ? null : () => notifier.clearProgram(),
                                child: Text(
                                  'CLEAR ALL',
                                  style: CyberTheme.fontCode(
                                    size: 9.0,
                                    color: isRunning ? CyberTheme.textMuted : CyberTheme.neonPink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Expanded(
                        child: _buildWorkspace(state, notifier),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedSegment(double speed, String label) {
    final notifier = ref.read(gameStateProvider.notifier);
    final activeSpeed = notifier.speedMultiplier;
    final isActive = activeSpeed == speed;

    return GestureDetector(
      onTap: () => notifier.setSpeed(speed),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isActive ? CyberTheme.neonCyan.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(100.0),
        ),
        child: Text(
          label,
          style: CyberTheme.fontCode(
            size: 10,
            color: isActive ? CyberTheme.neonCyan : CyberTheme.textMuted,
          ).copyWith(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 6.0),
      child: Text(
        title,
        style: CyberTheme.fontCode(size: 8.0, color: Colors.white54),
      ),
    );
  }

  Widget _buildPaletteItem(ProgramBlock templateBlock, Color blockColor, String label, IconData icon) {
    final isRunning = ref.read(gameStateProvider).status == GameStatus.running;

    return Draggable<ProgramBlock>(
      data: templateBlock,
      ignoringFeedbackSemantics: true,
      maxSimultaneousDrags: isRunning ? 0 : 1,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 140.0,
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: CyberTheme.cardBg,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: blockColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13.0, color: blockColor),
              const SizedBox(width: 8.0),
              Text(
                label,
                style: CyberTheme.fontCode(size: 9.5, color: Colors.white).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(8.0),
          onTap: isRunning
              ? null
              : () {
                  final notifier = ref.read(gameStateProvider.notifier);
                  notifier.addBlock(templateBlock.copyWith(id: 'block_${DateTime.now().microsecondsSinceEpoch}'));
                },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: CyberTheme.darkBg,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: isRunning ? CyberTheme.borderTranslucent : blockColor.withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 13.0,
                  color: isRunning ? CyberTheme.textMuted : blockColor,
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    label,
                    style: CyberTheme.fontCode(
                      size: 9.5,
                      color: isRunning ? CyberTheme.textMuted : CyberTheme.textMain,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkspace(DroneGameState state, GameStateNotifier notifier) {
    final program = state.program;
    final isRunning = state.status == GameStatus.running;

    return DragTarget<ProgramBlock>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final incoming = details.data;
        if (incoming.id.isEmpty) {
          final newBlock = incoming.copyWith(id: 'block_${DateTime.now().microsecondsSinceEpoch}');
          notifier.addBlock(newBlock);
        } else {
          notifier.moveBlock(incoming.id, targetParentId: null);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isHovered ? Colors.white.withValues(alpha: 0.03) : CyberTheme.darkBg,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: isHovered ? CyberTheme.neonCyan : CyberTheme.borderTranslucent,
              width: 1.0,
            ),
          ),
          padding: const EdgeInsets.all(8.0),
          child: program.isEmpty
              ? _buildEmptyQueuePlaceholder()
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: program.length,
                  itemBuilder: (context, idx) {
                    return Column(
                      children: [
                        _buildInsertDropTarget(idx, null, false, notifier),
                        VisualBlock(
                          block: program[idx],
                          parentId: null,
                          isElse: false,
                          index: idx,
                          isRunning: isRunning,
                          activeBlockId: state.activeBlockId,
                        ),
                        if (idx == program.length - 1)
                          _buildInsertDropTarget(idx + 1, null, false, notifier),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildInsertDropTarget(int index, String? parentId, bool isElse, GameStateNotifier notifier) {
    return DragTarget<ProgramBlock>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        final incoming = details.data;
        if (incoming.id.isEmpty) {
          final newBlock = incoming.copyWith(id: 'block_${DateTime.now().microsecondsSinceEpoch}');
          notifier.addBlock(newBlock, parentId: parentId, isElse: isElse, index: index);
        } else {
          notifier.moveBlock(incoming.id, targetParentId: parentId, isElse: isElse, index: index);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: isHovered ? 20.0 : 4.0,
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          decoration: BoxDecoration(
            color: isHovered ? CyberTheme.neonCyan.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(4.0),
            border: isHovered ? Border.all(color: CyberTheme.neonCyan) : null,
          ),
          child: isHovered
              ? const Center(
                  child: Icon(Icons.add, size: 12.0, color: CyberTheme.neonCyan),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildEmptyQueuePlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.terminal_outlined,
            color: CyberTheme.textMuted.withValues(alpha: 0.3),
            size: 28.0,
          ),
          const SizedBox(height: 10.0),
          Text(
            'WORKSPACE IS EMPTY',
            style: CyberTheme.fontCode(size: 11, color: CyberTheme.textMuted),
          ),
          const SizedBox(height: 4.0),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Drag blocks from the palette or tap them to write your program.',
              style: CyberTheme.fontBody(size: 11.5, color: CyberTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class VisualBlock extends ConsumerWidget {
  final ProgramBlock block;
  final String? parentId;
  final bool isElse;
  final int index;
  final bool isRunning;
  final String? activeBlockId;

  const VisualBlock({
    super.key,
    required this.block,
    this.parentId,
    this.isElse = false,
    required this.index,
    required this.isRunning,
    this.activeBlockId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gameStateProvider.notifier);
    final isActive = activeBlockId == block.id;

    return Draggable<ProgramBlock>(
      data: block,
      ignoringFeedbackSemantics: true,
      maxSimultaneousDrags: isRunning ? 0 : 1,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.75,
          child: _buildCardContent(context, notifier, isActive, isFeedback: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.2,
        child: _buildCardContent(context, notifier, isActive),
      ),
      child: _buildCardContent(context, notifier, isActive),
    );
  }

  Widget _buildCardContent(BuildContext context, GameStateNotifier notifier, bool isActive, {bool isFeedback = false}) {
    Color blockColor;
    IconData icon;
    String title;
    Widget? customInput;
    Widget? nestedBody;

    switch (block.type) {
      case BlockType.action:
        blockColor = const Color(0xFF0EA5E9); // Cyan-blue
        icon = block.action?.icon ?? Icons.code;
        title = block.action?.label ?? 'ACTION';
        break;

      case BlockType.repeat:
        blockColor = const Color(0xFF8B5CF6); // Loop purple
        icon = Icons.loop;
        title = 'REPEAT';
        customInput = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              height: 20,
              decoration: BoxDecoration(
                color: CyberTheme.darkBg,
                borderRadius: BorderRadius.circular(4.0),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: block.repeatCount,
                  dropdownColor: CyberTheme.cardBg,
                  icon: const Icon(Icons.arrow_drop_down, size: 12, color: Colors.white70),
                  style: CyberTheme.fontCode(size: 10, color: Colors.white).copyWith(fontWeight: FontWeight.bold),
                  onChanged: isRunning ? null : (val) {
                    if (val != null) notifier.updateBlockRepeat(block.id, val);
                  },
                  items: List.generate(9, (i) => i + 2).map((i) {
                    return DropdownMenuItem<int>(
                      value: i,
                      child: Text('$i '),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 4.0),
            Text('TIMES', style: CyberTheme.fontCode(size: 9.5, color: Colors.white70)),
          ],
        );
        nestedBody = _buildNestedList(block.body, false, notifier);
        break;

      case BlockType.whileLoop:
        blockColor = const Color(0xFF6D28D9); // While dark purple
        icon = Icons.autorenew;
        title = 'WHILE';
        customInput = Container(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          height: 20,
          decoration: BoxDecoration(
            color: CyberTheme.darkBg,
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ConditionType>(
              value: block.condition,
              dropdownColor: CyberTheme.cardBg,
              icon: const Icon(Icons.arrow_drop_down, size: 12, color: Colors.white70),
              style: CyberTheme.fontCode(size: 9.5, color: Colors.white).copyWith(fontWeight: FontWeight.bold),
              onChanged: isRunning ? null : (val) {
                if (val != null) notifier.updateBlockCondition(block.id, val);
              },
              items: ConditionType.values.map((cond) {
                return DropdownMenuItem<ConditionType>(
                  value: cond,
                  child: Text('${cond.label} '),
                );
              }).toList(),
            ),
          ),
        );
        nestedBody = _buildNestedList(block.body, false, notifier);
        break;

      case BlockType.ifElse:
        blockColor = const Color(0xFFF59E0B); // If orange
        icon = Icons.alt_route;
        title = 'IF';
        customInput = Container(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          height: 20,
          decoration: BoxDecoration(
            color: CyberTheme.darkBg,
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ConditionType>(
              value: block.condition,
              dropdownColor: CyberTheme.cardBg,
              icon: const Icon(Icons.arrow_drop_down, size: 12, color: Colors.white70),
              style: CyberTheme.fontCode(size: 9.5, color: Colors.white).copyWith(fontWeight: FontWeight.bold),
              onChanged: isRunning ? null : (val) {
                if (val != null) notifier.updateBlockCondition(block.id, val);
              },
              items: ConditionType.values.map((cond) {
                return DropdownMenuItem<ConditionType>(
                  value: cond,
                  child: Text('${cond.label} '),
                );
              }).toList(),
            ),
          ),
        );
        nestedBody = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildNestedList(block.body, false, notifier),
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.subdirectory_arrow_right, size: 14, color: Colors.white38),
                  const SizedBox(width: 4.0),
                  Text('ELSE', style: CyberTheme.fontCode(size: 10, color: Colors.white38)),
                ],
              ),
            ),
            _buildNestedList(block.elseBody, true, notifier),
          ],
        );
        break;
    }

    return Container(
      width: isFeedback ? 220.0 : double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: CyberTheme.cardBg,
        borderRadius: BorderRadius.circular(10.0),
        border: Border.all(
          color: isActive
              ? CyberTheme.neonYellow
              : (isRunning ? blockColor.withValues(alpha: 0.4) : blockColor.withValues(alpha: 0.8)),
          width: isActive ? 2.0 : 1.0,
        ),
        boxShadow: isActive ? CyberTheme.neonGlow(CyberTheme.neonYellow, radius: 8.0) : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Block Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Row(
              children: [
                if (!isRunning && !isFeedback)
                  const Padding(
                    padding: EdgeInsets.only(right: 6.0),
                    child: Icon(Icons.drag_indicator, size: 14.0, color: Colors.white38),
                  ),
                Icon(icon, size: 14.0, color: blockColor),
                const SizedBox(width: 6.0),
                Text(
                  title,
                  style: CyberTheme.fontCode(size: 11.0, color: Colors.white).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8.0),
                ?customInput,
                const Spacer(),
                if (!isRunning && !isFeedback)
                  InkWell(
                    onTap: () => notifier.removeBlock(block.id),
                    child: const Padding(
                      padding: EdgeInsets.all(2.0),
                      child: Icon(Icons.close, size: 14.0, color: Colors.white38),
                    ),
                  ),
              ],
            ),
          ),

          // Block Body (Nested lists)
          if (nestedBody != null)
            Padding(
              padding: const EdgeInsets.only(left: 12.0, right: 8.0, bottom: 8.0),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: Colors.white10, width: 1.0),
                  ),
                ),
                padding: const EdgeInsets.only(left: 8.0),
                child: nestedBody,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNestedList(List<ProgramBlock> children, bool nestedIsElse, GameStateNotifier notifier) {
    return DragTarget<ProgramBlock>(
      onWillAcceptWithDetails: (details) {
        // Prevent recursive loops: a block cannot be accepted inside itself or inside its children
        final incoming = details.data;
        if (incoming.id == block.id) return false;
        
        bool isDescendant(ProgramBlock current, String targetId) {
          for (final b in current.body) {
            if (b.id == targetId) return true;
            if (isDescendant(b, targetId)) return true;
          }
          for (final b in current.elseBody) {
            if (b.id == targetId) return true;
            if (isDescendant(b, targetId)) return true;
          }
          return false;
        }
        
        if (incoming.id.isNotEmpty && isDescendant(incoming, block.id)) {
          return false; // prevent drag source from being parent of drop target
        }
        return true;
      },
      onAcceptWithDetails: (details) {
        final incoming = details.data;
        if (incoming.id.isEmpty) {
          final newBlock = incoming.copyWith(id: 'block_${DateTime.now().microsecondsSinceEpoch}');
          notifier.addBlock(newBlock, parentId: block.id, isElse: nestedIsElse);
        } else {
          notifier.moveBlock(incoming.id, targetParentId: block.id, isElse: nestedIsElse);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isHovered ? Colors.white.withValues(alpha: 0.03) : Colors.transparent,
            borderRadius: BorderRadius.circular(6.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: children.isEmpty
              ? Container(
                  height: 36.0,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white10),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Text(
                    isHovered ? 'RELEASE TO DROP' : 'DROP CODE HERE',
                    style: CyberTheme.fontCode(size: 9.0, color: Colors.white30),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: children.length,
                  itemBuilder: (context, idx) {
                    return Column(
                      children: [
                        _buildInsertDropTarget(idx, block.id, nestedIsElse, notifier),
                        VisualBlock(
                          block: children[idx],
                          parentId: block.id,
                          isElse: nestedIsElse,
                          index: idx,
                          isRunning: isRunning,
                          activeBlockId: activeBlockId,
                        ),
                        if (idx == children.length - 1)
                          _buildInsertDropTarget(idx + 1, block.id, nestedIsElse, notifier),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }

  Widget _buildInsertDropTarget(int index, String parentBlockId, bool isElse, GameStateNotifier notifier) {
    return DragTarget<ProgramBlock>(
      onWillAcceptWithDetails: (details) {
        final incoming = details.data;
        if (incoming.id == parentBlockId) return false;
        return true;
      },
      onAcceptWithDetails: (details) {
        final incoming = details.data;
        if (incoming.id.isEmpty) {
          final newBlock = incoming.copyWith(id: 'block_${DateTime.now().microsecondsSinceEpoch}');
          notifier.addBlock(newBlock, parentId: parentBlockId, isElse: isElse, index: index);
        } else {
          notifier.moveBlock(incoming.id, targetParentId: parentBlockId, isElse: isElse, index: index);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: isHovered ? 20.0 : 4.0,
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          decoration: BoxDecoration(
            color: isHovered ? CyberTheme.neonCyan.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(4.0),
            border: isHovered ? Border.all(color: CyberTheme.neonCyan) : null,
          ),
          child: isHovered
              ? const Center(
                  child: Icon(Icons.add, size: 12.0, color: CyberTheme.neonCyan),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}
