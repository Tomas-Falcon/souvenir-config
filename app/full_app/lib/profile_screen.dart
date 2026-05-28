import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'album_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _supabase = Supabase.instance.client;
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  User? get _user => _supabase.auth.currentUser;

  Future<void> _updatePassword() async {
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("La contraseña debe tener al menos 6 caracteres")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contraseña actualizada con éxito")),
        );
        _passwordController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final albumService = AlbumService();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Cómo quieres irte?"),
        content: const Text(
          "Tienes dos opciones para tus imanes antes de borrar tu cuenta:\n\n"
          "A) Borrado Total: Se borran todas tus fotos y los imanes quedan libres para reutilizar.\n\n"
          "B) Legado: Tus fotos se quedan en los imanes para siempre, pero ya no tendrás acceso a ellas.",
        ),
        actions: [
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    // Opción A: Borrar todo
                    final albums = await albumService.getUserAlbums();
                    for (var album in albums) {
                      await albumService.deleteAlbum(album['id']);
                    }
                    await _executeAccountDeletion();
                  },
                  child: const Text("A) Borrar todo y liberar imanes"),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  onPressed: () async {
                    // Opción B: Dejar legado
                    final albums = await albumService.getUserAlbums();
                    for (var album in albums) {
                      await albumService.orphanAlbum(album['id']);
                    }
                    await _executeAccountDeletion();
                  },
                  child: const Text("B) Dejar mis recuerdos (Legado)"),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar"),
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _executeAccountDeletion() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cuenta procesada con éxito.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Mi Perfil")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: CircleAvatar(
                radius: 50,
                child: Icon(Icons.person, size: 50),
              ),
            ),
            const SizedBox(height: 24),
            const Text("Email", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            Text(_user?.email ?? "No disponible", style: const TextStyle(fontSize: 18)),
            const Divider(height: 40),
            const Text("Cambiar Contraseña", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: "Nueva Contraseña",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
            ),
            const SizedBox(height: 16),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _updatePassword,
                      child: const Text("Actualizar Contraseña"),
                    ),
                  ),
            const SizedBox(height: 60),
            const Divider(),
            const Text("Zona Peligrosa", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _confirmDeleteAccount,
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                label: const Text("Cerrar/Eliminar mi cuenta", style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
