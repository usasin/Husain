import 'package:flutter/material.dart';

/// ════════════════════════════════════════════════════════════
///  Catalogues d'avatars 2026
///  · Emojis : organisés par catégorie thématique WC 2026.
///  · Icônes : sélection Material moderne.
///  · Frames : couleurs des "rings" autour des avatars.
/// ════════════════════════════════════════════════════════════

const Map<String, List<String>> kAvatarCategories = {
  'WC 2026' : ['🏆','⚽','🥅','🥇','🎟️','🏟️','📣','🔥','⭐','💎','👑','🎯','🌎','🚀','✨','💥'],
  'Sport'   : ['🏀','🏈','⚾','🎾','🏐','🏉','🎱','🥊','🏓','🏸','⛳','🏆','🥇','🥈','🥉','🚴'],
  'Animaux' : ['🦁','🐯','🐺','🦊','🐻','🐼','🦅','🦉','🦈','🐬','🐢','🐉','🦄','🐸','🐵','🐧'],
  'Énergie' : ['🔥','⚡','💥','🌪️','☄️','🌈','🌊','🌟','✨','💎','🔮','🧿','🌙','☀️','🪐','⭐'],
  'Fun'     : ['😎','🤖','👑','🎩','🕶️','🎪','🎮','🎨','🎵','🎬','🎤','🚀','🛸','🍀','🍕','🍔'],
  'Hôtes'   : ['🇨🇦','🇺🇸','🇲🇽','🌎','🗽','🏔️','🌵','🍁','🌴','🏞️','🚆','🌆','🎡','🌅','🏟️','🛫'],
  'Nations' : ['🇫🇷','🇲🇦','🇧🇷','🇦🇷','🇪🇸','🇵🇹','🇩🇪','🇮🇹','🇬🇧','🇯🇵','🇰🇷','🇸🇳','🇳🇬','🇳🇱','🇨🇮','🇸🇦'],
  'Mix'     : ['🥷','🧠','🦋','🐙','🦂','🐲','🪄','🔱','🛡️','💫','🪙','📣','🎉','🏟️','📍','⌛'],
};

/// Sélection d'icônes Material rendues comme avatars.
const List<IconData> kAvatarIcons = [
  Icons.sports_soccer,
  Icons.emoji_events,
  Icons.shield,
  Icons.local_fire_department,
  Icons.bolt,
  Icons.star,
  Icons.diamond_outlined,
  Icons.rocket_launch,
  Icons.public,
  Icons.flag_circle,
  Icons.workspace_premium,
  Icons.military_tech,
  Icons.psychology_alt,
  Icons.gps_fixed,
  Icons.celebration,
  Icons.whatshot,
  Icons.favorite,
  Icons.pets,
  Icons.savings,
  Icons.auto_awesome,
  Icons.flash_on,
  Icons.headset,
  Icons.music_note,
  Icons.code,
  Icons.coffee,
  Icons.directions_run,
  Icons.fitness_center,
  Icons.castle,
  Icons.pool,
  Icons.terrain,
];

const List<String> kAvatarFrames = [
  'gold',
  'cyan',
  'pink',
  'emerald',
  'sunset',
  'royal',
];

const List<String> kTeamBadgeIcons = [
  '🛡️','🏆','⚽','🔥','⚡','👑','💎','🦁','🐉','🌟','🚀','🎯','🇫🇷','🇲🇦','🦅','🐺',
];

const List<String> kTeamBadgeColors = [
  '#FFD230', // gold
  '#FF2E4D', // canada red
  '#00C853', // mexico green
  '#2962FF', // usa blue
  '#00D9FF', // cyan
  '#8B5CF6', // violet
  '#FF3DA0', // magenta
  '#B5FF3A', // lime
];
