class MockLocation {
  const MockLocation({
    required this.id,
    required this.name,
    required this.district,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String district;
  final double latitude;
  final double longitude;
}

const List<MockLocation> mockLocations = <MockLocation>[
  MockLocation(
    id: 'kariakoo',
    name: 'Kariakoo Market',
    district: 'Ilala',
    latitude: -6.8161,
    longitude: 39.2804,
  ),
  MockLocation(
    id: 'ubungo',
    name: 'Ubungo Bus Terminal',
    district: 'Ubungo',
    latitude: -6.7924,
    longitude: 39.2083,
  ),
  MockLocation(
    id: 'mbezi-beach',
    name: 'Mbezi Beach',
    district: 'Kinondoni',
    latitude: -6.6878,
    longitude: 39.2243,
  ),
  MockLocation(
    id: 'temeke-hospital',
    name: 'Temeke Hospital',
    district: 'Temeke',
    latitude: -6.8915,
    longitude: 39.2671,
  ),
  MockLocation(
    id: 'kigamboni-ferry',
    name: 'Kigamboni Ferry',
    district: 'Kigamboni',
    latitude: -6.8271,
    longitude: 39.3020,
  ),
  MockLocation(
    id: 'airport',
    name: 'Julius Nyerere International Airport',
    district: 'Ilala',
    latitude: -6.8781,
    longitude: 39.2026,
  ),
  MockLocation(
    id: 'mlimani-city',
    name: 'Mlimani City Mall',
    district: 'Ubungo',
    latitude: -6.7797,
    longitude: 39.2236,
  ),
  MockLocation(
    id: 'slipway',
    name: 'Slipway',
    district: 'Kinondoni',
    latitude: -6.7467,
    longitude: 39.2732,
  ),
  MockLocation(
    id: 'morocco',
    name: 'Morocco Junction',
    district: 'Kinondoni',
    latitude: -6.7738,
    longitude: 39.2601,
  ),
  MockLocation(
    id: 'tabata',
    name: 'Tabata Kimanga',
    district: 'Ilala',
    latitude: -6.8447,
    longitude: 39.2108,
  ),
];
