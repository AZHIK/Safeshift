// Driver documents state (mock).
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/mock/mock_documents.dart';

part 'documents_provider.g.dart';

@riverpod
class DocumentsState extends _$DocumentsState {
  @override
  List<MockDocument> build() {
    ref.keepAlive();
    return mockDocuments;
  }
}
