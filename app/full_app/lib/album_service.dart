import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class AlbumService {
  final _supabase = Supabase.instance.client;

  /// Creates a new album and links it to a tag.
  Future<String> createAlbumAndLinkTag({
    required String tagUuid,
    required String title,
    bool isPrivate = false,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    // 1. Create the album
    final albumResponse = await _supabase.from('albums').insert({
      'user_id': user.id,
      'title': title,
      'is_private': isPrivate,
    }).select().single();

    final albumId = albumResponse['id'];

    // 2. Link the tag to the album and mark as active
    await _supabase.from('tags').update({
      'status': 'active',
      'album_id': albumId,
    }).eq('uuid', tagUuid);

    return albumId;
  }

  /// Uploads media to Supabase Storage and records it in the Media table.
  Future<void> uploadMedia({
    required String albumId,
    required File file,
    required String type, // 'image' or 'video'
  }) async {
    final cleanFileName = file.path.split(RegExp(r'[/\\]')).last;
    final extension = file.path.split('.').last;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$cleanFileName';
    final path = '$albumId/$fileName';

    // 1. Upload to Storage
    await _supabase.storage.from('souvenir-media').upload(
      path, 
      file,
      fileOptions: FileOptions(contentType: type == 'image' ? 'image/$extension' : 'video/$extension'),
    );

    // 2. Get Public URL
    final publicUrl = _supabase.storage.from('souvenir-media').getPublicUrl(path);

    // 3. Save to Media table
    await _supabase.from('media').insert({
      'album_id': albumId,
      'type': type,
      'url': publicUrl,
    });

    // 4. Proactive: Automate Cover Image if not set
    if (type == 'image') {
      try {
        final albumData = await _supabase
            .from('albums')
            .select('cover_url')
            .eq('id', albumId)
            .maybeSingle();
        if (albumData != null && albumData['cover_url'] == null) {
          await _supabase
              .from('albums')
              .update({'cover_url': publicUrl})
              .eq('id', albumId);
        }
      } catch (e) {
        // Silent catch to prevent blocking main upload flow if cover update fails
      }
    }
  }

  /// Fetches all media for a specific album.
  Future<List<Map<String, dynamic>>> getAlbumMedia(String albumId) async {
    return await _supabase
        .from('media')
        .select()
        .eq('album_id', albumId)
        .order('created_at', ascending: true);
  }

  /// Fetches all albums owned by the current user.
  Future<List<Map<String, dynamic>>> getUserAlbums() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];
    
    return await _supabase
        .from('albums')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
  }

  /// Updates an album's title.
  Future<void> updateAlbumTitle(String albumId, String newTitle) async {
    await _supabase
        .from('albums')
        .update({'title': newTitle})
        .eq('id', albumId);
  }

  /// Toggles the "liberated/published" status of an album.
  Future<void> toggleAlbumPublication(String albumId, bool isPublished) async {
    await _supabase
        .from('albums')
        .update({'is_published': isPublished})
        .eq('id', albumId);
  }

  /// Sets or updates the cover image for an album.
  Future<void> setAlbumCover(String albumId, File file) async {
    final cleanFileName = file.path.split(RegExp(r'[/\\]')).last;
    final extension = file.path.split('.').last;
    final fileName = 'cover_${DateTime.now().millisecondsSinceEpoch}_$cleanFileName';
    final path = '$albumId/$fileName';

    // 1. Upload cover to Storage
    await _supabase.storage.from('souvenir-media').upload(
      path, 
      file,
      fileOptions: FileOptions(contentType: 'image/$extension'),
    );

    // 2. Get Public URL
    final publicUrl = _supabase.storage.from('souvenir-media').getPublicUrl(path);

    // 3. Update Album table
    await _supabase.from('albums').update({'cover_url': publicUrl}).eq('id', albumId);
  }

  /// Logs a scan for an album via its tag UUID.
  Future<void> logScan(String tagUuid) async {
    await _supabase.rpc('log_album_scan', params: {'tag_uuid': tagUuid});
  }

  /// Deletes an album and all its associated media and tag links.
  Future<void> deleteAlbum(String albumId) async {
    // 1. Unlink tags (set to unassigned)
    await _supabase
        .from('tags')
        .update({'status': 'unassigned', 'album_id': null})
        .eq('album_id', albumId);

    // 2. Delete the album
    await _supabase.from('albums').delete().eq('id', albumId);
  }

  /// Deletes multiple media items from DB and Storage.
  Future<void> deleteMediaItems(List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;

    final List<String> ids = items.map((e) => e['id'].toString()).toList();
    final List<String> storagePaths = items.map((e) {
      // Extract path from URL: .../souvenir-media/albumId/filename
      final uri = Uri.parse(e['url']);
      final pathSegments = uri.pathSegments;
      // pathSegments usually looks like: [..., souvenir-media, albumId, filename]
      final storageIndex = pathSegments.indexOf('souvenir-media');
      return pathSegments.sublist(storageIndex + 1).join('/');
    }).toList();

    // 1. Delete from Database
    await _supabase.from('media').delete().inFilter('id', ids);

    // 2. Delete from Storage
    await _supabase.storage.from('souvenir-media').remove(storagePaths);
  }

  /// "Orphans" an album: removes the owner but keeps the content and makes it public.
  Future<void> orphanAlbum(String albumId) async {
    await _supabase
        .from('albums')
        .update({
          'user_id': null, 
          'is_published': true // Lo hacemos público para que se siga viendo
        })
        .eq('id', albumId);
  }
}
