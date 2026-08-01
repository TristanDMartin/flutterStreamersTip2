import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/support_shell_style.dart';
import 'approval_queue_contract.dart';
import 'approval_queue_models.dart';
import 'approval_queue_service.dart';

class ApprovalReviewArgs {
  const ApprovalReviewArgs({
    required this.requestId,
    required this.workspaceId,
  });

  final String requestId;
  final String workspaceId;
}

/// Mobile Approval Queue detail + decide (buttons; swipe optional later).
class ApprovalReviewView extends StatefulWidget {
  const ApprovalReviewView({
    super.key,
    required this.requestId,
    required this.workspaceId,
  });

  final String requestId;
  final String workspaceId;

  @override
  State<ApprovalReviewView> createState() => _ApprovalReviewViewState();
}

class _ApprovalReviewViewState extends State<ApprovalReviewView> {
  final ApprovalQueueService _service = ApprovalQueueService();
  ApprovalQueueRequest? _request;
  String? _error;
  bool _loading = true;
  bool _deciding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ApprovalQueueRequest request = await _service.fetchApprovalDetail(
        workspaceId: widget.workspaceId,
        requestId: widget.requestId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _request = request;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _decide(String decision) async {
    final ApprovalQueueRequest? request = _request;
    if (request == null || _deciding) {
      return;
    }
    if (request.contentVersionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing content version. Refresh and retry.')),
      );
      return;
    }
    String? reasonCode;
    String? notes;
    if (decision == 'changes_requested' || decision == 'rejected') {
      final ({String? reasonCode, String? notes})? sheet =
          await _showReasonSheet(decision);
      if (sheet == null) {
        return;
      }
      reasonCode = sheet.reasonCode;
      notes = sheet.notes;
    }
    setState(() => _deciding = true);
    try {
      final ApprovalDecideResult result = await _service.decideApproval(
        workspaceId: widget.workspaceId,
        requestId: request.id,
        decision: decision,
        contentVersionId: request.contentVersionId,
        reasonCode: reasonCode,
        notes: notes,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'approved'
                ? 'Approved. ${result.remainingApprovals} left in queue.'
                : decision == 'changes_requested'
                    ? 'Changes requested.'
                    : 'Rejected.',
          ),
        ),
      );
      Navigator.of(context).pop(result);
    } on ApprovalQueueException catch (error) {
      if (!mounted) {
        return;
      }
      if (error.isVersionConflict) {
        await _load();
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) {
        setState(() => _deciding = false);
      }
    }
  }

  Future<({String? reasonCode, String? notes})?> _showReasonSheet(
    String decision,
  ) async {
    String? selected = kApprovalReasonChoices.first.value;
    final TextEditingController notesController = TextEditingController();
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    decision == 'rejected'
                        ? 'Reject approval'
                        : 'Request changes',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kApprovalReasonChoices.map(
                      (({String value, String label}) choice) {
                        final bool selectedChip = selected == choice.value;
                        return ChoiceChip(
                          label: Text(choice.label),
                          selected: selectedChip,
                          onSelected: (_) {
                            setModalState(() => selected = choice.value);
                          },
                        );
                      },
                    ).toList(growable: false),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Submit'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    final String? reason = selected;
    final String notes = notesController.text;
    notesController.dispose();
    if (saved != true) {
      return null;
    }
    return (reasonCode: reason, notes: notes);
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Scaffold(
      backgroundColor: shell.scaffold,
      appBar: AppBar(
        backgroundColor: shell.scaffold,
        foregroundColor: shell.onChrome,
        title: const Text('Approval review'),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: shell.pageGradient,
          ),
        ),
        child: _buildBody(shell),
      ),
    );
  }

  Widget _buildBody(StSupportShellStyle shell) {
    if (_loading && _request == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _request == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_error!, style: TextStyle(color: shell.mutedStrong)),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final ApprovalQueueRequest request = _request!;
    final ApprovalQueueSnapshot snap = request.snapshot;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        if (snap.thumbnailUrl != null && snap.thumbnailUrl!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: CachedNetworkImage(
                imageUrl: snap.thumbnailUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: shell.panelSurface,
                  alignment: Alignment.center,
                  child: Icon(Icons.videocam_off, color: shell.muted),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          request.title,
          style: TextStyle(
            color: shell.onChrome,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${request.status.replaceAll('_', ' ')}'
          '${request.priority == null ? '' : ' · ${request.priority}'}',
          style: TextStyle(color: shell.mutedStrong),
        ),
        if (snap.platforms.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Platforms: ${snap.platforms.join(', ')}',
            style: TextStyle(color: shell.muted),
          ),
        ],
        if (snap.caption != null && snap.caption!.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            snap.caption!,
            style: TextStyle(color: shell.onChrome, height: 1.4),
          ),
        ],
        if (snap.proposedScheduledAt != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            'Proposed: ${snap.proposedScheduledAt}',
            style: TextStyle(color: shell.muted),
          ),
        ],
        const SizedBox(height: 24),
        if (!request.isPending)
          Text(
            'This approval is already ${request.status.replaceAll('_', ' ')}.',
            style: TextStyle(color: shell.mutedStrong),
          )
        else ...<Widget>[
          FilledButton(
            onPressed: _deciding ? null : () => _decide('approved'),
            child: Text(_deciding ? 'Saving…' : 'Approve'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _deciding ? null : () => _decide('changes_requested'),
            child: const Text('Request changes'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _deciding ? null : () => _decide('rejected'),
            child: Text(
              'Reject',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ],
    );
  }
}
