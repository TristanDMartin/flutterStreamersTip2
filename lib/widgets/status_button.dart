import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_status.dart';
import '../providers/status_provider.dart';

class StatusButton extends ConsumerWidget {
  final bool showLabel;
  final double? size;
  final VoidCallback? onTap;

  const StatusButton({
    super.key,
    this.showLabel = true,
    this.size,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(statusNotifierProvider);
    final updateStatus = ref.read(updateStatusProvider);

    return statusAsync.when(
      data: (presence) => _buildStatusButton(
        context,
        presence.status,
        updateStatus,
      ),
      loading: () => _buildLoadingButton(context),
      error: (error, stack) => _buildErrorButton(context),
    );
  }

  Widget _buildStatusButton(
    BuildContext context,
    UserStatus status,
    void Function(UserStatus) updateStatus,
  ) {
    return GestureDetector(
      onTap: onTap ?? () => _showStatusPicker(context, status, updateStatus),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getStatusColor(status).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getStatusColor(status),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size ?? 8,
              height: size ?? 8,
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                shape: BoxShape.circle,
              ),
            ),
            if (showLabel) ...[
              const SizedBox(width: 6),
              Text(
                status.displayName,
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size ?? 8,
            height: size ?? 8,
            child: const CircularProgressIndicator(
              strokeWidth: 1,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 6),
            const Text(
              'Loading...',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size ?? 8,
            height: size ?? 8,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 6),
            const Text(
              'Error',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showStatusPicker(
    BuildContext context,
    UserStatus currentStatus,
    void Function(UserStatus) updateStatus,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatusPickerModal(
        currentStatus: currentStatus,
        onStatusSelected: (status) {
          updateStatus(status);
          Navigator.pop(context);
        },
      ),
    );
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return const Color(0xFF4CAF50); // Green
      case UserStatus.offline:
        return const Color(0xFF9E9E9E); // Grey
      case UserStatus.busy:
        return const Color(0xFFFF9800); // Orange
      case UserStatus.dnd:
        return const Color(0xFFF44336); // Red
      case UserStatus.streaming:
        return const Color(0xFF9C27B0); // Purple
    }
  }
}

class StatusPickerModal extends StatelessWidget {
  final UserStatus currentStatus;
  final Function(UserStatus) onStatusSelected;

  const StatusPickerModal({
    super.key,
    required this.currentStatus,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Text(
                    'Set Status',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Status options
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: UserStatus.values.asMap().entries.map((entry) {
                  final index = entry.key;
                  final status = entry.value;
                  final isSelected = status == currentStatus;
                  final isLast = index == UserStatus.values.length - 1;
                  return _buildStatusOption(
                    context,
                    status,
                    isSelected,
                    isLast,
                    () => onStatusSelected(status),
                  );
                }).toList(),
              ),
            ),

            // Extra bottom padding to prevent cutoff on devices with home indicators
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(
    BuildContext context,
    UserStatus status,
    bool isSelected,
    bool isLast,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.2)
              : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: Colors.white, width: 1) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getStatusColor(status),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _getStatusDescription(status),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check,
                color: Colors.white,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return const Color(0xFF4CAF50); // Green
      case UserStatus.offline:
        return const Color(0xFF9E9E9E); // Grey
      case UserStatus.busy:
        return const Color(0xFFFF9800); // Orange
      case UserStatus.dnd:
        return const Color(0xFFF44336); // Red
      case UserStatus.streaming:
        return const Color(0xFF9C27B0); // Purple
    }
  }

  String _getStatusDescription(UserStatus status) {
    switch (status) {
      case UserStatus.online:
        return 'Available to chat and receive notifications';
      case UserStatus.offline:
        return 'Appears offline to others';
      case UserStatus.busy:
        return 'Available but may be slow to respond';
      case UserStatus.dnd:
        return 'Do not disturb - no notifications';
      case UserStatus.streaming:
        return 'Currently live streaming';
    }
  }
}
