// TODO: implement with Supabase (quotes/jobs tables) in a later sprint.
import '../models/job_model.dart';
import '../models/quote_model.dart';

/// Remote data source contract for booking. Placeholder only.
abstract class BookingRemoteDataSource {
  Future<QuoteModel> fetchQuote(String jobId);
  Future<JobModel> createJob(JobModel job);
  Future<List<JobModel>> fetchJobs();
}
