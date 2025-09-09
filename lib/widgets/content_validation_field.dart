import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/content_moderation_service.dart';

/// A text field with real-time content moderation validation
class ContentValidationField extends StatefulWidget {
  final String initialValue;
  final String hintText;
  final int maxLines;
  final int maxLength;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onValidationChanged;
  final bool enabled;

  const ContentValidationField({
    super.key,
    required this.initialValue,
    required this.hintText,
    required this.onChanged,
    required this.onValidationChanged,
    this.maxLines = 1,
    this.maxLength = 100,
    this.enabled = true,
  });

  @override
  State<ContentValidationField> createState() => _ContentValidationFieldState();
}

class _ContentValidationFieldState extends State<ContentValidationField> {
  late TextEditingController _controller;
  Timer? _debounceTimer;
  ModerationResult? _lastResult;
  bool _isValidating = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(ContentValidationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue) {
      _controller.text = widget.initialValue;
      print('🔍 ContentValidationField: Updated controller text to "${widget.initialValue}"');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    print('🔍 ContentValidationField: Text changed to "${_controller.text}"');
    widget.onChanged(_controller.text);
    
    // Cancel previous timer
    _debounceTimer?.cancel();
    
    // Start new timer for debounced validation
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _validateContent();
    });
  }

  Future<void> _validateContent() async {
    print('🔍 ContentValidationField: Validating "${_controller.text}"');
    
    if (_controller.text.trim().isEmpty) {
      print('🔍 ContentValidationField: Empty text, allowing');
      setState(() {
        _hasError = false;
        _errorMessage = null;
        _isValidating = false;
      });
      widget.onValidationChanged(true);
      return;
    }

    setState(() {
      _isValidating = true;
    });

    try {
      print('🔍 ContentValidationField: Calling ContentModerationService...');
      final result = await ContentModerationService().check(_controller.text);
      
      print('🔍 ContentValidationField: Result - isAllowed: ${result.isAllowed}, reason: ${result.reason}');
      
      setState(() {
        _lastResult = result;
        _hasError = !result.isAllowed;
        _errorMessage = result.reason;
        _isValidating = false;
      });
      
      widget.onValidationChanged(result.isAllowed);
    } catch (e) {
      print('🔍 ContentValidationField: Error during validation: $e');
      setState(() {
        _hasError = false;
        _errorMessage = null;
        _isValidating = false;
      });
      widget.onValidationChanged(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          style: const TextStyle(
            color: Colors.white, // Ensure text is visible
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _hasError ? Colors.red : Colors.grey,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: _hasError ? Colors.red : Theme.of(context).primaryColor,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.red),
            ),
            filled: true,
            fillColor: const Color(0xFF1C1C1E), // Dark background
            suffixIcon: _isValidating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : _hasError
                    ? const Icon(Icons.error, color: Colors.red)
                    : _controller.text.isNotEmpty
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
            errorText: _hasError ? _errorMessage : null,
          ),
        ),
        if (_hasError && _lastResult != null) ...[
          const SizedBox(height: 8),
          _buildErrorDetails(),
        ],
      ],
    );
  }

  Widget _buildErrorDetails() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 16),
              SizedBox(width: 8),
              Text(
                'Content Policy Violation',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'This content violates our community guidelines.',
            style: const TextStyle(color: Colors.red, fontSize: 13),
          ),
          if (_lastResult!.matchedTerms.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Issues found:',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _lastResult!.matchedTerms.map((term) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    term,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _showPolicyDetails,
                icon: const Icon(Icons.info_outline, size: 16),
                label: const Text('Why?'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _reportMistake,
                icon: const Icon(Icons.flag_outlined, size: 16),
                label: const Text('Report Mistake'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPolicyDetails() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildPolicySheet(),
    );
  }

  Widget _buildPolicySheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Content Policy',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'We prohibit content that includes:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          _buildPolicyItem(
            'Hate speech or slurs',
            'Language that attacks or demeans people based on race, ethnicity, religion, gender, sexual orientation, disability, or other protected characteristics.',
          ),
          _buildPolicyItem(
            'Violence or threats',
            'Calls for harm, violence, or dehumanization of individuals or groups.',
          ),
          _buildPolicyItem(
            'Harassment',
            'Derogatory insults or content aimed at intimidating or harassing individuals or groups.',
          ),
          _buildPolicyItem(
            'Workarounds',
            'Attempts to bypass filters using leetspeak, spacing, or special characters.',
          ),
          const SizedBox(height: 16),
          const Text(
            'Examples of prohibited content:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '• "All [group] are [slur]"\n'
            '• "I hate [protected group]"\n'
            '• "Kill all [group]"\n'
            '• "[Slur] people are [insult]"\n'
            '• "n1gg*r" or "g a y" (workarounds)',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _reportMistake() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report a Mistake'),
        content: const Text(
          'If you believe this content was incorrectly flagged, please provide additional context:',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement appeal submission
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Appeal submitted for review'),
                ),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
