import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'album_service.dart';

class GalleryScreen extends StatefulWidget {
  final String albumId;
  final String albumTitle;
  final List<Map<String, dynamic>> media;

  const GalleryScreen({
    super.key,
    required this.albumId,
    required this.albumTitle,
    required this.media,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final AlbumService _albumService = AlbumService();
  late List<Map<String, dynamic>> _currentMedia;
  final Set<int> _selectedIndexes = {};
  bool _isSelectionMode = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _currentMedia = List.from(widget.media);
  }

  Future<void> _uploadMore() async {
    final picker = ImagePicker();
    // Probamos pickMultiImage que es más compatible con versiones variadas de Android
    final List<XFile> images = await picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      setState(() => _isUploading = true);
      try {
        for (var image in images) {
          await _albumService.uploadMedia(
            albumId: widget.albumId, 
            file: File(image.path),
            type: 'image'
          );
        }
        final updatedMedia = await _albumService.getAlbumMedia(widget.albumId);
        setState(() {
          _currentMedia = updatedMedia;
          _isUploading = false;
        });
      } catch (e) {
        setState(() => _isUploading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al subir: $e")));
      }
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndexes.contains(index)) {
        _selectedIndexes.remove(index);
        if (_selectedIndexes.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIndexes.add(index);
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _deleteSelected() async {
    final itemsToDelete = _selectedIndexes.map((i) => _currentMedia[i]).toList();
    
    setState(() => _isUploading = true);
    try {
      await _albumService.deleteMediaItems(itemsToDelete);
      final updatedMedia = await _albumService.getAlbumMedia(widget.albumId);
      setState(() {
        _currentMedia = updatedMedia;
        _selectedIndexes.clear();
        _isSelectionMode = false;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al borrar: $e")));
    }
  }

  void _openFullScreen(int initialIndex) {
    if (_isSelectionMode) {
      _toggleSelection(initialIndex);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenGallery(
          media: _currentMedia,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode ? "${_selectedIndexes.length} seleccionados" : widget.albumTitle),
        backgroundColor: _isSelectionMode ? Colors.deepPurple : Colors.black.withOpacity(0.5),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _deleteSelected,
            ),
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _isSelectionMode = false;
                _selectedIndexes.clear();
              }),
            ),
        ],
      ),
      extendBodyBehindAppBar: true,
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton(
        onPressed: _isUploading ? null : _uploadMore,
        child: _isUploading 
          ? const CircularProgressIndicator(color: Colors.white) 
          : const Icon(Icons.add_a_photo),
      ),
      body: _currentMedia.isEmpty
          ? const Center(child: Text("Este álbum aún no tiene fotos."))
          : GridView.builder(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
                left: 8,
                right: 8,
                bottom: 8,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _currentMedia.length,
              itemBuilder: (context, index) {
                final item = _currentMedia[index];
                final isVideo = item['type'] == 'video';
                final isSelected = _selectedIndexes.contains(index);

                return GestureDetector(
                  onTap: () => _openFullScreen(index),
                  onLongPress: () => _toggleSelection(index),
                  child: Hero(
                    tag: item['url'],
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                        color: Colors.grey[900],
                        image: isVideo ? null : DecorationImage(
                          image: NetworkImage(item['url']),
                          fit: BoxFit.cover,
                          colorFilter: isSelected ? ColorFilter.mode(Colors.black.withOpacity(0.5), BlendMode.darken) : null,
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (isVideo) const Center(child: Icon(Icons.play_circle_outline, size: 40, color: Colors.white70)),
                          if (isSelected) const Positioned(top: 5, right: 5, child: Icon(Icons.check_circle, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class FullScreenGallery extends StatefulWidget {
  final List<Map<String, dynamic>> media;
  final int initialIndex;

  const FullScreenGallery({
    super.key,
    required this.media,
    required this.initialIndex,
  });

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.media.length,
        itemBuilder: (context, index) {
          final item = widget.media[index];
          final isVideo = item['type'] == 'video';

          return Center(
            child: isVideo 
              ? Hero(
                  tag: item['url'],
                  child: AlbumVideoPlayer(videoUrl: item['url']),
                )
              : InteractiveViewer(
                  child: Hero(
                    tag: item['url'],
                    child: Image.network(item['url'], fit: BoxFit.contain),
                  ),
                ),
          );
        },
      ),
    );
  }
}

class AlbumVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const AlbumVideoPlayer({super.key, required this.videoUrl});

  @override
  State<AlbumVideoPlayer> createState() => _AlbumVideoPlayerState();
}

class _AlbumVideoPlayerState extends State<AlbumVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {
          _isInitialized = true;
        });
        _controller.play(); // Auto play
        _controller.setLooping(true); // Loop
      }).catchError((error) {
        setState(() {
          _hasError = true;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 60),
          SizedBox(height: 16),
          Text(
            "Error al reproducir el video",
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      );
    }

    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_controller.value.isPlaying) {
            _controller.pause();
          } else {
            _controller.play();
          }
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          if (!_controller.value.isPlaying)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(16),
              child: const Icon(
                Icons.play_arrow,
                size: 50,
                color: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}
