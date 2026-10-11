import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'api_client.dart';
import 'options_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final t = data?.text?.trim();
    if (t != null && t.isNotEmpty) setState(() => _ctrl.text = t);
  }

  Future<void> _analyze() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final info = await context.read<ApiClient>().analyze(url);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => OptionsSheet(info: info),
      );
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذّر الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset('assets/logo_mark.png', width: 52, height: 52),
            ),
            const SizedBox(width: 12),
            const Text('FlixGo', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 6),
          Text('الصق الرابط وابدأ التحميل',
              style: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('رابط الفيديو', style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => _analyze(),
                        decoration: InputDecoration(
                          hintText: 'الصق الرابط هنا',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      onPressed: _paste,
                      tooltip: 'لصق',
                      icon: const Icon(Icons.content_paste),
                      style: IconButton.styleFrom(fixedSize: const Size(52, 52)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.tonal(
                    onPressed: _loading ? null : _analyze,
                    child: _loading
                        ? const SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('تحليل الرابط'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
