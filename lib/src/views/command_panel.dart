import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/drone_command.dart';
import '../providers/game_state.dart';
import '../theme/colors.dart';

class CommandPanel extends ConsumerWidget {
  const CommandPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameStateProvider);
    final notifier = ref.read(gameStateProvider.notifier);
    final isRunning = state.status == GameStatus.running;

    return Container(
      padding: const EdgeInsets.all(20.0),
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
          // 1. Panel Header & Playback Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CMD CONSOLE',
                style: CyberTheme.fontSubheading(size: 13.5, color: CyberTheme.textMain),
              ),
              Row(
                children: [
                  // Unified Segmented Speed Pill Selector
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
                        _buildSpeedSegment(ref, 1.0, '1X'),
                        _buildSpeedSegment(ref, 2.0, '2X'),
                        _buildSpeedSegment(ref, 4.0, '4X'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  // Reset Button
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20.0),
                    color: CyberTheme.textMuted,
                    hoverColor: CyberTheme.neonPink.withValues(alpha: 0.1),
                    tooltip: 'Reset Simulation',
                    onPressed: () {
                      notifier.resetSimulation();
                    },
                  ),
                  // Play/Pause Action Button
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
          
          const SizedBox(height: 16.0),
          Container(
            height: 1.0,
            color: CyberTheme.borderTranslucent,
          ),
          const SizedBox(height: 16.0),

          // 2. Programmed Queue (Reorderable List)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'FLIGHT PATH SEQUENCE',
                      style: CyberTheme.fontCode(size: 10.0, color: CyberTheme.textMuted),
                    ),
                    Text(
                      '${state.commandQueue.length} STEPS',
                      style: CyberTheme.fontCode(size: 10.0, color: CyberTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 10.0),
                Expanded(
                  child: state.commandQueue.isEmpty
                      ? _buildEmptyQueuePlaceholder()
                      : _buildQueueList(context, state, notifier),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20.0),

          // 3. Command Library
          Text(
            'INSTRUCTION LIBRARY',
            style: CyberTheme.fontCode(size: 10.0, color: CyberTheme.textMuted),
          ),
          const SizedBox(height: 10.0),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: CommandType.values.map((type) {
                final cmd = DroneCommand(type);
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100.0),
                      onTap: isRunning ? null : () => notifier.addCommand(type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                        decoration: BoxDecoration(
                          color: CyberTheme.darkBg,
                          borderRadius: BorderRadius.circular(100.0),
                          border: Border.all(
                            color: isRunning
                                ? CyberTheme.borderTranslucent
                                : CyberTheme.neonCyan.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              cmd.icon,
                              size: 14.0,
                              color: isRunning ? CyberTheme.textMuted : CyberTheme.neonCyan,
                            ),
                            const SizedBox(width: 8.0),
                            Text(
                              cmd.shortLabel,
                              style: CyberTheme.fontCode(
                                size: 10.5,
                                color: isRunning ? CyberTheme.textMuted : CyberTheme.textMain,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedSegment(WidgetRef ref, double speed, String label) {
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

  Widget _buildEmptyQueuePlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: CyberTheme.darkBg,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: CyberTheme.borderTranslucent,
          width: 1.0,
        ),
      ),
      child: Center(
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
              'QUEUE IS EMPTY',
              style: CyberTheme.fontCode(size: 11, color: CyberTheme.textMuted),
            ),
            const SizedBox(height: 2.0),
            Text(
              'Select instructions from the library to build path.',
              style: CyberTheme.fontBody(size: 11.5, color: CyberTheme.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueList(BuildContext context, DroneGameState state, GameStateNotifier notifier) {
    final isRunning = state.status == GameStatus.running;

    return Container(
      decoration: BoxDecoration(
        color: CyberTheme.darkBg,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: CyberTheme.borderTranslucent,
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.0),
        child: Theme(
          data: Theme.of(context).copyWith(
            canvasColor: CyberTheme.darkBg,
            shadowColor: Colors.transparent,
          ),
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: state.commandQueue.length,
            onReorder: notifier.reorderQueue,
            buildDefaultDragHandles: !isRunning,
            itemBuilder: (context, index) {
              final cmd = state.commandQueue[index];
              final isCurrent = state.currentCommandIndex == index;
              final isExecuted = state.currentCommandIndex > index;

              Color borderCol = CyberTheme.borderTranslucent;
              Color bgCol = CyberTheme.cardBg;
              Color textCol = CyberTheme.textMain;
              Color iconCol = CyberTheme.neonCyan;

              if (isCurrent) {
                borderCol = CyberTheme.neonYellow;
                bgCol = CyberTheme.neonYellow.withValues(alpha: 0.08);
                textCol = CyberTheme.neonYellow;
                iconCol = CyberTheme.neonYellow;
              } else if (isExecuted) {
                borderCol = CyberTheme.neonGreen.withValues(alpha: 0.2);
                bgCol = CyberTheme.neonGreen.withValues(alpha: 0.03);
                textCol = CyberTheme.textMuted;
                iconCol = CyberTheme.neonGreen.withValues(alpha: 0.4);
              }

              return Container(
                key: ValueKey('cmd_${index}_${cmd.type}'),
                width: 90.0,
                margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: bgCol,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: borderCol, width: 1.0),
                ),
                child: Stack(
                  children: [
                    // Card Content
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            (index + 1).toString().padLeft(2, '0'),
                            style: CyberTheme.fontCode(size: 8.5, color: CyberTheme.textMuted),
                            textAlign: TextAlign.start,
                          ),
                          const Spacer(),
                          Icon(cmd.icon, color: iconCol, size: 20.0),
                          const Spacer(),
                          Text(
                            cmd.shortLabel,
                            style: CyberTheme.fontCode(size: 10, color: textCol).copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Delete button (Top Right, hidden when running)
                    if (!isRunning)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: InkWell(
                          onTap: () => notifier.removeCommand(index),
                          borderRadius: BorderRadius.circular(100.0),
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(
                              Icons.close,
                              size: 12.0,
                              color: CyberTheme.textMuted.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
