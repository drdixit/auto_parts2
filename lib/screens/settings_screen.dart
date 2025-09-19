import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showSearch = true;
  bool _showFilters = false;
  bool _showProducts = true;
  bool _showBill = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showSearch = prefs.getBool('pos_show_search') ?? true;
      _showProducts = prefs.getBool('pos_show_products') ?? true;
      _showBill = prefs.getBool('pos_show_bill') ?? true;
      _showFilters = prefs.getBool('pos_show_filters') ?? false;
    });
  }

  Future<void> _apply() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pos_show_search', _showSearch);
    await prefs.setBool('pos_show_products', _showProducts);
    await prefs.setBool('pos_show_bill', _showBill);
    await prefs.setBool('pos_show_filters', _showFilters);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Show search product'),
                    value: _showSearch,
                    onChanged: (v) => setState(() => _showSearch = v),
                  ),
                  SwitchListTile(
                    title: const Text('Show filters section'),
                    value: _showFilters,
                    onChanged: (v) => setState(() => _showFilters = v),
                  ),
                  SwitchListTile(
                    title: const Text('Show products section'),
                    value: _showProducts,
                    onChanged: (v) => setState(() => _showProducts = v),
                  ),
                  SwitchListTile(
                    title: const Text('Show bill section'),
                    value: _showBill,
                    onChanged: (v) => setState(() => _showBill = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
