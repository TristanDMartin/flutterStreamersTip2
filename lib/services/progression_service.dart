import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'progression_push_notification_service.dart';

class ProgressionTaskIds {
  const ProgressionTaskIds._();

  static const String profileCompleted = 'profileCompleted';
  static const String firstPostCreated = 'firstPostCreated';
  static const String firstCommentMade = 'firstCommentMade';
  static const String firstBookmarkSaved = 'firstBookmarkSaved';
  static const String firstConnectionMade = 'firstConnectionMade';
  static const String firstLikeGiven = 'firstLikeGiven';
  static const String firstMessageSent = 'firstMessageSent';

  static const List<String> all = <String>[
    profileCompleted,
    firstPostCreated,
    firstCommentMade,
    firstBookmarkSaved,
    firstConnectionMade,
    firstLikeGiven,
    firstMessageSent,
  ];
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class ProgressionTask {
  const ProgressionTask({
    required this.id,
    required this.title,
    required this.xpReward,
    required this.priority,
    this.source = 'account_evidence',
    this.hidden = false,
  });

  final String id;
  final String title;
  final int xpReward;
  final int priority;
  final String source;
  final bool hidden;
}

class ProgressionTaskState {
  const ProgressionTaskState({
    required this.taskId,
    required this.completed,
    this.xpReward = 0,
    this.completedAt,
    this.source,
  });

  final String taskId;
  final bool completed;
  final int xpReward;
  final DateTime? completedAt;
  final String? source;

  factory ProgressionTaskState.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final Object? completedAt = data['completedAt'];
    return ProgressionTaskState(
      taskId: (data['taskId'] as String?) ?? doc.id,
      completed: data['completed'] as bool? ?? false,
      xpReward: _readInt(data['xpReward']) ??
          ProgressionService.taskById(doc.id)?.xpReward ??
          0,
      completedAt: completedAt is Timestamp ? completedAt.toDate() : null,
      source: data['source'] as String?,
    );
  }
}

class UserProgressionSnapshot {
  const UserProgressionSnapshot(this.tasks);

  final Map<String, ProgressionTaskState> tasks;

  bool isCompleted(String taskId) => tasks[taskId]?.completed ?? false;

  Set<String> get completedTaskIds => tasks.entries
      .where((entry) => entry.value.completed)
      .map((entry) => entry.key)
      .toSet();
}

class ProgressionService {
  ProgressionService._({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  static final ProgressionService instance = ProgressionService._();

  static const List<ProgressionTask> allTasks = <ProgressionTask>[
    ProgressionTask(
      id: ProgressionTaskIds.profileCompleted,
      title: 'Complete your profile setup',
      xpReward: 50,
      priority: 10,
      source: 'users',
    ),
    ProgressionTask(
      id: ProgressionTaskIds.firstPostCreated,
      title: 'Upload your first post',
      xpReward: 50,
      priority: 20,
      source: 'videos',
    ),
    ProgressionTask(
      id: ProgressionTaskIds.firstConnectionMade,
      title: 'Make your first connection',
      xpReward: 50,
      priority: 30,
      source: 'connections',
    ),
    ProgressionTask(
      id: ProgressionTaskIds.firstCommentMade,
      title: 'Leave your first comment',
      xpReward: 50,
      priority: 40,
      source: 'comments',
    ),
    ProgressionTask(
      id: ProgressionTaskIds.firstBookmarkSaved,
      title: 'Save your first post',
      xpReward: 50,
      priority: 50,
      source: 'bookmarks',
    ),
    ProgressionTask(
      id: ProgressionTaskIds.firstLikeGiven,
      title: 'Like your first post',
      xpReward: 50,
      priority: 60,
      source: 'likes',
    ),
    ProgressionTask(
      id: ProgressionTaskIds.firstMessageSent,
      title: 'Send your first message',
      xpReward: 50,
      priority: 70,
      source: 'messages',
    ),
  ];

  static ProgressionTask? taskById(String taskId) {
    for (final ProgressionTask task in allTasks) {
      if (task.id == taskId) return task;
    }
    return null;
  }

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final StreamController<String> _optimisticController =
      StreamController<String>.broadcast();
  final Map<String, Map<String, ProgressionTaskState>> _optimisticTasksByUid =
      <String, Map<String, ProgressionTaskState>>{};
  final Map<String, Future<UserProgressionSnapshot>> _refreshInFlight =
      <String, Future<UserProgressionSnapshot>>{};
  final Map<String, DateTime> _lastRefreshStartedAt = <String, DateTime>{};

  CollectionReference<Map<String, dynamic>> _progressionCollection(
    String uid,
  ) {
    return _firestore.collection('users').doc(uid).collection('progression');
  }

  DocumentReference<Map<String, dynamic>> _userDocument(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  HttpsCallable get _progressionCallable =>
      _functions.httpsCallable('progressionSync');

  Stream<UserProgressionSnapshot> listenToProgress(String uid) {
    late StreamController<UserProgressionSnapshot> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? remoteSub;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? summarySub;
    StreamSubscription<String>? optimisticSub;
    Map<String, ProgressionTaskState> remoteTasks =
        <String, ProgressionTaskState>{};
    Map<String, ProgressionTaskState>? summaryTasks;
    bool isRemoteReady = false;
    bool isSummaryReady = false;

    void emit() {
      if (controller.isClosed) return;
      // Wait for at least one Firestore source so we never flash an empty
      // snapshot (which looks like "all incomplete" then "Setup complete").
      if (!isRemoteReady && !isSummaryReady) return;
      if (summaryTasks == null && !isRemoteReady) return;
      controller.add(UserProgressionSnapshot(<String, ProgressionTaskState>{
        ...(summaryTasks ?? remoteTasks),
        ...?_optimisticTasksByUid[uid],
      }));
    }

    controller = StreamController<UserProgressionSnapshot>.broadcast(
      onListen: () {
        remoteSub = _progressionCollection(uid).snapshots().listen(
          (QuerySnapshot<Map<String, dynamic>> snapshot) {
            remoteTasks = <String, ProgressionTaskState>{
              for (final doc in snapshot.docs)
                doc.id: ProgressionTaskState.fromDoc(doc),
            };
            isRemoteReady = true;
            emit();
          },
          onError: controller.addError,
        );
        summarySub = _userDocument(uid).snapshots().listen(
          (DocumentSnapshot<Map<String, dynamic>> snapshot) {
            summaryTasks = _tasksFromSummary(snapshot.data());
            isSummaryReady = true;
            emit();
          },
          onError: controller.addError,
        );
        optimisticSub =
            _optimisticController.stream.listen((String changedUid) {
          if (changedUid == uid) {
            emit();
          }
        });
      },
      onCancel: () async {
        await remoteSub?.cancel();
        await summarySub?.cancel();
        await optimisticSub?.cancel();
      },
    );
    return controller.stream;
  }

  Future<UserProgressionSnapshot> getUserProgress(String uid) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> userSnapshot =
          await _userDocument(uid).get();
      final Map<String, ProgressionTaskState>? summaryTasks =
          _tasksFromSummary(userSnapshot.data());
      if (summaryTasks != null) {
        return UserProgressionSnapshot(summaryTasks);
      }
      final snapshot = await _progressionCollection(uid).get();
      return UserProgressionSnapshot(<String, ProgressionTaskState>{
        for (final doc in snapshot.docs)
          doc.id: ProgressionTaskState.fromDoc(doc),
      });
    } catch (e) {
      debugPrint('ProgressionService getUserProgress skipped: $e');
      return const UserProgressionSnapshot(<String, ProgressionTaskState>{});
    }
  }

  Map<String, ProgressionTaskState>? _tasksFromSummary(
    Map<String, dynamic>? userData,
  ) {
    final Object? rawSummary = userData?['progressionSummary'];
    final Map<String, dynamic>? summary =
        rawSummary is Map ? Map<String, dynamic>.from(rawSummary) : null;
    final Object? rawCompleted = summary?['completedTaskIds'];
    if (rawCompleted is! Iterable) return null;

    final Set<String> completedTaskIds = rawCompleted
        .whereType<String>()
        .where((String id) => taskById(id) != null)
        .toSet();
    final Map<String, ProgressionTaskState> tasks =
        <String, ProgressionTaskState>{};
    for (final ProgressionTask task in allTasks) {
      final bool completed = completedTaskIds.contains(task.id);
      tasks[task.id] = ProgressionTaskState(
        taskId: task.id,
        completed: completed,
        xpReward: task.xpReward,
        completedAt: completed ? _summaryUpdatedAt(summary) : null,
        source: task.source,
      );
    }
    return tasks;
  }

  DateTime? _summaryUpdatedAt(Map<String, dynamic>? summary) {
    final Object? updatedAt = summary?['updatedAt'];
    return updatedAt is Timestamp ? updatedAt.toDate() : null;
  }

  Future<List<ProgressionTask>> getActiveTasks(String uid) async {
    final UserProgressionSnapshot snapshot = await getUserProgress(uid);
    return activeTasksForSnapshot(snapshot);
  }

  Future<List<ProgressionTask>> getCompletedTasks(String uid) async {
    final UserProgressionSnapshot snapshot = await getUserProgress(uid);
    return completedTasksForSnapshot(snapshot);
  }

  List<ProgressionTask> activeTasksForSnapshot(
    UserProgressionSnapshot? snapshot,
  ) {
    final Set<String> completedTaskIds =
        snapshot?.completedTaskIds ?? const <String>{};
    return allTasks
        .where(
          (ProgressionTask task) =>
              !task.hidden && !completedTaskIds.contains(task.id),
        )
        .toList()
      ..sort((ProgressionTask a, ProgressionTask b) =>
          a.priority.compareTo(b.priority));
  }

  List<ProgressionTask> completedTasksForSnapshot(
    UserProgressionSnapshot? snapshot,
  ) {
    final Set<String> completedTaskIds =
        snapshot?.completedTaskIds ?? const <String>{};
    return allTasks
        .where(
          (ProgressionTask task) =>
              !task.hidden && completedTaskIds.contains(task.id),
        )
        .toList()
      ..sort((ProgressionTask a, ProgressionTask b) =>
          a.priority.compareTo(b.priority));
  }

  Future<int> calculateTotalXP(String uid) async {
    final UserProgressionSnapshot snapshot = await getUserProgress(uid);
    return _calculateTotalXPFromSnapshot(snapshot);
  }

  int calculateLevel(int totalXP) {
    const List<int> floors = <int>[
      0,
      100,
      250,
      500,
      900,
      1400,
      2000,
      3000,
      4500,
      6500
    ];
    int level = 1;
    for (int i = 0; i < floors.length; i++) {
      if (totalXP >= floors[i]) {
        level = i + 1;
      }
    }
    return level;
  }

  String calculateRank(int level) {
    switch (level.clamp(1, 10)) {
      case 1:
        return 'New Creator';
      case 2:
        return 'Getting Started';
      case 3:
        return 'Rising Creator';
      case 4:
        return 'Consistent Creator';
      case 5:
        return 'Momentum Builder';
      case 6:
        return 'Community Builder';
      case 7:
        return 'Growth Creator';
      case 8:
        return 'Pro Creator';
      case 9:
        return 'Elite Creator';
      default:
        return 'Creator Legend';
    }
  }

  Future<void> dismissLevelUpModal(String uid) async {
    try {
      await _progressionCallable.call(<String, dynamic>{
        'action': 'dismissLevelUpModal',
      });
    } catch (e) {
      debugPrint('ProgressionService.dismissLevelUpModal: $e');
    }
  }

  Future<void> markTaskCompleted(
    String uid,
    String taskId, {
    String source = 'user_action',
  }) async {
    await completeTask(uid, taskId, source: source);
  }

  Future<void> completeTask(
    String uid,
    String taskId, {
    String? source,
  }) async {
    if (uid.trim().isEmpty || taskId.trim().isEmpty) return;
    final ProgressionTask? task = taskById(taskId);
    if (task == null || task.hidden) return;

    _markTaskCompletedOptimistically(
      uid,
      taskId,
      source: source ?? task.source,
    );

    try {
      final HttpsCallableResult<Object?> result =
          await _progressionCallable.call(<String, dynamic>{
        'action': 'completeTask',
        'taskId': taskId,
        'source': source ?? task.source,
      });
      final Object? progress =
          result.data is Map ? (result.data as Map)['progress'] : null;
      final Object? reason = progress is Map ? progress['reason'] : null;
      if (reason == 'evidence_not_found') {
        _clearOptimisticTask(uid, taskId);
      } else {
        unawaited(
          ProgressionPushNotificationService.instance
              .maybePromptAfterCreatorAction(uid),
        );
      }
    } catch (e) {
      _clearOptimisticTask(uid, taskId);
      debugPrint('ProgressionService completeTask skipped: $e');
    }
  }

  void _markTaskCompletedOptimistically(
    String uid,
    String taskId, {
    required String source,
  }) {
    _optimisticTasksByUid.putIfAbsent(
            uid, () => <String, ProgressionTaskState>{})[taskId] =
        ProgressionTaskState(
      taskId: taskId,
      completed: true,
      xpReward: taskById(taskId)?.xpReward ?? 0,
      completedAt: DateTime.now(),
      source: source,
    );
    _optimisticController.add(uid);
  }

  void _clearOptimisticTask(String uid, String taskId) {
    final Map<String, ProgressionTaskState>? optimisticTasks =
        _optimisticTasksByUid[uid];
    if (optimisticTasks == null) return;
    optimisticTasks.remove(taskId);
    if (optimisticTasks.isEmpty) {
      _optimisticTasksByUid.remove(uid);
    }
    _optimisticController.add(uid);
  }

  Future<void> recalculateLevelAndRank(String uid) async {
    if (uid.trim().isEmpty) return;
    await refreshUserProgress(uid);
  }

  Future<UserProgressionSnapshot> refreshUserProgress(String uid) async {
    if (uid.trim().isEmpty) {
      return const UserProgressionSnapshot(<String, ProgressionTaskState>{});
    }

    final DateTime now = DateTime.now();
    final DateTime? lastStarted = _lastRefreshStartedAt[uid];
    final Future<UserProgressionSnapshot>? inFlight = _refreshInFlight[uid];
    if (inFlight != null) {
      return inFlight;
    }
    if (lastStarted != null &&
        now.difference(lastStarted) < const Duration(seconds: 2)) {
      return getUserProgress(uid);
    }

    final Future<UserProgressionSnapshot> refresh =
        _refreshUserProgressNow(uid);
    _refreshInFlight[uid] = refresh;
    _lastRefreshStartedAt[uid] = now;
    refresh.whenComplete(() => _refreshInFlight.remove(uid));
    return refresh;
  }

  Future<UserProgressionSnapshot> _refreshUserProgressNow(String uid) async {
    try {
      await _progressionCallable.call(<String, dynamic>{
        'action': 'refresh',
      });
      return getUserProgress(uid);
    } catch (e) {
      debugPrint('ProgressionService refreshUserProgress skipped: $e');
      return getUserProgress(uid);
    }
  }

  int _calculateTotalXPFromSnapshot(UserProgressionSnapshot snapshot) {
    int total = 0;
    for (final MapEntry<String, ProgressionTaskState> entry
        in snapshot.tasks.entries) {
      if (!entry.value.completed) continue;
      total += entry.value.xpReward > 0
          ? entry.value.xpReward
          : taskById(entry.key)?.xpReward ?? 0;
    }
    return total;
  }
}
