import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/upload_job.dart';
import '../services/upload_status_manager.dart';

class UploadStatusBar extends StatefulWidget {
  const UploadStatusBar({super.key});

  @override
  State<UploadStatusBar> createState() => _UploadStatusBarState();
}

class _UploadStatusBarState extends State<UploadStatusBar> {
  final UploadStatusManager _mgr = UploadStatusManager();

  @override
  void initState() {
    super.initState();
    _mgr.addListener(_rebuild);
  }

  @override
  void dispose() {
    _mgr.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_mgr.showStatusBar) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    switch (_mgr.currentState) {
      case UploadJobState.uploading:
      case UploadJobState.queued:
        return _UploadingCard(mgr: _mgr);
      case UploadJobState.processing:
        return _ProcessingCard(mgr: _mgr);
      case UploadJobState.ready:
      case UploadJobState.done:
        return _ReadyCard(mgr: _mgr);
      case UploadJobState.failed:
        return _FailedCard(mgr: _mgr);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Shared card shell ────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final Color borderColor;
  final List<Widget> children;

  const _StatusCard({required this.borderColor, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

// ─── Uploading ────────────────────────────────────────────────────────────────

class _UploadingCard extends StatelessWidget {
  final UploadStatusManager mgr;
  const _UploadingCard({required this.mgr});

  @override
  Widget build(BuildContext context) {
    final pct = (mgr.currentProgress * 100).toStringAsFixed(0);
    return _StatusCard(
      borderColor: const Color(0xFF9248D2),
      children: [
        Row(
          children: [
            const Icon(Icons.cloud_upload_outlined,
                color: Color(0xFF9248D2), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mgr.currentStatusMessage,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
            if (mgr.currentJobId != null)
              GestureDetector(
                onTap: () {
                  if (mgr.currentJobId != null) {
                    mgr.cancelUpload(mgr.currentJobId!);
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.close, color: Colors.white54, size: 18),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: mgr.currentProgress,
            minHeight: 4,
            backgroundColor: Colors.white12,
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$pct%',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// ─── Processing ───────────────────────────────────────────────────────────────

class _ProcessingCard extends StatelessWidget {
  final UploadStatusManager mgr;
  const _ProcessingCard({required this.mgr});

  @override
  Widget build(BuildContext context) {
    return _StatusCard(
      borderColor: const Color(0xFF9248D2),
      children: [
        Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Color(0xFF9248D2)),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Processing your video...',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
            GestureDetector(
              onTap: mgr.dismissStatusBar,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close, color: Colors.white38, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          "You can leave — we'll notify you when it's live.",
          style: TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}

// ─── Ready ────────────────────────────────────────────────────────────────────

class _ReadyCard extends StatelessWidget {
  final UploadStatusManager mgr;
  const _ReadyCard({required this.mgr});

  @override
  Widget build(BuildContext context) {
    return _StatusCard(
      borderColor: Colors.greenAccent,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mgr.thumbnailUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CachedNetworkImage(
                  imageUrl: mgr.thumbnailUrl!,
                  width: 44,
                  height: 60,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const _ThumbnailPlaceholder(),
                  placeholder: (_, __) => const _ThumbnailPlaceholder(),
                ),
              )
            else
              const _ThumbnailPlaceholder(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your video is live 🎉',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap View to see it on your profile.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _PillButton(
                        label: 'View',
                        color: const Color(0xFF9248D2),
                        onTap: () {
                          mgr.dismissStatusBar();
                          // Navigation to profile handled at the app level.
                        },
                      ),
                      const SizedBox(width: 8),
                      _PillButton(
                        label: 'Dismiss',
                        color: Colors.white24,
                        onTap: mgr.dismissStatusBar,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Failed ───────────────────────────────────────────────────────────────────

class _FailedCard extends StatelessWidget {
  final UploadStatusManager mgr;
  const _FailedCard({required this.mgr});

  @override
  Widget build(BuildContext context) {
    return _StatusCard(
      borderColor: Colors.redAccent,
      children: [
        Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                mgr.errorMessage ?? 'Upload failed',
                style: const TextStyle(color: Colors.white, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: mgr.dismissStatusBar,
              child: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.close, color: Colors.white38, size: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _PillButton(
              label: 'Retry',
              color: Colors.redAccent,
              onTap: mgr.retryUpload,
            ),
            const SizedBox(width: 8),
            _PillButton(
              label: 'Dismiss',
              color: Colors.white24,
              onTap: mgr.dismissStatusBar,
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Icon(Icons.movie, color: Colors.white38, size: 20),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PillButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
