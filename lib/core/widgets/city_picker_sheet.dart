import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Fetches the city list from Firestore settings/shipping and opens
/// a searchable bottom-sheet picker.
///
/// Returns the selected city string, or null if dismissed.
///
/// Usage:
///   final city = await CityPickerSheet.show(context);
class CityPickerSheet extends StatefulWidget {
  final List<String> cities;

  const CityPickerSheet._({required this.cities});

  /// Loads cities from Firestore then shows the picker.
  static Future<String?> show(BuildContext context) async {
    List<String> cities = [];
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('shipping')
          .get();
      cities = List<String>.from(doc.data()?['cities'] ?? []);
    } catch (e) {
      debugPrint('CityPickerSheet load error: $e');
    }

    if (!context.mounted) return null;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CityPickerSheet._(cities: cities),
    );
  }

  @override
  State<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<CityPickerSheet> {
  final _searchCtrl = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.cities);
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(widget.cities)
          : widget.cities
              .where((c) => c.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxH = MediaQuery.of(context).size.height * 0.75;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'မြို့ရွေးပါ',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),

          // ── Search field ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'မြို့ name ရိုက်ရှာပါ...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          FocusScope.of(context).unfocus();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── City list ─────────────────────────────────────────────
          Flexible(
            child: widget.cities.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Admin မှ မြို့ မထည့်ရသေးပါ',
                        style:
                            TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  )
                : _filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '"${_searchCtrl.text}" မတွေ့ပါ',
                            style: TextStyle(
                                color: scheme.onSurfaceVariant),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(
                            left: 8, right: 8, bottom: 24),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, _) => Divider(
                            height: 1, color: scheme.outlineVariant),
                        itemBuilder: (context, i) {
                          final city = _filtered[i];
                          return ListTile(
                            title: Text(city),
                            leading:
                                const Icon(Icons.location_on_outlined),
                            onTap: () => Navigator.pop(context, city),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
