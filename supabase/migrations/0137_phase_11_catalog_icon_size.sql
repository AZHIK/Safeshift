-- ============================================================================
-- SafeShift — Phase 11 / Migration 0137
-- Raise the catalogue icon size limit to 512 KB.
--
-- Migration 0131 created the public catalog-icons bucket with a 256 KB
-- limit. Operators uploading higher-resolution artwork found that too
-- tight, so the bucket now accepts up to 512 KB. The console's own check in
-- apps/admin-console/lib/configuration/icons.ts is raised to match, so the
-- console refuses an oversized file before it uploads rather than after.
-- ============================================================================

update storage.buckets
   set file_size_limit = 524288
 where id = 'catalog-icons';
