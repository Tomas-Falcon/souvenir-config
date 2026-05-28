import 'package:nfc_manager/nfc_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';

class NfcService {
  final _supabase = Supabase.instance.client;

  /// Starts an NFC session to read a tag.
  Future<void> startTagRead({
    required Function(String uuid, bool isRegistered) onResult,
    required Function(String error) onError,
  }) async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      onError("NFC is not available on this device.");
      return;
    }

    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      try {
        var ndef = Ndef.from(tag);
        if (ndef == null) {
          onError("Tag is not NDEF formatted.");
          return;
        }

        final message = ndef.cachedMessage;
        if (message == null || message.records.isEmpty) {
          onError("Tag is empty.");
          return;
        }

        // We expect the URL in the first record: https://app.tudominio.com/m/{uuid}
        final record = message.records.first;
        final payload = String.fromCharCodes(record.payload);
        
        // Extract UUID from URL (assuming format .../m/UUID)
        final uri = Uri.parse(payload.substring(1)); // payload[0] is often the URI prefix code
        final uuid = uri.pathSegments.last;

        // Check in Supabase if registered
        final response = await _supabase
            .from('tags')
            .select()
            .eq('uuid', uuid)
            .maybeSingle();

        onResult(uuid, response != null);
        NfcManager.instance.stopSession();
      } catch (e) {
        onError("Error reading tag: $e");
        NfcManager.instance.stopSession();
      }
    });
  }

  /// (ADMIN ONLY) Writes a new UUID to a blank tag and registers it in Supabase.
  Future<void> adminRegisterNewTag({
    required String batchId,
    required Function(String uuid) onSuccess,
    required Function(String error) onError,
  }) async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      onError("NFC not available.");
      return;
    }

    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      try {
        var ndef = Ndef.from(tag);
        if (ndef == null || !ndef.isWritable) {
          onError("Tag is not writable.");
          return;
        }

        // 1. Generate new UUID
        final newUuid = _supabase.rpc('gen_random_uuid') as String? ?? 
                         DateTime.now().millisecondsSinceEpoch.toString(); // Fallback simpler ID if RPC fails

        // 2. Register in DB (Admin Role required)
        await _supabase.from('tags').insert({
          'uuid': newUuid,
          'status': 'unassigned',
          'batch_id': batchId,
        });

        // 3. Write URL to Tag
        String url = "https://tomas-falcon.github.io/souvenir-config/m/$newUuid";
        NdefMessage message = NdefMessage([
          NdefRecord.createUri(Uri.parse(url)),
        ]);

        await ndef.write(message);
        
        // 4. (Optional) LOCK BIT - Warning: Permanent
        // await ndef.makeReadOnly(); 

        onSuccess(newUuid);
        NfcManager.instance.stopSession();
      } catch (e) {
        onError("Admin Error: $e");
        NfcManager.instance.stopSession();
      }
    });
  }
}
