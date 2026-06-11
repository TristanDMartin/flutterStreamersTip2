import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SupportTicketsState {
  final int totalTickets;
  final int pendingTickets;
  final int inProgressTickets;
  final int resolvedTickets;
  final bool isLoading;

  const SupportTicketsState({
    this.totalTickets = 0,
    this.pendingTickets = 0,
    this.inProgressTickets = 0,
    this.resolvedTickets = 0,
    this.isLoading = false,
  });

  SupportTicketsState copyWith({
    int? totalTickets,
    int? pendingTickets,
    int? inProgressTickets,
    int? resolvedTickets,
    bool? isLoading,
  }) {
    return SupportTicketsState(
      totalTickets: totalTickets ?? this.totalTickets,
      pendingTickets: pendingTickets ?? this.pendingTickets,
      inProgressTickets: inProgressTickets ?? this.inProgressTickets,
      resolvedTickets: resolvedTickets ?? this.resolvedTickets,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SupportTicketsNotifier extends StateNotifier<SupportTicketsState> {
  SupportTicketsNotifier() : super(const SupportTicketsState()) {
    _listenToTickets();
  }

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _listenToTickets() {
    _db
        .collection('support_tickets')
        .orderBy(FieldPath.documentId)
        .limit(500)
        .snapshots()
        .listen(
      (snapshot) {
      final tickets = snapshot.docs;

      int pending = 0;
      int inProgress = 0;
      int resolved = 0;

      for (var doc in tickets) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'pending';

        switch (status) {
          case 'pending':
            pending++;
            break;
          case 'in_progress':
            inProgress++;
            break;
          case 'resolved':
            resolved++;
            break;
        }
      }

      state = state.copyWith(
        totalTickets: tickets.length,
        pendingTickets: pending,
        inProgressTickets: inProgress,
        resolvedTickets: resolved,
      );
    },
      onError: (Object error) {
        debugPrint('support_tickets listen error: $error');
      },
    );
  }

  bool hasPendingTickets() {
    return state.pendingTickets > 0;
  }
}

final supportTicketsProvider =
    StateNotifierProvider<SupportTicketsNotifier, SupportTicketsState>(
  (ref) => SupportTicketsNotifier(),
);
