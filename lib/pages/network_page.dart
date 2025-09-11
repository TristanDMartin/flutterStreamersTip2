import 'package:flutter/material.dart';

class NetworkPage extends StatelessWidget {
  const NetworkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Network',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const _NetworkBody(),
    );
  }
}

class _NetworkBody extends StatefulWidget {
  const _NetworkBody();

  @override
  State<_NetworkBody> createState() => _NetworkBodyState();
}

class _NetworkBodyState extends State<_NetworkBody> {
  final TextEditingController _searchController = TextEditingController();
  final List<_UserCardData> _allUsers = const [
    _UserCardData(
      username: 'tech_creator',
      displayName: 'Tech Creator',
      avatarColor: Colors.purple,
      isOnline: true,
    ),
    _UserCardData(
      username: 'pro_streamer',
      displayName: 'Pro Streamer',
      avatarColor: Colors.blue,
      isOnline: false,
    ),
    _UserCardData(
      username: 'gaming_daily',
      displayName: 'Gaming Daily',
      avatarColor: Colors.indigo,
      isOnline: true,
    ),
  ];

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<_UserCardData> filtered = _allUsers
        .where((u) => _query.isEmpty
            || u.username.toLowerCase().contains(_query)
            || u.displayName.toLowerCase().contains(_query))
        .toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            onChanged: (text) => setState(() => _query = text.toLowerCase()),
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search creators',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
              prefixIcon: const Icon(Icons.search, color: Colors.white),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? const _EmptyState()
              : ListView.separated(
                  itemCount: filtered.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _UserCard(data: filtered[index]),
                ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, color: Colors.white.withValues(alpha: 0.6), size: 56),
            const SizedBox(height: 12),
            const Text(
              'No results',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
}

class _UserCardData {
  final String username;
  final String displayName;
  final Color avatarColor;
  final bool isOnline;

  const _UserCardData({
    required this.username,
    required this.displayName,
    required this.avatarColor,
    required this.isOnline,
  });
}

class _UserCard extends StatelessWidget {
  final _UserCardData data;

  const _UserCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.5),
      ),
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: data.avatarColor,
              child: Text(
                data.displayName.isNotEmpty ? data.displayName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: data.isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(data.displayName, style: const TextStyle(color: Colors.white)),
        subtitle: Text('@${data.username}', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
        trailing: TextButton(
          onPressed: () {},
          child: const Text('Follow'),
        ),
        onTap: () {},
      ),
    );
  }
}
