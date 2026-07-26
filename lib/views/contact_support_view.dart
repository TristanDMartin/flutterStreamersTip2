import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import '../constants/app_colors.dart';
import '../core/theme/support_shell_style.dart';
import '../utils/user_facing_error.dart';
import '../widgets/screen_feedback_state.dart';

class ContactSupportView extends StatefulWidget {
  const ContactSupportView({super.key});

  @override
  State<ContactSupportView> createState() => _ContactSupportViewState();
}

class _ContactSupportViewState extends State<ContactSupportView> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedCategory = 'General';
  bool _isSubmitting = false;
  String? _actionError;

  final List<String> _categories = [
    'General',
    'Technical Issue',
    'Account Issue',
    'Payment/Billing',
    'Bug Report',
    'Feature Request',
    'Report User',
    'Other'
  ];

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = fa.FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          _showError('You must be logged in to submit a ticket');
        }
        return;
      }

      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();

      // Create support ticket
      await FirebaseFirestore.instance.collection('support_tickets').add({
        'userId': user.uid,
        'username': userData?['username'] ?? 'Unknown',
        'displayName':
            userData?['displayName'] ?? user.displayName ?? 'Unknown',
        'email': user.email ?? '',
        'category': _selectedCategory,
        'subject': _subjectController.text,
        'message': _messageController.text,
        'status': 'pending',
        'priority': _selectedCategory == 'Bug Report' ||
                _selectedCategory == 'Technical Issue'
            ? 'high'
            : 'medium',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _actionError = null);
      _showSuccess();

      // Clear form
      _subjectController.clear();
      _messageController.clear();
      setState(() {
        _selectedCategory = 'General';
      });
    } catch (e) {
      if (mounted) {
        _showError(UserFacingError.message(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSuccess() {
    final ColorScheme cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ticket submitted successfully',
          style: TextStyle(color: cs.onInverseSurface),
        ),
        backgroundColor: cs.inverseSurface,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    setState(() => _actionError = message);
  }

  Widget _buildLabel(String text) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Text(
      text,
      style: TextStyle(
        color: shell.onChrome.withValues(alpha: 0.9),
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    IconData? icon,
  }) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: shell.surfaceCardBorder),
    );
    return InputDecoration(
      filled: true,
      fillColor: shell.surfaceCard,
      hintText: hintText,
      hintStyle: TextStyle(color: shell.mutedStrong),
      prefixIcon:
          icon == null ? null : Icon(icon, color: shell.muted, size: 20),
      border: border,
      enabledBorder: border,
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.supportAccentGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child:
                const Icon(Icons.support_agent, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tell us what happened',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Include the device, account, and steps you took so support can move quickly.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: shell.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: shell.surfaceCardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: shell.muted,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Support tickets are linked to your signed-in account. Typical response time is 24-48 hours.',
              style: TextStyle(
                color: shell.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final StSupportShellStyle shell = StSupportShellStyle.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: shell.scaffold,
      appBar: AppBar(
        backgroundColor: shell.panelSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: shell.onChrome),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Contact Support',
          style: TextStyle(color: shell.onChrome),
        ),
      ),
      body: GestureDetector(
        onTap: FocusScope.of(context).unfocus,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            28 + MediaQuery.of(context).padding.bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_actionError != null) ...[
                      ScreenInlineErrorBanner(
                        message: _actionError!,
                        onDismiss: () {
                          if (mounted) {
                            setState(() => _actionError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildHero(),
                    const SizedBox(height: 24),
                    _buildLabel('Category *'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: _fieldDecoration(
                        hintText: 'Choose a support topic',
                        icon: Icons.topic_outlined,
                      ),
                      style: TextStyle(color: shell.onChrome),
                      dropdownColor: shell.panelSurface,
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('Subject *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _subjectController,
                      decoration: _fieldDecoration(
                        hintText: 'Brief description of your issue',
                        icon: Icons.short_text,
                      ),
                      style: TextStyle(color: shell.onChrome),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a subject';
                        }
                        return null;
                      },
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(100),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildLabel('Message *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _messageController,
                      maxLines: 8,
                      minLines: 6,
                      decoration: _fieldDecoration(
                        hintText:
                            'What happened? What did you expect? Any error messages?',
                      ),
                      style: TextStyle(color: shell.onChrome),
                      textInputAction: TextInputAction.newline,
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Please enter a message';
                        }
                        if (trimmed.length < 20) {
                          return 'Message must be at least 20 characters';
                        }
                        return null;
                      },
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(1000),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitTicket,
                        icon: _isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                color: Colors.white),
                        label: Text(
                          _isSubmitting ? 'Submitting...' : 'Submit Ticket',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.supportAccent,
                          disabledBackgroundColor:
                              AppColors.supportAccent.withValues(alpha: 0.45),
                          foregroundColor: scheme.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
