import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_user_detail_view.dart';

class AdminUsersView extends StatefulWidget {
  const AdminUsersView({super.key});

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> {
  final TextEditingController _q = TextEditingController();
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _hits = [];
  bool _loading = false;
  String? _err;

  Future<void> _runSearch(String raw) async {
    final String q = raw.trim().toLowerCase();
    setState(() {
      _loading = true;
      _err = null;
      _hits = [];
    });
    if (q.length < 2) {
      setState(() => _loading = false);
      return;
    }
    try {
      final QuerySnapshot<Map<String, dynamic>> snap =
          await FirebaseFirestore.instance
              .collection('users')
              .where('username', isGreaterThanOrEqualTo: q)
              .where('username', isLessThan: '$q\uf8ff')
              .limit(24)
              .get();
      setState(() {
        _hits = snap.docs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _err = '$e';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _q,
                  decoration: const InputDecoration(
                    labelText: 'Username prefix',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: _runSearch,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _runSearch(_q.text),
                child: const Text('Search'),
              ),
            ],
          ),
        ),
        if (_err != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText.rich(
              TextSpan(
                text: _err!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        if (_loading)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _hits.length,
              itemBuilder: (context, i) {
                final doc = _hits[i];
                final d = doc.data();
                final un =
                    (d['username'] ?? doc.id).toString();
                final em = (d['email'] ?? '—').toString();
                final tier =
                    (d['subscriptionTier'] ?? '—').toString();
                final role = (d['role'] ?? '—').toString();
                final ac =
                    (d['accountStatus'] ?? 'active').toString();
                return Card(
                  child: ListTile(
                    title: Text(un),
                    subtitle: Text('$em · $tier · $role · $ac'),
                    onTap: () {
                      Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              AdminUserDetailView(userId: doc.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
