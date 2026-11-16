<h1 align="center">Xen Jump Pad</h1>

<p align="center">
  <a href="https://www.youtube.com/watch?v=wO5SUCOOFrc"><img src="https://img.youtube.com/vi/wO5SUCOOFrc/maxresdefault.jpg" alt="Watch on YouTube" width="600"></a>
</p>

## 📝 Description
This plugin adds fully dynamic Xen jump pads to Counter-Strike 1.6.
Jump pads can be placed, managed and configured during gameplay with full runtime control over strength, activation timing and cooldown behavior.
Custom setups are saved per map and automatically loaded on every map start.
- Create and remove jump pads during gameplay via an in-game menu
- Multiple jump pad types, each with individually configurable launch strength
- Players are launched automatically on contact within a configurable radius
- Configurable per pad: launch strength, radius, cooldown, spawn chance, and activation timing
- Round-based activation with delayed start, active duration, and cooldown before reactivation
- Ghost preview tracking for natural alignment with grounds and walls

## 📋 Requirements
- ReGameDLL
- AMX Mod X 1.10+

## 💬 Commands
- `say /xenjump` - Opens the Xen Jump Pad menu.
- `say_team /xenjump` - Opens the Xen Jump Pad menu.
- `xenjump_reload` - Reloads the configuration file.

## ⚙️ Configuration
```ini
# To add a new pad, follow the example below
# [Pad Name]
# PAD_FLAGS                 = a - Active Delay      b - Active Duration     c - Players Only
# PAD_TEAM                  = 0 - None              1 - Terrorist           2 - Counter-Terrorist    3 - Both
# PAD_SIZE                  = 0 - Small             1 - Mid                 2 - Large
# PAD_SPAWN_CHANCE          = Pad's respawn probability (0.0 = never, 1.0 = always)
# PAD_ACTIVE_DELAY          = Delay in seconds before the pad becomes active at round start
# PAD_ACTIVE_DURATION       = Duration of the active state in seconds
# PAD_ACTIVE_COOLDOWN       = Cooldown in seconds before the pad becomes active again
# PAD_RADIUS                = Trigger radius for launching players
# PAD_STRENGTH              = Launch strength range (min - max)
# PAD_COOLDOWN              = Delay in seconds between consecutive launches on the same player
```

## 🔄 Changelog
```text
* v1.0: Initial release.
* v1.1: Fixed the model, added different sizes, added usage per team.
```

[![Watch on YouTube](https://img.shields.io/badge/YouTube-Watch%20video-FF0000?logo=youtube&logoColor=white)](https://www.youtube.com/watch?v=wO5SUCOOFrc)
