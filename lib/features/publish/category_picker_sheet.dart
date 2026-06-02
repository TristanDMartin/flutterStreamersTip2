import 'package:flutter/material.dart';

import '../../core/theme/support_shell_style.dart';
import '../../widgets/video_publishing_screen.dart';

Future<String?> showCategoryPickerSheet({
  required BuildContext context,
  required List<VideoCategory> categories,
  required String selectedCategoryId,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext sheetContext) {
      return _CategoryPickerSheet(
        categories: categories,
        selectedCategoryId: selectedCategoryId,
      );
    },
  );
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedCategoryId,
  });

  final List<VideoCategory> categories;
  final String selectedCategoryId;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late String _selected = widget.selectedCategoryId;
  String _query = '';

  List<VideoCategory> get _filtered {
    if (_query.trim().isEmpty) return widget.categories;
    final String q = _query.toLowerCase();
    return widget.categories
        .where(
          (VideoCategory c) =>
              c.name.toLowerCase().contains(q) ||
              c.id.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final TextTheme tt = Theme.of(context).textTheme;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: shell.iconDim,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Choose category',
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: shell.onChrome,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  onChanged: (String v) => setState(() => _query = v),
                  style: tt.bodyMedium?.copyWith(color: shell.onChrome),
                  decoration: InputDecoration(
                    hintText: 'Search categories…',
                    prefixIcon:
                        Icon(Icons.search_rounded, color: shell.iconDim),
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: shell.panelBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: shell.panelBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: _filtered.length,
                  itemBuilder: (BuildContext _, int index) {
                    final VideoCategory category = _filtered[index];
                    final bool isSelected = category.id == _selected;
                    return ListTile(
                      leading: Text(
                        category.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                      title: Text(
                        category.name,
                        style: tt.titleSmall?.copyWith(
                          color: shell.onChrome,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded, color: cs.primary)
                          : null,
                      onTap: () => setState(() => _selected = category.id),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('Done'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
