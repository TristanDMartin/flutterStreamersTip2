import 'package:flutter/material.dart';
import '../services/video_actions_service.dart';

const List<String> kBulkVideoCategories = <String>[
  'Gaming',
  'Art',
  'Music',
  'Tech',
  'Sports',
  'Food',
  'Travel',
  'Fashion',
  'Comedy',
  'Education',
  'Fitness',
  'Lifestyle',
  'Other',
];

/// Bulk metadata editor for multiple owned videos (no caption/media).
Future<bool> showBulkEditVideosSheet({
  required BuildContext context,
  required List<String> videoIds,
  required VideoActionsService actions,
}) async {
  if (videoIds.isEmpty) {
    return false;
  }
  String category = kBulkVideoCategories.first;
  String privacy = 'public';
  bool allowComments = true;
  bool applyCategory = true;
  bool applyPrivacy = true;
  bool applyComments = false;
  bool isSaving = false;
  String? error;
  int progress = 0;

  final bool? saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1C1C1E),
    builder: (BuildContext sheetContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Edit ${videoIds.length} videos',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Bulk update shared fields. Captions stay per-video.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: applyCategory,
                    onChanged: isSaving
                        ? null
                        : (bool? v) => setModalState(() {
                              applyCategory = v ?? false;
                            }),
                    title: const Text('Category',
                        style: TextStyle(color: Colors.white)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (applyCategory)
                    DropdownButton<String>(
                      value: category,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF2C2C2E),
                      items: kBulkVideoCategories
                          .map(
                            (String c) => DropdownMenuItem<String>(
                              value: c,
                              child: Text(c),
                            ),
                          )
                          .toList(),
                      onChanged: isSaving
                          ? null
                          : (String? v) {
                              if (v == null) return;
                              setModalState(() => category = v);
                            },
                      style: const TextStyle(color: Colors.white),
                    ),
                  CheckboxListTile(
                    value: applyPrivacy,
                    onChanged: isSaving
                        ? null
                        : (bool? v) => setModalState(() {
                              applyPrivacy = v ?? false;
                            }),
                    title: const Text('Visibility',
                        style: TextStyle(color: Colors.white)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (applyPrivacy)
                    Wrap(
                      spacing: 8,
                      children: <MapEntry<String, String>>[
                        const MapEntry<String, String>('public', 'Public'),
                        const MapEntry<String, String>(
                            'followers', 'Followers'),
                        const MapEntry<String, String>('private', 'Private'),
                      ]
                          .map(
                            (MapEntry<String, String> e) => ChoiceChip(
                              label: Text(e.value),
                              selected: privacy == e.key,
                              onSelected: isSaving
                                  ? null
                                  : (bool selected) {
                                      if (!selected) return;
                                      setModalState(() => privacy = e.key);
                                    },
                            ),
                          )
                          .toList(),
                    ),
                  CheckboxListTile(
                    value: applyComments,
                    onChanged: isSaving
                        ? null
                        : (bool? v) => setModalState(() {
                              applyComments = v ?? false;
                            }),
                    title: const Text('Comments',
                        style: TextStyle(color: Colors.white)),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (applyComments)
                    SwitchListTile(
                      value: allowComments,
                      onChanged: isSaving
                          ? null
                          : (bool v) =>
                              setModalState(() => allowComments = v),
                      title: const Text('Allow comments',
                          style: TextStyle(color: Colors.white)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  if (isSaving)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Updating $progress/${videoIds.length}…',
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving
                              ? null
                              : () => Navigator.pop(sheetContext, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!applyCategory &&
                                      !applyPrivacy &&
                                      !applyComments) {
                                    setModalState(() {
                                      error =
                                          'Select at least one field to update.';
                                    });
                                    return;
                                  }
                                  setModalState(() {
                                    isSaving = true;
                                    error = null;
                                    progress = 0;
                                  });
                                  try {
                                    for (final String id in videoIds) {
                                      await actions.updateVideoMetadata(
                                        videoId: id,
                                        category:
                                            applyCategory ? category : null,
                                        privacy:
                                            applyPrivacy ? privacy : null,
                                        allowComments: applyComments
                                            ? allowComments
                                            : null,
                                      );
                                      setModalState(() {
                                        progress += 1;
                                      });
                                    }
                                    if (sheetContext.mounted) {
                                      Navigator.pop(sheetContext, true);
                                    }
                                  } catch (_) {
                                    setModalState(() {
                                      isSaving = false;
                                      error =
                                          "Couldn't update videos. Try again.";
                                    });
                                  }
                                },
                          child: Text(isSaving ? 'Saving…' : 'Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  return saved == true;
}
