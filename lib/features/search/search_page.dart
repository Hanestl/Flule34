import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import '../../features/video/video_detail_page.dart';
import '../../shared/video_card.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key, required this.api});

  final Rule34VideoApi api;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<TagSuggestion> _suggestions = const [];
  List<VideoItem> _results = const [];
  var _searching = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final values = await widget.api.searchTags(value);
        if (mounted && _controller.text == value) {
          setState(() => _suggestions = values.take(8).toList(growable: false));
        }
      } catch (_) {
        if (mounted) {
          setState(() => _suggestions = const []);
        }
      }
    });
  }

  Future<void> _search([String? query]) async {
    final text = (query ?? _controller.text).trim();
    if (text.isEmpty || _searching) {
      return;
    }
    _controller.value = _controller.value.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _error = null;
      _suggestions = const [];
    });
    try {
      final results = await widget.api.searchVideos(text, 1);
      if (mounted) {
        setState(() => _results = results);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _controller,
            onChanged: _onChanged,
            onSubmitted: (_) => _search(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '按标签或关键词搜索',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.arrow_forward),
                onPressed: _search,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (_suggestions.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ActionChip(
                  label: Text(
                    '${suggestion.title} · ${formatCount(suggestion.total)}',
                  ),
                  onPressed: () => _search(suggestion.title),
                );
              },
            ),
          ),
        Expanded(child: _buildResults(context)),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(child: Text('输入关键词后即可搜索视频和标签。'));
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final video = _results[index];
        return VideoCard(
          video: video,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => VideoDetailPage(api: widget.api, video: video),
            ),
          ),
        );
      },
    );
  }
}
