// TODO: wire to [BookingRemoteDataSource] and map failures in a later sprint.
// Every method throws until the booking feature is implemented.
import '../../domain/entities/job.dart';
import '../../domain/entities/quote.dart';
import '../../domain/repositories/booking_repository.dart';
import '../datasources/booking_remote_datasource.dart';

class BookingRepositoryImpl implements BookingRepository {
  BookingRepositoryImpl(this._remoteDataSource);

  // ignore: unused_field, field reserved for the real implementation.
  final BookingRemoteDataSource _remoteDataSource;

  @override
  Future<Quote> fetchQuote(String jobId) {
    throw UnimplementedError('fetchQuote is not implemented yet.');
  }

  @override
  Future<Job> createJob(Job job) {
    throw UnimplementedError('createJob is not implemented yet.');
  }

  @override
  Future<List<Job>> fetchJobs() {
    throw UnimplementedError('fetchJobs is not implemented yet.');
  }
}
