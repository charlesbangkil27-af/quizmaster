import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: service.notifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load notifications.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('You are all caught up!'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final read = data['isRead'] == true;
              final type = data['type']?.toString();
              final icon = type == 'quiz'
                  ? Icons.quiz_rounded
                  : type == 'announcement'
                  ? Icons.campaign_rounded
                  : Icons.group_add_rounded;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: read
                        ? Colors.grey.shade100
                        : const Color(0xFFE9EDFF),
                    child: Icon(icon, color: read ? Colors.grey : qmBlue),
                  ),
                  title: Text(
                    data['title']?.toString() ?? 'Notification',
                    style: TextStyle(
                      fontWeight: read ? FontWeight.w500 : FontWeight.w800,
                    ),
                  ),
                  subtitle: Text(data['body']?.toString() ?? ''),
                  trailing: read
                      ? null
                      : const Icon(Icons.circle, size: 9, color: qmBlue),
                  onTap: read ? null : () => service.markRead(doc.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
