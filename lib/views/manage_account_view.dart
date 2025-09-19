import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Comprehensive Manage Account screen with TikTok-style design
class ManageAccountView extends StatefulWidget {
  const ManageAccountView({super.key});

  @override
  State<ManageAccountView> createState() => _ManageAccountViewState();
}

class _ManageAccountViewState extends State<ManageAccountView> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6137EB), Color(0xFF1C135D)],
          ),
        ),
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Account Information Section
            _buildSection(
              title: 'Account Information',
              items: [
                _buildAccountItem(
                  icon: Icons.person_outline,
                  title: 'Username',
                  subtitle: _auth.currentUser?.displayName ?? 'Not set',
                  onTap: () => _showAccountInformation(context),
                ),
                _buildAccountItem(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  subtitle: _auth.currentUser?.email ?? 'Not set',
                  onTap: () => _showAccountInformation(context),
                ),
                _buildAccountItem(
                  icon: Icons.phone_outlined,
                  title: 'Phone Number',
                  subtitle: _auth.currentUser?.phoneNumber ?? 'Not set',
                  onTap: () => _showAccountInformation(context),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Security Section
            _buildSection(
              title: 'Security',
              items: [
                _buildAccountItem(
                  icon: Icons.lock_outline,
                  title: 'Password',
                  subtitle: 'Change your password',
                  onTap: () => _showChangePassword(context),
                ),
                _buildAccountItem(
                  icon: Icons.verified_user_outlined,
                  title: 'Verification',
                  subtitle: 'Verify your identity',
                  onTap: () => _showVerification(context),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Data & Privacy Section
            _buildSection(
              title: 'Data & Privacy',
              items: [
                _buildAccountItem(
                  icon: Icons.download_outlined,
                  title: 'Download Your Data',
                  subtitle: 'Get a copy of your data',
                  onTap: () => _showDownloadData(context),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Account Actions Section
            _buildSection(
              title: 'Account Actions',
              items: [
                _buildAccountItem(
                  icon: Icons.pause_circle_outline,
                  title: 'Deactivate Account',
                  subtitle: 'Temporarily disable your account',
                  onTap: () => _showDeactivateAccount(context),
                  isDestructive: true,
                ),
                _buildAccountItem(
                  icon: Icons.delete_outline,
                  title: 'Delete Account',
                  subtitle: 'Permanently delete your account',
                  onTap: () => _showDeleteAccount(context),
                  isDestructive: true,
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Manage Account',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey[800]!,
              width: 1,
            ),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildAccountItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDestructive 
                    ? Colors.red.withValues(alpha: 0.1)
                    : Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isDestructive ? Colors.red : Colors.white70,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isDestructive ? Colors.red : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isDestructive ? Colors.red[300] : Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white30,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Action Methods
  void _showAccountInformation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildAccountInformationSheet(),
    );
  }

  void _showChangePassword(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildChangePasswordSheet(),
    );
  }

  void _showVerification(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildVerificationSheet(),
    );
  }

  void _showDownloadData(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildDownloadDataSheet(),
    );
  }

  void _showDeactivateAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _buildDeactivateDialog(),
    );
  }

  void _showDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _buildDeleteDialog(),
    );
  }

  // Sheet Builders
  Widget _buildAccountInformationSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Information',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoField('Username', _auth.currentUser?.displayName ?? 'Not set'),
          const SizedBox(height: 16),
          _buildInfoField('Email', _auth.currentUser?.email ?? 'Not set'),
          const SizedBox(height: 16),
          _buildInfoField('Phone', _auth.currentUser?.phoneNumber ?? 'Not set'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangePasswordSheet() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Change Password',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildPasswordField('Current Password', currentPasswordController, true),
          const SizedBox(height: 16),
          _buildPasswordField('New Password', newPasswordController, true),
          const SizedBox(height: 16),
          _buildPasswordField('Confirm New Password', confirmPasswordController, true),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[600]!),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handlePasswordChange(
                    currentPasswordController.text,
                    newPasswordController.text,
                    confirmPasswordController.text,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Change Password',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Verification',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Verify your identity to unlock premium features and monetization options.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          _buildVerificationStep('Email Verification', Icons.email, true),
          const SizedBox(height: 16),
          _buildVerificationStep('Phone Verification', Icons.phone, false),
          const SizedBox(height: 16),
          _buildVerificationStep('ID Verification', Icons.credit_card, false),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _startVerification(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Start Verification',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadDataSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Download Your Data',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Request a copy of all your data including videos, analytics, and account information.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Data includes:',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                _buildDataItem('Videos and content'),
                _buildDataItem('Analytics and insights'),
                _buildDataItem('Messages and comments'),
                _buildDataItem('Account settings'),
                _buildDataItem('Followers and following'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey[600]!),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _requestDataDownload(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Request Data',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeactivateDialog() {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        'Deactivate Account',
        style: TextStyle(color: Colors.white),
      ),
      content: const Text(
        'Your account will be temporarily disabled. You can reactivate it anytime by logging back in. Your content will remain private during this time.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        TextButton(
          onPressed: () => _handleDeactivateAccount(),
          child: const Text(
            'Deactivate',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  Widget _buildDeleteDialog() {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        'Delete Account',
        style: TextStyle(color: Colors.red),
      ),
      content: const Text(
        'This action cannot be undone. All your data, videos, and account information will be permanently deleted.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        TextButton(
          onPressed: () => _handleDeleteAccount(),
          child: const Text(
            'Delete Forever',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  // Helper Widgets
  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, bool obscure) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationStep(String title, IconData icon, bool completed) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: completed ? Colors.green.withValues(alpha: 0.1) : Colors.grey[800],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completed ? Colors.green : Colors.grey[700]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : icon,
            color: completed ? Colors.green : Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: completed ? Colors.green : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (completed)
            const Icon(
              Icons.check,
              color: Colors.green,
              size: 16,
            ),
        ],
      ),
    );
  }

  Widget _buildDataItem(String item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white70,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            item,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // Action Handlers
  void _handlePasswordChange(String currentPassword, String newPassword, String confirmPassword) {
    if (newPassword != confirmPassword) {
      _showSnackBar('Passwords do not match');
      return;
    }
    
    if (newPassword.length < 6) {
      _showSnackBar('Password must be at least 6 characters');
      return;
    }

    // Here you would implement actual password change logic
    _showSnackBar('Password changed successfully');
    Navigator.pop(context);
  }

  void _startVerification() {
    _showSnackBar('Verification process started');
    Navigator.pop(context);
  }

  void _requestDataDownload() {
    _showSnackBar('Data download requested. You will be notified when ready.');
    Navigator.pop(context);
  }

  void _handleDeactivateAccount() {
    // Here you would implement actual deactivation logic
    _showSnackBar('Account deactivated successfully');
    Navigator.pop(context);
  }

  void _handleDeleteAccount() {
    // Here you would implement actual deletion logic
    _showSnackBar('Account deletion initiated');
    Navigator.pop(context);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.grey[800],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
