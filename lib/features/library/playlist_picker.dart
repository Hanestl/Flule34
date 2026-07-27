import 'package:flutter/material.dart';

import '../../core/api/rule34video_api.dart';
import '../../core/models/video_models.dart';
import 'playlist_form_dialog.dart';

Future<String?> manageVideoAccountPlaylists({
  required BuildContext context,
  required Rule34VideoApi api,
  required VideoItem video,
}) async {
  final playlistsFuture = api.loadMyPlaylists();
  final containedIdsFuture = api.playlistIdsForVideo(video);
  final playlists = await playlistsFuture;
  final containedIds = await containedIdsFuture;
  if (!context.mounted) {
    return null;
  }
  final selectedId = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    builder: (context) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text('播放列表', style: Theme.of(context).textTheme.titleLarge),
        ),
        for (final item in playlists)
          ListTile(
            leading: const Icon(Icons.playlist_play),
            title: Text(item.title),
            subtitle: item.videoCount == null
                ? null
                : Text('${item.videoCount} 个视频'),
            trailing: containedIds.contains(item.id)
                ? const Icon(Icons.check_circle)
                : null,
            onTap: () => Navigator.pop(context, item.id),
          ),
        ListTile(
          leading: const Icon(Icons.playlist_add),
          title: const Text('新建播放列表'),
          onTap: () => Navigator.pop(context, _newPlaylistValue),
        ),
      ],
    ),
  );
  if (selectedId == null || !context.mounted) {
    return null;
  }
  if (selectedId == _newPlaylistValue) {
    final form = await showPlaylistEditor(
      context,
      title: '新建播放列表',
      initial: const PlaylistFormData(title: ''),
    );
    if (form == null || !context.mounted) {
      return null;
    }
    final previousIds = playlists.map((item) => item.id).toSet();
    await api.createPlaylist(form);
    final updated = await api.loadMyPlaylists(force: true);
    final created = updated
        .where((item) => !previousIds.contains(item.id))
        .toList(growable: false);
    if (created.isEmpty) {
      throw const ApiException('播放列表已创建，但未能读取新列表。');
    }
    final playlist = created.where((item) => item.title == form.title).isEmpty
        ? created.first
        : created.firstWhere((item) => item.title == form.title);
    await api.addVideoToPlaylist(video: video, playlistId: playlist.id);
    return '已新建并加入播放列表“${playlist.title}”。';
  }
  final playlist = playlists.firstWhere((item) => item.id == selectedId);
  if (containedIds.contains(playlist.id)) {
    await api.removeVideoFromPlaylist(video: video, playlistId: playlist.id);
    return '已从播放列表“${playlist.title}”移出。';
  }
  await api.addVideoToPlaylist(video: video, playlistId: playlist.id);
  return '已加入播放列表“${playlist.title}”。';
}

const _newPlaylistValue = '__new_playlist__';
