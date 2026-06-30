import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/design/st_radius.dart';
import '../core/design/st_spacing.dart';
import '../core/theme/support_shell_style.dart';
import '../models/home_video.dart';
import '../routing/app_navigator.dart';
import '../services/video_deletion_service.dart';
import '../services/video_unavailable_service.dart';
import '../widgets/player_screen.dart';
import '../widgets/optimized_thumbnail.dart';

/// Full-screen unavailable state — no profile dropdown in header.
class VideoUnavailablePage extends ConsumerStatefulWidget {
  const VideoUnavailablePage({
    super.key,
    required this.videoId,
    this.creatorId,
    this.creatorName,
    this.creatorUsername,
  });

  final String videoId;
  final String? creatorId;
  final String? creatorName;
  final String? creatorUsername;

  @override
  ConsumerState<VideoUnavailablePage> createState() =>
      _VideoUnavailablePageState();
}

class _VideoUnavailablePageState extends ConsumerState<VideoUnavailablePage> {
  VideoUnavailableContext? _context;
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final VideoUnavailableContext? ctx =
          await VideoUnavailableService.instance.loadContext(widget.videoId);
      if (!mounted) {
        return;
      }
      setState(() {
        _context = ctx;
        _isLoading = false;
        _error = ctx == null ? 'Video not found' : null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = 'Unable to load video';
      });
    }
  }

  Future<void> _deleteVideo() async {
    final VideoUnavailableContext? ctx = _context;
    if (ctx == null || !ctx.canDelete || _isDeleting) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete video?'),
          content: const Text(
            'This removes the video everywhere, including related thread posts.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _isDeleting = true);
    try {
      await ref.read(videoDeletionServiceProvider).deleteVideo(
            widget.videoId,
            source: 'unavailable_page',
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: shell.scaffold,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _SimpleBackHeader(shell: shell),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: cs.primary),
                    )
                  : _error != null
                      ? _CenteredMessage(
                          shell: shell,
                          title: 'Video unavailable',
                          subtitle: _error!,
                          onGoBack: () => Navigator.maybePop(context),
                        )
                      : LayoutBuilder(
                          builder: (
                            BuildContext context,
                            BoxConstraints constraints,
                          ) {
                            final bool wide = constraints.maxWidth >= 900;
                            if (wide) {
                              return Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _CenteredMessage(
                                      shell: shell,
                                      title: 'Video unavailable',
                                      subtitle:
                                          'This video has been removed or is no longer available.',
                                      onGoBack: () =>
                                          Navigator.maybePop(context),
                                      canDelete: _context!.canDelete,
                                      isDeleting: _isDeleting,
                                      onDelete: _deleteVideo,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 360,
                                    child: _DetailsPanel(
                                      contextData: _context!,
                                      shell: shell,
                                      onOpenCreator: _openCreator,
                                      onOpenVideo: _openVideo,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return SingleChildScrollView(
                              padding: const EdgeInsets.all(STSpacing.lg),
                              child: Column(
                                children: <Widget>[
                                  _CenteredMessage(
                                    shell: shell,
                                    title: 'Video unavailable',
                                    subtitle:
                                        'This video has been removed or is no longer available.',
                                    onGoBack: () => Navigator.maybePop(context),
                                    canDelete: _context!.canDelete,
                                    isDeleting: _isDeleting,
                                    onDelete: _deleteVideo,
                                  ),
                                  const SizedBox(height: STSpacing.xxl),
                                  _DetailsPanel(
                                    contextData: _context!,
                                    shell: shell,
                                    onOpenCreator: _openCreator,
                                    onOpenVideo: _openVideo,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCreator() {
    final VideoUnavailableContext? ctx = _context;
    if (ctx?.creatorId == null || ctx!.creatorId!.isEmpty) {
      return;
    }
    AppNavigator.openProfile(
      context,
      user: VideoUnavailableService.instance.buildCreatorUser(ctx),
      isCurrentUser: false,
    );
  }

  void _openVideo(HomeVideo video) {
    AppNavigator.openPlayer(
      context,
      mode: PlayerMode.homeFeed,
      initialIndex: 0,
      videoIds: <String>[video.id],
      videos: <HomeVideo>[video],
    );
  }
}

class _SimpleBackHeader extends StatelessWidget {
  const _SimpleBackHeader({required this.shell});

  final StSupportShellStyle shell;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back_rounded, color: shell.onChrome),
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.shell,
    required this.title,
    required this.subtitle,
    required this.onGoBack,
    this.canDelete = false,
    this.isDeleting = false,
    this.onDelete,
  });

  final StSupportShellStyle shell;
  final String title;
  final String subtitle;
  final VoidCallback onGoBack;
  final bool canDelete;
  final bool isDeleting;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(STSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.asset(
                'assets/logo.png',
                width: 72,
                height: 72,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.play_circle_fill_rounded,
                  size: 72,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: STSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: shell.onChrome,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: STSpacing.sm),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: shell.muted,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: STSpacing.xxl),
              FilledButton(
                onPressed: onGoBack,
                child: const Text('Go back'),
              ),
              if (canDelete && onDelete != null) ...<Widget>[
                const SizedBox(height: STSpacing.md),
                TextButton(
                  onPressed: isDeleting ? null : onDelete,
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                  child: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Delete video'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    required this.contextData,
    required this.shell,
    required this.onOpenCreator,
    required this.onOpenVideo,
  });

  final VideoUnavailableContext contextData;
  final StSupportShellStyle shell;
  final VoidCallback onOpenCreator;
  final void Function(HomeVideo video) onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String? uploadedLabel = contextData.uploadedAt == null
        ? null
        : DateFormat.yMMMd().format(contextData.uploadedAt!);

    return Padding(
      padding: const EdgeInsets.all(STSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'About this video',
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: STSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(STSpacing.lg),
            decoration: BoxDecoration(
              color: shell.surfaceCard,
              borderRadius: BorderRadius.circular(STRadius.xxl),
              border: Border.all(color: shell.surfaceCardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'This video has been removed by the creator or is no longer available.',
                  style: TextStyle(color: shell.muted, height: 1.45),
                ),
                if (contextData.creatorName != null) ...<Widget>[
                  const SizedBox(height: STSpacing.md),
                  _MetaRow(
                    label: 'Creator',
                    value: contextData.creatorName!,
                    shell: shell,
                  ),
                ],
                if (contextData.category != null) ...<Widget>[
                  const SizedBox(height: STSpacing.sm),
                  _MetaRow(
                    label: 'Category',
                    value: contextData.category!,
                    shell: shell,
                  ),
                ],
                const SizedBox(height: STSpacing.sm),
                _MetaRow(
                  label: 'Status',
                  value: 'Removed',
                  shell: shell,
                ),
                if (uploadedLabel != null) ...<Widget>[
                  const SizedBox(height: STSpacing.sm),
                  _MetaRow(
                    label: 'Uploaded previously',
                    value: uploadedLabel,
                    shell: shell,
                  ),
                ],
                const SizedBox(height: STSpacing.lg),
                Wrap(
                  spacing: STSpacing.sm,
                  runSpacing: STSpacing.sm,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: () => Navigator.maybePop(context),
                      child: const Text('Go back'),
                    ),
                    if (contextData.creatorId != null &&
                        contextData.creatorId!.isNotEmpty)
                      OutlinedButton(
                        onPressed: onOpenCreator,
                        child: const Text('View creator profile'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: STSpacing.xxl),
          Text(
            'More from this creator',
            style: TextStyle(
              color: shell.onChrome,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: STSpacing.md),
          if (contextData.moreFromCreator.isEmpty)
            Text(
              'No other videos from this creator are available right now.',
              style: TextStyle(color: shell.muted),
            )
          else
            ...contextData.moreFromCreator.map(
              (HomeVideo video) => Padding(
                padding: const EdgeInsets.only(bottom: STSpacing.md),
                child: Material(
                  color: shell.surfaceCard,
                  borderRadius: BorderRadius.circular(STRadius.lg),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(STRadius.lg),
                    onTap: () => onOpenVideo(video),
                    child: Container(
                      padding: const EdgeInsets.all(STSpacing.sm),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(STRadius.lg),
                        border: Border.all(color: shell.surfaceCardBorder),
                      ),
                      child: Row(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(STRadius.md),
                            child: SizedBox(
                              width: 72,
                              height: 96,
                              child: OptimizedThumbnail(
                                video: video,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: STSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  video.caption.isNotEmpty
                                      ? video.caption
                                      : 'Untitled video',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: shell.onChrome,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (video.categoryId.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(
                                    video.categoryId,
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  '${video.views} views',
                                  style: TextStyle(
                                    color: shell.muted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    required this.shell,
  });

  final String label;
  final String value;
  final StSupportShellStyle shell;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: TextStyle(color: shell.mutedStrong, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: shell.onChrome, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
