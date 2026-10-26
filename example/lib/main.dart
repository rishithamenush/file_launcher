import 'dart:io';
import 'package:file_launcher/file_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'samples.dart';

void main() => runApp(const FileLauncherExample());

class FileLauncherExample extends StatelessWidget {
  const FileLauncherExample({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'File launcher',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087f72)),
      scaffoldBackgroundColor: const Color(0xfff4f7fa),
      useMaterial3: true,
    ),
    home: const SamplePage(),
  );
}

class SamplePage extends StatefulWidget {
  const SamplePage({super.key});
  @override
  State<SamplePage> createState() => _SamplePageState();
}

class _SamplePageState extends State<SamplePage> {
  String _status = 'Choose a sample to open on this device.';
  String _category = 'All';
  OpenFileResult? _result;
  bool _busy = false;
  Future<Directory>? _directory;

  bool _fromMemory = false;
  bool _askEveryTime = false;

  Future<void> _open(
    FileSample sample, {
    bool missing = false,
    bool share = false,
    Rect? origin,
  }) async {
    setState(() {
      _busy = true;
      _result = null;
      _status = 'Preparing ${sample.label.toLowerCase()}…';
    });
    try {
      final OpenFileResult result;
      final watch = Stopwatch();
      if (_fromMemory && !missing && !share) {
        final data = await rootBundle.load('assets/${sample.name}');
        watch.start();
        result = await FileLauncher.openBytes(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          fileName: sample.name,
          title: sample.label,
          mimeType: sample.mimeType,
          showAppChooser: _askEveryTime,
          sharePositionOrigin: origin,
        );
      } else {
        final directory = await (_directory ??= Directory.systemTemp.createTemp(
          'file_launcher_example_',
        ));
        final file = File('${directory.path}/${sample.name}');
        if (!missing) {
          final bytes = await rootBundle.load('assets/${sample.name}');
          await file.writeAsBytes(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
        }
        watch.start();
        result = share
            ? await FileLauncher.share(
                file.path,
                title: sample.label,
                mimeType: sample.mimeType,
                sharePositionOrigin: origin,
              )
            : await FileLauncher.open(
                file.path,
                title: sample.label,
                mimeType: sample.mimeType,
                showAppChooser: _askEveryTime,
                sharePositionOrigin: origin,
              );
      }
      if (mounted) {
        setState(() {
          _result = result;
          _status =
              '${result.status.name} · ${watch.elapsedMilliseconds} ms\n${result.message}';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Could not prepare sample: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _clearCache() async {
    final cleared = await FileLauncher.clearCache();
    if (mounted) {
      setState(() {
        _result = null;
        _status = cleared
            ? 'Cleared the private copies made by file_launcher.'
            : 'Could not clear copies now. Close any open viewer and retry.';
      });
    }
  }

  static Rect? _originOf(BuildContext context) {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final visible = fileSamples
        .where((sample) => _category == 'All' || sample.category == _category)
        .toList();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xfff4f7fa),
        title: const Text(
          'file_launcher',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: Chip(
              label: Text('EXAMPLE'),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xff102f40), Color(0xff096d66)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'LOCAL FILES. NATIVE EXPERIENCES.',
                      style: TextStyle(
                        color: Color(0xff8debd3),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'One call.\nOpen possibilities.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Documents, audio, video and images.\nTry a real file on your device.',
                      style: TextStyle(
                        color: Color(0xffd1e4e9),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final label in [
                          'Mobile + desktop',
                          '${fileSamples.length} samples',
                          'No storage prompts',
                        ])
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffdce5ea)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _result == null
                          ? Icons.touch_app_outlined
                          : _result!.isSuccess
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      color: const Color(0xff087f72),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _status,
                        key: const Key('status'),
                        style: const TextStyle(fontSize: 13, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
              const SizedBox(height: 24),
              const Text(
                'Explore file types',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff102f40),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final category in [
                      'All',
                      'Documents',
                      'Audio',
                      'Video',
                      'Images',
                      'Data',
                      'Other',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category),
                          selected: _category == category,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final sample in visible)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Builder(
                    builder: (row) => Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 5,
                        ),
                        leading: Container(
                          width: 42,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xffe8f5f0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            sample.icon,
                            color: const Color(0xff087f72),
                          ),
                        ),
                        title: Text(
                          sample.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          '${sample.name} · ${sample.detail}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xff5c7180),
                          ),
                        ),
                        trailing: Builder(
                          builder: (button) => IconButton(
                            tooltip: 'Share',
                            icon: const Icon(
                              Icons.ios_share,
                              size: 20,
                              color: Color(0xff087f72),
                            ),
                            onPressed: _busy
                                ? null
                                : () => _open(
                                    sample,
                                    share: true,
                                    origin: _originOf(button),
                                  ),
                          ),
                        ),
                        onTap: _busy
                            ? null
                            : () => _open(sample, origin: _originOf(row)),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Material(
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xffdce5ea)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Open from memory'),
                      subtitle: const Text('Uses FileLauncher.openBytes'),
                      value: _fromMemory,
                      onChanged: (value) => setState(() => _fromMemory = value),
                    ),
                    SwitchListTile(
                      title: const Text('Ask which app every time'),
                      subtitle: const Text('Android and Windows'),
                      value: _askEveryTime,
                      onChanged: (value) =>
                          setState(() => _askEveryTime = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'iOS uses Quick Look. Android, macOS, Windows and Linux use an installed app. When no viewer is available on mobile or macOS, the system share sheet is the fallback. Tap the share icon to skip the viewer. Close native UI before opening another sample.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Color(0xff5c7180),
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _open(
                        const FileSample(
                          'missing.pdf',
                          'Missing file',
                          'Other',
                          '',
                          Icons.error_outline,
                        ),
                        missing: true,
                      ),
                child: const Text('Test a missing file'),
              ),
              TextButton(
                onPressed: _busy ? null : _clearCache,
                child: const Text('Clear cached copies'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
