import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_service.dart';
import '../../../core/network/supabase_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/data/driver_repository.dart';

class DocumentsNotifier extends AsyncNotifier<List<DriverDocumentSnapshot>> {
  @override
  Future<List<DriverDocumentSnapshot>> build() async {
    final user = ref.watch(authProvider).currentUser;
    if (user == null) return const <DriverDocumentSnapshot>[];
    final cache = ref.read(cacheServiceProvider);
    final cached = _readCache(cache, user.id);
    if (cached.isNotEmpty) {
      unawaited(_refresh(user.id));
      return cached;
    }
    return _refresh(user.id);
  }

  Future<List<DriverDocumentSnapshot>> _refresh(String userId) async {
    final docs = await DriverRepository(
      ref.read(supabaseProvider),
    ).documents();
    await ref.read(cacheServiceProvider).putJson(
      userId,
      'driver_documents',
      docs
          .map(
            (doc) => {
              'id': doc.id,
              'document_type_id': doc.documentTypeId,
              'title': doc.title,
              'status': doc.status,
              'expires_at': doc.expiresAt?.toIso8601String(),
              'file_path': doc.filePath,
              'rejection_reason': doc.rejectionReason,
            },
          )
          .toList(growable: false),
    );
    return docs;
  }

  Future<void> refresh() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) {
      state = const AsyncData(<DriverDocumentSnapshot>[]);
      return;
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _refresh(user.id));
  }

  Future<void> upload({
    required String documentTypeId,
    required List<int> bytes,
    required String fileName,
    String? mimeType,
    DateTime? expiresAt,
  }) async {
    await DriverRepository(ref.read(supabaseProvider)).uploadDocument(
      documentTypeId: documentTypeId,
      bytes: bytes,
      fileName: fileName,
      mimeType: mimeType,
      expiresAt: expiresAt,
    );
    await refresh();
  }

  List<DriverDocumentSnapshot> _readCache(CacheService cache, String userId) {
    final raw = cache.getJson(userId, 'driver_documents');
    if (raw is! List) return const <DriverDocumentSnapshot>[];
    final docs = <DriverDocumentSnapshot>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = item.cast<String, dynamic>();
      docs.add(
        DriverDocumentSnapshot(
          id: map['id'] as String? ?? '',
          documentTypeId: map['document_type_id'] as String? ?? '',
          title: map['title'] as String? ?? 'Document',
          status: map['status'] as String? ?? 'pending',
          expiresAt: DateTime.tryParse('${map['expires_at'] ?? ''}'),
          filePath: map['file_path'] as String?,
          rejectionReason: map['rejection_reason'] as String?,
        ),
      );
    }
    return docs;
  }
}

final documentsStateProvider =
    AsyncNotifierProvider<DocumentsNotifier, List<DriverDocumentSnapshot>>(
      DocumentsNotifier.new,
    );
