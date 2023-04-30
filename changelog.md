# Changelog
## v1.5
- Added changelog

### Mod Additions:
  - Kill Combo: Killing several players in a row displays a popup, and is saved in Stats.
  - Stats: Do /stats to see stats for all players. Keeps track of wins (as runner), kills, and maximum kill streak.
  - While the game is not started, a new music track plays
  - Hunters now move faster when punching underwater
  - Runners have more invulnerability frames underwater
  - /mh hack: Sets rom hack
### Adjustments:
  - Not all cutscenes activate the camp timer anymore
  - Runners can no longer constantly grab caps to remain invincible
  - Kill messages now display while the game is not active
  - When the game ends, all players are warped to the starting area
  - The pause command now pauses the entire game
  - A popup is displayed when a player is paused
  - Added color to the upper bar text
  - /mh randomize and /mh addrunner commands will try not to pick the same runner twice in a row
  - Bowser now jumps at the start of the 2nd Bowser fight, like in vanilla
  - Bowser bombs now respawn
  - Players that have not been hit by a player for 10 seconds are not marked as being attacked by that player
  - Popups now display for all players
  - The "got a star!" and "got a key!" messages now include what star or key
    - This mod has issues with Progress Popups, which is why this change is necessary
### Fixes/Backend changes:
  - Made some packets non-essential
  - Exiting spectator no longer warps you to the water's surface
  - Fixed issue in which using multiple spectate commands in a row could teleport you
  - Optimized (?) kill message code a bit
  - Rejoin timer now works for Beta 34
  - Players cannot leave starting area while game is not started
  - Fixed issues regarding star requirements