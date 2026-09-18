from pathlib import Path

PUBSPEC = Path("pubspec.yaml")
AD_SERVICE = Path("lib/services/ad_service.dart")

pubspec = PUBSPEC.read_text()
if "app_tracking_transparency:" not in pubspec:
    anchor = "  google_mobile_ads: ^9.0.0\n"
    if anchor not in pubspec:
        raise SystemExit("PRONO4 BUILD52 ATT patch failed: pubspec AdMob anchor missing")
    pubspec = pubspec.replace(
        anchor,
        anchor + "  app_tracking_transparency: ^2.0.7\n",
        1,
    )
PUBSPEC.write_text(pubspec)

ad = AD_SERVICE.read_text()
att_import = "import 'package:app_tracking_transparency/app_tracking_transparency.dart';\n"
if att_import not in ad:
    anchor = "import 'package:flutter/foundation.dart';\n"
    if anchor not in ad:
        raise SystemExit("PRONO4 BUILD52 ATT patch failed: ad_service import anchor missing")
    ad = ad.replace(anchor, anchor + att_import, 1)

helper = """  Future<void> _requestTrackingAuthorizationIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;

    try {
      // The Flutter UI is already visible when AdService starts. Waiting a
      // moment avoids presenting ATT during the first transition frame.
      // ATT is always resolved before UMP or Google Mobile Ads is initialized.
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      final status =
          await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        final result =
            await AppTrackingTransparency.requestTrackingAuthorization();
        debugPrint('ATT authorization result: $result');
      } else {
        debugPrint('ATT authorization already resolved: $status');
      }
    } catch (e) {
      // Ads are optional; an ATT API failure must not block PRONO4 itself.
      debugPrint('ATT authorization request error: $e');
    }
  }

"""

if "_requestTrackingAuthorizationIfNeeded() async" not in ad:
    anchor = "  Future<bool> _initializeInternal() async {\n"
    if anchor not in ad:
        raise SystemExit("PRONO4 BUILD52 ATT patch failed: initialize anchor missing")
    ad = ad.replace(anchor, helper + anchor, 1)

if "await _requestTrackingAuthorizationIfNeeded();" not in ad:
    anchor = "  Future<bool> _initializeInternal() async {\n"
    if anchor not in ad:
        raise SystemExit("PRONO4 BUILD52 ATT patch failed: initialize call anchor missing")
    ad = ad.replace(
        anchor,
        anchor + "    await _requestTrackingAuthorizationIfNeeded();\n\n",
        1,
    )

AD_SERVICE.write_text(ad)
print("PRONO4 BUILD52 ATT patch applied")
