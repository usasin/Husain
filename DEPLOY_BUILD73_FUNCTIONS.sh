#!/usr/bin/env bash
set -euo pipefail
firebase deploy --only functions:syncClubMatchesNow,functions:syncClubMatchesScheduled,functions:notifyMatchFinished,functions:notifyLastTeammateToVote
