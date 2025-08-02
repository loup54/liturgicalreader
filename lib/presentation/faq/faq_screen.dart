import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_export.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  static const _faqItems = [
    {
      'q': 'Why do some days show “No readings available”?',
      'a':
          'The local 90-day cache may not have synced yet. Make sure you are online and pull-to-refresh.'
    },
    {
      'q': 'How far back / ahead can I browse?',
      'a':
          'The app stores 30 days in the past and 60 days in the future for offline use.'
    },
    {
      'q': 'How do I report an error in a reading?',
      'a':
          'Open the reading, tap the ⋯ menu, and choose “Report content issue”.'
    },
  ];

  void _launchSupportEmail() async {
    const uri =
        'mailto:support@liturgicalreader.app?subject=Liturgical%20Reader%20Support';
    final url = Uri.parse(uri);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FAQ & Support')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _faqItems.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          if (index == _faqItems.length) {
            return Center(
              child: TextButton.icon(
                onPressed: _launchSupportEmail,
                icon: const Icon(Icons.mail_outline),
                label: const Text('Contact Support'),
              ),
            );
          }
          final item = _faqItems[index];
          return ExpansionTile(
            title: Text(item['q']!),
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(item['a']!),
              ),
            ],
          );
        },
      ),
    );
  }
}
