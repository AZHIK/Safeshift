// TODO: implement with Supabase quote/jobs APIs in a later sprint.
import '../entities/job.dart';
import '../entities/quote.dart';

/// Booking repository contract. Placeholder only.
abstract class BookingRepository {
  Future<Quote> fetchQuote(String jobId);
  Future<Job> createJob(Job job);
  Future<List<Job>> fetchJobs();
}
