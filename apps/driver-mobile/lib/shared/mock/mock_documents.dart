// Mock driver documents with verification statuses.

class MockDocument {
  const MockDocument({
    required this.id,
    required this.title,
    required this.status,
    required this.expiry,
  });

  final String id;
  final String title;
  final String status;
  final String expiry;
}

const List<MockDocument> mockDocuments = <MockDocument>[
  MockDocument(
    id: 'doc-001',
    title: 'Driving licence',
    status: 'verified',
    expiry: '12 Dec 2027',
  ),
  MockDocument(
    id: 'doc-002',
    title: 'Vehicle registration (card)',
    status: 'verified',
    expiry: 'No expiry',
  ),
  MockDocument(
    id: 'doc-003',
    title: 'Vehicle insurance',
    status: 'pending',
    expiry: 'Under review',
  ),
  MockDocument(
    id: 'doc-004',
    title: 'Roadworthiness (safety inspection)',
    status: 'expired',
    expiry: 'Expired 02 Jan 2026',
  ),
];
