import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'nfc_service.dart';
import 'album_service.dart';
import 'gallery_screen.dart';
import 'profile_screen.dart';
import 'app_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppSettings.supabaseUrl,
    anonKey: AppSettings.supabaseAnonKey,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppSettings.appName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.light),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return const MyHomePage(title: AppSettings.appName);
    }
    return const LoginPage();
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSigningUp = false;
  bool _obscurePassword = true;

  Future<void> _authenticate() async {
    setState(() => _isLoading = true);
    try {
      if (_isSigningUp) {
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          emailRedirectTo: AppSettings.siteUrl,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("¡Cuenta creada! Revisa tu email para confirmar.")),
          );
        }
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthGate()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isSigningUp ? "Crear Cuenta" : "Bienvenido")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.auto_awesome, size: 60, color: Colors.deepPurpleAccent),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: "Contraseña", 
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
            ),
            const SizedBox(height: 24),
            _isLoading 
              ? const CircularProgressIndicator() 
              : SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _authenticate, 
                    child: Text(_isSigningUp ? "Registrarme" : "Entrar"),
                  ),
                ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _isSigningUp = !_isSigningUp),
              child: Text(_isSigningUp 
                ? "¿Ya tienes cuenta? Entra aquí" 
                : "¿No tienes cuenta? Regístrate"),
            ),
          ],
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final NfcService _nfcService = NfcService();
  final AlbumService _albumService = AlbumService();
  String _status = "Listo para escanear";
  List<Map<String, dynamic>> _myAlbums = [];
  bool _isLoadingAlbums = true;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    try {
      final albums = await _albumService.getUserAlbums();
      setState(() {
        _myAlbums = albums;
        _isLoadingAlbums = false;
      });
    } catch (e) {
      setState(() => _isLoadingAlbums = false);
    }
  }

  void _onTagScanned() {
    setState(() => _status = "Acerca el imán...");
    _nfcService.startTagRead(
      onResult: (uuid, isRegistered) => _processScannedUuid(uuid),
      onError: (err) => setState(() => _status = "Error: $err"),
    );
  }

  Future<void> _processScannedUuid(String uuid) async {
    final supabase = Supabase.instance.client;
    final tagRecord = await supabase
        .from('tags')
        .select('*, albums(*)')
        .eq('uuid', uuid)
        .maybeSingle();

    if (tagRecord == null || tagRecord['album_id'] == null) {
      _showCreateAlbumDialog(uuid);
    } else {
      final album = tagRecord['albums'];
      final isOwner = album['user_id'] == supabase.auth.currentUser?.id;
      final isPublished = album['is_published'] ?? false;

      // Registrar el escaneo en la BD
      await _albumService.logScan(uuid);

      if (isOwner || isPublished) {
        _openGallery(tagRecord['album_id'], album['title']);
      } else {
        setState(() => _status = "Este imán aún no ha sido liberado.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("El dueño aún no ha liberado este contenido.")),
          );
        }
      }
    }
  }

  Future<void> _openGallery(String albumId, String title) async {
    final media = await _albumService.getAlbumMedia(albumId);
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GalleryScreen(
            albumId: albumId,
            albumTitle: title,
            media: media,
          ),
        ),
      ).then((_) => _loadAlbums()); // Recargar al volver
    }
  }

  void _showCreateAlbumDialog(String uuid) {
    final titleController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¡Imán nuevo detectado!"),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(hintText: "Nombre del álbum (Ej: Madrid 2024)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              final title = titleController.text;
              if (title.isEmpty) return;
              final albumId = await _albumService.createAlbumAndLinkTag(tagUuid: uuid, title: title);
              if (mounted) {
                Navigator.pop(context);
                _loadAlbums();
                _showUploadOptions(albumId);
              }
            },
            child: const Text("Crear Álbum"),
          ),
        ],
      ),
    );
  }

  void _showUploadOptions(String albumId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Añadir Fotos"),
              subtitle: const Text("Múltiple: Mantén presionado para seleccionar varios"),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final List<XFile> images = await picker.pickMultiImage();
                if (images.isNotEmpty) {
                  setState(() => _status = "Subiendo ${images.length} fotos...");
                  for (var item in images) {
                    await _albumService.uploadMedia(albumId: albumId, file: File(item.path), type: 'image');
                  }
                  _loadAlbums();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Fotos subidas!")));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text("Añadir Video"),
              onTap: () async {
                Navigator.pop(context);
                final picker = ImagePicker();
                final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
                if (video != null) {
                  setState(() => _status = "Subiendo video...");
                  await _albumService.uploadMedia(albumId: albumId, file: File(video.path), type: 'video');
                  _loadAlbums();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Video subido!")));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => const ProfileScreen())
            ), 
            icon: const Icon(Icons.person_outline)
          ),
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthGate()));
            }, 
            icon: const Icon(Icons.logout)
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.nfc, size: 40),
                    title: Text(_status),
                    subtitle: const Text("Toca para escanear un nuevo souvenir"),
                    onTap: _onTagScanned,
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              hintText: "Simular UUID (Pega aquí)",
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (value) {
                              if (value.isNotEmpty) _processScannedUuid(value);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.bug_report, color: Colors.orange),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.photo_album_outlined),
                SizedBox(width: 10),
                Text("Mis Recuerdos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingAlbums
                ? const Center(child: CircularProgressIndicator())
                : _myAlbums.isEmpty
                    ? const Center(child: Text("Aún no tienes álbumes registrados."))
                    : ListView.builder(
                        itemCount: _myAlbums.length,
                        itemBuilder: (context, index) {
                          final album = _myAlbums[index];
                          final bool isPublished = album['is_published'] ?? false;
                          final String? coverUrl = album['cover_url'];
                          final String lastScan = album['last_scanned_at'] != null 
                              ? album['last_scanned_at'].toString().split('T')[1].substring(0, 5) 
                              : "Nunca";

                          return ListTile(
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: isPublished ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                                image: coverUrl != null ? DecorationImage(
                                  image: NetworkImage(coverUrl),
                                  fit: BoxFit.cover,
                                ) : null,
                              ),
                              child: coverUrl == null 
                                ? Icon(isPublished ? Icons.public : Icons.public_off, 
                                    color: isPublished ? Colors.green : Colors.grey, size: 24)
                                : null,
                            ),
                            title: Text(album['title']),
                            subtitle: Text("Escaneado: $lastScan"),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  _showEditAlbumDialog(album['id'], album['title']);
                                } else if (value == 'set_cover') {
                                  _pickAndSetCover(album['id']);
                                } else if (value == 'toggle_pub') {
                                  await _albumService.toggleAlbumPublication(album['id'], !isPublished);
                                  _loadAlbums();
                                } else if (value == 'delete') {
                                  _showDeleteConfirm(album['id']);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Text("Renombrar")),
                                const PopupMenuItem(value: 'set_cover', child: Text("Cambiar Portada")),
                                PopupMenuItem(
                                  value: 'toggle_pub', 
                                  child: Text(isPublished ? "Bloquear" : "Liberar")
                                ),
                                const PopupMenuItem(value: 'delete', child: Text("Eliminar", style: TextStyle(color: Colors.red))),
                              ],
                            ),
                            onTap: () => _openGallery(album['id'], album['title']),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showEditAlbumDialog(String albumId, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Renombrar Álbum"),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            onPressed: () async {
              await _albumService.updateAlbumTitle(albumId, controller.text);
              if (mounted) {
                Navigator.pop(context);
                _loadAlbums();
              }
            }, 
            child: const Text("Guardar")
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(String albumId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar álbum?"),
        content: const Text("Esto desvinculará el imán y borrará el álbum de tu cuenta. No se puede deshacer."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _albumService.deleteAlbum(albumId);
              if (mounted) {
                Navigator.pop(context);
                _loadAlbums();
              }
            }, 
            child: const Text("Eliminar", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndSetCover(String albumId) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() => _status = "Subiendo portada...");
      try {
        await _albumService.setAlbumCover(albumId, File(image.path));
        _loadAlbums();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("¡Portada actualizada!"))
          );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        setState(() => _status = "Listo");
      }
    }
  }
}
