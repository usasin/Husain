"""Check the source snapshot before the explicitly requested iOS build."""
from pathlib import Path

root = Path(__file__).resolve().parents[1]

def require(path, marker):
    if marker not in (root / path).read_text():
        raise SystemExit(f"Unexpected BUILD74 source: {path} is missing {marker!r}")

require('pubspec.yaml', 'version: 2.6.18+74')
require('pubspec.yaml', 'app_tracking_transparency: ^2.0.7')
require('lib/screens/competition_home_screen.dart', 'GameLoopCard()')
require('lib/screens/game_center_screen.dart', 'class GameCenterScreen')
require('lib/providers/app_provider.dart', 'GameSeasonWindow get currentGameSeason')
for screen in ('team_chat_screen.dart', 'match_lounge_screen.dart'):
    require('lib/screens/' + screen, 'contentReports')
    require('lib/screens/' + screen, 'Sous chaque pseudo : Bloquer ou Signaler')

ads = (root / 'lib/services/ad_service.dart').read_text()
initialize = ads[ads.index('Future<bool> _initializeInternal() async'):]
if initialize.index('await _requestTrackingAuthorizationIfNeeded();') > initialize.index('ConsentInformation.instance'):
    raise SystemExit('ATT must precede the advertising consent/initialization flow.')

require('lib/main.dart', 'await Firebase.initializeApp().timeout(')
require('scripts/PREPARE_IOS_IPAD.sh', 'com.digitalsolutionsai.prono4')
require('scripts/PREPARE_IOS_IPAD.sh', 'NSUserTrackingUsageDescription')
require('scripts/PREPARE_IOS_IPAD.sh', 'resources.add_file_reference(firebase_ref, true)')
require('ios/Podfile', "platform :ios, '15.0'")

print('BUILD74 source and preserved iOS integration checks passed.')
