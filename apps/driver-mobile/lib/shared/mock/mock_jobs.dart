// Mock incoming job requests with Dar es Salaam routes and TZS fares.

class DriverJob {
  const DriverJob({
    required this.id,
    required this.pickup,
    required this.destination,
    required this.distanceKm,
    required this.estimatedFareTzs,
    required this.cargoClass,
    required this.customerName,
    required this.pickupDistanceKm,
  });

  final String id;
  final String pickup;
  final String destination;
  final double distanceKm;
  final int estimatedFareTzs;
  final String cargoClass;
  final String customerName;
  final double pickupDistanceKm;
}

const List<DriverJob> mockJobs = <DriverJob>[
  DriverJob(
    id: 'JOB-1001',
    pickup: 'Kariakoo Market, Mchikichini',
    destination: 'Slipway, Masaki',
    distanceKm: 12.4,
    estimatedFareTzs: 62000,
    cargoClass: 'Furniture · 1 bedroom',
    customerName: 'Neema Juma',
    pickupDistanceKm: 1.8,
  ),
  DriverJob(
    id: 'JOB-1002',
    pickup: 'Mlimani City Mall, Ubungo',
    destination: 'Temeke Hospital, Temeke',
    distanceKm: 16.2,
    estimatedFareTzs: 78000,
    cargoClass: 'Shop stock · 800 kg',
    customerName: 'Juma Komba',
    pickupDistanceKm: 2.5,
  ),
  DriverJob(
    id: 'JOB-1003',
    pickup: 'Ubungo Bus Terminal',
    destination: 'Kigamboni Ferry',
    distanceKm: 21.5,
    estimatedFareTzs: 89000,
    cargoClass: 'Parcels · 12 boxes',
    customerName: 'Asha Mziwanda',
    pickupDistanceKm: 3.1,
  ),
  DriverJob(
    id: 'JOB-1004',
    pickup: 'Julius Nyerere International Airport',
    destination: 'Mbezi Beach, Africana',
    distanceKm: 24.8,
    estimatedFareTzs: 105000,
    cargoClass: 'Luggage · 6 suitcases',
    customerName: 'Kelvin Mushi',
    pickupDistanceKm: 4.0,
  ),
  DriverJob(
    id: 'JOB-1005',
    pickup: 'Tabata Kimanga',
    destination: 'Morocco Junction, Kinondoni',
    distanceKm: 9.6,
    estimatedFareTzs: 45000,
    cargoClass: 'Electronics · fragile',
    customerName: 'Zawadi Temba',
    pickupDistanceKm: 1.2,
  ),
  DriverJob(
    id: 'JOB-1006',
    pickup: 'Sinza Mori',
    destination: 'Posta, Kivukoni',
    distanceKm: 11.1,
    estimatedFareTzs: 54000,
    cargoClass: 'Office move · desks',
    customerName: 'David Lyimo',
    pickupDistanceKm: 2.2,
  ),
];
