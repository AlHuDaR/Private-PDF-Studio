import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/model.dart';
import '../platform/files.dart';
import 'strings.dart';

class StudioApp extends StatefulWidget {
  const StudioApp({
    super.key,
    required this.engine,
    required this.files,
    required this.initialize,
  });
  final PdfEngine engine;
  final Files files;
  final Future<void> Function() initialize;
  @override
  State<StudioApp> createState() => _StudioAppState();
}

class _Page {
  _Page(this.ref);
  PageRef ref;
  bool selected = false;
}

class _StudioAppState extends State<StudioApp> {
  bool _arabic = false;
  bool _busy = false;
  bool _ready = false;
  bool _canCancel = false;
  double? _progress;
  Cancellation? _cancellation;
  final _sources = <SourceInfo>[];
  final _pages = <_Page>[];
  Failure? _error;
  String Function(Strings)? _message;
  Strings get s => Strings(_arabic);

  void _report(int completed, int total) {
    if (mounted) {
      setState(() => _progress = total == 0 ? null : completed / total);
    }
  }

  Future<void> _run(Future<void> Function(Cancellation token) work) async {
    if (_busy) {
      return;
    }
    final token = Cancellation();
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
      _progress = null;
      _cancellation = token;
    });
    try {
      await work(token);
    } on StudioException catch (error) {
      if (mounted) {
        setState(() => _error = error.code);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = Failure.fileAccess);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _canCancel = false;
          _cancellation = null;
          _progress = null;
        });
      }
    }
  }

  Future<void> _import() => _run((token) async {
    _message = (s) => s.reading;
    final inputs = await widget.files.pick(
      remainingFiles: Limits.files - _sources.length,
      remainingBytes:
          Limits.totalBytes -
          _sources.fold(0, (n, source) => n + source.byteLength),
    );
    if (!mounted) {
      token.cancel();
      return;
    }
    if (inputs.isEmpty) {
      setState(() => _message = null);
      return;
    }
    setState(() {
      _canCancel = true;
      _message = (s) => s.working;
    });
    if (!_ready) {
      try {
        await widget.initialize();
        _ready = true;
      } catch (_) {
        throw const StudioException(Failure.engineUnavailable);
      }
    }
    token.check();
    final imported = await widget.engine.import(inputs, token, _report);
    if (!mounted) {
      return;
    }
    setState(() {
      _sources.addAll(imported);
      for (final source in imported) {
        _pages.addAll(
          List.generate(
            source.pageCount,
            (index) => _Page(PageRef(source.id, index)),
          ),
        );
      }
      _message = (s) => s.imported;
    });
  });

  Future<void> _export(bool selectedOnly) => _run((token) async {
    final refs = _pages
        .where((p) => !selectedOnly || p.selected)
        .map((p) => p.ref)
        .toList(growable: false);
    if (refs.isEmpty) {
      throw const StudioException(Failure.emptySelection);
    }
    setState(() {
      _canCancel = true;
      _message = (s) => s.working;
    });
    final bytes = await widget.engine.export(refs, token, _report);
    token.check();
    if (!mounted) {
      return;
    }
    setState(() {
      _canCancel = false;
      _message = (s) => s.saving;
    });
    // Export never reuses an input path. Desktop refuses existing destinations;
    // Android creates a fresh SAF document; browsers use a blob download.
    final result = await widget.files.save(
      bytes,
      selectedOnly ? 'extracted-pages.pdf' : 'merged-pages.pdf',
    );
    if (!mounted) {
      return;
    }
    setState(
      () => _message = (s) => switch (result) {
        SaveResult.saved => s.saved,
        SaveResult.cancelled => s.saveCancelled,
        SaveResult.downloadStarted => s.download,
      },
    );
  });

  Future<void> _clear() => _run((token) async {
    await widget.engine.clear();
    if (mounted) {
      setState(() {
        _pages.clear();
        _sources.clear();
        _message = (s) => s.cleared;
      });
    }
  });

  void _move(int index, int offset) => setState(() {
    final page = _pages.removeAt(index);
    _pages.insert(index + offset, page);
  });

  @override
  void dispose() {
    _cancellation?.cancel();
    // Workspaces live for the app lifetime. Explicit Clear releases PDF handles.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Private PDF Studio',
    debugShowCheckedModeBanner: false,
    locale: Locale(_arabic ? 'ar' : 'en'),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff14665b)),
      fontFamily: _arabic ? 'NotoSansArabic' : 'NotoSans',
      fontFamilyFallback: [_arabic ? 'NotoSans' : 'NotoSansArabic'],
    ),
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: Text(s.title),
          actions: [
            TextButton(
              onPressed: () => setState(() => _arabic = !_arabic),
              child: Text(_arabic ? 'English' : 'العربية'),
            ),
            IconButton(
              tooltip: s.about,
              icon: const Icon(Icons.info_outline),
              onPressed: () => showAboutDialog(
                context: context,
                applicationName: s.title,
                applicationVersion: '0.1.0',
                children: [Text(s.explanation)],
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(s.privacy),
                    const SizedBox(height: 8),
                    Text(
                      s.limits,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _busy ? null : _import,
                          icon: const Icon(Icons.file_open),
                          label: Text(s.add),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _busy || _pages.isEmpty
                              ? null
                              : () => _export(false),
                          icon: const Icon(Icons.merge),
                          label: Text(s.merge),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy || !_pages.any((p) => p.selected)
                              ? null
                              : () => _export(true),
                          icon: const Icon(Icons.call_split),
                          label: Text(s.extract),
                        ),
                        TextButton(
                          onPressed: _busy || _sources.isEmpty ? null : _clear,
                          child: Text(s.clear),
                        ),
                      ],
                    ),
                    if (_busy) ...[
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _progress),
                      if (_canCancel)
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: TextButton(
                            onPressed: () => _cancellation?.cancel(),
                            child: Text(s.cancel),
                          ),
                        ),
                    ],
                    if (_error != null || _message != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _error != null ? s.error(_error!) : _message!(s),
                            style: TextStyle(
                              color: _error == null
                                  ? null
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      s.summary(
                        _sources.length,
                        _pages.length,
                        _pages.where((p) => p.selected).length,
                      ),
                    ),
                    if (_pages.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    for (final p in _pages) {
                                      p.selected = true;
                                    }
                                  }),
                            child: Text(s.selectAll),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    for (final p in _pages) {
                                      p.selected = false;
                                    }
                                  }),
                            child: Text(s.deselect),
                          ),
                        ],
                      ),
                    Expanded(
                      child: _pages.isEmpty
                          ? Center(child: Text(s.empty))
                          : ListView.builder(
                              itemCount: _pages.length,
                              itemBuilder: (context, i) {
                                final page = _pages[i];
                                final source = _sources.firstWhere(
                                  (source) => source.id == page.ref.sourceId,
                                );
                                return Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        CheckboxListTile(
                                          value: page.selected,
                                          dense: true,
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                          title: Text(
                                            source.name,
                                            textDirection: TextDirection.ltr,
                                          ),
                                          subtitle: Text(
                                            s.page(
                                              page.ref.index + 1,
                                              page.ref.turns * 90,
                                            ),
                                          ),
                                          onChanged: _busy
                                              ? null
                                              : (v) => setState(
                                                  () => page.selected =
                                                      v ?? false,
                                                ),
                                        ),
                                        Wrap(
                                          alignment: WrapAlignment.end,
                                          children: [
                                            IconButton(
                                              tooltip: s.up,
                                              icon: const Icon(
                                                Icons.arrow_upward,
                                              ),
                                              onPressed: _busy || i == 0
                                                  ? null
                                                  : () => _move(i, -1),
                                            ),
                                            IconButton(
                                              tooltip: s.down,
                                              icon: const Icon(
                                                Icons.arrow_downward,
                                              ),
                                              onPressed:
                                                  _busy ||
                                                      i == _pages.length - 1
                                                  ? null
                                                  : () => _move(i, 1),
                                            ),
                                            IconButton(
                                              tooltip: s.rotate,
                                              icon: const Icon(
                                                Icons.rotate_right,
                                              ),
                                              onPressed: _busy
                                                  ? null
                                                  : () => setState(
                                                      () => page.ref = page.ref
                                                          .rotate(),
                                                    ),
                                            ),
                                            IconButton(
                                              tooltip: s.remove,
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                              ),
                                              onPressed: _busy
                                                  ? null
                                                  : () => setState(
                                                      () => _pages.removeAt(i),
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
