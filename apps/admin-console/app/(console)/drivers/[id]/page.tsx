import type { ReactNode } from 'react';
import Link from 'next/link';
import { notFound } from 'next/navigation';

import { approveVerificationAction, rejectVerificationAction } from '@/app/actions/admin';
import { MetricCard } from '@/components/metric-card';
import { Notice } from '@/components/notice';
import { PageHeader } from '@/components/page-header';
import { StatusBadge } from '@/components/status-badge';
import { requireArea } from '@/lib/guard';
import { formatDate, formatMoney, shortId, titleize } from '@/lib/format';
import { createClient } from '@/lib/supabase/server';

export const dynamic = 'force-dynamic';

const PREVIEW_TTL_SECONDS = 600;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

type AdminClient = Awaited<ReturnType<typeof createClient>>;

type DocumentRow = {
  id: string;
  document_code: string | null;
  document_name: string | null;
  document_number: string | null;
  issued_at: string | null;
  expires_at: string | null;
  file_path: string | null;
  file_mime_type: string | null;
  file_size_bytes: number | null;
  verification_status: string | null;
  rejection_reason: string | null;
  is_current: boolean | null;
  created_at: string | null;
};

type VehicleRow = {
  id: string;
  registration_number: string | null;
  vehicle_type_name: string | null;
  vehicle_type_code: string | null;
  make: string | null;
  model: string | null;
  year: number | null;
  color: string | null;
  capacity_kg: number | null;
  verification_status: string | null;
  is_active: boolean | null;
  home_city_name: string | null;
  photo_urls: string[] | null;
  created_at: string | null;
  documents: DocumentRow[] | null;
};

type VerificationRequestRow = {
  id: string;
  request_type: string;
  status: string;
  priority: string;
  submitted_at: string | null;
  reviewed_at: string | null;
  decided_at: string | null;
  decision_notes: string | null;
  vehicle_id: string | null;
  vehicle_registration: string | null;
};

type HistoryRow = {
  id: number;
  action: string;
  notes: string | null;
  actor_name: string | null;
  vehicle_id: string | null;
  created_at: string | null;
};

type DriverDetail = {
  profile: {
    id: string;
    full_name: string | null;
    display_name: string | null;
    phone: string | null;
    email: string | null;
    avatar_url: string | null;
    primary_role: string | null;
    is_active: boolean | null;
    phone_verified: boolean | null;
    email_verified: boolean | null;
    preferred_language: string | null;
    default_country: string | null;
    last_login_at: string | null;
    terms_accepted_at: string | null;
    privacy_accepted_at: string | null;
    created_at: string | null;
  };
  driver: {
    id: string;
    country_id: string | null;
    country_name: string | null;
    home_city_id: string | null;
    home_city_name: string | null;
    licence_number: string | null;
    licence_expiry: string | null;
    licence_country_name: string | null;
    verification_status: string | null;
    risk_tier: string | null;
    rating: number | null;
    total_trips: number | null;
    total_earnings: number | null;
    is_available: boolean | null;
    current_location: { coordinates?: [number, number] } | null;
    location_updated_at: string | null;
    verified_at: string | null;
    re_verification_due_at: string | null;
    created_at: string | null;
  };
  driver_documents: DocumentRow[] | null;
  vehicles: VehicleRow[] | null;
  verification_requests: VerificationRequestRow[] | null;
  verification_history: HistoryRow[] | null;
  permissions: {
    can_review_driver: boolean;
    can_review_vehicle: boolean;
  };
};

type DocumentWithPreview = DocumentRow & { preview_url: string | null };
type VehicleWithPreviews = Omit<VehicleRow, 'documents' | 'photo_urls'> & {
  documents: DocumentWithPreview[];
  photos: Array<{ url: string; name: string }>;
};

function isImageDocument(document: DocumentRow): boolean {
  const mime = document.file_mime_type ?? '';
  if (mime.startsWith('image/')) return true;
  return /\.(png|jpe?g|webp|gif|heic)$/i.test(document.file_path ?? '');
}

async function signedPreview(
  supabase: AdminClient,
  bucket: string,
  path: string | null,
): Promise<string | null> {
  if (!path) return null;
  const { data, error } = await supabase.storage
    .from(bucket)
    .createSignedUrl(path, PREVIEW_TTL_SECONDS);
  if (error) return null;
  return data?.signedUrl ?? null;
}

async function withPreviews(
  supabase: AdminClient,
  bucket: string,
  documents: DocumentRow[],
): Promise<DocumentWithPreview[]> {
  return Promise.all(
    documents.map(async (document) => ({
      ...document,
      preview_url: await signedPreview(supabase, bucket, document.file_path),
    })),
  );
}

function DetailItem({ label, children }: { label: string; children: ReactNode }) {
  return (
    <div className="driver-detail-item">
      <span className="driver-detail-label">{label}</span>
      <span className="driver-detail-value">{children}</span>
    </div>
  );
}

function DocumentCard({ document, registry=false }: { document: DocumentWithPreview; registry?:boolean }) {
  const isImage = isImageDocument(document);
  return (
    <div className="driver-doc">
      <div className="driver-doc-preview">
        {document.preview_url && isImage ? (
          <a href={document.preview_url} target="_blank" rel="noreferrer">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={document.preview_url} alt={document.document_name ?? 'Document'} />
          </a>
        ) : (
          <span className="small muted">
            {document.preview_url ? 'PDF document' : 'Preview unavailable'}
          </span>
        )}
      </div>
      <div className="driver-doc-body">
        {registry && document.is_current && <Link href={'/registry?document='+document.id}>Request registry check</Link>}
        <strong>{document.document_name ?? titleize(document.document_code)}</strong>
        {document.document_number ? (
          <span className="small muted">No. {document.document_number}</span>
        ) : null}
        <span className="small muted">
          {document.expires_at
            ? `Expires ${formatDate(document.expires_at)}`
            : 'No expiry recorded'}
        </span>
        <StatusBadge value={document.verification_status ?? 'pending'} />
        {document.rejection_reason ? (
          <span className="small" style={{ color: '#982626' }}>
            {document.rejection_reason}
          </span>
        ) : null}
        {document.preview_url ? (
          <a className="small" href={document.preview_url} target="_blank" rel="noreferrer">
            Open file
          </a>
        ) : (
          <span className="small muted">You do not have access to this file.</span>
        )}
      </div>
    </div>
  );
}

export default async function DriverDetailPage({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<Record<string, string | string[] | undefined>>;
}) {
  await requireArea('drivers');
  const { id } = await params;
  if (!UUID_PATTERN.test(id)) notFound();
  const query = await searchParams;
  const supabase = await createClient();

  const { data, error } = await supabase.rpc('admin_driver_detail', { p_driver_id: id });

  if (error) {
    const missingFunction = error.code === 'PGRST202' || error.code === '42883';
    if (error.code === 'P0002') notFound();
    return (
      <>
        <PageHeader
          title="Driver"
          description="This driver file could not be loaded."
          actions={
            <Link className="btn" href="/drivers">
              Back to drivers
            </Link>
          }
        />
        <div className="notice notice-error">
          {missingFunction
            ? 'The admin_driver_detail function is missing from this database. Apply supabase/migrations/0138_phase_11_admin_driver_detail.sql, then reload this page.'
            : error.message}
        </div>
      </>
    );
  }

  if (!data) notFound();

  const detail = data as DriverDetail;
  const profile = detail.profile;
  const driver = detail.driver;
  const permissions = detail.permissions;

  const [driverDocuments, vehicles] = await Promise.all([
    withPreviews(supabase, 'driver-documents', detail.driver_documents ?? []),
    Promise.all(
      (detail.vehicles ?? []).map(async (vehicle): Promise<VehicleWithPreviews> => {
        const photos = await Promise.all(
          (vehicle.photo_urls ?? []).map(async (path, index) => {
            const url = /^https?:\/\//i.test(path)
              ? path
              : await signedPreview(supabase, 'vehicle-documents', path);
            return url ? { url, name: `Vehicle photo ${index + 1}` } : null;
          }),
        );
        return {
          ...vehicle,
          documents: await withPreviews(supabase, 'vehicle-documents', vehicle.documents ?? []),
          photos: photos.filter((photo): photo is { url: string; name: string } => photo !== null),
        };
      }),
    ),
  ]);

  const requests = detail.verification_requests ?? [];
  const openRequests = requests.filter(
    (request) => request.status === 'pending' || request.status === 'in_review',
  );
  const decidedRequests = requests.filter(
    (request) => request.status !== 'pending' && request.status !== 'in_review',
  );
  const history = detail.verification_history ?? [];

  const name = profile.full_name ?? profile.display_name ?? shortId(id);
  const coordinates = driver.current_location?.coordinates;
  const canDecide = (request: VerificationRequestRow) =>
    request.request_type === 'vehicle_verification'
      ? permissions.can_review_vehicle
      : permissions.can_review_driver;

  return (
    <>
      <PageHeader
        title={name}
        description={[
          profile.phone,
          profile.email,
          driver.country_name ?? driver.home_city_name,
          `joined ${formatDate(profile.created_at)}`,
        ]
          .filter(Boolean)
          .join(' · ')}
        actions={
          <>
            <StatusBadge value={driver.verification_status ?? 'pending'} />
            <StatusBadge value={driver.is_available ? 'active' : 'paused'} />
            <Link className="btn" href={`/users/${profile.id}`}>
              Account &amp; suspension
            </Link>
            <Link className="btn" href="/drivers">
              Back to drivers
            </Link>
          </>
        }
      />
      <Notice searchParams={query} />

      <div className="grid grid-4" style={{ marginBottom: 16 }}>
        <MetricCard label="Rating" value={Number(driver.rating ?? 0).toFixed(2)} />
        <MetricCard label="Trips" value={driver.total_trips ?? 0} />
        <MetricCard label="Lifetime earnings" value={formatMoney(driver.total_earnings, 'TZS')} />
        <MetricCard label="Risk tier" value={titleize(driver.risk_tier ?? 'standard')} />
      </div>

      <div className="split">
        <div className="section-stack">
          <div className="card card-pad">
            <h2 className="card-title">Profile</h2>
            <p className="card-sub">Contact details and consent captured at registration.</p>
            <div className="driver-detail-grid">
              <DetailItem label="Full name">{profile.full_name ?? '—'}</DetailItem>
              <DetailItem label="Display name">{profile.display_name ?? '—'}</DetailItem>
              <DetailItem label="Phone">
                {profile.phone ?? '—'} {profile.phone_verified ? '· verified' : ''}
              </DetailItem>
              <DetailItem label="Email">
                {profile.email ?? '—'} {profile.email_verified ? '· verified' : ''}
              </DetailItem>
              <DetailItem label="Language">{profile.preferred_language ?? '—'}</DetailItem>
              <DetailItem label="Default country">{profile.default_country ?? '—'}</DetailItem>
              <DetailItem label="Account status">
                {titleize(profile.is_active ? 'active' : 'disabled')}
              </DetailItem>
              <DetailItem label="Last login">{formatDate(profile.last_login_at)}</DetailItem>
              <DetailItem label="Terms accepted">
                {formatDate(profile.terms_accepted_at)}
              </DetailItem>
              <DetailItem label="Privacy accepted">
                {formatDate(profile.privacy_accepted_at)}
              </DetailItem>
            </div>
          </div>

          <div className="card card-pad">
            <h2 className="card-title">Driver & licence</h2>
            <p className="card-sub">The compliance fields the platform verifies.</p>
            <div className="driver-detail-grid">
              <DetailItem label="Driver ID">
                <span className="mono">{driver.id}</span>
              </DetailItem>
              <DetailItem label="Licence number">{driver.licence_number ?? '—'}</DetailItem>
              <DetailItem label="Licence expiry">{formatDate(driver.licence_expiry)}</DetailItem>
              <DetailItem label="Licence country">{driver.licence_country_name ?? '—'}</DetailItem>
              <DetailItem label="Operating country">{driver.country_name ?? '—'}</DetailItem>
              <DetailItem label="Home city">{driver.home_city_name ?? '—'}</DetailItem>
              <DetailItem label="Verified at">{formatDate(driver.verified_at)}</DetailItem>
              <DetailItem label="Re-verification due">
                {formatDate(driver.re_verification_due_at)}
              </DetailItem>
              <DetailItem label="Registered">{formatDate(driver.created_at)}</DetailItem>
              <DetailItem label="Last location">
                {coordinates
                  ? `${coordinates[1].toFixed(5)}, ${coordinates[0].toFixed(5)} · ${formatDate(driver.location_updated_at)}`
                  : '—'}
              </DetailItem>
            </div>
          </div>

          <div className="card card-pad">
            <h2 className="card-title">Driver documents</h2>
            <p className="card-sub">
              Identity and licence papers. Files are private; the links below expire after ten
              minutes.
            </p>
            {driverDocuments.length === 0 ? (
              <div className="table-empty">
                {permissions.can_review_driver
                  ? 'No driver documents uploaded.'
                  : 'Your role can view the driver but not their documents.'}
              </div>
            ) : (
              <div className="driver-doc-grid">
                {driverDocuments.map((document) => (
                  <DocumentCard key={document.id} document={document} registry />
                ))}
              </div>
            )}
          </div>

          {vehicles.map((vehicle) => (
            <div className="card card-pad" key={vehicle.id}>
              <div className="inline" style={{ justifyContent: 'space-between', width: '100%' }}>
                <div>
                  <h2 className="card-title">
                    {vehicle.registration_number ?? shortId(vehicle.id)}
                    {vehicle.vehicle_type_name ? ` · ${vehicle.vehicle_type_name}` : ''}
                  </h2>
                  <p className="card-sub">
                    Vehicle <span className="mono">{shortId(vehicle.id)}</span>
                  </p>
                </div>
                <StatusBadge value={vehicle.verification_status ?? 'pending'} />
              </div>
              <div className="driver-detail-grid">
                <DetailItem label="Registration">{vehicle.registration_number ?? '—'}</DetailItem>
                <DetailItem label="Category">{vehicle.vehicle_type_name ?? '—'}</DetailItem>
                <DetailItem label="Make">{vehicle.make ?? '—'}</DetailItem>
                <DetailItem label="Model">{vehicle.model ?? '—'}</DetailItem>
                <DetailItem label="Year">{vehicle.year ?? '—'}</DetailItem>
                <DetailItem label="Colour">{vehicle.color ?? '—'}</DetailItem>
                <DetailItem label="Capacity">
                  {vehicle.capacity_kg ? `${Number(vehicle.capacity_kg).toLocaleString()} kg` : '—'}
                </DetailItem>
                <DetailItem label="Home city">{vehicle.home_city_name ?? '—'}</DetailItem>
                <DetailItem label="Active">{vehicle.is_active ? 'Yes' : 'No'}</DetailItem>
                <DetailItem label="Registered">{formatDate(vehicle.created_at)}</DetailItem>
              </div>

              {vehicle.photos.length > 0 ? (
                <>
                  <h3 className="card-title" style={{ marginTop: 16 }}>
                    Photos
                  </h3>
                  <div className="driver-doc-grid">
                    {vehicle.photos.map((photo) => (
                      <div className="driver-doc" key={photo.url}>
                        <div className="driver-doc-preview">
                          <a href={photo.url} target="_blank" rel="noreferrer">
                            {/* eslint-disable-next-line @next/next/no-img-element */}
                            <img src={photo.url} alt={photo.name} />
                          </a>
                        </div>
                        <div className="driver-doc-body">
                          <strong>{photo.name}</strong>
                          <a className="small" href={photo.url} target="_blank" rel="noreferrer">
                            Open photo
                          </a>
                        </div>
                      </div>
                    ))}
                  </div>
                </>
              ) : null}

              <h3 className="card-title" style={{ marginTop: 16 }}>
                Vehicle documents
              </h3>
              {vehicle.documents.length === 0 ? (
                <div className="table-empty">
                  {permissions.can_review_vehicle
                    ? 'No vehicle documents uploaded.'
                    : 'Your role can view the vehicle but not its documents.'}
                </div>
              ) : (
                <div className="driver-doc-grid">
                  {vehicle.documents.map((document) => (
                    <DocumentCard key={document.id} document={document} />
                  ))}
                </div>
              )}
            </div>
          ))}
        </div>

        <div className="section-stack">
          <div className="card card-pad">
            <h2 className="card-title">Verification decisions</h2>
            <p className="card-sub">
              Approving marks the driver verified for twelve months. Rejecting requires a reason the
              driver sees in the app.
            </p>
            {openRequests.length === 0 ? (
              <div className="table-empty">
                {permissions.can_review_driver
                  ? 'No open verification request for this driver.'
                  : 'Your role can view the driver but not decide verification.'}
              </div>
            ) : (
              <div className="section-stack" style={{ marginTop: 12, gap: 14 }}>
                {openRequests.map((request) => (
                  <div className="driver-decision" key={request.id}>
                    <div
                      className="inline"
                      style={{ justifyContent: 'space-between', width: '100%' }}
                    >
                      <strong>{titleize(request.request_type)}</strong>
                      <StatusBadge value={request.status} />
                    </div>
                    <div className="small muted">
                      Submitted {formatDate(request.submitted_at)}
                      {request.vehicle_registration ? ` · ${request.vehicle_registration}` : ''}
                    </div>
                    {!canDecide(request) ? (
                      <p className="small muted">Your role cannot decide this request.</p>
                    ) : (
                      <>
                        <form
                          action={approveVerificationAction}
                          className="form"
                          style={{ gap: 5, marginTop: 8 }}
                        >
                          <input type="hidden" name="request_id" value={request.id} />
                          <input type="hidden" name="return_to" value={`/drivers/${id}`} />
                          <input
                            className="input"
                            name="notes"
                            placeholder="Approval note (optional)"
                          />
                          <button className="btn btn-primary btn-sm" type="submit">
                            Approve
                          </button>
                        </form>
                        <form
                          action={rejectVerificationAction}
                          className="form"
                          style={{ gap: 5, marginTop: 6 }}
                        >
                          <input type="hidden" name="request_id" value={request.id} />
                          <input type="hidden" name="return_to" value={`/drivers/${id}`} />
                          <input
                            className="input"
                            name="reason"
                            placeholder="Rejection reason (required)"
                            required
                          />
                          <button className="btn btn-danger btn-sm" type="submit">
                            Reject
                          </button>
                        </form>
                      </>
                    )}
                  </div>
                ))}
              </div>
            )}

            {decidedRequests.length > 0 ? (
              <div style={{ marginTop: 16 }}>
                <h3 className="card-title">Earlier decisions</h3>
                <div className="section-stack" style={{ marginTop: 8, gap: 8 }}>
                  {decidedRequests.map((request) => (
                    <div className="driver-decision" key={request.id}>
                      <div
                        className="inline"
                        style={{ justifyContent: 'space-between', width: '100%' }}
                      >
                        <span className="small">{titleize(request.request_type)}</span>
                        <StatusBadge value={request.status} />
                      </div>
                      <div className="small muted">
                        {formatDate(
                          request.decided_at ?? request.reviewed_at ?? request.submitted_at,
                        )}
                        {request.vehicle_registration ? ` · ${request.vehicle_registration}` : ''}
                      </div>
                      {request.decision_notes ? (
                        <div className="small">{request.decision_notes}</div>
                      ) : null}
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
          </div>

          <div className="card card-pad">
            <h2 className="card-title">Decision history</h2>
            <p className="card-sub">Every verification action is audited.</p>
            {history.length === 0 ? (
              <div className="table-empty">No decisions recorded yet.</div>
            ) : (
              <div className="section-stack" style={{ marginTop: 12, gap: 8 }}>
                {history.map((entry) => (
                  <div className="driver-decision" key={entry.id}>
                    <div
                      className="inline"
                      style={{ justifyContent: 'space-between', width: '100%' }}
                    >
                      <StatusBadge value={entry.action} />
                      <span className="small muted">{formatDate(entry.created_at)}</span>
                    </div>
                    <div className="small">
                      {entry.actor_name ?? 'SafeShift'} · {titleize(entry.action)}
                      {entry.vehicle_id ? ` · ${shortId(entry.vehicle_id)}` : ''}
                    </div>
                    {entry.notes ? <div className="small muted">{entry.notes}</div> : null}
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      </div>
    </>
  );
}
