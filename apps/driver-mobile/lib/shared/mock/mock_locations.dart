// Mock Dar es Salaam locations for the address suggestion sheet.
// Demo data only — no backend involved.

class MockLocation {
  const MockLocation({required this.name, required this.district});

  final String name;
  final String district;
}

const List<MockLocation> mockLocations = <MockLocation>[
  MockLocation(name: 'Kariakoo Market', district: 'Ilala'),
  MockLocation(name: 'Mlimani City Mall', district: 'Ubungo'),
  MockLocation(name: 'Slipway', district: 'Masaki'),
  MockLocation(name: 'Ubungo Bus Terminal', district: 'Ubungo'),
  MockLocation(name: 'Kigamboni Ferry', district: 'Kigamboni'),
  MockLocation(name: 'Julius Nyerere International Airport', district: 'Ilala'),
  MockLocation(name: 'Mbezi Beach', district: 'Kinondoni'),
  MockLocation(name: 'Tabata Kimanga', district: 'Ilala'),
  MockLocation(name: 'Morocco Junction', district: 'Kinondoni'),
  MockLocation(name: 'Temeke Hospital', district: 'Temeke'),
  MockLocation(name: 'Sinza Mori', district: 'Ubungo'),
  MockLocation(name: 'Posta, Kivukoni', district: 'Ilala'),
];
