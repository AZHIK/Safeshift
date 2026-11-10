import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:safeshift_customer/shared/utils/polyline.dart';

void main() {
  group('decodePolyline', () {
    test('returns empty for null input', () {
      expect(decodePolyline(null), isEmpty);
    });

    test('returns empty for empty string', () {
      expect(decodePolyline(''), isEmpty);
    });

    test('decodes a single-segment polyline', () {
      // "g~" encodes a delta of (0.005, 0) degrees from the (0,0) origin.
      final points = decodePolyline('g~');
      expect(points, hasLength(1));
      expect(points.first.latitude, closeTo(0.005, 1e-9));
      expect(points.first.longitude, closeTo(0.0, 1e-9));
    });

    test('decodes a known multi-point polyline', () {
      // Google's reference encoded polyline for:
      // (38.5, -120.2), (40.7, -120.95), (43.252, -126.453)
      final encoded = r'_p~iF~ps|U_ulLnnqC_mqNvxq`@';
      final points = decodePolyline(encoded);
      expect(points, hasLength(3));
      expect(points[0].latitude, closeTo(38.5, 1e-6));
      expect(points[0].longitude, closeTo(-120.2, 1e-6));
      expect(points[1].latitude, closeTo(40.7, 1e-6));
      expect(points[1].longitude, closeTo(-120.95, 1e-6));
      expect(points[2].latitude, closeTo(43.252, 1e-6));
      expect(points[2].longitude, closeTo(-126.453, 1e-6));
    });

    test('produces LatLng objects in latitude, longitude order', () {
      final points = decodePolyline('a~l~Fjk~uOwHJ}@~');
      expect(points.first, isA<LatLng>());
    });

    test('decodes a live TRAFFIC_AWARE route between two Dar es Salaam points', () {
      // Captured from Google Routes API `directions/v2:computeRoutes` for a
      // driving route in Dar es Salaam. Guards the decoder against a change
      // in the provider's polyline encoding.
      const encoded =
          'jsmh@qzhnFQCyAYA?eAMc@Ea@EOCw@CkBGc@AG?[Cc@Cc@A_@CoAOmDw@OGSK]QA?UOi@]]Y]Y_AeAw@'
          '_AY_@GGUYKKe@i@e@k@w@}@GIe@k@w@_AMOy@aAEEaAiAWYCEUWEEQSY]UUs@q@ECSSg@a@QKWQaAo@'
          'WOOM{@k@y@i@IGq@c@WOkBoAw@i@_@W]UoA{@_Am@y@k@uBsAu@g@_@WOKZe@X_@Ze@PUFIDG@?DEJIDElAkB'
          '\\g@FKlAmBLUJUFKDM?CFUH]D]DY@U@gA?q@@[@Y@OHi@F_@BKFUHSJSd@u@JQZc@FKU]S]Og@uAmC]m@wAq'
          'CeAoBs@uASa@We@cAmBOY[m@GIc@}@e@{@a@w@MWMWU[[g@[a@MO]_@AAYWMMsAiAgAw@a@YKGeAy@uAgAII'
          'IGUUMOKQMUQc@I]G[Ea@A[?Y?SDu@@I?w@Di@Dy@@M?UCg@AWG[GSGSKUMSMSQSSUQMEEk@c@gAw@_BkAy@o@'
          'u@k@[Uw@k@cBiACC?ACIQMc@a@~@iAxA{B\\i@r@cAR[xAoBxCgElAeBJM`@a@`AcAl@q@T[`@u@^s@b@{@h@m@P'
          'U^m@Nq@Xg@^s@\\{AHOFOv@sBn@aCH[\\qAl@iDVuALo@f@}BLe@Ja@Nw@Jm@Ny@f@uCB]BM?A@MFYFc@D[D]D[D'
          'u@@YDi@Do@BY?IDq@B_A@U?m@S{EKgCUkCWcCGi@e@sG[uFK_AKw@Cy@UyBCSUyBIa@CYAi@CkAAs@C_AAM?a@AS?_'
          '@?]?_@@]?IBoABcABaABk@Bk@@c@Dk@BQBa@Fk@Fu@Hm@Fc@?AHm@Fa@Hi@Lw@Ha@F[Lg@Jc@Lg@Pk@b@uAJWJ[Ri'
          '@DK\\u@DKRc@b@}@Xi@JSZk@R[t@gABCPYJQFIDGP[RYZg@R[FIb@m@V[LOv@cAVYn@u@TUFGSMUOi@W[OQGMCSK'
          'MKKGGG]e@CEGIKSKOSWKMIGIG]MYKWIOEc@Mo@Um@Q_AWIEa@MA?e@QUIMCQGKCE?QEOCOCC?OCA?SCUA_AAs@?Q'
          '?]A[@[@W@E?Q@O@wAR}Cb@wATK@WF}@N_@LGBg@Nk@VKDuAn@E@a@LeBl@wA\\e@LI@kB^wAV]F_C`@{AP]B{@BkA'
          'Dc@@eAD[@iA@C?W?i@AQ?cAAAA_@A[EaAOCAk@Oe@Km@Qg@OkA]eAa@_@O_@OOGeB{@_BaAi@a@WQqAeAq@g@w@q@'
          'MIw@\\wBbAd@bA@@DLR`@@BBHBT?FAFCD';

      final points = decodePolyline(encoded);
      expect(points.length, greaterThan(400));
      expect(points.first.latitude, closeTo(-6.79238, 1e-4));
      expect(points.first.longitude, closeTo(39.20825, 1e-4));
      expect(points.last.latitude, closeTo(-6.76075, 1e-4));
      expect(points.last.longitude, closeTo(39.27623, 1e-4));
    });
  });
}
