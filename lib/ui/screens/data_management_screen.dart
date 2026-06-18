import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_theme.dart';
import '../../services/export_import_service.dart';
import '../../widgets/responsive_page.dart';

class DataManagementScreen extends StatefulWidget {
  const DataManagementScreen({super.key});

  @override
  State<DataManagementScreen> createState() => _DataManagementScreenState();
}

class _DataManagementScreenState extends State<DataManagementScreen> {
  ImportMode _mode = ImportMode.overwrite;
  String? _status;
  ImportReport? _report;

  Future<void> _exportFile() async {
    final service = await ExportImportService.create();
    final file = await service.exportToFilePicker();
    setState(() {
      _status = file == null ? 'Export cancelled.' : 'Exported: ${file.path}';
      _report = null;
    });
  }

  Future<void> _exportClipboard() async {
    final service = await ExportImportService.create();
    final json = await service.exportToJsonString();
    await Clipboard.setData(ClipboardData(text: json));
    setState(() {
      _status = 'Export copied to clipboard.';
      _report = null;
    });
  }

  Future<void> _importFile() async {
    try {
      final service = await ExportImportService.create();
      final report = await service.importFromFilePicker(mode: _mode);
      setState(() {
        _status = 'Import completed.';
        _report = report;
      });
    } catch (error) {
      setState(() => _status = error.toString());
    }
  }

  Future<void> _importClipboard() async {
    try {
      final service = await ExportImportService.create();
      final data = await Clipboard.getData('text/plain');
      if (data?.text == null) {
        setState(() => _status = 'Clipboard is empty.');
        return;
      }
      final report = await service.importFromJsonString(
        data!.text!,
        mode: _mode,
      );
      setState(() {
        _status = 'Import completed.';
        _report = report;
      });
    } catch (error) {
      setState(() => _status = error.toString());
    }
  }

  Future<void> _restoreBackup() async {
    try {
      final service = await ExportImportService.create();
      final report = await service.restoreLastBackup();
      setState(() {
        _status = 'Backup restored.';
        _report = report;
      });
    } catch (error) {
      setState(() => _status = error.toString());
    }
  }

  Future<void> _confirmOverwrite(VoidCallback action) async {
    if (_mode != ImportMode.overwrite) {
      action();
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Overwrite data?'),
        content: const Text(
          'This will replace existing data. A backup will be stored automatically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      action();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Management')),
      body: ResponsivePage(
        maxWidth: 1040,
        children: [
          ResponsiveSplit(
            breakpoint: 820,
            start: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Export',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton(
                      onPressed: _exportFile,
                      child: const Text('Export to file'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: _exportClipboard,
                      child: const Text('Export to clipboard'),
                    ),
                  ],
                ),
              ),
            ),
            end: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Import',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _ImportModePicker(
                      mode: _mode,
                      onChanged: (value) =>
                          setState(() => _mode = value ?? _mode),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton(
                      onPressed: () => _confirmOverwrite(_importFile),
                      child: const Text('Import from file'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: () => _confirmOverwrite(_importClipboard),
                      child: const Text('Import from clipboard'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _restoreBackup,
                      child: const Text('Restore from last backup'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(_status!),
              ),
            ),
          ],
          if (_report != null) ...[
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import report',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Added players: ${_report!.addedPlayers}\n'
                      'Updated players: ${_report!.updatedPlayers}\n'
                      'Added matches: ${_report!.addedMatches}\n'
                      'Skipped matches: ${_report!.skippedMatches}',
                    ),
                    if (_report!.errors.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _report!.errors.join('\n'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImportModePicker extends StatelessWidget {
  const _ImportModePicker({
    required this.mode,
    required this.onChanged,
  });

  final ImportMode mode;
  final ValueChanged<ImportMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tile(ImportMode value, String title) {
      return RadioListTile<ImportMode>(
        value: value,
        groupValue: mode,
        onChanged: onChanged,
        title: Text(title),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: tile(ImportMode.overwrite, 'Overwrite'),
              ),
              SizedBox(
                width: double.infinity,
                child: tile(ImportMode.merge, 'Merge'),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: tile(ImportMode.overwrite, 'Overwrite')),
            Expanded(child: tile(ImportMode.merge, 'Merge')),
          ],
        );
      },
    );
  }
}
