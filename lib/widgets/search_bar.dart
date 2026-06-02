import 'package:flutter/material.dart';

class SearchBar extends StatefulWidget {
  final String text;
  final bool isSearching;
  final ValueChanged<String> onTextChanged;
  final VoidCallback? onCancel;

  const SearchBar({
    super.key,
    required this.text,
    required this.isSearching,
    required this.onTextChanged,
    this.onCancel,
  });

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late FocusNode _focusNode;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = TextEditingController(text: widget.text);

    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && widget.text.isEmpty) {
        widget.onTextChanged('');
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _controller.text = widget.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search,
                  color: Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: (value) {
                      widget.onTextChanged(value);
                    },
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search creators, categories...',
                      hintStyle: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (widget.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _controller.clear();
                      widget.onTextChanged('');
                    },
                    child: const Icon(
                      Icons.cancel,
                      color: Colors.grey,
                      size: 17,
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (widget.isSearching) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {
              _controller.clear();
              widget.onTextChanged('');
              _focusNode.unfocus();
              widget.onCancel?.call();
            },
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
