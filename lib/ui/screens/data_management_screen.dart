import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/export_import_service.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Export',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _exportFile,
            child: const Text('Export to file'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _exportClipboard,
            child: const Text('Export to clipboard'),
          ),
          const SizedBox(height: 16),
          Text(
            'Import',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: RadioListTile<ImportMode>(
                  value: ImportMode.overwrite,
                  groupValue: _mode,
                  onChanged: (value) =>
                      setState(() => _mode = value ?? _mode),
                  title: const Text('Overwrite'),
                ),
              ),
              Expanded(
                child: RadioListTile<ImportMode>(
                  value: ImportMode.merge,
                  groupValue: _mode,
                  onChanged: (value) =>
                      setState(() => _mode = value ?? _mode),
                  title: const Text('Merge'),
                ),
              ),
            ],
          ),
          FilledButton(
            onPressed: () => _confirmOverwrite(_importFile),
            child: const Text('Import from file'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => _confirmOverwrite(_importClipboard),
            child: const Text('Import from clipboard'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _restoreBackup,
            child: const Text('Restore from last backup'),
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!),
          ],
          if (_report != null) ...[
            const SizedBox(height: 8),
            Text(
              'Added players: ${_report!.addedPlayers}\n'
              'Updated players: ${_report!.updatedPlayers}\n'
              'Added matches: ${_report!.addedMatches}\n'
              'Skipped matches: ${_report!.skippedMatches}',
            ),
            if (_report!.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _report!.errors.join('\n'),
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
