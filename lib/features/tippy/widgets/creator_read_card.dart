import 'package:flutter/material.dart';

import '../tippy_brain_client.dart';
import '../tippy_brain_contract.dart';

class CreatorReadCard extends StatefulWidget {
  const CreatorReadCard({
    super.key,
    this.brainClient,
    this.compact = false,
  });

  final TippyBrainClient? brainClient;
  final bool compact;

  @override
  State<CreatorReadCard> createState() => _CreatorReadCardState();
}

class _CreatorReadCardState extends State<CreatorReadCard> {
  late final TippyBrainClient _client =
      widget.brainClient ?? TippyBrainClient();
  TippyCreatorRead? _read;
  bool _showLearnMore = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadBrain();
  }

  Future<void> _loadBrain() async {
    final TippyBrainLayers? brain = await _client.fetchBrain();
    if (!mounted) {
      return;
    }
    setState(() {
      _read = projectCreatorReadFromBrain(brain);
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _read == null) {
      return const SizedBox.shrink();
    }
    final TippyCreatorRead read = _read!;
    final List<String> identity = <String>[
      if (read.creatorType != null) read.creatorType!,
      if (read.niche != null) read.niche!,
      if (read.platforms.isNotEmpty) read.platforms.join(', '),
    ];
    return Container(
      width: double.infinity,
      margin: widget.compact ? const EdgeInsets.only(top: 10) : EdgeInsets.zero,
      padding: EdgeInsets.all(widget.compact ? 10 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF67E8F9).withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            read.title.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF67E8F9),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            read.continuityCopy,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: widget.compact ? 12.5 : 13.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if (read.openingRead != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              read.openingRead!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
          if (identity.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              identity.join(' · '),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (read.biggestOpportunity != null || read.firstFocus != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              (read.biggestOpportunity ?? read.firstFocus)!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ],
          if (read.notices.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            ...read.notices.map(
              (String notice) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '· $notice',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.74),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
          if (read.observed.isNotEmpty ||
              read.inferred.isNotEmpty ||
              read.confirmed.isNotEmpty) ...<Widget>[
            TextButton(
              onPressed: () {
                setState(() {
                  _showLearnMore = !_showLearnMore;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF67E8F9),
                padding: EdgeInsets.zero,
              ),
              child: Text(
                _showLearnMore
                    ? 'Hide Learn More'
                    : 'Learn more about this read',
              ),
            ),
            if (_showLearnMore) ...<Widget>[
              _LearnMoreGroup(label: 'What I could actually see', items: read.observed),
              _LearnMoreGroup(label: "What I'm inferring", items: read.inferred),
              _LearnMoreGroup(label: 'Confirmed', items: read.confirmed),
            ],
          ],
        ],
      ),
    );
  }
}

class _LearnMoreGroup extends StatelessWidget {
  const _LearnMoreGroup({required this.label, required this.items});

  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.48),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          ...items.map(
            (String item) => Text(
              item,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
