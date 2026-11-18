-- ============================================================================
-- SafeShift — Migration 0139
-- Align the Dar es Salaam service boundary with the real city footprint.
--
-- The pilot seed used a coarse rectangle covering only the central corridor
-- (39.15–39.35E, 6.65–6.95S). Customers in the wider Dar es Salaam area —
-- Kimara, Mbezi, Kunduchi, Mbagala, Kigamboni, etc. — were rejected by
-- quote_calculate_and_persist with "pickup point is outside every active
-- service city" even though drivers operate there.
--
-- This boundary is the OSM Dar es Salaam administrative polygon, simplified
-- to ~1 km tolerance (69 vertices) so it stays small and query-fast. It is
-- still a single polygon because public.cities.boundary is geography(polygon).
-- Service zones remain the smaller pricing zones; pickups outside a zone use
-- the city-wide pricing plan, which is the intended behaviour.
-- ============================================================================

update public.cities
   set boundary = extensions.ST_GeogFromText(
         'SRID=4326;POLYGON(('
         '39.007030 -6.790543, 39.054128 -6.790076, 39.054347 -6.842875, '
         '39.071253 -6.867684, 39.118821 -6.880036, 39.108846 -6.915069, '
         '39.088076 -6.923149, 39.094144 -6.933371, 39.059600 -6.973104, '
         '39.074478 -6.979623, 39.065205 -7.013962, 39.050895 -7.028325, '
         '39.023073 -7.023264, 39.030203 -7.046482, 39.068367 -7.031407, '
         '39.069703 -7.057316, 39.113054 -7.073113, 39.115121 -7.093877, '
         '39.151625 -7.019664, 39.174412 -7.011036, 39.170167 -6.995146, '
         '39.192502 -6.982367, 39.220554 -6.994276, 39.244801 -6.950880, '
         '39.269737 -6.943809, 39.277778 -6.957692, 39.298209 -6.948134, '
         '39.314347 -6.959666, 39.327560 -6.947989, 39.359884 -6.969983, '
         '39.384870 -6.967965, 39.384893 -6.996721, 39.405613 -7.009641, '
         '39.409984 -7.065282, 39.393039 -7.085732, 39.417688 -7.125585, '
         '39.407082 -7.168957, 39.422036 -7.151831, 39.435191 -7.168101, '
         '39.451479 -7.156455, 39.444185 -7.181051, 39.487985 -7.165577, '
         '39.502764 -7.186706, 39.520869 -7.169983, 39.525896 -7.129568, '
         '39.555073 -7.131213, 39.540750 -7.079344, 39.546200 -6.988183, '
         '39.519963 -6.968561, 39.476054 -6.865627, 39.366618 -6.853295, '
         '39.314141 -6.815157, 39.294539 -6.825032, 39.306999 -6.852076, '
         '39.285897 -6.869816, 39.300310 -6.852600, 39.286841 -6.822526, '
         '39.301389 -6.817010, 39.281555 -6.796200, 39.285913 -6.740756, '
         '39.276181 -6.732738, 39.268350 -6.759693, 39.245798 -6.750394, '
         '39.223678 -6.669063, 39.150000 -6.577524, 39.121477 -6.566206, '
         '39.080664 -6.602921, 39.060939 -6.720523, 39.007030 -6.790543'
         '))'
       ),
       updated_at = now()
 where id = '55555555-0000-4000-8000-000000000001'
   and name = 'Dar es Salaam';

comment on column public.cities.boundary is
  'Service footprint used by quote_calculate_and_persist. A pickup must be covered by an active city boundary to receive a quote.';
