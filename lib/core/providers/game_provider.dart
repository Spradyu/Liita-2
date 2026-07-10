import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liita/core/models/game_message.dart';
import 'package:liita/core/utils/trivia_questions.dart';

class TicTacToeState {
  final String gameId;
  final String opponentId;
  final String opponentName;
  final bool isChallenger;
  final List<String> board;
  final bool isMyTurn;
  final String? winner;
  final bool opponentDisconnected;

  const TicTacToeState({
    required this.gameId,
    required this.opponentId,
    required this.opponentName,
    required this.isChallenger,
    required this.board,
    required this.isMyTurn,
    this.winner,
    this.opponentDisconnected = false,
  });

  TicTacToeState copyWith({
    String? gameId,
    String? opponentId,
    String? opponentName,
    bool? isChallenger,
    List<String>? board,
    bool? isMyTurn,
    String? winner,
    bool? opponentDisconnected,
  }) {
    return TicTacToeState(
      gameId: gameId ?? this.gameId,
      opponentId: opponentId ?? this.opponentId,
      opponentName: opponentName ?? this.opponentName,
      isChallenger: isChallenger ?? this.isChallenger,
      board: board ?? this.board,
      isMyTurn: isMyTurn ?? this.isMyTurn,
      winner: winner ?? this.winner,
      opponentDisconnected: opponentDisconnected ?? this.opponentDisconnected,
    );
  }

  String? checkWinner() {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (final line in lines) {
      final a = board[line[0]], b = board[line[1]], c = board[line[2]];
      if (a.isNotEmpty && a == b && b == c) return a;
    }
    if (board.every((cell) => cell.isNotEmpty)) return 'draw';
    return null;
  }
}

class PendingGameInvite {
  final String gameId;
  final GameType gameType;
  final String peerId;
  final String peerName;

  const PendingGameInvite({
    required this.gameId,
    required this.gameType,
    required this.peerId,
    required this.peerName,
  });
}

final pendingGameInviteProvider = StateProvider<PendingGameInvite?>((ref) => null);

final ticTacToeProvider = StateNotifierProvider<TicTacToeNotifier, TicTacToeState?>((ref) {
  return TicTacToeNotifier(ref);
});

class TicTacToeNotifier extends StateNotifier<TicTacToeState?> {
  TicTacToeNotifier(this._ref) : super(null);
  
  // ignore: unused_field
  final Ref _ref;

  void startGame(String opponentId, String opponentName, String gameId) {
    state = TicTacToeState(
      gameId: gameId,
      opponentId: opponentId,
      opponentName: opponentName,
      isChallenger: true,
      board: List.filled(9, ''),
      isMyTurn: false, // Waiting for the opponent to accept; isMyTurn → true in onInviteAccepted
    );
  }

  /// Called when the opponent's device is no longer visible on the mesh.
  void markDisconnected() {
    if (state != null && state!.winner == null) {
      state = state!.copyWith(opponentDisconnected: true);
    }
  }

  void onInviteAccepted(String gameId, String opponentId, String opponentName) {
    // If I sent the invite, my state is already populated, I just know it's accepted.
    // If I received the invite, I am O, and it's X's turn (opponent).
    if (state != null && state!.gameId == gameId) {
      // I am challenger, it was accepted. X goes first, so it's my turn.
      state = state!.copyWith(isMyTurn: true);
    } else {
      // I am the opponent accepting.
      state = TicTacToeState(
        gameId: gameId,
        opponentId: opponentId,
        opponentName: opponentName,
        isChallenger: false,
        board: List.filled(9, ''),
        isMyTurn: false, // X (challenger) goes first
      );
    }
  }

  void onMoveReceived(int index) {
    if (state == null) return;
    
    final currentBoard = List<String>.from(state!.board);
    final opponentMarker = state!.isChallenger ? 'O' : 'X';
    
    if (currentBoard[index].isEmpty) {
      currentBoard[index] = opponentMarker;
      state = state!.copyWith(
        board: currentBoard,
        isMyTurn: true,
      );
      
      final winner = state!.checkWinner();
      if (winner != null) {
        state = state!.copyWith(winner: winner);
      }
    }
  }

  void applyMove(int index) {
    if (state == null || !state!.isMyTurn) return;
    
    final currentBoard = List<String>.from(state!.board);
    final myMarker = state!.isChallenger ? 'X' : 'O';
    
    if (currentBoard[index].isEmpty) {
      currentBoard[index] = myMarker;
      state = state!.copyWith(
        board: currentBoard,
        isMyTurn: false,
      );
      
      final winner = state!.checkWinner();
      if (winner != null) {
        state = state!.copyWith(winner: winner);
      }
    }
  }

  void reset() {
    state = null;
  }
}

// ===========================================================================
// CONNECT FOUR
// ===========================================================================
//
// Turn-based, structurally identical to Tic-Tac-Toe (which is reliable on the
// mesh): only the current player moves, sends the COLUMN it dropped into, and
// the peer applies it. Because both boards apply the same moves in the same
// order, the landing row is deterministic on both sides — so sending just the
// column (not the resolved cell) stays in sync. Challenger is 'R' (red, moves
// first); opponent is 'Y' (yellow).

class ConnectFourState {
  static const int cols = 7;
  static const int rows = 6;

  final String gameId;
  final String opponentId;
  final String opponentName;
  final bool isChallenger;
  final List<String> board; // rows*cols, row-major (index = row*cols + col)
  final bool isMyTurn;
  final String? winner; // 'R' | 'Y' | 'draw' | null
  final int? lastMoveIndex; // most recent drop, for highlight
  final bool opponentDisconnected;

  const ConnectFourState({
    required this.gameId,
    required this.opponentId,
    required this.opponentName,
    required this.isChallenger,
    required this.board,
    required this.isMyTurn,
    this.winner,
    this.lastMoveIndex,
    this.opponentDisconnected = false,
  });

  ConnectFourState copyWith({
    List<String>? board,
    bool? isMyTurn,
    String? winner,
    int? lastMoveIndex,
    bool? opponentDisconnected,
  }) {
    return ConnectFourState(
      gameId: gameId,
      opponentId: opponentId,
      opponentName: opponentName,
      isChallenger: isChallenger,
      board: board ?? this.board,
      isMyTurn: isMyTurn ?? this.isMyTurn,
      winner: winner ?? this.winner,
      lastMoveIndex: lastMoveIndex ?? this.lastMoveIndex,
      opponentDisconnected: opponentDisconnected ?? this.opponentDisconnected,
    );
  }

  /// Row-major index where a token dropped in [col] would land (lowest empty
  /// cell), or -1 if the column is full.
  int landingIndex(int col) {
    for (int r = rows - 1; r >= 0; r--) {
      final idx = r * cols + col;
      if (board[idx].isEmpty) return idx;
    }
    return -1;
  }

  String? checkWinner() {
    // Scan every cell as a line start in 4 directions: →, ↓, ↘, ↙.
    const dirs = [
      [0, 1],
      [1, 0],
      [1, 1],
      [1, -1],
    ];
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final cell = board[r * cols + c];
        if (cell.isEmpty) continue;
        for (final d in dirs) {
          int count = 1;
          int nr = r + d[0], nc = c + d[1];
          while (nr >= 0 &&
              nr < rows &&
              nc >= 0 &&
              nc < cols &&
              board[nr * cols + nc] == cell) {
            if (++count >= 4) return cell;
            nr += d[0];
            nc += d[1];
          }
        }
      }
    }
    if (board.every((x) => x.isNotEmpty)) return 'draw';
    return null;
  }
}

final connectFourProvider =
    StateNotifierProvider<ConnectFourNotifier, ConnectFourState?>(
        (ref) => ConnectFourNotifier(ref));

class ConnectFourNotifier extends StateNotifier<ConnectFourState?> {
  ConnectFourNotifier(this._ref) : super(null);

  // ignore: unused_field
  final Ref _ref;

  void startGame(String opponentId, String opponentName, String gameId) {
    state = ConnectFourState(
      gameId: gameId,
      opponentId: opponentId,
      opponentName: opponentName,
      isChallenger: true,
      board: List.filled(ConnectFourState.rows * ConnectFourState.cols, ''),
      isMyTurn: false, // becomes true in onInviteAccepted (R goes first)
    );
  }

  void markDisconnected() {
    if (state != null && state!.winner == null) {
      state = state!.copyWith(opponentDisconnected: true);
    }
  }

  void onInviteAccepted(String gameId, String opponentId, String opponentName) {
    if (state != null && state!.gameId == gameId) {
      // I'm the challenger (R) — accepted, R moves first, so it's my turn.
      state = state!.copyWith(isMyTurn: true);
    } else {
      // I'm the opponent (Y). R (challenger) goes first.
      state = ConnectFourState(
        gameId: gameId,
        opponentId: opponentId,
        opponentName: opponentName,
        isChallenger: false,
        board: List.filled(ConnectFourState.rows * ConnectFourState.cols, ''),
        isMyTurn: false,
      );
    }
  }

  /// Drops my token in [col]. Returns the landing index if applied, or -1 if
  /// it's not my turn / the game is over / the column is full.
  int applyMove(int col) {
    if (state == null || !state!.isMyTurn || state!.winner != null) return -1;
    final idx = state!.landingIndex(col);
    if (idx < 0) return -1;
    final myMarker = state!.isChallenger ? 'R' : 'Y';
    final board = List<String>.from(state!.board);
    board[idx] = myMarker;
    state = state!.copyWith(board: board, isMyTurn: false, lastMoveIndex: idx);
    final w = state!.checkWinner();
    if (w != null) state = state!.copyWith(winner: w);
    return idx;
  }

  void onMoveReceived(int col) {
    if (state == null) return;
    final idx = state!.landingIndex(col);
    if (idx < 0) return;
    final opponentMarker = state!.isChallenger ? 'Y' : 'R';
    final board = List<String>.from(state!.board);
    board[idx] = opponentMarker;
    state = state!.copyWith(board: board, isMyTurn: true, lastMoveIndex: idx);
    final w = state!.checkWinner();
    if (w != null) state = state!.copyWith(winner: w);
  }

  void reset() {
    state = null;
  }
}

// ===========================================================================
// CABIN TRIVIA
// ===========================================================================

enum TriviaPhase {
  waitingForAccept,    // host: invite sent, waiting for opponent to accept
  waitingForQuestion,  // opponent: between rounds, waiting for host's question packet
  answering,           // both: timer running, accepting input
  waitingForOpponent,  // host: I answered, waiting for opponent answer packet
  waitingForResult,    // opponent: I answered, waiting for result packet from host
  showingResult,       // both: 2-second result display
  finished,            // game over
}

class TriviaGameState {
  final String gameId;
  final String opponentId;
  final String opponentName;
  final bool isHost;
  final int myScore;
  final int opponentScore;
  final int currentQuestionIndex;
  final int totalQuestions;
  final List<Map<String, dynamic>> questions; // host-owned shuffled list
  final Map<String, dynamic>? currentQuestion;
  final int? myAnswerIndex;           // null = not yet answered; -1 = timed out
  final int? opponentAnswerIndex;     // host tracks this; null until received
  final int? correctAnswerIndex;      // revealed during showingResult
  final TriviaPhase phase;

  const TriviaGameState({
    required this.gameId,
    required this.opponentId,
    required this.opponentName,
    required this.isHost,
    required this.myScore,
    required this.opponentScore,
    required this.currentQuestionIndex,
    required this.totalQuestions,
    required this.questions,
    this.currentQuestion,
    this.myAnswerIndex,
    this.opponentAnswerIndex,
    this.correctAnswerIndex,
    required this.phase,
  });

  TriviaGameState copyWith({
    String? gameId,
    String? opponentId,
    String? opponentName,
    bool? isHost,
    int? myScore,
    int? opponentScore,
    int? currentQuestionIndex,
    int? totalQuestions,
    List<Map<String, dynamic>>? questions,
    Map<String, dynamic>? currentQuestion,
    int? myAnswerIndex,
    int? opponentAnswerIndex,
    int? correctAnswerIndex,
    TriviaPhase? phase,
  }) {
    return TriviaGameState(
      gameId: gameId ?? this.gameId,
      opponentId: opponentId ?? this.opponentId,
      opponentName: opponentName ?? this.opponentName,
      isHost: isHost ?? this.isHost,
      myScore: myScore ?? this.myScore,
      opponentScore: opponentScore ?? this.opponentScore,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      questions: questions ?? this.questions,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      myAnswerIndex: myAnswerIndex ?? this.myAnswerIndex,
      opponentAnswerIndex: opponentAnswerIndex ?? this.opponentAnswerIndex,
      correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
      phase: phase ?? this.phase,
    );
  }
}

final triviaGameProvider =
    StateNotifierProvider<TriviaGameNotifier, TriviaGameState?>(
        (ref) => TriviaGameNotifier());

class TriviaGameNotifier extends StateNotifier<TriviaGameState?> {
  TriviaGameNotifier() : super(null);

  // ---------------------------------------------------------------------------
  // Called by UI — game initiation
  // ---------------------------------------------------------------------------

  /// HOST: called when the host sends the invite. Generates 10 shuffled questions.
  void startGame(String opponentId, String opponentName, String gameId) {
    final questions = TriviaQuestions.getShuffled(10);
    state = TriviaGameState(
      gameId: gameId,
      opponentId: opponentId,
      opponentName: opponentName,
      isHost: true,
      myScore: 0,
      opponentScore: 0,
      currentQuestionIndex: 0,
      totalQuestions: 10,
      questions: questions,
      phase: TriviaPhase.waitingForAccept,
    );
  }

  /// OPPONENT: called when opponent accepts (before navigating to TriviaScreen).
  void onOpponentJoined(String gameId, String peerId, String peerName) {
    state = TriviaGameState(
      gameId: gameId,
      opponentId: peerId,
      opponentName: peerName,
      isHost: false,
      myScore: 0,
      opponentScore: 0,
      currentQuestionIndex: 0,
      totalQuestions: 10,
      questions: const [],
      phase: TriviaPhase.waitingForQuestion,
    );
  }

  // ---------------------------------------------------------------------------
  // HOST-SIDE lifecycle (called by AppController or TriviaScreen)
  // ---------------------------------------------------------------------------

  /// HOST: called by AppController when accept packet arrives.
  /// Returns the first question to send (so AppController can send the packet).
  Map<String, dynamic>? onAcceptReceived() {
    if (state == null || !state!.isHost) return null;
    final question = state!.questions[0];
    state = state!.copyWith(
      currentQuestion: question,
      phase: TriviaPhase.answering,
      myAnswerIndex: null,
      opponentAnswerIndex: null,
    );
    return question;
  }

  /// HOST: called by AppController when opponent's answer packet arrives.
  /// Returns result payload to send if both answers are in; null otherwise.
  Map<String, dynamic>? onAnswerReceived(int selectedIndex) {
    if (state == null || !state!.isHost) return null;
    final updated = state!.copyWith(opponentAnswerIndex: selectedIndex);
    state = updated;
    return _tryScore();
  }

  /// HOST: called by TriviaScreen when the 20s absolute timeout fires.
  /// Force-scores opponent as timed out (-1).
  Map<String, dynamic>? forceOpponentTimeout() {
    if (state == null || !state!.isHost || state!.opponentAnswerIndex != null) return null;
    state = state!.copyWith(opponentAnswerIndex: -1);
    return _tryScore();
  }

  /// HOST: called by TriviaScreen after the 2s result display.
  /// Returns the next question map if there is one, or null if game is over.
  Map<String, dynamic>? advanceToNextQuestion() {
    if (state == null || !state!.isHost) return null;
    final nextIndex = state!.currentQuestionIndex + 1;
    if (nextIndex >= state!.totalQuestions) {
      state = state!.copyWith(phase: TriviaPhase.finished);
      return null; // caller sends 'end' packet
    }
    final nextQuestion = state!.questions[nextIndex];
    state = state!.copyWith(
      currentQuestionIndex: nextIndex,
      currentQuestion: nextQuestion,
      phase: TriviaPhase.answering,
      myAnswerIndex: null,
      opponentAnswerIndex: null,
      correctAnswerIndex: null,
    );
    return nextQuestion;
  }

  // ---------------------------------------------------------------------------
  // BOTH SIDES — answer submission
  // ---------------------------------------------------------------------------

  /// Both players call this when they tap an answer or the timer fires.
  ///
  /// - Opponent: returns [answerIndexToSend] — caller sends an 'answer' packet.
  /// - Host: if the opponent's answer had already arrived (the host-answers-
  ///   second race), scoring completes immediately and [resultToSend] carries
  ///   the payload the caller must send as a 'result' packet — otherwise the
  ///   opponent's screen hangs in "waiting for result" forever, since nothing
  ///   else would ever notify them.
  ({int? answerIndexToSend, Map<String, dynamic>? resultToSend}) submitAnswer(
      int answerIndex) {
    if (state == null || state!.phase != TriviaPhase.answering) {
      return (answerIndexToSend: null, resultToSend: null);
    }
    if (state!.myAnswerIndex != null) {
      return (answerIndexToSend: null, resultToSend: null); // already answered
    }

    if (state!.isHost) {
      // Host records locally; waits for opponent answer.
      state = state!.copyWith(
        myAnswerIndex: answerIndex,
        phase: TriviaPhase.waitingForOpponent,
      );
      // Opponent may have already answered before us — score immediately if so.
      final result = _tryScore();
      return (answerIndexToSend: null, resultToSend: result);
    } else {
      // Opponent records locally and signals caller to send packet.
      state = state!.copyWith(
        myAnswerIndex: answerIndex,
        phase: TriviaPhase.waitingForResult,
      );
      return (answerIndexToSend: answerIndex, resultToSend: null);
    }
  }

  /// Called by both submitAnswer paths when host. Attempts to compute score
  /// if both answers are present. Returns result payload or null.
  Map<String, dynamic>? _tryScore() {
    if (state == null || !state!.isHost) return null;
    if (state!.myAnswerIndex == null || state!.opponentAnswerIndex == null) return null;

    final correctIndex = state!.currentQuestion!['answer'] as int;
    final myCorrect = state!.myAnswerIndex == correctIndex;
    final opponentCorrect = state!.opponentAnswerIndex == correctIndex;
    final newMyScore = state!.myScore + (myCorrect ? 1 : 0);
    final newOpponentScore = state!.opponentScore + (opponentCorrect ? 1 : 0);

    state = state!.copyWith(
      myScore: newMyScore,
      opponentScore: newOpponentScore,
      correctAnswerIndex: correctIndex,
      phase: TriviaPhase.showingResult,
    );

    return {
      'correctIndex': correctIndex,
      'hostScore': newMyScore,
      'opponentScore': newOpponentScore,
      'hostAnswerIndex': state!.myAnswerIndex,
      'opponentAnswerIndex': state!.opponentAnswerIndex,
    };
  }

  // ---------------------------------------------------------------------------
  // OPPONENT-SIDE lifecycle (called by AppController)
  // ---------------------------------------------------------------------------

  /// OPPONENT: called by AppController when a question packet arrives.
  void onQuestionReceived(Map<String, dynamic> question, int questionIndex) {
    if (state == null) return;
    state = state!.copyWith(
      currentQuestion: question,
      currentQuestionIndex: questionIndex,
      phase: TriviaPhase.answering,
      myAnswerIndex: null,
      opponentAnswerIndex: null,
      correctAnswerIndex: null,
    );
  }

  /// OPPONENT: called by AppController when result packet arrives.
  void onResultReceived({
    required int correctIndex,
    required int hostScore,
    required int opponentScore,
    required int hostAnswerIndex,
    required int opponentAnswerIndex,
  }) {
    if (state == null) return;
    // For opponent: "my" score = opponentScore, "their" score = hostScore
    state = state!.copyWith(
      myScore: opponentScore,
      opponentScore: hostScore,
      correctAnswerIndex: correctIndex,
      myAnswerIndex: opponentAnswerIndex,
      opponentAnswerIndex: hostAnswerIndex,
      phase: TriviaPhase.showingResult,
    );
  }

  /// OPPONENT: called by TriviaScreen after the 2s result display.
  void acknowledgeResult() {
    if (state == null) return;
    final nextIndex = state!.currentQuestionIndex + 1;
    if (nextIndex >= state!.totalQuestions) {
      state = state!.copyWith(phase: TriviaPhase.finished);
    } else {
      state = state!.copyWith(
        phase: TriviaPhase.waitingForQuestion,
        currentQuestion: null,
        myAnswerIndex: null,
        opponentAnswerIndex: null,
        correctAnswerIndex: null,
      );
    }
  }

  /// Called by AppController when end packet arrives.
  void onGameEnded({required int hostScore, required int opponentScore}) {
    if (state == null) return;
    state = state!.copyWith(
      myScore: state!.isHost ? hostScore : opponentScore,
      opponentScore: state!.isHost ? opponentScore : hostScore,
      phase: TriviaPhase.finished,
    );
  }

  /// Timer expired — auto-submit -1 (timed out). Same return contract as
  /// [submitAnswer], which this delegates to.
  ({int? answerIndexToSend, Map<String, dynamic>? resultToSend})
      onTimerExpired() {
    return submitAnswer(-1);
  }

  void reset() {
    state = null;
  }
}
