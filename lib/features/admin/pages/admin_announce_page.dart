import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sigmamoby/core/widgets/brand_app_bar.dart';

class AdminAnnouncePage extends StatefulWidget {
  const AdminAnnouncePage({super.key});

  @override
  State<AdminAnnouncePage> createState() => _AdminAnnouncePageState();
}

class _AdminAnnouncePageState extends State<AdminAnnouncePage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl  = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body  = _bodyCtrl.text.trim();

    if (title.isEmpty) { _snack('Title ထည့်ပါ'); return; }
    if (body.isEmpty)  { _snack('Message ထည့်ပါ'); return; }

    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('announcements').add({
        'title':     title,
        'body':      body,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _titleCtrl.clear();
      _bodyCtrl.clear();
      _snack('Announcement ပို့ပြီးပါပြီ ✅');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _onLinkTap(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Announce link tap error: $e');
    }
  }

  Widget _buildLinkifiedText(String text, ColorScheme scheme) {
    final urlRegExp = RegExp(
      r"((https?|ftp|file)://|www\.)[-A-Z0-9+&@#/%?=~_|!:,.;]*[-A-Z0-9+&@#/%=~_|]",
      caseSensitive: false,
    );

    final matches = urlRegExp.allMatches(text);
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    final List<TextSpan> spans = [];
    int start = 0;
    for (final match in matches) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: text.substring(start, match.start),
          style: TextStyle(color: scheme.onSurfaceVariant),
        ));
      }

      final url = match.group(0)!;
      final fullUrl = url.startsWith('www.') ? 'https://$url' : url;

      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: scheme.primary,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.bold,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => _onLinkTap(fullUrl),
      ));
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: TextStyle(color: scheme.onSurfaceVariant),
      ));
    }

    return RichText(
      text: TextSpan(
        children: spans,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme    = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const BrandAppBar(title: 'Announce to Users'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info banner ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.campaign_outlined,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'User အားလုံး၏ Profile bell icon မှ မြင်ရမည်',
                      style: textTheme.bodySmall?.copyWith(
                          color: scheme.primary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Title ──────────────────────────────────────────────────
            Text('Title', style: textTheme.labelMedium),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              enabled: !_sending,
              maxLength: 80,
              decoration: InputDecoration(
                hintText: 'ဥပမာ — အရေးကြီးသောကြေငြာချက်',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: scheme.surface,
                counterText: '',
              ),
            ),

            const SizedBox(height: 14),

            // ── Body ───────────────────────────────────────────────────
            Text('Message', style: textTheme.labelMedium),
            const SizedBox(height: 6),
            TextField(
              controller: _bodyCtrl,
              enabled: !_sending,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'User တွေဆီ ပေးပို့မည့် message ကို ရေးပါ...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: scheme.surface,
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 20),

            // ── Send button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: _sending
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'ပို့နေသည်...' : 'ပို့မည်'),
                onPressed: _sending ? null : _send,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 32),
            Divider(color: scheme.outlineVariant),
            const SizedBox(height: 16),

            // ── History ────────────────────────────────────────────────
            Text('ပို့ပြီးသော Announcements',
                style: textTheme.titleSmall),
            const SizedBox(height: 10),

            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('announcements')
                  .orderBy('createdAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Text('မရှိသေးပါ',
                      style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant));
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: scheme.outlineVariant),
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final ts = d['createdAt'] as Timestamp?;
                    final date = ts != null
                        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year}'
                        : '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.campaign_outlined,
                                  size: 16, color: scheme.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(d['title'] ?? '',
                                    style: textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600)),
                              ),
                              Text(date,
                                  style: textTheme.labelSmall?.copyWith(
                                      color: scheme.onSurfaceVariant)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onLongPress: () {
                              Clipboard.setData(ClipboardData(text: d['body'] ?? ''));
                              _snack('Copy ယူပြီးပါပြီ');
                            },
                            child: _buildLinkifiedText(d['body'] ?? '', scheme),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
