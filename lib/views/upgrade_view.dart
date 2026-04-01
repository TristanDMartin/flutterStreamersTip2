import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import 'contact_support_view.dart';

class UpgradeView extends StatefulWidget {
  const UpgradeView({super.key});

  @override
  State<UpgradeView> createState() => _UpgradeViewState();
}

class _UpgradeViewState extends State<UpgradeView> {
  static const Set<String> _bypassStudioUids = {
    'bU0RxyZ2L4ULAv1Co5L4f825yV73',
    'jsmbQMLQjoUyC5cUFvkrRbi9mkp1',
  };

  String _resolvedTier = 'starter';
  String? _subscriptionStatus;
  bool _isLoadingTier = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptionTier();
  }

  Future<void> _loadSubscriptionTier() async {
    final user = fa.FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _resolvedTier = 'starter';
          _subscriptionStatus = null;
          _isLoadingTier = false;
        });
      }
      return;
    }

    try {
      if (_bypassStudioUids.contains(user.uid)) {
        if (mounted) {
          setState(() {
            _resolvedTier = 'studio';
            _subscriptionStatus = 'active';
            _isLoadingTier = false;
          });
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? const <String, dynamic>{};
      final rawTier = (data['subscriptionTier'] as String?)?.toLowerCase();
      final status = (data['subscriptionStatus'] as String?)?.toLowerCase();
      const validTiers = {'starter', 'pro', 'studio'};
      const activeStatuses = {'active', 'trialing'};

      final resolvedTier = validTiers.contains(rawTier) &&
              activeStatuses.contains(status)
          ? rawTier!
          : 'starter';

      if (mounted) {
        setState(() {
          _resolvedTier = resolvedTier;
          _subscriptionStatus = status;
          _isLoadingTier = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resolvedTier = 'starter';
          _subscriptionStatus = null;
          _isLoadingTier = false;
        });
      }
    }
  }

  String _tierLabel(String tier) {
    switch (tier) {
      case 'pro':
        return 'Pro';
      case 'studio':
        return 'Studio';
      default:
        return 'Starter';
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'trialing':
        return 'Trialing';
      case 'active':
        return 'Active';
      case 'past_due':
        return 'Past Due';
      case 'canceled':
        return 'Canceled';
      default:
        return 'Starter';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.supportBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildHero(),
              const SizedBox(height: 16),
              _buildCurrentPlanCard(),
              const SizedBox(height: 24),
              _buildTierCard(
                context,
                tierKey: 'starter',
                name: 'Starter',
                price: '\$0',
                cadence: '/month',
                description:
                    'A solid free plan for creators getting started with cross-posting and lightweight planning.',
                features: const [
                  '1 connected platform',
                  '1 active content plan',
                  '1 cross-post per week',
                  '7-day analytics window',
                  '10 AI credits per month',
                  'Scheduling included',
                ],
              ),
              const SizedBox(height: 16),
              _buildTierCard(
                context,
                tierKey: 'pro',
                name: 'Pro',
                price: '\$29',
                cadence: '/month',
                secondaryPrice: '\$288/year',
                description:
                    'For active creators who need more platforms, stronger publishing tools, and deeper growth support.',
                features: const [
                  'Up to 5 platforms',
                  'Unlimited content plans',
                  'Scheduled and bulk publishing',
                  '90-day analytics window',
                  '250 AI credits per month',
                  'Caption rewrite and hashtags',
                  'Growth reports',
                  'Unlimited weekly cross-posting',
                ],
                isFeatured: true,
              ),
              const SizedBox(height: 16),
              _buildTierCard(
                context,
                tierKey: 'studio',
                name: 'Studio',
                price: '\$89',
                cadence: '/month',
                secondaryPrice: '\$888/year',
                description:
                    'For serious teams and power creators who need advanced analytics, automation, and team access.',
                features: const [
                  'Unlimited platforms',
                  'Unlimited content plans',
                  'Bulk publishing and automation',
                  '365-day analytics window',
                  'Advanced analytics',
                  '1,000 AI credits per month',
                  'Up to 5 team members',
                  'Exportable reports and priority support',
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Website pricing and entitlements are mirrored here. Paid subscriptions still route through support while mobile billing is being finalized.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPlanCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _isLoadingTier
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current plan',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.64),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isLoadingTier
                      ? 'Checking your subscription...'
                      : '${_tierLabel(_resolvedTier)} · ${_statusLabel(_subscriptionStatus)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
        ),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upgrade',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose the tier that fits your creator journey',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.68),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.supportAccentGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Pick the same tier model used across the website, backend, and creator tools.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Starter keeps things lightweight, Pro unlocks serious publishing power, and Studio adds advanced analytics, automation, and team features.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTierCard(
    BuildContext context, {
    required String tierKey,
    required String name,
    required String price,
    required String cadence,
    required String description,
    required List<String> features,
    String? secondaryPrice,
    bool isFeatured = false,
  }) {
    final isCurrentTier = !_isLoadingTier && _resolvedTier == tierKey;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: isCurrentTier
              ? 0.12
              : (isFeatured ? 0.1 : 0.07),
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: isCurrentTier
                ? 0.26
                : (isFeatured ? 0.18 : 0.1),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isCurrentTier)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: const Text(
                          'Current Plan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    if (isFeatured)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.supportAccentGradient,
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Most Popular',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: price,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          TextSpan(
                            text: cadence,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.68),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (secondaryPrice != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        secondaryPrice,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.66),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.74),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCurrentTier
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ContactSupportView(),
                        ),
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isFeatured
                    ? AppColors.supportAccent
                    : Colors.white.withValues(alpha: 0.1),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              child: Text(
                isCurrentTier
                    ? 'Current Plan'
                    : (name == 'Starter'
                        ? 'Stay on Starter'
                        : 'Subscribe to $name'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
