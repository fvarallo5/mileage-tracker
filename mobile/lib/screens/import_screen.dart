import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/import_result.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/section_header.dart';

final _currency = NumberFormat.currency(symbol: '\$');

const _platforms = [
  ('uber', 'Uber', Icons.local_taxi, AppColors.uber),
  ('doordash', 'DoorDash', Icons.delivery_dining, AppColors.doordash),
  ('lyft', 'Lyft', Icons.directions_car, AppColors.lyft),
  ('instacart', 'Instacart', Icons.shopping_bag, AppColors.instacart),
  ('generic', 'Other', Icons.table_chart, AppColors.accent),
];

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  String _platform = 'uber';
  final _csvController = TextEditingController();
  final _defaultMilesController = TextEditingController(text: '2.5');
  ImportFormats? _formats;
  ImportResult? _preview;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFormats();
  }

  @override
  void dispose() {
    _csvController.dispose();
    _defaultMilesController.dispose();
    super.dispose();
  }

  Future<void> _loadFormats() async {
    try {
      final formats = await context.read<AppState>().api.getImportFormats();
      if (mounted) setState(() => _formats = formats);
    } catch (_) {}
  }

  double get _defaultMiles => double.tryParse(_defaultMilesController.text) ?? 0;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes != null) {
      setState(() {
        _csvController.text = String.fromCharCodes(file.bytes!);
        _preview = null;
        _error = null;
      });
    }
  }

  Future<void> _runPreview() async {
    if (_csvController.text.trim().isEmpty) {
      setState(() => _error = 'Paste or upload a CSV file first');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await context.read<AppState>().api.previewImport(
            csv: _csvController.text,
            platform: _platform,
            defaultMiles: _defaultMiles,
          );
      setState(() => _preview = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmImport() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final state = context.read<AppState>();
      final result = await state.api.importTrips(
        csv: _csvController.text,
        platform: _platform,
        defaultMiles: _defaultMiles,
      );
      await state.refresh();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.importedCount} trips'
            '${result.skippedCount > 0 ? ', skipped ${result.skippedCount} duplicates' : ''}',
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _loadSample() {
    final sample = _formats?.sampleCsv[_platform];
    if (sample != null) {
      setState(() {
        _csvController.text = sample;
        _preview = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final instructions = _formats?.instructions[_platform] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Import Trips'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Text(
            'Import earnings & mileage from gig app CSV exports',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(title: 'Platform'),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _platforms.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, i) {
                final p = _platforms[i];
                final selected = _platform == p.$1;
                return FilterChip(
                  selected: selected,
                  showCheckmark: false,
                  avatar: Icon(p.$3, size: 16, color: selected ? p.$4 : AppColors.textMuted),
                  label: Text(p.$2),
                  onSelected: (_) => setState(() {
                    _platform = p.$1;
                    _preview = null;
                  }),
                );
              },
            ),
          ),
          if (instructions != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.card),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: AppColors.accent),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Export from ${instructions['name']}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...(instructions['steps'] as List).asMap().entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${e.key + 1}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(child: Text(e.value as String, style: const TextStyle(fontSize: 13))),
                              ],
                            ),
                          ),
                        ),
                    if (instructions['note'] != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        instructions['note'] as String,
                        style: const TextStyle(fontSize: 12, color: AppColors.amber),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _defaultMilesController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Default miles (if CSV has no distance)',
              helperText: 'DoorDash exports often need 2–3 mi per delivery',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload CSV'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              OutlinedButton(onPressed: _loadSample, child: const Text('Sample')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _csvController,
            maxLines: 8,
            style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Or paste CSV here',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.card),
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : _runPreview,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Preview'),
                ),
              ),
              if (_preview != null && _preview!.preview.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _loading ? null : _confirmImport,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.green),
                  child: const Text('Import'),
                ),
              ],
            ],
          ),
          if (_preview != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'Preview',
              subtitle: '${_preview!.preview.length} trips ready',
            ),
            ..._preview!.preview.take(8).map(
                  (row) => Card(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: ListTile(
                      dense: true,
                      title: Text(row.date, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(row.notes, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${row.miles.toStringAsFixed(1)} mi'),
                          Text(
                            _currency.format(row.tips),
                            style: const TextStyle(color: AppColors.green, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            if (_preview!.preview.length > 8)
              Text(
                '+ ${_preview!.preview.length - 8} more…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ],
      ),
    );
  }
}