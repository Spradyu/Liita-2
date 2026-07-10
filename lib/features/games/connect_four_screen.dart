import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:liita/core/theme/app_theme.dart';
import 'package:liita/core/providers/providers.dart';
import 'package:liita/core/providers/game_provider.dart';
import 'package:liita/core/models/game_message.dart';

/// Connect Four board — turn-based, mirrors the reliable Tic-Tac-Toe flow.
/// The challenger is Red (moves first); the opponent is Yellow. Tapping a
/// column drops your token into the lowest empty slot; the column index is
/// sent to the peer, who applies the same drop.
class ConnectFourScreen extends ConsumerStatefulWidget {
  const ConnectFourScreen({super.key});

  @override
  ConsumerState<ConnectFourScreen> createState() => _ConnectFourScreenState();
}

class _ConnectFourScreenState extends ConsumerState<ConnectFourScreen> {
  static const Color _red = AppColors.error; // challenger 'R'
  static const Color _yellow = AppColors.warning; // opponent 'Y'

  Color _tokenColor(String cell) => cell == 'R' ? _red : _yellow;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectFourProvider);

    // Opponent-disconnect detection: if the opponent drops off the live peer
    // list mid-game, flag it (mirrors Tic-Tac-Toe).
    ref.listen(peersProvider, (_, peersAsync) {
      final gs = ref.read(connectFourProvider);
      if (gs == null || gs.winner != null || gs.opponentDisconnected) return;
      peersAsync.whenData((peers) {
        if (!peers.any((p) => p.deviceId == gs.opponentId)) {
          ref.read(connectFourProvider.notifier).markDisconnected();
        }
      });
    });

    if (state == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => context.canPop() ? context.pop() : context.go('/games'),
          ),
        ),
        body: const Center(
          child: Text('Game not found or ended',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    final isFinished = state.winner != null;
    final isDisconnected = state.opponentDisconnected;
    final myMarker = state.isChallenger ? 'R' : 'Y';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _quitGame(state);
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
            onPressed: () => _quitGame(state),
          ),
          centerTitle: true,
          title: Text(
            'Connect Four  vs  ${state.opponentName}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 17),
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (isDisconnected)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('${state.opponentName} left the game',
                            style: const TextStyle(
                                color: AppColors.error, fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: () => _quitGame(state),
                        child: const Text('Exit',
                            style:
                                TextStyle(color: AppColors.error, fontSize: 13)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // ── Marker + turn indicator ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('You are ',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: _tokenColor(myMarker),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isDisconnected
                    ? 'Opponent left the game'
                    : (isFinished
                        ? 'Game Over'
                        : (state.isMyTurn
                            ? 'Your turn'
                            : "${state.opponentName}'s turn")),
                style: TextStyle(
                  color: (state.isMyTurn && !isFinished && !isDisconnected)
                      ? AppColors.primary
                      : AppColors.textTertiary,
                  fontSize: 15,
                ),
              ),

              const Spacer(),

              // ── Board ──
              Opacity(
                opacity: (isFinished || isDisconnected) ? 0.55 : 1.0,
                child: _buildBoard(state, isFinished || isDisconnected),
              ),

              const Spacer(),

              // ── Result ──
              if (isFinished && !isDisconnected)
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    children: [
                      Text(
                        state.winner == 'draw'
                            ? 'Draw'
                            : (state.winner == myMarker
                                ? 'You win!'
                                : 'You lose!'),
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceLight,
                              foregroundColor: AppColors.textPrimary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999)),
                            ),
                            onPressed: () => _quitGame(state),
                            child: const Text('Exit'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textOnPrimary,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999)),
                            ),
                            onPressed: () => _playAgain(state),
                            child: const Text('Play Again'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoard(ConnectFourState state, bool locked) {
    const cols = ConnectFourState.cols;
    const rows = ConnectFourState.rows;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Neumorphic(
        style: NeumorphicStyle(
          boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(18)),
          depth: -6,
          color: NeuDark.base,
        ),
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cell = constraints.maxWidth / cols;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int r = 0; r < rows; r++)
                  Row(
                    children: [
                      for (int c = 0; c < cols; c++)
                        _cell(state, r * cols + c, cell, c, locked),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _cell(
      ConnectFourState state, int index, double size, int col, bool locked) {
    final cell = state.board[index];
    final isLast = state.lastMoveIndex == index;
    final canTap = !locked &&
        state.isMyTurn &&
        state.landingIndex(col) >= 0;
    return GestureDetector(
      onTap: canTap ? () => _drop(state, col) : null,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.12),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cell.isEmpty ? NeuDark.shadow : _tokenColor(cell),
            border: Border.all(
              color: isLast ? AppColors.textPrimary : NeuDark.hairline,
              width: isLast ? 2 : 1,
            ),
          ),
        ),
      ),
    );
  }

  void _drop(ConnectFourState state, int col) {
    final idx = ref.read(connectFourProvider.notifier).applyMove(col);
    if (idx < 0) return; // column full / not our turn
    ref.read(appControllerProvider).sendGameMessage(
          state.opponentId,
          GameMessage(
            gameId: state.gameId,
            gameType: GameType.connectFour,
            type: GameMessageType.move,
            payload: {'column': col},
          ),
        );
  }

  void _playAgain(ConnectFourState state) {
    final opponentId = state.opponentId;
    final opponentName = state.opponentName;
    final newGameId = const Uuid().v4();
    ref.read(appControllerProvider).sendGameMessage(
          opponentId,
          GameMessage(
            gameId: newGameId,
            gameType: GameType.connectFour,
            type: GameMessageType.invite,
            payload: {},
          ),
        );
    ref
        .read(connectFourProvider.notifier)
        .startGame(opponentId, opponentName, newGameId);
  }

  void _quitGame(ConnectFourState state) {
    final app = ref.read(appControllerProvider);
    app.cancelPendingGameSends(state.gameId);
    app.sendGameMessage(
      state.opponentId,
      GameMessage(
        gameId: state.gameId,
        gameType: GameType.connectFour,
        type: GameMessageType.end,
        payload: {},
      ),
    );
    ref.read(connectFourProvider.notifier).reset();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/games');
    }
  }
}
