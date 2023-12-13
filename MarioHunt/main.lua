-- name: ! \\#00ffff\\Mario\\#ff5a5a\\Hun\\\\t\\#dcdcdc\\ (v2.4) !
-- incompatible: gamemode
-- description: A gamemode based off of Beyond's concept.\n\nHunters stop Runners from clearing the game!\n\nProgramming by EmilyEmmi, TroopaParaKoopa, Blocky, Sunk, and Sprinter05.\n\nSpanish Translation made with help from KanHeaven and SonicDark.\nGerman Translation made by N64 Mario.\nBrazillian Portuguese translation made by PietroM.\nFrench translation made by Skeltan.\n\n\"Shooting Star Summit\" port by pieordie1

menu = false
mhHideHud = false
expectedHudState = false -- for custom huds

LEVEL_LOBBY = level_register('level_lobby_entry', COURSE_NONE, 'Lobby', 'lobby', 28000, 0x28, 0x28, 0x28)

-- this reduces lag apparently
local djui_chat_message_create, djui_popup_create, djui_hud_measure_text, djui_hud_print_text, djui_hud_set_color, djui_hud_set_font, djui_hud_set_resolution, network_player_set_description, network_get_player_text_color_string, network_is_server, is_game_paused, get_current_save_file_num, save_file_get_star_flags, save_file_get_flags, djui_hud_render_rect, warp_to_level, mod_storage_save, mod_storage_load =
    djui_chat_message_create, djui_popup_create, djui_hud_measure_text, djui_hud_print_text, djui_hud_set_color,
    djui_hud_set_font, djui_hud_set_resolution, network_player_set_description, network_get_player_text_color_string,
    network_is_server, is_game_paused, get_current_save_file_num, save_file_get_star_flags, save_file_get_flags,
    djui_hud_render_rect, warp_to_level, mod_storage_save_fix_bug, mod_storage_load
local GST = gGlobalSyncTable
local PST = gPlayerSyncTable
local NetP = gNetworkPlayers
local MST = gMarioStates
local m0, sMario0, np0 = MST[0], PST[0], NetP[0]

-- TroopaParaKoopa's pause mod
GST.pause = false

hunterAppearance = tonumber(mod_storage_load("hunterApp")) or
2                                                               -- TroopaParaKoopa's hns metal cap option + hunter glow option
showSpeedrunTimer = true                                        -- show speedrun timer
if mod_storage_load("showSpeedrunTimer") == "false" then showSpeedrunTimer = false end
noSeason = false
if mod_storage_load("noSeason") == "true" then noSeason = true end

local rejoin_timer = {} -- rejoin timer for runners (host only)
if network_is_server() then
  -- all settings here
  GST.runnerLives = 1      -- the lives runners get (0 is a life)
  GST.runTime = 7200       -- time runners must stay in stage to leave (default: 4 minutes)
  GST.starRun = 70         -- stars runners must get to face bowser; star doors and infinite stairs will be disabled accordingly
  GST.noBowser = false     -- ignore bowser requirement; only stars are needed
  GST.allowSpectate = true -- hunters can spectate
  GST.allowStalk = false   -- players can use /stalk
  GST.starMode = false     -- use stars collected instead of timer
  GST.weak = false         -- cut invincibility frames in half
  GST.mhMode = 0           -- game modes, as follows:
  --[[
    0: Normal
    1: Swap
    2: Mini
  ]]
  GST.blacklistData = "none" -- encrypted data for blacklist
  GST.campaignCourse = 0     -- campaign course for minihunt (64 tour)
  GST.gameAuto = 0           -- automatically start new games
  GST.anarchy = 0            -- team attack; comes with 4 options
  --[[
    0 - Neither team
    1 - Runners only
    2 - Hunters only
    3 - Everyone
  ]]
  GST.dmgAdd = 0        -- Adds additional damage to pvp attacks (0-8)
  GST.nerfVanish = true -- Changes vanish cap a bit
  GST.firstTimer = true -- First place player in MiniHunt gets death timer

  -- now for other data
  GST.mhState = 0 -- game state
  --[[
    0: not started
    1: timer
    2: game started
    3: game ended (hunters win)
    4: game ended (runners win)
    5: game ended (minihunt)
  ]]
  GST.mhTimer = 0           -- timer in frames (game is 30 FPS)
  GST.speedrunTimer = 0     -- the total amount of time we've played in frames
  GST.gameLevel = 0         -- level for MiniHunt
  GST.getStar = 0           -- what star must be collected (for MiniHunt)
  GST.votes = 0             -- amount of votes for skipping (MiniHunt)
  GST.otherSave = false     -- using other save file
  GST.bowserBeaten = false  -- used for some rom hacks as a two-part completion process
  GST.ee = false            -- used for SM74
  GST.forceSpectate = false -- force all players to spectate unless otherwise stated
end

if get_os_name() ~= "Mac OSX" then -- replacing sequnce past 0x47 crashes the game on mac
  custom_seq = 0x53
else
  custom_seq = 0x41
end
smlua_audio_utils_replace_sequence(custom_seq, 0x25, 65, "Shooting_Star_Summit") -- for lobby; hopefully there's no conflicts

-- force pvp, knockback, skip intro, and no bubble death
gServerSettings.playerInteractions = PLAYER_INTERACTIONS_PVP
gServerSettings.bubbleDeath = 0
gServerSettings.skipIntro = 1
gServerSettings.playerKnockbackStrength = 20
gServerSettings.enablePlayerList = 1
-- level settings for better experience
gLevelValues.visibleSecrets = 1
gLevelValues.previewBlueCoins = 1
gLevelValues.respawnBlueCoinsSwitch = 1
gLevelValues.extendedPauseDisplay = 1
gLevelValues.hudCapTimer = 1
gLevelValues.mushroom1UpHeal = 1
gLevelValues.showStarNumber = 1

local gotStar = nil             -- what star we just got
local died = false              -- if we've died (because on_death runs every frame of death fsr)
local didFirstJoinStuff = false -- if all of the initial code was run (rules message, etc.)
frameCounter = 120              -- frame counter over 4 seconds
local cooldownCaps = 0          -- stores m.flags, to see what caps are on cooldown
local regainCapTimer = 0        -- timer for being able to recollect a cap
local storeVanish = false       -- temporarily stores the vanish cap for pvp purposes
local campTimer                 -- for camping actions (such as reading text or being in the star menu), nil means it is inactive
warpCooldown = 0                -- to avoid warp spam
warpCount = 0
local warpTree = {}
local killTimer = 0            -- timer for kills in quick succession
local killCombo = 0            -- kills in quick succession
local hitTimer = 0             -- timer for being hit by another player
local localRunTime = 0         -- our run time is usually made local for less lag
local neededRunTime = 0        -- how long we need to wait to leave this course
local inHard = 0               -- what hard mode we started in (to prevent cheesy hard/extreme mode wins)
local deathTimer = 900         -- for extreme mode
local localPrevCourse = 0      -- for entrance popups
local lastObtainable = -1      -- doesn't display if it's the same number
local leader = false           -- if we're winning in minihunt
local scoreboard = {}          -- table of everyone's score
month = 0                      -- the current month of the year, for holiday easter eggs
local parkourTimer = 0         -- timer for parkour
local noSettingDisp = false    -- disables setting change display temporarily

OmmEnabled = false             -- is true if using OMM Rebirth
local ACT_OMM_STAR_DANCE = nil -- the grab star action in OMM Rebirth (might change with updates, idk)
local ommStarID = nil          -- the object id of the star we got; for OMM
local ommStar = nil            -- what star we just got; for omm (gotStar is set to nil earlier)
local ommRenameTimer = 0       -- after someone gets the same kind of star, there is a timer until someone can have their star renamed on their end

-- Converts string into a table using a determiner (but stop splitting after a certain amount)
function split(s, delimiter, limit_)
  local limit = limit_ or 999
  local result = {}
  local finalmatch = ""
  local i = 0
  for match in (s):gmatch(string.format("[^%s]+", delimiter)) do
    --djui_chat_message_create(match)
    i = i + 1
    if i >= limit then
      finalmatch = finalmatch .. match .. delimiter
    else
      table.insert(result, match)
    end
  end
  if i >= limit then
    finalmatch = string.sub(finalmatch, 1, string.len(finalmatch) - string.len(delimiter))
    table.insert(result, finalmatch)
  end
  return result
end

-- handle game starting (all players)
function do_game_start(data, self)
  save_settings()
  omm_disable_mode_for_minihunt(GST.mhMode == 2) -- change non stop mode setting for minihunt
  menu = false
  showingStats = false
  local cmd = data.cmd or ""

  if GST.mhMode == 2 then
    GST.mhState = 2

    if string.lower(cmd) ~= "continue" then
      GST.mhTimer = GST.runTime or 0
    end
  elseif string.lower(cmd) ~= "continue" then
    deathTimer = 1830     -- start with 60 seconds
    GST.mhState = 1
    GST.mhTimer = 15 * 30 -- 15 seconds
  else
    deathTimer = 900      -- start with 30 seconds
    GST.mhState = 2
    GST.mhTimer = 0
  end

  if network_is_server() and GST.mhMode == 2 then
    if tonumber(cmd) ~= nil and tonumber(cmd) > 0 and (tonumber(cmd) % 1 == 0) then
      GST.campaignCourse = tonumber(cmd)
    else
      GST.campaignCourse = 0
    end
    random_star(nil, GST.campaignCourse)
  end

  if string.lower(cmd) ~= "continue" then
    m0.health = 0x880
    SVcln = nil
    set_lighting_dir(2, 0)

    GST.votes = 0
    iVoted = false
    GST.speedrunTimer = 0

    sMario0.totalStars = 0
    leader = false
    scoreboard = {}
    if sMario0.team == 1 then
      sMario0.runnerLives = GST.runnerLives
      sMario0.runTime = 0
      died = false
      m0.numLives = sMario0.runnerLives
    else -- save 'been runner' status
      print("Our 'Been Runner' status has been cleared")
      sMario0.beenRunner = 0
      mod_storage_save("beenRunnner", "0")
    end
    inHard = sMario0.hard or 0
    killTimer = 0
    killCombo = 0
    campTimer = nil
    warpCount = 0
    warpCooldown = 0

    warp_beginning()

    if (string.lower(cmd) == "main") then
      GST.otherSave = false
    elseif (string.lower(cmd) == "alt") or (string.lower(cmd) == "reset") then
      GST.otherSave = true
    end
    GST.bowserBeaten = false
    save_file_set_using_backup_slot(GST.otherSave)
    if (string.lower(cmd) == "reset") then
      print("did reset")
      --save_file_erase_current_backup_save()
      local file = get_current_save_file_num() - 1
      for course = 0, 25 do
        save_file_remove_star_flags(file, course - 1, 0xFF)
      end
      save_file_clear_flags(0xFFFFFFFF) -- ALL OF THEM
      save_file_do_save(file, 1)
    end
  end
end

-- code from arena
function allow_pvp_attack(attacker, victim)
  -- false if timer going or game end
  if GST.mhState == 1 then return false end
  if GST.mhState >= 3 then return false end

  -- allow hurting each other in lobby, except in parkour challenge
  if GST.mhState == 0 then
    local raceTimerOn = hud_get_value(HUD_DISPLAY_FLAGS) & HUD_DISPLAY_FLAGS_TIMER
    return (raceTimerOn == 0)
  end

  if attacker.playerIndex == victim.playerIndex then
    return false
  end

  local sAttacker = PST[attacker.playerIndex]
  local sVictim = PST[victim.playerIndex]

  -- sanitize
  local attackTeam = sAttacker.team or 0
  local victimTeam = sVictim.team or 0

  -- team attack setting
  if GST.anarchy == 0 then
    return attackTeam ~= victimTeam
  elseif (GST.anarchy == 3) then
    return true
  elseif (GST.anarchy == 1 and attackTeam == 1) then
    return true
  elseif (GST.anarchy == 2 and attackTeam ~= 1) then
    return true
  end

  return attackTeam ~= victimTeam
end

function on_pvp_attack(attacker, victim)
  local sVictim = PST[victim.playerIndex]
  local npAttacker = NetP[attacker.playerIndex]
  if sVictim.team == 1 then
    if GST.dmgAdd >= 8 then -- instant death
      victim.health = 0xFF
      victim.healCounter = 0
    else
      if (victim.flags & MARIO_METAL_CAP) ~= 0 then
        victim.hurtCounter = victim.hurtCounter + 4            -- one unit
      end
      victim.hurtCounter = victim.hurtCounter + GST.dmgAdd * 4 -- hurtCounter goes by 4 for some reason
    end
  end
  if victim.playerIndex == 0 then
    attackedBy = npAttacker.globalIndex
    hitTimer = 300 -- 10 seconds
    if (victim.health - math.max((victim.hurtCounter - victim.healCounter) * 0x40, 0)) <= 0xFF then
      play_sound(SOUND_GENERAL_BOWSER_BOMB_EXPLOSION, victim.marioObj.header.gfx.cameraToObject)
      set_camera_shake_from_hit(SHAKE_LARGE_DAMAGE)
    end
  end
end

-- omm support
function omm_allow_attack(index, setting)
  if setting == 3 and index ~= 0 then
    return allow_pvp_attack(MST[index], m0)
  end
  return true
end

function omm_attack(index, setting)
  if setting == 3 and index ~= 0 then
    on_pvp_attack(MST[index], m0)
  end
end

-- sadly this no longer works for omm (while I CAN force the value, it prevents it from being changed)
function hide_both_hud(hide)
  if OmmEnabled then return end

  -- don't override custom huds
  if expectedHudState ~= hud_is_hidden() then
    return
  end
  if hide then
    hud_hide()
  else
    hud_show()
  end
  expectedHudState = hide
  hide_star_counters(hide)
end

-- personal star counter support (even though it's set to incompatible anyway)
function hide_star_counters(hide)
  return
end

function get_leave_requirements(sMario)
  -- for leave command
  if sMario.allowLeave then
    return 0
  end

  -- in castle
  if np0.currCourseNum == 0 or (ROMHACK ~= nil and ROMHACK.hubStages ~= nil and ROMHACK.hubStages[np0.currCourseNum] ~= nil) then
    return 0, trans("in_castle")
  end

  -- allow leaving bowser stages if done
  if np0.currCourseNum == COURSE_BITDW and ((save_file_get_flags() & (SAVE_FLAG_HAVE_KEY_1 | SAVE_FLAG_UNLOCKED_BASEMENT_DOOR)) ~= 0) then
    return 0
  elseif np0.currCourseNum == COURSE_BITFS and ((save_file_get_flags() & (SAVE_FLAG_HAVE_KEY_2 | SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR)) ~= 0) then
    return 0
  elseif np0.currCourseNum == COURSE_BITS and GST.bowserBeaten then -- star road and such
    return 0
  end

  -- allow leaving any course EXCEPT final if the needed stars are collected
  local final = (ROMHACK and ROMHACK.final) or COURSE_BITS
  if m0.numStars >= GST.starRun and GST.starRun ~= -1 and final ~= -1 and np0.currCourseNum ~= final then
    return 0
  end

  -- can't leave some stages in star mode
  if neededRunTime == -1 then
    return 1, trans("cant_leave")
  end

  return (neededRunTime - localRunTime)
end

-- only do this sometimes to reduce lag
function calculate_leave_requirements(sMario, runTime, gotStar)
  -- skip calculation if we're in a hub stage, and prevent leaving bowser areas
  if np0.currCourseNum == 0 or (ROMHACK ~= nil and ROMHACK.hubStages ~= nil and ROMHACK.hubStages[np0.currCourseNum] ~= nil) then
    return 0, 0
  elseif np0.currLevelNum == LEVEL_BOWSER_1 or np0.currLevelNum == LEVEL_BOWSER_2 or np0.currLevelNum == LEVEL_BOWSER_3 then
    return -1, 0 -- -1 means no leaving
  end

  -- less time for secret courses
  local total_time = GST.runTime
  local star_data_table = { 8, 8, 8, 8, 8, 8, 8 }
  if ROMHACK.star_data and ROMHACK.star_data[np0.currCourseNum] then
    star_data_table = ROMHACK.star_data[np0.currCourseNum]
    -- for EE
    if GST.ee and ROMHACK.star_data_ee and ROMHACK.star_data_ee[np0.currCourseNum] then
      star_data_table = ROMHACK.star_data_ee[np0.currCourseNum]
    end
  elseif np0.currCourseNum > 15 then
    star_data_table = { 8 }
  end
  if (np0.currCourseNum == COURSE_DDD and ROMHACK.ddd and ((save_file_get_flags() & (SAVE_FLAG_HAVE_KEY_2 | SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR)) == 0)) then
    star_data_table = { 8 } -- treat DDD as only having star 1
  end

  -- if a "exit" star was obtained, allow leaving immediatly
  if gotStar and star_data_table[gotStar] and star_data_table[gotStar] & STAR_EXIT ~= 0 then
    local skip_rule = (gLevelValues.disableActs and star_data_table[gotStar] & STAR_APPLY_NO_ACTS == 0)
    if not skip_rule then
      sMario.allowLeave = true
      return 0, 0
    end
  end

  -- calculate what stars can still be obtained
  local counting_stars = 0
  local obtainable_stars = 0
  local file = get_current_save_file_num() - 1
  local course_star_flags = save_file_get_star_flags(file, np0.currCourseNum - 1)
  for i = 1, #star_data_table do
    if star_data_table[i] and (course_star_flags & (1 << (i - 1)) == 0) then
      local data = star_data_table[i]
      local areaValid = false
      local area = data & STAR_AREA_MASK
      if star_data_table[i] < STAR_MULTIPLE_AREAS then
        if area == 8 or np0.currAreaIndex == area then
          areaValid = true
        end
      else
        local areas = (data & ~(STAR_MULTIPLE_AREAS - 1))
        if areas & (np0.currAreaIndex) ~= 0 then
          areaValid = true
        end
      end

      -- for star road
      if i == #star_data_table and ROMHACK.replica_start ~= nil and m0.numStars < ROMHACK.replica_start and np0.currCourseNum > 15 and np0.currCourseNum ~= 25 then
        area = 0
      end

      local act = math.max(np0.currActNum, 1) -- anything below act 1 is still act 1
      local skip_rule = (gLevelValues.disableActs and data & STAR_APPLY_NO_ACTS == 0)
      if (skip_rule and area ~= 0)
          or (areaValid
            and (data & STAR_ACT_SPECIFIC == 0 or act == i)
            and (data & STAR_NOT_ACT_1 == 0 or act > 1)
            and (data & STAR_NOT_BEFORE_THIS_ACT == 0 or act >= i)) then
        obtainable_stars = obtainable_stars + 1
        if skip_rule or (not GST.starMode) or data & STAR_IGNORE_STARMODE == 0 then
          counting_stars = counting_stars + 1
        end
      end
    end
  end

  -- if there aren't any in this stage, treat as a 1 star stage
  if #star_data_table <= 0 then
    counting_stars = 1
    if GST.starMode or ROMHACK.isUnder then return -1, 0 end -- impossible to leave in star mode
  end

  if lastObtainable ~= obtainable_stars then
    djui_popup_create(trans("stars_in_area", obtainable_stars), 1)
    lastObtainable = obtainable_stars
  end

  if GST.starMode then
    if (total_time - runTime) > counting_stars then
      runTime = total_time - counting_stars
    end
  elseif (total_time - runTime) > counting_stars * 2700 then
    runTime = total_time - counting_stars * 2700
  end
  return total_time, runTime
end

-- random star for MiniHunt
function random_star(prevCourse, campaignCourse_)
  local campaignCourse = campaignCourse_ or 0
  local selectedStar = nil
  if campaignCourse > 0 and campaignCourse < 26 then
    -- the campaign from the 64 tour!
    local starorder = { 15, 22, 33, 44, 54, 64, 75, 85, 94, 101, 113, 121, 137, 144, 154, 171, 221, 14, 47, 62, 77, 93, 161, 181, 231 }
    selectedStar = starorder[campaignCourse]
  elseif selectedStar == nil then
    local replicas = true
    if ROMHACK.replica_start ~= nil then
      local courseMax = 25
      local courseMin = 1
      local totalStars = save_file_get_total_star_count(get_current_save_file_num() - 1, courseMin - 1, courseMax - 1)
      if ROMHACK.replica_start > totalStars then
        replicas = false
      end
    end

    local valid_star_table = generate_star_table(prevCourse, false, replicas)
    if #valid_star_table < 1 then
      valid_star_table = generate_star_table(prevCourse, false, replicas, GST.getStar)
      if #valid_star_table < 1 then
        global_popup_lang("no_valid_star", nil, nil, 1)
        GST.mhTimer = 1 -- end game
        return
      end
      selectedStar = valid_star_table[math.random(1, #valid_star_table)]
    else
      selectedStar = valid_star_table[math.random(1, #valid_star_table)]
    end
  end

  GST.getStar = selectedStar % 10
  GST.gameLevel = course_to_level[selectedStar // 10]
  print("Selected", GST.gameLevel, GST.getStar)
end

-- generate table of valid stars
function generate_star_table(exCourse, standard, replicas, recentAct)
  local valid_star_table = {}
  for course, level in pairs(course_to_level) do
    if course ~= exCourse or recentAct ~= nil then
      for act = 1, 7 do
        if recentAct ~= act and valid_star(course, act, standard, replicas) then
          table.insert(valid_star_table, course * 10 + act)
        end
      end
    end
  end
  return valid_star_table
end

-- gets if the star is valid for minihunt
function valid_star(course, act, standard, replicas)
  if course < 0 or course > 25 or (course % 1 ~= 0) then return false end

  if (standard or (course ~= 0 and course ~= 25 and (ROMHACK.hubStages == nil or ROMHACK.hubStages[course] == nil))) then
    local star_data_table = { 8, 8, 8, 8, 8, 8, 8 }
    if course == 25 and not ROMHACK.star_data[course] then
      return false
    elseif course > 15 or ROMHACK.star_data[course] then
      star_data_table = ROMHACK.star_data[course] or { 8 }
      if GST.ee and ROMHACK.star_data_ee and ROMHACK.star_data_ee[course] then
        star_data_table = ROMHACK.star_data_ee[course]
      end
    elseif course == 0 then
      star_data_table = { 8, 8, 8, 8, 8 }
    end

    if star_data_table[act] then
      if (not replicas) and act == #star_data_table then
        return false
      elseif star_data_table[act] ~= 0 and (standard or mini_blacklist == nil or mini_blacklist[course * 10 + act] == nil) and (standard or act ~= 7 or course > 15) then
        return true
      end
      return false
    else
      return false
    end
  end
  return false
end

function on_pause_exit(exitToCastle)
  if GST.mhState == 0 then return false end
  if (m0.health - math.max((m0.hurtCounter - m0.healCounter) * 0x40, 0)) <= 0xFF then return false end -- prevent leaving in death
  if sMario0.spectator == 1 then return false end
  if GST.mhMode == 2 then
    if m0.invincTimer <= 0 and (m0.action & ACT_FLAG_AIR) == 0 then
      warp_beginning()
    end
    return false
  end
  if sMario0.team == 1 and get_leave_requirements(sMario0) > 0 then return false end

  if exitToCastle then
    m0.health = 0x880 -- full health
    m0.hurtCounter = 0x0
  end
end

function on_death(m, nonStandard)
  if m.playerIndex ~= 0 then return true end
  if ROMHACK.isUnder and (not nonStandard) and m.health <= 0xFF and NetP[0].currLevelNum == LEVEL_CASTLE_COURTYARD then
    m.health = 0x880
    m.hurtCounter = 0
    force_idle_state(m)
    reset_camera(m.area.camera)
    return false
  elseif not nonStandard and GST.mhMode ~= 2 and GST.mhState ~= 0 and NetP[0].currCourseNum == 0 and m.floor.type ~= SURFACE_INSTANT_QUICKSAND then -- for star road (and also 121rst star)
    m.numLives = 101
    died = true
    return true
  end

  if died == false then
    local lost = false
    local newID = nil
    local runner = false
    local time = localRunTime or 0
    m.health = 0xFF  -- Mario's health is used to see if he has respawned
    m.numLives = 100 -- prevent star road 0 life
    died = true
    warpCount = 0
    warpCooldown = 0
    killTimer = 0
    killCombo = 0

    -- change to hunter
    if GST.mhState == 2 and sMario0.team == 1 and sMario0.runnerLives <= 0 then
      runner = true
      m.numLives = 100
      become_hunter(sMario0)
      localRunTime = 0
      lost = true

      -- pick new runner
      if GST.mhMode ~= 0 then
        if attackedBy ~= nil then
          local killerNP = network_player_from_global_index(attackedBy)
          local kSMario = PST[killerNP.localIndex]
          if kSMario.team ~= 1 then
            become_runner(kSMario)
            newID = attackedBy
          else
            newID = new_runner()
          end
        else
          newID = new_runner()
        end
      end
    end

    if sMario0.runnerLives ~= nil and GST.mhState == 2 then
      sMario0.runnerLives = sMario0.runnerLives - 1
      runner = true
    end

    if attackedBy == nil and (not runner) then return true end -- no one cares about hunters dying

    network_send_include_self(true, {
      id = PACKET_KILL,
      killed = np0.globalIndex,
      killer = attackedBy,
      death = lost,
      newRunnerID = newID,
      time = time,
      runner = runner,
    })
  end

  if (not nonStandard) and (GST.mhState == 0 or GST.mhMode == 2) then
    if m.playerIndex == 0 then warp_beginning() end
    m.health = 0x880
    return false
  end

  return true
end

function new_runner(includeLocal)
  local startingI = 1
  if includeLocal then
    startingI = 0
  end

  local currHunterIDs = {}
  local closest = -1
  local closestDist = 0

  -- get current hunters
  local runnerCount = 0
  for i = startingI, (MAX_PLAYERS - 1) do
    local np = NetP[i]
    local sMario = PST[i]
    if np.connected and sMario.spectator ~= 1 then
      if sMario.team ~= 1 then
        table.insert(currHunterIDs, np.localIndex)
        if (not includeLocal) and is_player_active(MST[i]) ~= 0 then -- give to closest mario
          local dist = dist_between_objects(MST[i].marioObj, m0.marioObj)
          if closest == -1 or dist < closestDist then
            closestDist = dist
            closest = i
          end
        end
      else
        runnerCount = runnerCount + 1
      end
    end
  end
  if #currHunterIDs < 1 then
    if not includeLocal then
      if GST.mhMode == 2 and runnerCount == 0 then -- singleplayer minihunt
        GST.mhTimer = 1                            -- end game
        return nil
      else
        return NetP[0].globalIndex
      end
    else
      return nil
    end
  end

  local lIndex = 0
  if closest == -1 then
    lIndex = currHunterIDs[math.random(1, #currHunterIDs)]
  else
    lIndex = closest
  end
  local np = NetP[lIndex]
  return np.globalIndex
end

function omm_disable_mode_for_minihunt(disable)
  if OmmEnabled then
    gLevelValues.disableActs = not disable
    _G.OmmApi.omm_disable_feature("trueNonStop", disable)
  end
end

function update()
  noSettingDisp = false
  do_pause()
  if obj_get_first_with_behavior_id(id_bhvActSelector) ~= nil then
    before_mario_update(m0, true)
  end

  -- detect victory for runners
  if GST.mhState == 2 and GST.mhMode ~= 2 and sMario0.team == 1 then
    local win = false
    if GST.noBowser then
      win = m0.numStars >= GST.starRun
    else
      win = ROMHACK and ROMHACK.runner_victory and ROMHACK.runner_victory(m0)
    end
    if win then
      network_send_include_self(true, {
        id = PACKET_GAME_END,
        winner = 1,
      })
      rejoin_timer = {}
      GST.mhState = 4
      GST.mhTimer = 20 * 30 -- 20 seconds
    end
  end

  if warpCooldown > 0 then warpCooldown = warpCooldown - 1 end
  if GST.votes == 0 then iVoted = false end -- undo vote

  -- handle timers
  if not (GST.pause and sMario0.pause) then
    if frameCounter < 1 then
      frameCounter = 121
    end
    frameCounter = frameCounter - 1

    if network_is_server() and didFirstJoinStuff then
      if GST.mhTimer > 0 then
        GST.mhTimer = GST.mhTimer - 1
        if GST.mhTimer == 0 then
          if GST.mhState == 1 then
            GST.mhState = 2
          elseif GST.mhState >= 3 or GST.mhState == 0 then
            if GST.gameAuto ~= 0 then
              print("New game started")

              local singlePlayer = true
              for i = 1, MAX_PLAYERS - 1 do
                local np = NetP[i]
                local sMario = PST[i]
                if np.connected and sMario.spectator ~= 1 then
                  singlePlayer = false
                  break
                end
              end
              if not singlePlayer then
                runner_randomize(GST.gameAuto)
              end

              if GST.mhMode ~= 2 then
                start_game("reset")
              elseif GST.campaignCourse > 0 then
                start_game("1") -- stay in campaign mode
              else
                start_game("")
              end
              if GST.mhTimer == 0 then
                GST.mhTimer = 20 * 30 -- 20 seconds (in elseif o.oAction == start doesnt work)
              end
            else
              GST.mhState = 0
            end
          else
            GST.mhState = 5
            network_send_include_self(true, {
              id = PACKET_GAME_END,
            })
            GST.mhTimer = 20 * 30 -- 20 seconds
          end
        end
      end

      if GST.mhMode ~= 2 and (GST.mhState ~= 0 and (GST.mhState == 2 or (GST.mhState < 3 and GST.mhTimer < 300))) then
        GST.speedrunTimer = GST.speedrunTimer + 1
      end

      for id, data in pairs(rejoin_timer) do
        data.timer = data.timer - 1
        if data.timer <= 0 then
          global_popup_lang("rejoin_fail", data.name, nil, 1)
          rejoin_timer[id] = nil -- times up

          if GST.mhMode == 1 then
            local newID = new_runner(true)
            if newID ~= nil then
              network_send_include_self(true, {
                id = PACKET_KILL,
                newRunnerID = newID,
                time = 0,
              })
            end
          end
        end
      end
    end
  end

  -- kill combo stuff
  if killTimer > 0 then
    killTimer = killTimer - 1
  end
  if killTimer == 0 then killCombo = 0 end
  if hitTimer > 0 then
    hitTimer = hitTimer - 1
  end
  if hitTimer == 0 and (m0.action & ACT_FLAG_AIR) == 0 then attackedBy = nil end -- only reset on ground
end

-- do first join setup
function on_course_sync()
  if not didFirstJoinStuff then
    OmmEnabled = _G.OmmEnabled or false -- set up OMM support
    if OmmEnabled then
      _G.OmmApi.omm_resolve_cappy_mario_interaction = omm_attack
      _G.OmmApi.omm_allow_cappy_mario_interaction = omm_allow_attack
      _G.OmmApi.omm_disable_feature("lostCoins", true)
      _G.OmmApi.omm_force_setting("player", 2)
      _G.OmmApi.omm_force_setting("damage", 20)
      _G.OmmApi.omm_force_setting("bubble", 0)
      ACT_OMM_STAR_DANCE = _G.OmmApi.ACT_OMM_STAR_DANCE
    end
    if GST.romhackFile == "vanilla" then
      omm_replace(OmmEnabled)
    end
    if _G.PersonalStarCounter then
      hide_star_counters = _G.PersonalStarCounter.hide_star_counters
    end

    setup_hack_data(network_is_server(), true, OmmEnabled)
    if network_is_server() then
      load_settings()

      local fileName = string.gsub(GST.romhackFile, " ", "_")
      local option = mod_storage_load(fileName .. "_black") or "none"
      GST.blacklistData = option
      setup_mini_blacklist(option)

      if GST.gameAuto ~= 0 then
        GST.mhTimer = 20 * 30
      end
    else
      setup_mini_blacklist(GST.blacklistData)
    end

    -- holiday detection (it's a bit complex)
    local time = get_time() - 3600 * 4 -- EST (-4 hours)
    local hours = time%(3600*24)//3600
    local days = (time // 60 // 60 // 24) + 1
    local years = (days // 365.25)
    local year = 1970 + years
    days = days - years * 365 - years // 4 + years // 100 - years // 400
    while month < 12 do
      month = month + 1
      local DaysInMonth = 30
      if month == 2 then
        DaysInMonth = 28 + is_zero(year % 4) - is_zero(year % 100)
            + is_zero(year % 400)
      else
        DaysInMonth = 30 + (month + bool_to_int(month > 7)) % 2
      end
      if days > DaysInMonth then
        --djui_popup_create(tostring(DaysInMonth), 1)
        days = days - DaysInMonth
      else
        break
      end
    end
    if month == 4 and days == 1 then -- april fools
      month = 13
    end
    --djui_popup_create(string.format("%d/%d/%d, %d",month,days,year,hours), 1)

    print(time)
    math.randomseed(time)
    gLevelValues.starHeal = false

    save_file_set_using_backup_slot(GST.otherSave)
    --save_file_reload(1)
    if GST.allowStalk then
      stalk_command("", true)
      popup_sound(SOUND_GENERAL2_RIGHT_ANSWER)
      djui_popup_create(trans("stalk"), 1)
    else
      warp_beginning()
    end

    -- display and set stats
    local stats = {
      "wins",
      "hardWins",
      "exWins",
      "wins_standard",
      "hardWins_standard",
      "exWins_standard",
      "kills",
      "maxStreak",
      "maxStar",
    }
    for i, stat in ipairs(stats) do
      local value = tonumber(mod_storage_load(stat)) or 0
      sMario0[stat] = math.floor(value)
    end
    sMario0.hard = 0

    local wins = sMario0.wins + sMario0.wins_standard
    local hardWins = sMario0.hardWins + sMario0.hardWins_standard
    local exWins = sMario0.exWins + sMario0.exWins_standard

    local playerColor = network_get_player_text_color_string(0)
    if wins >= 1 then
      network_send(false, {
        id = PACKET_STATS,
        stat = "disp_wins",
        value = math.floor(wins),
        name = playerColor .. np0.name,
      })
      if (wins >= 100 or hardWins >= 5) and exWins <= 0 then
        djui_chat_message_create(trans("extreme_notice"))
      elseif wins >= 5 and hardWins <= 0 then
        djui_chat_message_create(trans("hard_notice"))
      end
    end
    if hardWins >= 1 then
      network_send(false, {
        id = PACKET_STATS,
        stat = "disp_wins_hard",
        value = math.floor(hardWins),
        name = playerColor .. np0.name,
      })
      if wins >= 5 and hardWins <= 0 then
        djui_chat_message_create(trans("hard_notice"))
      end
    end
    if exWins >= 1 then
      network_send(false, {
        id = PACKET_STATS,
        stat = "disp_wins_ex",
        value = math.floor(exWins),
        name = playerColor .. np0.name,
      })
    end
    if sMario0.kills >= 50 then
      network_send(false, {
        id = PACKET_STATS,
        stat = "disp_kills",
        value = math.floor(sMario0.kills),
        name = playerColor .. np0.name,
      })
    end
    local beenRunner = mod_storage_load("beenRunnner")
    sMario0.beenRunner = tonumber(beenRunner) or 0
    print("Our 'Been Runner' status is ", sMario0.beenRunner)

    local discordID = network_discord_id_from_local_index(0)
    discordID = tonumber(discordID) or 0
    print("My discord ID is", discordID)
    sMario0.discordID = discordID
    sMario0.placement = assign_place(discordID)
    check_for_roles()

    -- start out as hunter
    become_hunter(sMario0)
    sMario0.totalStars = 0
    leader, scoreboard = calculate_placement()
    sMario0.pause = GST.pause or false
    sMario0.forceSpectate = GST.forceSpectate or false
    sMario0.spectator = (GST.forceSpectate and 1) or 0
    sMario0.fasterActions = (mod_storage_load("fasterActions") ~= "false")

    show_rules()
    djui_chat_message_create(trans("open_menu"))
    djui_chat_message_create(trans("to_switch", lang_list))

    if GST.mhState == 0 then
      set_lobby_music(month)
      --play_music(0, custom_seq, 1)
    end
    omm_disable_mode_for_minihunt(GST.mhMode == 2) -- change non stop mode setting for minihunt

    menu_reload()
    action_setup()
    menu_enter()

    -- this works, surprisingly (runs last)
    hook_event(HOOK_ON_HUD_RENDER, on_hud_render)
    hook_event(HOOK_ALLOW_INTERACT, on_allow_interact)

    didFirstJoinStuff = true
    return
  end

  -- completely ruins the save file apparently :/
  --[[if justEntered and GST.otherSave ~= nil then
    save_file_set_using_backup_slot(GST.otherSave)
    save_file_reload(1)
    justEntered = false
  end]]

  -- prevent softlock if hunters kill bowser (vanilla only)
  if sMario0.team == 1 and (np0.currLevelNum == LEVEL_BOWSER_1 or np0.currLevelNum == LEVEL_BOWSER_2) and GST.romhackFile == "vanilla" then
    local bowser = obj_get_first_with_behavior_id(id_bhvBowser)
    local key = obj_get_first_with_behavior_id(id_bhvBowserKey)
    if bowser and bowser.oAction == 4 and (not key) then
      spawn_non_sync_object(
        id_bhvBowserKey,
        E_MODEL_BOWSER_KEY,
        m0.pos.x, m0.pos.y, m0.pos.z,
        nil
      )
    end
  end
end

-- load saved settings for host
function load_settings(miniOnly, starOnly, lifeOnly)
  if not network_is_server() then return end

  local settings = { "mhMode", "runnerLives", "starMode", "runTime", "allowSpectate", "weak", "campaignCourse",
    "gameAuto", "dmgAdd", "anarchy", "nerfVanish", "firstTimer" }
  for i, setting in ipairs(settings) do
    local option = mod_storage_load(setting)

    if starOnly then
      if (setting == "runTime") then
        if GST.starMode then
          option = mod_storage_load("neededStars")
        end
      else
        option = nil
      end
    elseif lifeOnly then
      if setting == "runnerLives" then
        if GST.mhMode == 1 then
          option = mod_storage_load("switch_runnerLives")
        elseif GST.mhMode == 2 then
          option = mod_storage_load("mini_runnerLives")
        end
      else
        option = nil
      end
    elseif (setting == "dmgAdd" or setting == "anarchy" or setting == "runTime" or setting == "runnerLives" or setting == "gameAuto") then
      if setting == "gameAuto" then
        if GST.mhMode ~= 2 then
          option = mod_storage_load("stan_" .. setting)
        end
      elseif GST.mhMode == 2 then
        option = mod_storage_load("mini_" .. setting)
      elseif setting == "runTime" and GST.starMode then
        option = mod_storage_load("neededStars")
      elseif setting == "runnerLives" and GST.mhMode == 1 then
        option = mod_storage_load("switch_runnerLives")
      end
    elseif miniOnly then
      option = nil -- only load settings that change with minihunt
    end

    if option ~= nil then
      if option == "true" then
        GST[setting] = true
      elseif option == "false" then
        GST[setting] = false
      elseif tonumber(option) ~= nil then
        GST[setting] = math.floor(tonumber(option))
        if setting == "gameAuto" and GST[setting] == 0 and (GST.mhState == 0 or GST.mhState >= 3) then
          GST.mhTimer = 0
        end
      end
    end
  end
  -- special cases
  if not (miniOnly or starOnly or lifeOnly) then
    local fileName = string.gsub(GST.romhackFile, " ", "_")
    option = mod_storage_load(fileName)
    local optionNoBow = mod_storage_load(fileName .. "_noBow")
    local optionStalk = mod_storage_load(fileName .. "_stalk")
    if option ~= nil and tonumber(option) ~= nil then
      GST.starRun = tonumber(option)
    end
    if optionNoBow == "true" then
      GST.noBowser = true
    elseif optionNoBow == "false" then
      GST.noBowser = false
    end
    if optionStalk == "true" then
      GST.allowStalk = true
    elseif optionStalk == "false" then
      GST.allowStalk = false
    end
  end
end

-- save settings for host
function save_settings()
  if not network_is_server() then return end

  local settings = { "runnerLives", "starMode", "runTime", "allowSpectate", "weak", "mhMode", "campaignCourse",
    "gameAuto", "dmgAdd", "anarchy", "nerfVanish", "firstTimer" }
  for i, setting in ipairs(settings) do
    local option = GST[setting]

    if setting == "gameAuto" and GST.mhMode ~= 2 then
      setting = "stan_" .. setting
    elseif (setting == "dmgAdd" or setting == "anarchy" or setting == "runTime" or setting == "runnerLives") and GST.mhMode == 2 then
      setting = "mini_" .. setting
    elseif setting == "runTime" and GST.starMode then
      setting = "neededStars"
    elseif setting == "runnerLives" and GST.mhMode == 1 then
      setting = "switch_runnerLives"
    end

    if option ~= nil then
      if option == true then
        mod_storage_save(setting, "true")
      elseif option == false then
        mod_storage_save(setting, "false")
      elseif tonumber(option) ~= nil then
        mod_storage_save(setting, tostring(math.floor(option)))
      end
    end
  end
  -- special cases
  option = GST.starRun
  local optionNoBow = GST.noBowser
  local optionStalk = GST.allowStalk
  local fileName = string.gsub(GST.romhackFile, " ", "_")
  if fileName ~= "custom" and option ~= nil then
    mod_storage_save(fileName, tostring(option))
    if (ROMHACK == nil or ROMHACK.no_bowser == nil) and (optionNoBow or mod_storage_load(fileName .. "_noBow")) then
      mod_storage_save(fileName .. "_noBow", tostring(optionNoBow))
    end
    if (ROMHACK and optionStalk ~= ROMHACK.stalk) or mod_storage_load(fileName .. "_stalk") then
      mod_storage_save(fileName .. "_stalk", tostring(optionNoBow))
    end
  end
end

-- loads default settings for host
function default_settings()
  setup_hack_data(true, false, OmmEnabled)

  if GST.mhMode == 1 then
    GST.runnerLives = 0
    GST.runTime = 7200
    GST.anarchy = 0
    GST.dmgAdd = 0
  elseif GST.mhMode == 2 then
    GST.runnerLives = 0
    GST.runTime = 9000
    GST.anarchy = 1
    GST.dmgAdd = 2
  else
    GST.runnerLives = 1
    GST.runTime = 7200
    GST.anarchy = 0
    GST.dmgAdd = 0
  end

  GST.allowSpectate = true
  GST.allowStalk = false
  GST.starMode = false
  GST.weak = false
  if GST.gameAuto ~= 0 and (GST.mhState == 0 or GST.mhState == 5) then
    GST.mhTimer = 0
  end
  GST.gameAuto = 0
  GST.campaignCourse = 0
  GST.nerfVanish = true
  GST.firstTimer = true
  save_settings()
  return true
end

-- lists every setting
function list_settings()
  local settings = { "mhMode", "campaignCourse", "starRun", "runnerLives", "runTime", "nerfVanish",
    "firstTimer", "weak", "dmgAdd", "anarchy", "allowSpectate", "allowStalk" }
  local settingName = { "menu_gamemode", "menu_campaign", "menu_category", "menu_run_lives", "menu_time",
    "menu_nerf_vanish", "menu_first_timer", "menu_weak", "menu_dmgAdd", "menu_anarchy",
    "menu_allow_spectate", "menu_allow_stalk" }
  for i, setting in ipairs(settings) do
    local name = settingName[i]
    local value = GST[setting]
    name, value = get_setting_as_string(name, value)

    if value then
      if name then
        djui_chat_message_create(trans(name) .. ": " .. value)
      else
        djui_chat_message_create(value)
      end
    end
  end
end

-- used for list settings and whenever a setting is changed
function get_setting_as_string(name, value)
  if name == "menu_gamemode" then -- gamemode
    if value == 0 then
      value = "\\#00ffff\\" .. "Normal"
    elseif value == 1 then
      value = "\\#5aff5a\\" .. "Swap"
    elseif value == 2 then
      value = "\\#ffff5a\\" .. "Mini"
    else
      value = "INVALID: " .. tostring(value)
    end
    if GST.gameAuto ~= 0 then
      local auto = ""
      if GST.gameAuto == 99 then
        auto = " \\#5aff5a\\(Auto)"
      elseif GST.gameAuto == 1 then
        auto = " \\#00ffff\\(Auto, 1 " .. trans("runner") .. ")"
      else
        auto = " \\#00ffff\\(Auto, " .. GST.gameAuto .. " " .. trans("runners") .. ")"
      end
      value = value .. auto
    end
  elseif name == "menu_auto" then
    if value == 99 then
      value = " \\#5aff5a\\Auto"
    elseif value == 1 then
      value = " \\#00ffff\\1 " .. trans("runner")
    elseif value == 0 then
      value = false
    else
      value = " \\#00ffff\\" .. value .. " " .. trans("runners")
    end
  elseif name == "menu_time" then -- run time or stars needed
    name = nil
    local timeLeft = value
    if GST.mhMode == 2 then
      name = "menu_time"
      local seconds = timeLeft // 30 % 60
      local minutes = (timeLeft // 1800)
      value = "\\#ffff5a\\" .. string.format("%d:%02d", minutes, seconds)
    elseif GST.starMode then
      value = trans("stars_left", timeLeft)
    else
      local seconds = timeLeft // 30 % 60
      local minutes = (timeLeft // 1800)
      value = trans("time_left", minutes, seconds)
    end
  elseif name == "menu_anarchy" then -- team attack
    if value == 3 then
      value = true
    elseif value == 1 then
      value = "\\#00ffff\\" .. trans("runners")
    elseif value == 2 then
      value = "\\#ff5a5a\\" .. trans("hunters")
    else
      value = false
    end
  elseif name == "menu_category" then -- category
    if GST.mhMode ~= 2 then
      local numVal = value
      if value == -1 then
        value = "\\#5aff5a\\Any%"
      else
        value = "\\#ffff5a\\" .. value .. " Star"
      end
      if GST.noBowser and numVal > 0 then
        value = value .. "\\#ff5a5a\\" .. " (No Bowser)"
      end
    else
      value = nil
    end
  elseif name == "menu_defeat_bowser" then
    local bad = ROMHACK["badGuy_" .. lang] or ROMHACK.badGuy or "Bowser"
    name = trans(name, bad)
    value = not value
  elseif (name == "menu_campaign") then -- minihunt campaign
    if GST.mhMode == 2 then
      if value == 0 then value = false end
    else
      value = nil
    end
  elseif name == "menu_first_timer" then -- leader death timer
    if GST.mhMode ~= 2 then
      value = nil
    end
  elseif name == "menu_dmgAdd" then
    if value == 8 then
      value = "\\#ff5a5a\\OHKO"
    end
  elseif name == "menu_allow_stalk" then
    if GST.mhMode == 2 then
      value = nil
    end
  end

  if value == true then
    value = trans("on")
  elseif value == false then
    value = trans("off")
  elseif tonumber(value) then
    value = "\\#ffff5a\\" .. value
  end

  return name, value
end

-- camp timer + other stuff
function before_mario_update(m, inSelect)
  -- funny new vanish cap code
  if GST.nerfVanish then
    if m.playerIndex == 0 then
      if m.capTimer <= 1 then
        storeVanish = false
      elseif storeVanish == false and m.flags & MARIO_VANISH_CAP ~= 0 then
        storeVanish = true
        m.flags = m.flags & ~MARIO_VANISH_CAP
        popup_sound(SOUND_GENERAL2_RIGHT_ANSWER)
        djui_popup_create(trans("vanish_custom"), 1)
      elseif storeVanish and (m.controller.buttonDown & B_BUTTON) ~= 0 then
        m.flags = m.flags | MARIO_VANISH_CAP
        m.capTimer = m.capTimer - 2
        if m.capTimer < 1 then m.capTimer = 1 end
      else
        m.flags = m.flags & ~MARIO_VANISH_CAP
      end
    elseif m.flags & MARIO_VANISH_CAP ~= 0 and (m.controller.buttonDown & B_BUTTON) == 0 then
      m.flags = m.flags & ~MARIO_VANISH_CAP
    end
  end

  if m.playerIndex ~= 0 then return end

  -- prevent oob in ssl area 3 (grounds is weird)
  if m.floor == nil and np0.currLevelNum == LEVEL_SSL and np0.currAreaIndex == 3 then
    print("correcting oob")
    m.pos.x = 0
    m.pos.y = 0
    m.pos.z = -2000
  end

  if sMario0.team == 1 then
    if m.freeze == true or (m.freeze ~= false and m.freeze > 2) then
      if campTimer == nil then
        campTimer = 600  -- 20 seconds
      end
      m.invincTimer = 60 -- 2 seconds
    elseif campTimer == nil and inSelect then
      campTimer = 300    -- 10 seconds
    end
  end
  if campTimer ~= nil and not sMario0.pause then
    campTimer = campTimer - 1
    if campTimer % 30 == 0 then
      play_sound(SOUND_MENU_CAMERA_BUZZ, m.marioObj.header.gfx.cameraToObject)
    end
    if campTimer <= 0 then
      campTimer = -1
      if not inSelect then
        m.controller.buttonPressed = m.controller.buttonPressed | A_BUTTON -- mash a to get out of menu
      else
        campTimer = nil
        sMario0.runnerLives = 0
        died = false
        on_death(m, true)
      end
      return
    end
  end
end

function show_rules()
  -- how to play message
  if GST.mhMode ~= 2 then
    if month == 13 or math.random(1, 100) == 1 then
      djui_chat_message_create(trans("welcome_egg"))
    else
      djui_chat_message_create(trans("welcome"))
    end
  else
    djui_chat_message_create(trans("welcome_mini"))
  end

  local runners = trans("runners")
  local hunters = trans("hunters")

  local extraRun = ""
  if GST.mhState ~= 0 and GST.mhState < 3 then
    if sMario0.team ~= 1 then
      extraRun = " " .. trans("shown_above")
    else
      extraRun = " " .. trans("thats_you")
    end
  end
  local runGoal = ""
  if GST.mhMode == 2 then
    runGoal = trans("mini_collect")
  elseif (GST.starRun) == -1 then
    local bad = ROMHACK["badGuy_" .. lang] or ROMHACK.badGuy or "Bowser"
    runGoal = trans("any_bowser", bad)
  elseif GST.noBowser ~= true then
    local bad = ROMHACK["badGuy_" .. lang] or ROMHACK.badGuy or "Bowser"
    runGoal = trans("collect_bowser", GST.starRun, bad)
  else
    runGoal = trans("collect_only", GST.starRun)
  end

  local extraHunt = ""
  if GST.mhState ~= 0 and GST.mhState < 3 and sMario0.team ~= 1 then
    extraHunt = " " .. trans("thats_you")
  end
  local huntGoal = ""
  if GST.mhMode == 0 then
    huntGoal = trans("all_runners")
  else
    huntGoal = trans("any_runners")
  end

  local runLives = trans_plural("lives", (GST.runnerLives + 1))
  local needed = ""
  if GST.mhMode == 2 then
    -- nothing
  elseif (GST.starMode) then
    needed = "; " .. trans("stars_needed", GST.runTime)
  else
    local seconds = GST.runTime // 30 % 60
    local minutes = GST.runTime // 1800
    needed = "; " .. trans("time_needed", minutes, seconds)
  end
  local becomeHunter = ""
  local becomeRunner = ""
  if GST.mhMode == 0 then
    becomeHunter = "; " .. trans("become_hunter")
  else
    becomeRunner = "; " .. trans("become_runner")
  end

  local spectate = ""
  if GST.allowSpectate == true then
    spectate = "; " .. trans("spectate")
  end
  local banned = ""
  if (GST.starRun) ~= -1 then
    banned = trans("banned_glitchless")
  else
    banned = trans("banned_general")
  end

  local fun = trans("fun")
  if GST.mhMode == 2 then
    fun = trans("mini_goal", GST.runTime // 1800, (GST.runTime % 1800) // 30) .. " " .. fun
  end

  local text = string.format("\\#00ffff\\%s\\#ffffff\\%s: %s" ..
    "\n\\#ff5a5a\\%s\\#ffffff\\%s: %s" ..
    "\n\\#00ffff\\%s\\#ffffff\\: %s%s%s." ..
    "\n\\#ff5a5a\\%s\\#ffffff\\: %s%s%s." ..
    "\n%s\n%s",
    runners,
    extraRun,
    runGoal,
    hunters,
    extraHunt,
    huntGoal,
    runners,
    runLives,
    needed,
    becomeHunter,
    hunters,
    trans("infinite_lives"),
    becomeRunner,
    spectate,
    banned,
    fun
  )
  djui_chat_message_create(text)
end

function rule_command()
  show_rules()
  return true
end

hook_chat_command("rules", trans("rules_desc"), rule_command)

-- from hide and seek
function on_hud_render()
  -- render to N64 screen space, with the NORMAL font
  djui_hud_set_render_behind_hud(false)
  djui_hud_set_resolution(RESOLUTION_N64)
  djui_hud_set_font(FONT_NORMAL)

  if not didFirstJoinStuff then return end

  -- stats hud
  if showingStats then
    hide_both_hud(true)
    do_star_stuff(false)
    return stats_table_hud()
  elseif menu or mhHideHud then -- Blocky's menu
    hide_both_hud(true)
    do_star_stuff(false)
    return handleMenu()
  elseif sMario0.spectator == 1 then
    hide_both_hud(true)
  else
    hide_both_hud(false)
  end

  local text = ""
  -- yay long if statement
  if GST.mhState == 1 then -- game start timer
    text = timer_hud()
  elseif tonumber(sMario0.pause) then
    text = timer_hud(sMario0)
  elseif GST.mhState == 0 then
    text = unstarted_hud(sMario0)
  elseif campTimer ~= nil then                        -- camp timer has top priority
    text = camp_hud(sMario0)
  elseif GST.mhState ~= nil and GST.mhState >= 3 then -- game end
    text = victory_hud()
  elseif sMario0.team == 1 then                       -- do runner hud
    text = runner_hud(sMario0)
  else                                                -- do hunter hud
    text = hunter_hud(sMario0)
  end

  -- player radar
  if sMario0.team ~= 1 then
    for i = 0, (MAX_PLAYERS - 1) do
      if PST[i].team == 1 then
        local np = NetP[i]
        if np.connected then
          if (np.currLevelNum == np0.currLevelNum) and (np.currAreaIndex == np0.currAreaIndex) and (np.currActNum == np0.currActNum) then
            local rm = MST[np.localIndex]
            render_radar(rm, icon_radar[i])
          end
        end
      end
    end
  end

  do_star_stuff(true)

  -- work with boxes
  local o = obj_get_first_with_behavior_id(id_bhvExclamationBox)
  while o ~= nil do
    if exclamation_box_valid[o.oBehParams2ndByte] and o.oAction ~= 6 then
      local star = (o.oBehParams >> 24) + 1
      if o.oBehParams2ndByte ~= 8 then
        star = o.oBehParams2ndByte - 8
      end
      if star == 0 then print("ERROR!") end
      if GST.mhMode ~= 2 then
        local file = get_current_save_file_num() - 1
        local course_star_flags = save_file_get_star_flags(file, NetP[0].currCourseNum - 1)
        if course_star_flags & (1 << (star - 1)) == 0 then
          render_radar(o, box_radar[star], true, "box")
        end
      elseif star == GST.getStar then
        render_radar(o, box_radar[star], true, "box")
      end
    end
    o = obj_get_next_with_same_behavior_id(o)
  end

  -- red coins
  o = obj_get_nearest_object_with_behavior_id(m0.marioObj, id_bhvRedCoin)
  if o ~= nil then
    render_radar(o, ex_radar[1], true, "coin")
  end
  -- secrets
  o = obj_get_nearest_object_with_behavior_id(m0.marioObj, id_bhvHiddenStarTrigger)
  if o ~= nil then
    render_radar(o, ex_radar[2], true, "secret")
  end
  -- green demon
  if demonOn then
    o = obj_get_first_with_behavior_id(id_bhvGreenDemon)
    if o then
      render_radar(o, ex_radar[3], true, "demon")
    end
  end

  local scale = 0.5

  -- get width of screen and text
  local screenWidth = djui_hud_get_screen_width()
  local width = djui_hud_measure_text(remove_color(text)) * scale
  if width > screenWidth - 10 then -- shrink to fit
    scale = scale * (screenWidth - 10) / width
    width = screenWidth - 10
  end

  local x = (screenWidth - width) * 0.5
  local y = 0

  djui_hud_set_color(0, 0, 0, 128);
  djui_hud_render_rect(x - 6, y, width + 12, 32 * scale);

  djui_hud_print_text_with_color(text, x, y, scale)

  -- death timer (extreme mode)
  scale = 0.5
  if (sMario0.hard == 2 or (leader and GST.deathTimer)) and sMario0.team == 1 and (GST.mhState == 2) then
    djui_hud_set_font(FONT_HUD)
    djui_hud_set_color(255, 255, 255, 255);

    local seconds = deathTimer // 30
    local screenHeight = djui_hud_get_screen_height()
    text = trans("death_timer")

    -- sorta based on personal star count
    local scale = 1
    local xOffset = -23
    local yOffset = 0
    y = screenHeight - 200
    if not (OmmEnabled and hud_is_hidden()) then
      local raceTimerOn = hud_get_value(HUD_DISPLAY_FLAGS) & HUD_DISPLAY_FLAGS_TIMER
      --djui_chat_message_create(tostring(raceTimerValue))
      if _G.PersonalStarCounter then
        yOffset = 40
      elseif raceTimerOn ~= 0 then
        yOffset = 20
      end
    else -- omm hud is enabled
      yOffset = -25
      xOffset = -60
    end
    width = djui_hud_measure_text(text) * scale
    x = (screenWidth - width)

    if deathTimer <= 180 then
      xOffset = xOffset + math.random(-2, 2)
      yOffset = yOffset + math.random(-2, 2)
    end

    print_text_ex_hud_font(text, x + xOffset, y + yOffset, scale)
    width = djui_hud_measure_text(tostring(seconds)) * scale
    x = (screenWidth - width)
    y = y + 17
    djui_hud_print_text(tostring(seconds), x + xOffset, y + yOffset, scale)

    djui_hud_set_font(FONT_NORMAL)
  end

  -- makes the cap timer appear
  if storeVanish and m0.capTimer ~= 0 then
    if not hud_is_hidden() then
      djui_hud_set_font(FONT_HUD)
      djui_hud_set_color(255, 255, 255, 255);
      text = tostring(m0.capTimer // 30 + 1)
      width = djui_hud_measure_text(text)
      x = (screenWidth - width) * 0.5
      local screenHeight = djui_hud_get_screen_height()
      y = screenHeight - 32
      djui_hud_print_text(text, x, y, 1);
      djui_hud_set_font(FONT_NORMAL)
    end
  end

  -- star name + scoreboard for minihunt
  if GST.mhMode == 2 and GST.mhState == 2 then
    text = get_custom_star_name(level_to_course[GST.gameLevel] or 0, GST.getStar)
    width = djui_hud_measure_text(text) * scale
    local screenHeight = djui_hud_get_screen_height()
    x = (screenWidth - width) * 0.5
    y = screenHeight - 16

    djui_hud_set_color(0, 0, 0, 128);
    djui_hud_render_rect(x - 6, y, width + 12, 32 * scale);

    djui_hud_set_color(255, 255, 255, 255);
    djui_hud_print_text(text, x, y, scale);

    -- render the scoreboard
    --[[scoreboard = {}
    for i=1,16 do
      table.insert(scoreboard, {0, 2})
    end
    table.insert(scoreboard, {0, 1})]]
    if #scoreboard > 0 then
      local place = 0
      local scores = {}
      local maxWidthTable = { 0, 0, 0 }
      local lastScore = 0
      local sameScoreCounter = 1

      for i, scoreTable in ipairs(scoreboard) do
        local index = scoreTable[1]
        local score = scoreTable[2]
        local placeText = ""
        local nameText = ""

        local np = NetP[index]
        if np.connected then
          if score == lastScore then
            sameScoreCounter = sameScoreCounter + 1
          else
            place = place + sameScoreCounter
            sameScoreCounter = 1
            lastScore = score
          end
          local playerColor = network_get_player_text_color_string(np.localIndex)
          nameText = nameText .. playerColor .. np.name
          nameText = cap_color_text(nameText, 16)

          nameText = nameText .. ":  "

          -- Generate place text (ordinal number rules)
          local digit = place % 10
          -- for German, we can skip this whole check because it's just the number
          -- for French, every number other than 1st follows the same pattern
          if lang == "de" or (place > 10 and (place < 20 or lang == "fr")) then
            placeText = trans("place_score", place)
          elseif digit == 1 then
            placeText = trans("place_score_1", place)
          elseif digit == 2 then
            placeText = trans("place_score_2", place)
          elseif digit == 3 then
            placeText = trans("place_score_3", place)
          else
            placeText = trans("place_score", place)
          end

          -- Gold, silver, and bronze
          if place == 1 then
            placeText = "\\#e3bc2d\\" .. placeText .. "\\ffffff\\"
          elseif place == 2 then
            placeText = "\\#c5d8de\\" .. placeText .. "\\ffffff\\"
          elseif place == 3 then
            placeText = "\\#b38752\\" .. placeText .. "\\ffffff\\"
          end

          placeText = placeText .. ": "

          local scoreText = tostring(score)
          if index == 0 then
            scoreText = "\\#ffff5a\\" .. scoreText
          end

          table.insert(scores, { placeText, nameText, scoreText })
          for i, text in ipairs(scores[#scores]) do
            local tWidth = djui_hud_measure_text(remove_color(text))
            if tWidth > maxWidthTable[i] then
              maxWidthTable[i] = tWidth
            end
          end
        end
      end

      scale = 0.25
      x = 5
      y = (screenHeight - 32 * #scores * scale) * 0.5
      if y < 32 then -- shrink to fit
        scale = (screenHeight - 64) / (32 * #scores)
        y = 32
      end
      width = (maxWidthTable[1] + maxWidthTable[2] + maxWidthTable[3]) * scale
      djui_hud_set_color(0, 0, 0, 128);
      djui_hud_render_rect(x - 5, y, width + 10, #scores * 32 * scale);

      for a, textTable in ipairs(scores) do
        for b, text in ipairs(textTable) do
          djui_hud_set_color(255, 255, 255, 255)
          djui_hud_print_text_with_color(text, x, y, scale)
          x = x + maxWidthTable[b] * scale
        end
        y = y + 32 * scale
        x = 5
      end
    end
  elseif showSpeedrunTimer and GST.mhMode ~= 2 then
    local miliseconds = math.floor(GST.speedrunTimer / 30 % 1 * 100)
    local seconds = GST.speedrunTimer // 30 % 60
    local minutes = GST.speedrunTimer // 30 // 60 % 60
    local hours = GST.speedrunTimer // 30 // 60 // 60
    text = string.format("%d:%02d:%02d.%02d", hours, minutes, seconds, miliseconds)
    width = 118 * scale
    local screenHeight = djui_hud_get_screen_height()
    x = (screenWidth - width) * 0.5
    y = screenHeight - 16

    djui_hud_set_color(0, 0, 0, 128);
    djui_hud_render_rect(x - 6, y, width + 12, 32 * scale);

    djui_hud_set_color(255, 255, 255, 255);
    djui_hud_print_text(text, x, y, scale);
  end

  -- timer
  scale = 0.5
  if GST.mhTimer ~= nil and GST.mhTimer > 0 then
    local seconds = GST.mhTimer // 30 % 60
    local minutes = GST.mhTimer // 1800
    text = string.format("%d:%02d", minutes, seconds)
    width = djui_hud_measure_text(text) * scale
    x = 6
    y = 0

    djui_hud_set_color(0, 0, 0, 128);
    djui_hud_render_rect(x - 6, y, width + 12, 16);

    djui_hud_set_color(255, 255, 255, 255);
    djui_hud_print_text(text, x, y, scale);
  end
end

function runner_hud(sMario)
  local text = ""
  if GST.mhMode ~= 2 then
    -- set star text
    local timeLeft, special = get_leave_requirements(sMario)
    if special ~= nil then
      text = special
    elseif timeLeft <= 0 then
      text = trans("can_leave")
    elseif GST.starMode then
      text = trans("stars_left", timeLeft)
    else
      local seconds = timeLeft // 30 % 60
      local minutes = (timeLeft // 1800)
      text = trans("time_left", minutes, seconds)
    end
  else
    return unstarted_hud(sMario)
  end
  return text
end

function hunter_hud(sMario)
  -- set player text
  local default = "\\#00ffff\\" .. trans("runners") .. ": "
  local text = default
  for i = 0, (MAX_PLAYERS - 1) do
    if PST[i].team == 1 then
      local np = NetP[i]
      if np.connected then
        local playerColor = network_get_player_text_color_string(np.localIndex)
        text = text .. playerColor .. np.name .. ", "
      end
    end
  end

  if text == default then
    text = trans("no_runners")
  else
    text = text:sub(1, -3)
  end

  return text
end

function timer_hud(sMario)
  -- set timer text
  local frames = (sMario and sMario.pause) or GST.mhTimer
  local seconds = math.ceil(frames / 30)
  local text = ""
  if not sMario then
    text = trans("until_hunters", seconds)
    if seconds > 10 then
      text = trans("until_runners", (seconds - 10))
    end
  else
    text = trans("frozen", seconds)
  end

  return text
end

function victory_hud()
  -- set win text
  local text = trans("win", "\\#ff5a5a\\" .. trans("hunters"))
  if GST.mhState == 5 then
    text = trans("game_over")
  elseif GST.mhState > 3 then
    text = trans("win", "\\#00ffff\\" .. trans("runners"))
  end
  return text
end

function unstarted_hud(sMario)
  -- display role
  local roleName, colorString = get_role_name_and_color(sMario)
  return colorString .. roleName
end

function camp_hud(sMario)
  return trans("camp_timer", campTimer // 30)
end

-- removes color string
function remove_color(text, get_color)
  local start = text:find("\\")
  local next = 1
  while (next ~= nil) and (start ~= nil) do
    start = text:find("\\")
    if start ~= nil then
      next = text:find("\\", start + 1)
      if next == nil then
        next = text:len() + 1
      end

      if get_color then
        local color = text:sub(start, next)
        local render = text:sub(1, start - 1)
        text = text:sub(next + 1)
        return text, color, render
      else
        text = text:sub(1, start - 1) .. text:sub(next + 1)
      end
    end
  end
  return text
end

-- stops color text at the limit selected
function cap_color_text(text, limit)
  local slash = false
  local capped_text = ""
  local chars = 0
  for i = 1, text:len() do
    local char = text:sub(i, i)
    if char == "\\" then
      slash = not slash
    elseif not slash then
      chars = chars + 1
      if chars > limit then break end
    end
    capped_text = capped_text .. char
  end
  return capped_text
end

-- converts hex string to RGB values
function convert_color(text)
  if text:sub(2, 2) ~= "#" then
    return nil
  end
  text = text:sub(3, -2)
  local rstring = text:sub(1, 2) or "ff"
  local gstring = text:sub(3, 4) or "ff"
  local bstring = text:sub(5, 6) or "ff"
  local astring = text:sub(7, 8) or "ff"
  local r = tonumber("0x" .. rstring) or 255
  local g = tonumber("0x" .. gstring) or 255
  local b = tonumber("0x" .. bstring) or 255
  local a = tonumber("0x" .. astring) or 255
  return r, g, b, a
end

-- prints text on the screen... with color!
function djui_hud_print_text_with_color(text, x, y, scale, alpha)
  djui_hud_set_color(255, 255, 255, alpha or 255)
  local space = 0
  local color = ""
  local render = ""
  text, color, render = remove_color(text, true)
  while render ~= nil do
    local r, g, b, a = convert_color(color)
    djui_hud_print_text(render, x + space, y, scale);
    if r then djui_hud_set_color(r, g, b, alpha or a) end
    space = space + djui_hud_measure_text(render) * scale
    text, color, render = remove_color(text, true)
  end
  djui_hud_print_text(text, x + space, y, scale);
end

-- used in many commands
function get_specified_player(msg)
  local playerID = tonumber(msg)
  if msg == "" then
    playerID = 0
  end

  local np = nil
  if playerID == nil then
    for i = 0, (MAX_PLAYERS - 1) do
      np = NetP[i]
      if remove_color(np.name) == remove_color(msg) then
        playerID = i
        break
      end
    end
    if playerID == nil then
      djui_chat_message_create(trans("no_such_player"))
      return nil
    end
  elseif playerID ~= math.floor(playerID) or playerID < 0 or playerID > (MAX_PLAYERS - 1) then
    djui_chat_message_create(trans("bad_id"))
    return nil
  else
    np = NetP[playerID]
  end
  if not np.connected then
    djui_chat_message_create(trans("no_such_player"))
    return nil
  end

  return playerID, np
end

-- uses custom star names if aplicable
function get_custom_star_name(course, starNum)
  if ROMHACK.starNames ~= nil then
    if GST.ee then
      if ROMHACK.starNames_ee ~= nil and ROMHACK.starNames_ee[course * 10 + starNum] ~= nil then
        return ROMHACK.starNames_ee[course * 10 + starNum]
      end
    elseif ROMHACK.starNames[course * 10 + starNum] ~= nil then
      return ROMHACK.starNames[course * 10 + starNum]
    end
  end
  if ROMHACK.vagueName then
    return ("Star " .. starNum)
  end
  -- fix garbage data
  if course == 0 then
    if starNum < 4 then
      return "Toad Star " .. starNum
    else
      return "Mips Star " .. starNum - 3
    end
  elseif course > 15 then
    return ("Star " .. starNum)
  end
  return get_star_name(course, starNum)
end

-- uses custom level names if applicable
function get_custom_level_name(course, level, area)
  if ROMHACK.levelNames and ROMHACK.levelNames[level * 10 + area] then
    return ROMHACK.levelNames[level * 10 + area]
  elseif ROMHACK.vagueName then
    return ("Course " .. course)
  end
  return get_level_name(course, level, area)
end

-- TroopaParaKoopa's Level Cooldown (and other stuff)
function on_warp()
  parkourTimer = 0
  if sMario0.spectator ~= 1 then
    m0.invincTimer = 150 -- 5 seconds

    if sMario0.team == 1 and GST.mhMode ~= 2 then
      if localPrevCourse ~= np0.currCourseNum then
        sMario0.runTime = 0
        localRunTime = 0
        sMario0.allowLeave = false
        lastObtainable = -1
      end
      neededRunTime, localRunTime = calculate_leave_requirements(sMario0, localRunTime)
    end

    if warpCooldown == 0 then
      warpCount = 0
    elseif warpTree[1] == nil or warpTree[1] ~= (np0.currLevelNum * 10 + np0.currAreaIndex) then
      warpCount = 0
    elseif warpCount >= 3 then
      m0.hurtCounter = m0.hurtCounter + (warpCount * 4)
      djui_popup_create(trans("warp_spam"), 1)
      warpCount = warpCount + 1
    else
      warpCount = warpCount + 1
    end
    warpCooldown = 300 -- 5 seconds
    table.insert(warpTree, (np0.currLevelNum * 10 + np0.currAreaIndex))
    if #warpTree > 2 then table.remove(warpTree, 1) end
  end

  local cname = ROMHACK.levelNames and ROMHACK.levelNames[np0.currLevelNum * 10 + np0.currAreaIndex]
  if cname and np0.currCourseNum ~= 0 then -- replace the name of the course
    local course = np0.currCourseNum
    if course < 16 then                    -- replace act names with.. themselves (there's no replace course function)
      local num = " " .. tostring(course) .. " "
      if course > 9 then num = tostring(course) .. " " end
      smlua_text_utils_course_acts_replace(course, num .. cname:upper(), get_star_name_ascii(course, 1, 1),
        get_star_name_ascii(course, 1, 2), get_star_name_ascii(course, 1, 3), get_star_name_ascii(course, 1, 4),
        get_star_name_ascii(course, 1, 5), get_star_name_ascii(course, 1, 6))
    elseif course ~= 0 then
      smlua_text_utils_secret_star_replace(course, "   " .. cname:upper())
    end
  end

  set_season_lighting(month, np0.currLevelNum)

  if GST.mhState == 0 then -- and background music
    set_lobby_music(month)
    --play_music(0, custom_seq, 1)
  end

  if GST.mhMode ~= 2 and GST.mhState ~= 0 then
    local data = {
      id = PACKET_OTHER_WARP,
      index = np0.globalIndex,
      level = np0.currLevelNum,
      course = np0.currCourseNum,
      area = np0.currAreaIndex,
      act = np0.currActNum,
      prevCourse = localPrevCourse,
    }

    if on_packet_other_warp(data, true) then
      network_send(false, data)
    end
  end
  localPrevCourse = np0.currCourseNum
end

-- set lighting
function set_season_lighting(month, level)
  if noSeason or (month ~= 10 and month ~= 12) then
    if level == LEVEL_LOBBY then
      set_lighting_dir(2, 300) -- dark?
    else
      set_lighting_dir(2, 0)
    end
    set_override_skybox(-1)
    set_lighting_color(0, 255)
    set_lighting_color(1, 255)
    set_override_envfx(-1)
  elseif month == 10 then
    set_override_skybox(BACKGROUND_HAUNTED)
    set_lighting_dir(2, 500)   -- dark?
    set_lighting_color(1, 100) -- purple tint
    set_lighting_color(0, 100)
  elseif month == 12 then
    set_override_skybox(BACKGROUND_SNOW_MOUNTAINS)
    set_lighting_dir(2, 0)
    set_lighting_color(0, 200) -- blue tint
    set_override_envfx(ENVFX_SNOW_NORMAL)
  end
end

function on_player_disconnected(m)
  local np = NetP[m.playerIndex]
  -- unassign attack
  if np.globalIndex == attackedBy then attackedBy = nil end


  -- for host only
  if network_is_server() then -- rejoin handling
    local sMario = PST[m.playerIndex]
    sMario.wins, sMario.kills, sMario.maxStreak, sMario.hardWins, sMario.maxStar, sMario.exWins, sMario.beenRunner = 0, 0,
        0, 0, 0, 0,
        0 -- unassign stats

    local runner = (sMario.team == 1)
    local discordID = sMario.discordID or 0
    sMario.discordID = 0
    sMario.placement = 999
    sMario.fasterActions = true
    if runner or GST.mhMode == 2 then
      local grantRunner = (sMario.team == 1 and GST.mhMode ~= 2)
      local runtime = sMario.runTime or 0
      local lives = sMario.runnerLives or GST.runnerLives

      print(tostring(discordID), "left")

      become_hunter(sMario) -- be hunter by default
      if discordID ~= 0 then
        local playerColor = network_get_player_text_color_string(np.localIndex)
        local name = playerColor .. np.name
        rejoin_timer[discordID] = {
          name = name,
          timer = 3600,
          runner = grantRunner,
          lives = lives,
          stars = sMario
              .totalStars
        } -- 2 minutes
        global_popup_lang("rejoin_start", name, nil, 1)
      end
      if runner and GST.mhMode ~= 0 and (discordID == 0 or GST.mhMode == 2) then
        local newID = new_runner(true)
        if newID ~= nil then
          network_send_include_self(true, {
            id = PACKET_KILL,
            newRunnerID = newID,
            time = runtime or 0,
          })
        end
      end
    end
  end
end

-- create the Green Demon object (built from 1up, obviously)
E_MODEL_DEMON = smlua_model_util_get_id("demon_geo") or E_MODEL_1UP
--- @param o Object
function demon_init(o)
  o.oFlags = o.oFlags | OBJ_FLAG_COMPUTE_ANGLE_TO_MARIO | OBJ_FLAG_UPDATE_GFX_POS_AND_ANGLE
  obj_set_billboard(o)

  cur_obj_set_hitbox_radius_and_height(30, 30)
  o.oGraphYOffset = 30
  bhv_1up_common_init()
end

--- @param o Object
function demon_loop(o)
  o.oIntangibleTimer = 0

  if o.oAction == 1 then
    local demonStop = (m0.invincTimer > 0)
    local demonDespawn = ((not demonOn) or sMario0.team ~= 1 or GST.mhState ~= 2)
    demon_move_towards_mario(o)
    if demonDespawn then
      o.activeFlags = ACTIVE_FLAG_DEACTIVATED
    elseif demonStop then
      -- nothing
    elseif dist_between_objects(o, m0.marioObj) > 5000 then -- clip at far distances
      o.oVelX = o.oForwardVel * sins(o.oMoveAngleYaw);
      o.oVelZ = o.oForwardVel * coss(o.oMoveAngleYaw);
      obj_update_pos_vel_xz()
      o.oPosY = o.oPosY + o.oVelY
    else
      object_step()
    end
  else
    bhv_1up_hidden_in_pole_loop()
  end
end

--- @param o Object
function demon_move_towards_mario(o)
  local player = m0.marioObj
  if (player) then
    local sp34 = player.header.gfx.pos.x - o.oPosX;
    local sp30 = player.header.gfx.pos.y + 120 - o.oPosY;
    local sp2C = player.header.gfx.pos.z - o.oPosZ;
    local sp2A = atan2s(math.sqrt(sqr(sp34) + sqr(sp2C)), sp30);

    obj_turn_toward_object(o, player, 16, 0x1000);
    o.oMoveAnglePitch = approach_s16_symmetric(o.oMoveAnglePitch, sp2A, 0x1000);

    if obj_check_if_collided_with_object(o, player) == 1 then
      play_sound(SOUND_GENERAL_COLLECT_1UP, player.header.gfx.cameraToObject) -- replace?
      o.activeFlags = ACTIVE_FLAG_DEACTIVATED
      m0.health = 0xFF                                                        -- die
    end
  end
  local vel = 30
  if m0.waterLevel >= m0.pos.y then
    vel = 15 -- half speed if mario is underwater
  end
  o.oVelY = sins(o.oMoveAnglePitch) * vel
  o.oForwardVel = coss(o.oMoveAnglePitch) * vel
end

id_bhvGreenDemon = hook_behavior(nil, OBJ_LIST_LEVEL, false, demon_init, demon_loop)

-- speed up these actions (troopa)
local faster_actions = {
  [ACT_GROUND_BONK] = true,
  [ACT_SPECIAL_DEATH_EXIT] = true,
  [ACT_FORWARD_GROUND_KB] = true,
  [ACT_BACKWARD_GROUND_KB] = true,
  [ACT_BACKFLIP_LAND] = true,
  [ACT_TRIPLE_JUMP_LAND] = true,
  [ACT_STAR_DANCE_EXIT] = true,
  [ACT_STAR_DANCE_WATER] = true,
  [ACT_STAR_DANCE_NO_EXIT] = true,
  [ACT_DIVE_PICKING_UP] = true,
  [ACT_PICKING_UP] = true,
  [ACT_PICKING_UP_BOWSER] = true,
  [ACT_HARD_FORWARD_GROUND_KB] = true,
  [ACT_SOFT_FORWARD_GROUND_KB] = true,
  [ACT_HARD_BACKWARD_GROUND_KB] = true,
  [ACT_SOFT_BACKWARD_GROUND_KB] = true,
  [ACT_ENTERING_STAR_DOOR] = true,
  [ACT_PUSHING_DOOR] = true,
  [ACT_PULLING_DOOR] = true,
  [ACT_UNLOCKING_STAR_DOOR] = true,
  [ACT_BACKWARD_WATER_KB] = true,
  [ACT_FORWARD_WATER_KB] = true,
  [ACT_RELEASING_BOWSER] = true,
  [ACT_HEAVY_THROW] = true,
  [ACT_BUTT_STUCK_IN_GROUND] = true,
  [ACT_FEET_STUCK_IN_GROUND] = true,
  [ACT_HEAD_STUCK_IN_GROUND] = true,
}

-- based off of example
---@param m MarioState
function mario_update(m)
  if not didFirstJoinStuff then return end

  local sMario = PST[m.playerIndex]
  local np = NetP[m.playerIndex]

  -- for b3313; prevents quick travel
  if ROMHACK and ROMHACK.name == "B3313" then
    if is_game_paused() and m.controller.buttonPressed & Y_BUTTON ~= 0 then
      if on_pause_exit(true) == false then
        m.controller.buttonPressed = m.controller.buttonPressed & ~Y_BUTTON
        play_sound(SOUND_MENU_CAMERA_BUZZ, m.marioObj.header.gfx.cameraToObject)
      end
    end
  end

  -- fast actions by troopa
  if faster_actions[m.action] and sMario.fasterActions then
    m.marioObj.header.gfx.animInfo.animFrame = m.marioObj.header.gfx.animInfo.animFrame + 1
  elseif m.action == ACT_UNLOCKING_KEY_DOOR then                                                                       -- nobody wants you we want a dancing floating key (edit) we dont have dancing key anymore
    set_anim_to_frame(m, m.marioObj.header.gfx.animInfo.curAnim.loopEnd)
  elseif m.action == ACT_WARP_DOOR_SPAWN then                                                                          -- the real (torpa)
    set_mario_action(m, ACT_IDLE, 0)
  elseif (m.action == ACT_SPAWN_NO_SPIN_AIRBORNE or m.action == ACT_SPAWN_SPIN_AIRBORNE) and sMario.fasterActions then -- dawg wtf??!?!? (torpa again)
    if m.floor and m.floor.type ~= SURFACE_DEATH_PLANE and m.floor.type ~= SURFACE_VERTICAL_WIND then
      m.pos.y = math.max(m.waterLevel, m.floorHeight)+100 -- go to floor to prevent fall damage
      set_mario_action(m, ACT_IDLE, 0)
    else
      set_mario_action(m, ACT_TRIPLE_JUMP, 0) -- if we spawn in the void, do a triple jump (prevents softlock with omm + ztar attack 2)
    end
  end

  -- force spectate
  if m.playerIndex == 0 and sMario.spectator ~= 1 and sMario.forceSpectate
      and sMario.team ~= 1 and GST.allowSpectate then
    spectate_command("runner")
  end

  if m.cap ~= 0 then m.cap = 0 end -- return cap

  -- handle unlocking Green Demon mode
  if (not demonUnlocked) and m.playerIndex == 0 then
    local demon = obj_get_nearest_object_with_behavior_id(m.marioObj, id_bhvHidden1upInPole)
    if demon and nearest_player_to_object(demon) == m.marioObj and demon.oAction ~= 0 then
      demonTimer = demonTimer + 1
      if demonTimer > 300 then
        demonUnlocked = true
        mod_storage_save("demon_unlocked", "true")
        djui_popup_create(trans("demon_unlock"), 1)
      end
    else
      demonTimer = 0
    end
  end

  -- set and decrement regain cap timer
  if m.playerIndex == 0 then
    if m.capTimer > 0 then
      cooldownCaps = m.flags & MARIO_SPECIAL_CAPS
      if storeVanish then cooldownCaps = cooldownCaps | MARIO_VANISH_CAP end
      regainCapTimer = 60
    elseif regainCapTimer > 0 then
      regainCapTimer = regainCapTimer - 1
    end
  end

  -- spawn 1up if it does not exist
  if m.playerIndex == 0 and demonOn then
    local demonOkay = (sMario.team == 1 and m.health > 0xFF and m.invincTimer <= 0 and GST.mhState == 2)
    local o = obj_get_first_with_behavior_id(id_bhvGreenDemon)

    if (not o) and demonOkay then
      spawn_non_sync_object(
        id_bhvGreenDemon,
        E_MODEL_DEMON,
        m.pos.x, m.pos.y, m.pos.z,
        nil)
    end
  end

  -- run death if health is 0, or reset death status
  if m.health <= 0xFF then
    on_death(m, true)
  elseif m.playerIndex == 0 then
    if died and m.invincTimer < 100 then m.invincTimer = 100 end -- start invincibility

    died = false

    -- match life counter to actual lives
    if sMario.team == 1 and m.numLives ~= sMario.runnerLives and sMario.runnerLives ~= nil then
      m.numLives = sMario.runnerLives
    end
  end

  -- update star counter in MiniHunt mode
  if GST.mhMode == 2 then
    m.numStars = sMario.totalStars or 0
    m.prevNumStarsForDialog = m.numStars
  end

  -- cut invincibility frames
  if GST.weak and m.invincTimer > 0 then
    m.invincTimer = m.invincTimer - 1
  end

  -- handle rejoining
  if rejoin_timer ~= nil and m.playerIndex ~= 0 and np.connected then
    local discordID = sMario.discordID or 0
    if discordID ~= 0 and rejoin_timer[discordID] ~= nil then
      -- become runner again
      local data = rejoin_timer[discordID]
      if data.runner then
        become_runner(sMario)
        sMario.runnerLives = data.lives
      end
      sMario.totalStars = data.stars or 0
      leader, scoreboard = calculate_placement()
      global_popup_lang("rejoin_success", data.name, nil, 1)
      rejoin_timer[discordID] = nil
    end
  end

  if (not noSeason) and month == 13 then np.overrideModelIndex = CT_LUIGI end -- april fools

  -- parkour stuff
  if np.currLevelNum == LEVEL_LOBBY and m.playerIndex == 0 then
    local dflags = hud_get_value(HUD_DISPLAY_FLAGS)
    local raceTimerOn = dflags & HUD_DISPLAY_FLAGS_TIMER
    if raceTimerOn ~= 0 then
      parkourTimer = parkourTimer + 1
      m.invincTimer = 2                                     -- prevent interaction
      hud_set_value(HUD_DISPLAY_TIMER, parkourTimer)
      if m.floor and m.floor.type == SURFACE_TIMER_END then -- finish
        local time = parkourTimer
        local miliseconds = math.floor(time / 30 % 1 * 100)
        local seconds = time // 30 % 60
        local minutes = time // 30 // 60 % 60
        local text = string.format("%02d:%02d.%02d", minutes, seconds, miliseconds)
        hud_set_value(HUD_DISPLAY_FLAGS, dflags & ~HUD_DISPLAY_FLAGS_TIMER)
        djui_chat_message_create(text)

        local ref = "parkourRecord"
        if OmmEnabled then ref = "pRecordOmm" end
        local record = mod_storage_load(ref)

        if (not record) and OmmEnabled then
          record = mod_storage_load("parkourRecordOmm")
        end

        if tonumber(record) == nil or tonumber(record) > time then
          play_star_fanfare()
          djui_chat_message_create(trans("new_record"))
          mod_storage_save(ref, tostring(time))
        else
          play_race_fanfare()
        end
      elseif m.pos.y < 200 and m.floor and m.floor.type ~= SURFACE_HARD and m.pos.y == m.floorHeight then
        parkourTimer = 0
        hud_set_value(HUD_DISPLAY_FLAGS, dflags & ~HUD_DISPLAY_FLAGS_TIMER)
        hud_set_value(HUD_DISPLAY_TIMER, 0)
      end
    elseif m.floor and m.floor.type == SURFACE_HARD then -- back on starting platform
      parkourTimer = 0
      hud_set_value(HUD_DISPLAY_FLAGS, dflags | HUD_DISPLAY_FLAGS_TIMER)
      if m.pos.y > 2000 then
        m.pos.y = m.floorHeight
      end
    elseif m.floorHeight > 200 and raceTimerOn == 0 and parkourTimer == 0 then -- prevent cheese by jumping over starting platform (omm)
      m.pos.x, m.pos.y, m.pos.z = -12, 63, -2476
    end

    if m.invincTimer > 2 then m.invincTimer = 2 end -- prevent flashing
    if m.pos.y < -1500 then                         -- falling effect like in mk wii
      set_mario_particle_flags(m, ACTIVE_PARTICLE_FIRE, 0)
    end
  end

  -- display as paused
  if sMario.pause and not mhHideHud then -- I need this for screenshots!
    m.marioBodyState.modelState = MODEL_STATE_NOISE_ALPHA
    m.invincTimer = 60
  end
  -- display metal particles
  if (m.flags & MARIO_METAL_CAP) ~= 0 then
    set_mario_particle_flags(m, PARTICLE_SPARKLES, 0)
  end

  if ROMHACK.special_run ~= nil then
    ROMHACK.special_run(m, gotStar)
  end

  -- set descriptions
  local rolename, _, color = get_role_name_and_color(sMario)
  if GST.mhMode == 2 and frameCounter > 60 then
    network_player_set_description(np, trans_plural("stars", sMario.totalStars or 0), color.r, color.g, color.b, 255)
  elseif sMario.team == 1 then
    if frameCounter > 60 then
      network_player_set_description(np, rolename, color.r, color.g, color.b, 255)
    else
      -- fix stupid desync bug
      if sMario.runnerLives == nil then
        sMario.runnerLives = GST.runnerLives
      elseif sMario.runnerLives < 0 then
        sMario.team = 0
      end
      network_player_set_description(np, trans_plural("lives", sMario.runnerLives), color.r, color.g, color.b, 255)
    end
  else
    network_player_set_description(np, rolename, color.r, color.g, color.b, 255)
  end

  -- keep player in certain levels
  if sMario.spectator ~= 1 then
    local correctAct = GST.getStar
    if correctAct == 7 then correctAct = 6 end
    if np.currCourseNum == 0 then correctAct = 0 end
    if didFirstJoinStuff and ROMHACK ~= nil and m.playerIndex == 0 and GST.mhState == 0 and np.currLevelNum ~= (((not ROMHACK.noLobby) and LEVEL_LOBBY) or gLevelValues.entryLevel) then
      warp_beginning()
    elseif m.playerIndex == 0 and GST.mhState == 2 and GST.mhMode == 2 and (np.currLevelNum ~= GST.gameLevel or np.currActNum ~= correctAct) then
      m.health = 0x880
      warp_beginning()
    end
  end

  -- if the game is inactive, disable the camp timer
  if GST.mhState ~= nil and (GST.mhState == 0 or GST.mhState >= 3) then
    campTimer = nil
    return
  end

  -- for all players: disable endless stairs if there's enough stars
  local surface = m.floor
  if GST.starRun ~= -1 and surface ~= nil and surface.type == 27 and m.numStars >= GST.starRun then
    surface.type = 0
    m.floor = surface
  end

  -- enforce star requirements
  if sMario.spectator ~= 1 and m.playerIndex == 0 and GST.starRun ~= -1 and ROMHACK.requirements ~= nil and GST.mhMode ~= 2 then
    local requirements = ROMHACK.requirements[np.currLevelNum] or 0
    if requirements >= GST.starRun then
      requirements = GST.starRun
      if ROMHACK.ddd and (np.currLevelNum == LEVEL_BITDW or np.currLevelNum == LEVEL_DDD) then
        requirements = requirements - 1
      end
    end
    if m.numStars < requirements then
      warp_beginning()
    end
  end

  -- Rename stars in OMM (I'm trying my best to correct desync issues)
  if OmmEnabled and m.playerIndex == 0 and ommStarID then
    if (m.action == ACT_OMM_STAR_DANCE and m.actionTimer == 35) then
      network_send(true, {
        id = PACKET_OMM_STAR_RENAME,
        act = ommStar,
        course = np.currCourseNum,
        obj_id = ommStarID,
      })
      if ommRenameTimer == 0 then
        local name = get_custom_star_name(np.currCourseNum, ommStar)
        _G.OmmApi.omm_register_star_behavior(ommStarID, name, string.upper(name))
      end
    elseif ommRenameTimer > 0 then
      ommRenameTimer = ommRenameTimer - 1
      if ommRenameTimer == 0 then
        local name = get_custom_star_name(np.currCourseNum, ommStar)
        _G.OmmApi.omm_register_star_behavior(ommStarID, name, string.upper(name))
      end
    end
  end

  -- hunter update
  if sMario.team ~= 1 then return hunter_update(m) end
  -- runner update
  return runner_update(m, sMario)
end

function runner_update(m, sMario)
  -- fix stupid desync bug
  if sMario.runnerLives == nil then
    sMario.runnerLives = GST.runnerLives
  elseif sMario.runnerLives < 0 then
    sMario.team = 0
  end
  local np = NetP[m.playerIndex]

  m.marioBodyState.shadeR = 127
  m.marioBodyState.shadeG = 127
  m.marioBodyState.shadeB = 127

  if m.playerIndex == 0 then
    -- set 'been runner' status
    if sMario.beenRunner == 0 then
      print("Our 'Been Runner' status has been set")
      sMario.beenRunner = 1
      mod_storage_save("beenRunnner", "1")
    end

    -- reduce level timer
    if (not sMario.allowLeave) and GST.mhMode ~= 2 then
      if not (GST.starMode or neededRunTime <= localRunTime) then
        localRunTime = localRunTime + 1
      end

      -- match run time with other runners in level
      if frameCounter % 30 == 0 then -- only every second for less lag maybe
        for i = 1, (MAX_PLAYERS - 1) do
          if PST[i].team == 1 and NetP[i].connected then
            local theirNP = NetP[i] -- daft variable naming conventions
            local theirSMario = PST[i]
            if theirSMario.runTime ~= nil and (theirNP.currLevelNum == np.currLevelNum) and (theirNP.currActNum == np.currActNum) and localRunTime < theirSMario.runTime then
              localRunTime = theirSMario.runTime
              neededRunTime, localRunTime = calculate_leave_requirements(sMario, localRunTime)
            end
          end
        end
        sMario.runTime = localRunTime
      end
    elseif GST.mhMode == 2 and frameCounter % 60 == 0 then -- resend to avoid desync
      GST.gameLevel = GST.gameLevel
      GST.getStar = GST.getStar
    end
  end

  -- invincibility timers for certain actions
  local runner_invincible = {
    [ACT_PICKING_UP_BOWSER] = 90, -- 3 seconds
    [ACT_RELEASING_BOWSER] = 20,
    [ACT_READING_NPC_DIALOG] = 30,
    [ACT_READING_AUTOMATIC_DIALOG] = 30,
    [ACT_READING_SIGN] = 20,
    [ACT_HEAVY_THROW] = 10,
    [ACT_PUTTING_ON_CAP] = 10,
    [ACT_STAR_DANCE_NO_EXIT] = 30, -- 1 second
    [ACT_STAR_DANCE_WATER] = 30,   -- 1 second
    [ACT_WAITING_FOR_DIALOG] = 10,
    [ACT_DEATH_EXIT_LAND] = 10,
    [ACT_SPAWN_SPIN_LANDING] = 100,
    [ACT_SPAWN_NO_SPIN_LANDING] = 100,
    [ACT_IN_CANNON] = 10,
    [ACT_PICKING_UP] = 10, -- can't differentiate if this is a heavy object

  }
  if ACT_OMM_STAR_DANCE then
    runner_invincible[ACT_OMM_STAR_DANCE] = 40 -- the action is 80 frames long
  end

  local runner_camping = {
    [ACT_READING_NPC_DIALOG] = 1,
    [ACT_READING_AUTOMATIC_DIALOG] = 1,
    [ACT_WAITING_FOR_DIALOG] = 1,
    [ACT_STAR_DANCE_NO_EXIT] = 1,
    [ACT_STAR_DANCE_WATER] = 1,
    [ACT_READING_SIGN] = 1,
    [ACT_IN_CANNON] = 1,
  }

  local newInvincTimer = runner_invincible[m.action]

  if newInvincTimer ~= nil and GST.weak then newInvincTimer = newInvincTimer * 2 end -- same amount in weak mode

  if newInvincTimer ~= nil and m.invincTimer < newInvincTimer then
    m.invincTimer = newInvincTimer
    if m.playerIndex == 0 and campTimer == nil and runner_camping[m.action] ~= nil then
      campTimer = 600 -- 20 seconds
    end
  end
  if m.playerIndex == 0 and runner_camping[m.action] == nil and (m.freeze == false or (m.freeze ~= true and m.freeze < 1)) then
    campTimer = nil
  end

  -- reduces water heal and boosts invincibility frames after getting hit in water
  if (m.action & ACT_FLAG_SWIMMING) ~= 0 and m.healCounter <= 0 and m.hurtCounter <= 0 then
    if m.pos.y >= m.waterLevel - 140 and (m.area.terrainType & TERRAIN_MASK) ~= TERRAIN_SNOW then
      -- water heal is 26 (decimal) per frame
      m.health = m.health - 22
      if (sMario.hard ~= 0) then m.health = m.health - 4 end -- no water heal in hard mode
    elseif m.prevAction == ACT_FORWARD_WATER_KB or m.prevAction == ACT_BACKWARD_WATER_KB then
      m.invincTimer = 60                                     -- 2 seconds
      m.prevAction = m.action
    elseif (sMario.hard ~= 0) and frameCounter % 2 == 0 then -- half speed drowning
      m.health = m.health + 1                                -- water drain is 1 (decimal) per frame
    end
  end

  -- hard mode
  if (sMario.hard == 1) and m.health > 0x400 then
    m.health = 0x400
    if m.playerIndex == 0 then deathTimer = 900 end
  elseif (sMario.hard == 2) or (leader and GST.firstTimer) then -- extreme mode
    if (sMario.hard == 2) then
      if m.health > 0xFF and ((m.hurtCounter <= 0 and m.action ~= ACT_BURNING_FALL and m.action ~= ACT_BURNING_GROUND and m.action ~= ACT_BURNING_JUMP)) then
        m.health = 500
      end
    end
    if m.playerIndex == 0 and deathTimer > 0 then
      if m.healCounter > 0 and m.health > 0xFF and deathTimer <= 1800 then
        deathTimer = deathTimer + 8
        if not OmmEnabled then deathTimer = deathTimer + 8 end -- double gain without OMM
      elseif deathTimer > 1800 then
        deathTimer = 1800
      end

      if not runner_invincible[m.action] then
        deathTimer = deathTimer - 1
        if deathTimer % 30 == 0 and deathTimer <= 330 then
          play_sound(SOUND_GENERAL2_SWITCH_TICK_FAST, m.marioObj.header.gfx.cameraToObject)
        end
      end
    elseif m.playerIndex == 0 and m.health > 0xFF then
      -- explode code
      m.freeze = 60
      local o = spawn_non_sync_object(id_bhvExplosion, E_MODEL_EXPLOSION, m.pos.x, m.pos.y,
        m.pos.z, nil)
      if (m.action & ACT_FLAG_ON_POLE) ~= 0 then -- prevent soft lock
        set_mario_action(m, ACT_STANDING_DEATH, 0)
      else
        take_damage_and_knock_back(m, o)
      end
      m.health = 0xFF
      m.hurtCounter = 0x8
      if m.playerIndex == 0 then deathTimer = 900 end
    end
  elseif m.playerIndex == 0 then
    deathTimer = 900
  end
  if ((sMario.hard and sMario.hard ~= 0) and sMario.runnerLives > 0) then sMario.runnerLives = 0 end

  -- add stars
  if m.playerIndex == 0 and gotStar ~= nil then
    if GST.mhMode == 2 then
      if gotStar == GST.getStar then
        GST.votes = 0
        sMario.totalStars = sMario.totalStars + 1

        -- send message
        network_send_include_self(false, {
          id = PACKET_RUNNER_COLLECT,
          runnerID = np.globalIndex,
          star = gotStar,
          level = np.currLevelNum,
          course = np.currCourseNum,
          area = np.currAreaIndex,
          noSound = (m.action == ACT_OMM_STAR_DANCE),
        })

        if (sMario.hard == 2 or leader) then deathTimer = deathTimer + 300 end

        -- new star for minihunt
        if GST.mhMode == 2 then
          if GST.campaignCourse ~= 0 then
            GST.campaignCourse = GST.campaignCourse + 1
          end
          random_star(np.currCourseNum, GST.campaignCourse)
        end
      end
    else
      if m.prevNumStarsForDialog < m.numStars or ROMHACK.isUnder then
        if GST.starMode then
          localRunTime = localRunTime + 1    -- 1 star
        else
          localRunTime = localRunTime + 1800 -- 1 minute
        end

        -- send message
        local unlocked = (GST.starRun ~= -1 and m.numStars >= GST.starRun and m.prevNumStarsForDialog < GST.starRun)
        network_send_include_self(false, {
          id = PACKET_RUNNER_COLLECT,
          runnerID = np.globalIndex,
          star = gotStar,
          level = np.currLevelNum,
          course = np.currCourseNum,
          area = np.currAreaIndex,
          unlocked = unlocked,
        })
      end
      if sMario.hard == 2 then deathTimer = deathTimer + 300 end

      neededRunTime, localRunTime = calculate_leave_requirements(sMario, localRunTime, gotStar)
    end
  end

  m.prevNumStarsForDialog = m.numStars -- this also disables some dialogue, which helps with the fast pace
  if m.playerIndex == 0 then
    gotStar = nil
  end
end

function hunter_update(m)
  -- infinite lives
  m.numLives = 100

  -- hns hunters become metal cap - troopa
  if hunterAppearance == 1 then
    m.marioBodyState.modelState = m.marioBodyState.modelState | MODEL_STATE_METAL
    m.marioBodyState.shadeR = 127
    m.marioBodyState.shadeG = 127
    m.marioBodyState.shadeB = 127
  elseif hunterAppearance == 2 then -- glow
    local t = math.abs((frameCounter % 30) - 15) / 15
    m.marioBodyState.shadeR = 255
    m.marioBodyState.shadeG = lerp(100, 0, t)
    m.marioBodyState.shadeB = lerp(100, 0, t)
  else
    m.marioBodyState.shadeR = 127
    m.marioBodyState.shadeG = 127
    m.marioBodyState.shadeB = 127
  end

  -- buff underwater punch
  local waterPunchVel = 20
  if OmmEnabled then waterPunchVel = waterPunchVel * 2 end -- omm has fast swim
  if m.forwardVel < waterPunchVel and m.action == ACT_WATER_PUNCH then
    m.forwardVel = waterPunchVel
  end

  -- only local mario at this point
  if m.playerIndex ~= 0 then return end

  deathTimer = 900

  -- camp timer for hunters!?
  if campTimer == nil and m.action == ACT_IN_CANNON then
    campTimer = 600 -- 20 seconds
  elseif m.action ~= ACT_IN_CANNON then
    campTimer = nil
  end

  -- detect victory for hunters (only host to avoid disconnect bugs)
  if network_is_server() then
    -- check for runners
    local stillrunners = false
    for i = 0, (MAX_PLAYERS - 1) do
      if PST[i].team == 1 and NetP[i].connected then
        stillrunners = true
        break
      end
    end

    if stillrunners == false and GST.mhState < 3 and GST.mhMode == 0 then
      for id, data in pairs(rejoin_timer) do
        if data.timer > 0 and data.runner then
          stillrunners = true
          break
        end
      end
      if stillrunners == false then
        network_send_include_self(true, {
          id = PACKET_GAME_END,
          winner = 0,
        })
        rejoin_timer = {}
        GST.mhState = 3
        GST.mhTimer = 20 * 30 -- 20 seconds
      end
    end
  end
end

function before_set_mario_action(m, action)
  local sMario = PST[m.playerIndex]
  if action == ACT_EXIT_LAND_SAVE_DIALOG or action == ACT_DEATH_EXIT_LAND or (action == ACT_HARD_BACKWARD_GROUND_KB and m.action == ACT_SPECIAL_DEATH_EXIT) then
    m.area.camera.cutscene = 0
    play_cutscene(m.area.camera) -- needed to fix toad bug
    set_camera_mode(m.area.camera, m.area.camera.defMode, 1)
    m.forwardVel = 0
    if action == ACT_EXIT_LAND_SAVE_DIALOG then
      m.faceAngle.y = m.faceAngle.y + 0x8000
    end
    return ACT_IDLE
  elseif action == ACT_FALL_AFTER_STAR_GRAB then
    return ACT_STAR_DANCE_WATER
  elseif action == ACT_READING_SIGN and m.invincTimer > 0 then
    return 1
  end
  -- don't do the ending cutscene for hunters
  if action == ACT_JUMBO_STAR_CUTSCENE and sMario.team ~= 1 then
    m.flags = m.flags | MARIO_WING_CAP
    return 1
  end
end

-- disable some interactions
--- @param o Object
function on_allow_interact(m, o, type)
  if m.playerIndex == 0 and type == INTERACT_STAR_OR_KEY and ROMHACK.isUnder then -- star detection is silly
    local obj_id = get_id_from_behavior(o.behavior)
    if (o.oInteractionSubtype & INT_SUBTYPE_GRAND_STAR) == 0 then
      gotStar = (o.oBehParams >> 24) + 1
      ommStar = gotStar
      ommStarID = obj_id
    end
  end

  if type == INTERACT_DOOR and not ROMHACK.isUnder then
    local starsNeeded = (o.oBehParams >> 24) or 0 -- this gets the star count
    if GST.starRun ~= nil and GST.starRun ~= -1 and GST.starRun <= starsNeeded then
      starsNeeded = GST.starRun
      if (np0.currAreaIndex ~= 2) and ROMHACK.ddd == true then
        starsNeeded = starsNeeded - 1
      end
    end

    if m.numStars >= starsNeeded then
      return false
    end
  end

  local sMario = PST[m.playerIndex]
  -- disable for spectators
  if sMario.spectator == 1 then return false end

  -- disable stars and warps during game start or end
  if (type == INTERACT_WARP or type == INTERACT_STAR_OR_KEY or type == INTERACT_WARP_DOOR)
      and GST.mhState ~= nil and (GST.mhState == 0 or GST.mhState >= 3) then
    return false
  end

  -- prevent hunters from interacting with certain things that help or softlock the runner
  local banned_hunter = {
    [id_bhvRedCoin] = 1, -- no!! you cant get the red coins you're helping the runner!!!!!! - troopa
    [id_bhvKingBobomb] = 1,
  }

  local obj_id = get_id_from_behavior(o.behavior)
  --print(get_behavior_name_from_id(obj_id))
  -- cap timer
  if type == INTERACT_CAP and regainCapTimer > 0 then
    if obj_id == id_bhvMetalCap and (cooldownCaps & MARIO_METAL_CAP) ~= 0 then return false end
    if obj_id == id_bhvVanishCap and (cooldownCaps & MARIO_VANISH_CAP) ~= 0 then return false end
  elseif type == INTERACT_STAR_OR_KEY or banned_hunter[obj_id] ~= nil then
    if OmmEnabled and obj_id == id_bhvRedCoin then return true end -- to fix a bug, simply let hunters collect red coins
    return sMario.team == 1
  end
end

-- handle collecting stars
function on_interact(m, o, type, value)
  local obj_id = get_id_from_behavior(o.behavior)
  local sMario = PST[m.playerIndex]
  -- reverted red coins not healing
  --[[if obj_id == id_bhvRedCoin then
    m.healCounter = m.healCounter - 0x8 -- two units
  end
  if m.healCounter < 0 then m.healCounter = 0 end]]

  if type == INTERACT_STAR_OR_KEY then
    if m.playerIndex ~= 0 then return true end -- only local player

    local np = NetP[m.playerIndex]
    if (np.currLevelNum == LEVEL_BOWSER_1 or np.currLevelNum == LEVEL_BOWSER_2) then -- is a key (stars in bowser levels are technically keys)
      sMario.allowLeave = true

      -- don't display message if the door is unlocked (doesn't apply when key is held because the flag gets set before this runs)
      if np.currCourseNum == COURSE_BITDW and ((save_file_get_flags() & (SAVE_FLAG_UNLOCKED_BASEMENT_DOOR)) ~= 0) then
        return 0
      elseif np.currCourseNum == COURSE_BITFS and ((save_file_get_flags() & (SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR)) ~= 0) then
        return 0
      end

      -- send message if we don't already have this key
      network_send_include_self(false, {
        id = PACKET_RUNNER_COLLECT,
        runnerID = np.globalIndex,
        level = np.currLevelNum,
        course = np.currCourseNum,
        area = np.currAreaIndex,
      })
    elseif (o.oInteractionSubtype & INT_SUBTYPE_GRAND_STAR) ~= 0 then -- handle grand star
      -- send message
      network_send_include_self(false, {
        id = PACKET_RUNNER_COLLECT,
        runnerID = np.globalIndex,
        level = np.currLevelNum,
        course = np.currCourseNum,
        area = np.currAreaIndex,
        grand = true
      })
    else
      gotStar = (o.oBehParams >> 24) + 1 -- set what star we got
      ommStar = gotStar
      ommStarID = obj_id
    end
  end
  return true
end

-- hard mode
function hard_mode_command(msg_)
  local msg = msg_ or ""
  local args = split(msg, " ")
  local toggle = args[1] or ""
  local mode = "hard"
  if args[2] ~= nil or string.lower(toggle) == "ex" then
    mode = args[1]
    toggle = args[2] or ""
  end

  if string.lower(toggle) == "on" then
    if string.lower(mode) ~= "ex" then
      sMario0.hard = 1
    else
      sMario0.hard = 2
    end
    play_sound(SOUND_OBJ_BOWSER_LAUGH, m0.marioObj.header.gfx.cameraToObject)
    if string.lower(mode) ~= "ex" then
      djui_chat_message_create(trans("hard_toggle", trans("on")))
    else
      djui_chat_message_create(trans("extreme_toggle", trans("on")))
    end
    if GST.mhState ~= 2 then
      inHard = sMario0.hard
    elseif inHard ~= sMario0.hard then
      inHard = 0
      djui_chat_message_create(trans("no_hard_win"))
    end
  elseif string.lower(toggle) == "off" then
    if sMario0.hard ~= 2 then
      djui_chat_message_create(trans("hard_toggle", trans("off")))
    else
      djui_chat_message_create(trans("extreme_toggle", trans("off")))
    end
    sMario0.hard = 0
    inHard = 0
  else
    if string.lower(mode) ~= "ex" then
      djui_chat_message_create(trans("hard_info"))
    else
      djui_chat_message_create(trans("extreme_info"))
    end
  end
  return true
end

hook_chat_command("hard", trans("hard_desc"), hard_mode_command)

paused = false
function do_pause()
  -- only during timer or pause
  if sMario0.pause
      or (GST.mhState == 1
        and sMario0.spectator ~= 1 and (sMario0.team ~= 1 or GST.mhTimer > 10 * 30)) then -- runners get 10 second head start
    if not paused then
      djui_popup_create(trans("paused"), 1)
      paused = true
    end

    enable_time_stop_including_mario()
    if GST.mhTimer > 0 then
      m0.health = 0x880
    end

    if tonumber(sMario0.pause) then
      sMario0.pause = sMario0.pause - 1
      if sMario0.pause < 1 then
        sMario0.pause = false
      end
    end
  elseif paused then
    djui_popup_create(trans("unpaused"), 1)
    m0.invincTimer = 60 -- 1 second
    paused = false
    disable_time_stop_including_mario()
    print("disabled pause")
  end
end

-- plays local sound unless popup sounds are turned off
function popup_sound(sound)
  if playPopupSounds then
    play_sound(sound, m0.marioObj.header.gfx.cameraToObject)
  end
end

-- chat related stuff
function tc_command(msg)
  if string.lower(msg) == "on" then
    if disable_chat_hook then
      djui_chat_message_create(trans("command_disabled"))
      return true
    end
    sMario0.teamChat = true
    djui_chat_message_create(trans("tc_toggle", trans("on")))
  elseif string.lower(msg) == "off" then
    if disable_chat_hook then
      djui_chat_message_create(trans("command_disabled"))
      return true
    end
    sMario0.teamChat = false
    djui_chat_message_create(trans("tc_toggle", trans("off")))
  else
    send_tc(msg)
  end
  return true
end

function send_tc(msg)
  if _G.mhApi.chatValidFunction ~= nil and (_G.mhApi.chatValidFunction(m0, msg) == false) then
    return false
  end

  local myGlobalIndex = np0.globalIndex
  network_send(false, {
    id = PACKET_TC,
    sender = myGlobalIndex,
    receiverteam = sMario0.team,
    msg = msg,
  })
  djui_chat_message_create(trans("to_team") .. msg)
  play_sound(SOUND_MENU_MESSAGE_DISAPPEAR, m0.marioObj.header.gfx.cameraToObject)

  return true
end

function on_packet_tc(data, self)
  local sender = data.sender
  local receiverteam = data.receiverteam
  local msg = data.msg
  if sMario0.team == receiverteam then
    local np = network_player_from_global_index(sender)
    if np ~= nil then
      local playerColor = network_get_player_text_color_string(np.localIndex)
      djui_chat_message_create(playerColor .. np.name .. trans("from_team") .. msg)
      play_sound(SOUND_MENU_MESSAGE_APPEAR, m0.marioObj.header.gfx.cameraToObject)
    end
  end
end

function on_chat_message(m, msg)
  if disable_chat_hook then return end
  local np = NetP[m.playerIndex]
  local playerColor = network_get_player_text_color_string(m.playerIndex)
  local name = playerColor .. np.name

  if _G.mhApi.chatValidFunction ~= nil and (_G.mhApi.chatValidFunction(m, msg) == false) then
    return false
  elseif _G.mhApi.chatModifyFunction ~= nil then
    local msg_, name_ = _G.mhApi.chatModifyFunction(m, msg)
    if name_ then name = name_ end
    if msg_ then msg = msg_ end
  end

  local sMario = PST[m.playerIndex]
  if sMario.teamChat == true then
    local sMario = PST[m.playerIndex]

    if m.playerIndex == 0 then
      djui_chat_message_create(trans("to_team") .. msg)
      play_sound(SOUND_MENU_MESSAGE_DISAPPEAR, m.marioObj.header.gfx.cameraToObject)
    elseif sMario0.team == sMario.team then
      djui_chat_message_create(playerColor .. np.name .. trans("from_team") .. msg)
      play_sound(SOUND_MENU_MESSAGE_APPEAR, m0.marioObj.header.gfx.cameraToObject)
    end

    return false
  elseif m.playerIndex == 0 then
    local lowerMsg = string.lower(msg)

    local dispRules = string.find(lowerMsg, "como se") -- start of "how do..." I think
        or string.find(lowerMsg, "how do")
        or string.find(lowerMsg, "collect star")
    local dispLang = string.find(lowerMsg, "ingl") -- for spanish speakers asking if this is an english (inglés) server; covers both with and without accent
    local dispSkip = GST.mhMode == 2 and (string.find(lowerMsg, "impossible"))
    local dispFix = m.input & INPUT_OFF_FLOOR == 0 and
        (string.find(lowerMsg, "stuck") or string.find(lowerMsg, "softlock"))
    local dispMenu = string.find(lowerMsg, "menu") -- is this too broad?

    if dispMenu then
      popup_sound(SOUND_GENERAL2_RIGHT_ANSWER)
      djui_popup_create(trans("open_menu"), 1)
    elseif dispLang then
      popup_sound(SOUND_GENERAL2_RIGHT_ANSWER)
      djui_popup_create(trans("to_switch", "ES", nil, "es"), 1)
    elseif dispSkip then
      popup_sound(SOUND_GENERAL2_RIGHT_ANSWER)
      djui_popup_create(trans("vote_info"), 1)
    elseif dispFix then
      force_idle_state(m)
      reset_camera(m.area.camera)
      m.marioObj.header.gfx.node.flags = m.marioObj.header.gfx.node.flags & ~GRAPH_RENDER_INVISIBLE
      popup_sound(SOUND_GENERAL2_RIGHT_ANSWER)
      djui_popup_create(trans("unstuck"), 1)
    elseif dispRules then
      popup_sound(SOUND_GENERAL2_RIGHT_ANSWER)
      djui_popup_create(trans("rule_command"), 1)
    end
  end
  if network_is_server() then
    local desync = string.find(msg:lower(), "desync")
    if desync then
      popup_sound(SOUND_GENERAL2_RIGHT_ANSWER)
      djui_popup_create(trans("unstuck"), 1)
      desync_fix_command()
    end
  end
  local tag = get_tag(m.playerIndex)
  if tag and tag ~= "" then
    djui_chat_message_create(name .. " " .. tag .. ": \\#dcdcdc\\" .. msg)

    if m.playerIndex == 0 then
      play_sound(SOUND_MENU_MESSAGE_DISAPPEAR, m.marioObj.header.gfx.cameraToObject)
    else
      play_sound(SOUND_MENU_MESSAGE_APPEAR, m0.marioObj.header.gfx.cameraToObject)
    end
    return false
  end
end

hook_chat_command("tc", trans("tc_desc"), tc_command)
hook_event(HOOK_ON_CHAT_MESSAGE, on_chat_message)

-- stats
function stats_command(msg)
  if not is_game_paused() then
    showingStats = not showingStats
  end
  return true
end

hook_chat_command("stats", trans("stats_desc"), stats_command)

demonOn = false
demonUnlocked = mod_storage_load("demon_unlocked") or false
demonTimer = 0

-- chat popup sound setting
playPopupSounds = true
if mod_storage_load("playPopupSounds") == "false" then playPopupSounds = false end

function show_timer(msg)
  if string.lower(msg) == "on" then
    showSpeedrunTimer = true
    mod_storage_save("showSpeedrunTimer", "true")
    return true
  elseif string.lower(msg) == "off" then
    showSpeedrunTimer = false
    mod_storage_save("showSpeedrunTimer", "false")
    return true
  end
  return false
end

hook_chat_command("timer", trans("menu_timer_desc"), show_timer)

function stalk_command(msg, noFeedback)
  if GST.mhMode == 2 then
    if not noFeedback then djui_chat_message_create(trans("wrong_mode")) end
    return true
  elseif not (GST.allowStalk) then
    if not noFeedback then djui_chat_message_create(trans("command_disabled")) end
    return true
  elseif GST.mhState ~= 2 then
    if not noFeedback then djui_chat_message_create(trans("not_started")) end
    return true
  elseif on_pause_exit() == false then
    if (not noFeedback) then
      if sMario0.team == 1 and get_leave_requirements(sMario0) > 0 then
        djui_chat_message_create(runner_hud(sMario0))
      end
      play_sound(SOUND_MENU_CAMERA_BUZZ, m0.marioObj.header.gfx.cameraToObject)
    end
    return true
  end

  local playerID, np
  if msg == "" then
    for i = 1, (MAX_PLAYERS - 1) do
      local sMario = PST[i]
      if sMario.team == 1 then
        playerID = i
        np = NetP[i]
        break
      end
    end
    if playerID == nil then
      if not noFeedback then djui_chat_message_create(trans("no_runners")) end
      return true
    end
  else
    playerID, np = get_specified_player(msg)
  end

  if playerID == 0 then
    return false
  elseif playerID == nil then
    return true
  end

  local sMario = PST[playerID]
  if sMario.team ~= 1 then
    local name = remove_color(np.name)
    djui_chat_message_create(trans("not_runner", name))
    return true
  end

  local level = np.currLevelNum
  -- prevent warping to boss arenas (unless this is b3313 which is silly and weird)
  if gGlobalSyncTable.romhackFile ~= "B3313" then
    if level == LEVEL_BOWSER_1 then
      level = LEVEL_BITDW
    elseif level == LEVEL_BOWSER_2 then
      level = LEVEL_BITFS
    elseif level == LEVEL_BOWSER_3 then
      level = LEVEL_BITS
    end
  end
  if obj_get_first_with_behavior_id(id_bhvActSelector) == nil and ((np.currLevelNum ~= np0.currLevelNum and level ~= np0.currLevelNum) or np.currAreaIndex ~= np0.currAreaIndex or np.currActNum ~= np0.currActNum) then
    local success = warp_to_level(level, np.currAreaIndex, np.currActNum) or warp_to_level(level, 1, np.currActNum)
    if success then
      sMario0.pause = 150
    end
  end
  return true
end

hook_chat_command("stalk", trans("stalk_desc"), stalk_command)

function on_course_enter()
  attackedBy = nil

  -- justEntered = true

  if GST.romhackFile == "vanilla" then
    omm_replace(OmmEnabled)
  elseif NetP[0].currLevelNum == LEVEL_LOBBY then -- erase signs when not in vanilla
    local sign = obj_get_first_with_behavior_id(id_bhvMessagePanel)
    while sign do
      obj_mark_for_deletion(sign)
      sign = obj_get_next_with_same_behavior_id(sign)
    end
  end
  if GST.mhState == 0 then -- and background music
    set_lobby_music(month)
    --play_music(0, custom_seq, 1)
  end

  omm_disable_mode_for_minihunt(GST.mhMode == 2) -- change non stop mode setting for minihunt
  if GST.mhMode == 2 and GST.mhState == 2 then   -- unlock cannon and caps in minihunt
    local file = get_current_save_file_num() - 1
    save_file_set_flags(SAVE_FLAG_HAVE_METAL_CAP | SAVE_FLAG_HAVE_VANISH_CAP | SAVE_FLAG_HAVE_WING_CAP)
    save_file_set_star_flags(file, np0.currCourseNum, 0x80)

    -- for Board Bowser's Sub
    if ROMHACK.ddd and GST.gameLevel == LEVEL_DDD then
      save_file_clear_flags(SAVE_FLAG_HAVE_KEY_2)
      if GST.getStar == 1 then
        save_file_clear_flags(SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR)
      else
        save_file_set_flags(SAVE_FLAG_UNLOCKED_UPSTAIRS_DOOR)
      end
    end
  else -- fix star count
    local courseMax = 25
    local courseMin = 1
    m0.numStars = save_file_get_total_star_count(get_current_save_file_num() - 1, courseMin - 1, courseMax - 1)
    m0.prevNumStarsForDialog = m0.numStars
  end
end

-- calculates all player's placements in minihunt
function calculate_placement()
  local leader = false
  local foundOne = false
  local scoreboard = {}

  if GST.mhMode ~= 2 then
    return false, scoreboard
  end

  local toBeat = sMario0.totalStars
  if toBeat > 0 then
    leader = true
    table.insert(scoreboard, { 0, toBeat })
  end

  for i = 1, MAX_PLAYERS - 1 do
    if NetP[i].connected then
      if PST[i].spectator ~= 1 then
        foundOne = true
      end
      if PST[i].totalStars and PST[i].totalStars ~= 0 then
        if PST[i].totalStars > toBeat then
          leader = false
        end
        table.insert(scoreboard, { i, PST[i].totalStars })
      end
    end
  end

  if not foundOne then
    return false, {}
  end

  -- sort
  if #scoreboard > 1 then
    table.sort(scoreboard, function(a, b)
      return a[2] > b[2]
    end)
  end

  return leader, scoreboard
end

function on_packet_runner_collect(data, self)
  runnerID = data.runnerID
  if runnerID ~= nil then
    leader, scoreboard = calculate_placement()
    local np = network_player_from_global_index(runnerID)
    local playerColor = network_get_player_text_color_string(np.localIndex)
    local place = get_custom_level_name(data.course, data.level, data.area)
    if data.star ~= nil then -- star
      local name = get_custom_star_name(data.course, data.star)

      if (not self) and data.noSound ~= true then
        popup_sound(SOUND_MENU_STAR_SOUND)
      end

      if GST.mhMode == 2 or not (OmmEnabled and gServerSettings.stayInLevelAfterStar == 1) then -- OMM shows its own progress, so don't show this
        djui_popup_create(trans("got_star", (playerColor .. np.name)) .. "\\#ffffff\\\n" .. place .. "\n" .. name, 2)
      end

      -- update time
      if (not self) and GST.mhMode ~= 2 and sMario0.team == 1 and data.course == np0.currCourseNum then
        neededRunTime, localRunTime = calculate_leave_requirements(sMario0, localRunTime)
      end
    elseif data.switch ~= nil then -- switch
      if not self then
        popup_sound(SOUND_GENERAL_ACTIVATE_CAP_SWITCH)
      end

      local switch_message = "hit_switch_yellow" -- used in b3313
      if data.switch == 0 then
        switch_message = "hit_switch_red"
      elseif data.switch == 1 then
        switch_message = "hit_switch_green"
      elseif data.switch == 2 then
        switch_message = "hit_switch_blue"
      end
      djui_popup_create(trans(switch_message, (playerColor .. np.name)), 2)
    elseif data.grand ~= nil then -- grand star
      if not self then
        popup_sound(SOUND_GENERAL_GRAND_STAR)
      end

      djui_popup_create(trans("got_star", (playerColor .. np.name)) .. "\\#ffffff\\\nGrand Star", 2)
    else -- key
      if not self then
        popup_sound(SOUND_GENERAL_UNKNOWN3_LOWPRIO)
      end

      djui_popup_create(trans("got_key", (playerColor .. np.name)) .. "\\#ffffff\\\n" .. place, 2)
    end
  end

  if data.unlocked then
    if playPopupSounds then
      play_peachs_jingle()
    end
    djui_popup_create(trans("got_all_stars"), 1)
  end
end

function on_packet_kill(data, self)
  local killed = data.killed
  local killer = data.killer
  local newRunnerID = data.newRunnerID

  if killed ~= nil then
    local np = network_player_from_global_index(killed)
    local playerColor = network_get_player_text_color_string(np.localIndex)

    if killer ~= nil then -- died from kill (most common)
      local killerNP = network_player_from_global_index(killer)
      local kPlayerColor = network_get_player_text_color_string(killerNP.localIndex)

      if killerNP.localIndex == 0 then -- is our kill
        m0.healCounter = 0x32          -- full health
        m0.hurtCounter = 0x0
        popup_sound(SOUND_GENERAL_STAR_APPEARS)
        -- save kill, but only in-game
        local kSMario = sMario0
        if GST.mhState ~= 0 then
          local kills = tonumber(mod_storage_load("kills"))
          if kills == nil then
            kills = 0
          end
          mod_storage_save("kills", tostring(math.floor(kills) + 1))
          kSMario.kills = kSMario.kills + 1
        end

        -- kill combo
        killCombo = killCombo + 1
        if killCombo > 1 then
          network_send_include_self(false, {
            id = PACKET_KILL_COMBO,
            name = kPlayerColor .. killerNP.name,
            kills = killCombo,
          })
        end
        if GST.mhState ~= 0 then
          local maxStreak = tonumber(mod_storage_load("maxStreak"))
          if maxStreak == nil or killCombo > maxStreak then
            mod_storage_save("maxStreak", tostring(math.floor(killCombo)))
            kSMario.maxStreak = killCombo
          end
        end
        killTimer = 300       -- 10 seconds
      elseif data.runner then -- play sound if runner dies
        popup_sound(SOUND_OBJ_BOWSER_LAUGH)
      end

      -- sidelined if this was their last life
      if data.death ~= true then
        djui_popup_create(trans("killed", (kPlayerColor .. killerNP.name), (playerColor .. np.name)), 1)
      else
        djui_popup_create(trans("sidelined", (kPlayerColor .. killerNP.name), (playerColor .. np.name)), 1)
      end
    else
      if data.death ~= true then -- runner only lost one life
        djui_popup_create(trans("lost_life", (playerColor .. np.name)), 1)
      else                       -- runner lost all lives
        djui_popup_create(trans("lost_all", (playerColor .. np.name)), 1)
      end
      if data.runner then -- play sound if runner dies
        popup_sound(SOUND_OBJ_BOWSER_LAUGH)
      end
    end
  end

  -- new runner for swap mode
  if newRunnerID ~= nil then
    local np = network_player_from_global_index(newRunnerID)
    if np then
      local sMario = PST[np.localIndex]
      become_runner(sMario)
      if np.localIndex == 0 and GST.mhMode ~= 2 then
        sMario.runTime = data.time or 0
        localRunTime = data.time or 0
        neededRunTime, localRunTime = calculate_leave_requirements(sMario, localRunTime)
        print("new time:", data.time)
      end
      on_packet_role_change({ id = PACKET_ROLE_CHANGE, index = newRunnerID }, true)
    else
      newRunnerID = nil
    end
  end

  _G.mhApi.onKill(killer, killed, data.runner, data.death, data.time, newRunnerID)
end

-- part of the API
function get_kill_combo()
  return killCombo
end

function on_game_end(data, self)
  if GST.mhMode == 2 and data.winner ~= -1 then
    local winCount = 1
    local winners = {}
    local weWon = true
    local singlePlayer = true
    local record = false
    local totalStarsAcrossAll = 0
    for i = 0, (MAX_PLAYERS - 1) do
      local sMario = PST[i]
      local np = NetP[i]

      if i == 0 then
        local maxStar = tonumber(mod_storage_load("maxStar"))
        if maxStar == nil then
          maxStar = 0
        end
        if sMario.totalStars > maxStar then
          mod_storage_save("maxStar", tostring(sMario.totalStars))
          sMario.maxStar = sMario.totalStars
          record = true
        end
      elseif np.connected and sMario.spectator ~= 1 then
        singlePlayer = false
      end

      if np.connected and sMario.totalStars ~= nil then
        totalStarsAcrossAll = totalStarsAcrossAll + sMario.totalStars
        if sMario.totalStars >= winCount then
          local playerColor = network_get_player_text_color_string(np.localIndex)
          local name = playerColor .. np.name
          if sMario.totalStars == winCount then
            table.insert(winners, name)
          else
            winners = { name }
            winCount = sMario.totalStars
            if i ~= 0 then weWon = false end
          end
        end
      end
    end

    if singlePlayer then
      djui_chat_message_create(trans("mini_score", sMario0.totalStars))
    elseif #winners > 0 then
      djui_chat_message_create(trans("winners"))
      for i, name in ipairs(winners) do
        djui_chat_message_create(name)
      end
      if weWon then
        add_win(sMario0)
      end
    else
      djui_chat_message_create(trans("no_winners"))
    end

    if record then
      play_star_fanfare()
      djui_chat_message_create(trans("new_record"))
    else
      play_race_fanfare()
    end
  elseif data.winner == 1 then
    play_star_fanfare()
    if sMario0.team == 1 then
      add_win(sMario0)
    end
  else
    play_dialog_sound(21) -- bowser intro
    --play_secondary_music(SEQ_EVENT_KOOPA_MESSAGE, 0, 80, 60)
  end
end

function on_packet_stats(data, self)
  djui_chat_message_create(trans_plural(data.stat, data.name, data.value))
end

function add_win(sMario)
  if network_player_connected_count() <= 1 then return end -- don't increment wins in solo
  local winType = "wins"
  if inHard == 1 then
    winType = "hardWins"
  elseif inHard == 2 then
    winType = "exWins"
  end
  if GST.mhMode ~= 2 then
    winType = winType .. "_standard"
  end
  local wins = tonumber(mod_storage_load(winType))
  if wins == nil then
    wins = 0
  end
  mod_storage_save(winType, tostring(math.floor(wins) + 1))
  sMario[winType] = sMario[winType] + 1
end

function on_packet_kill_combo(data, self)
  if data.kills > 5 then
    djui_popup_create(trans("kill_combo_large", data.name, data.kills), 1)
    popup_sound(SOUND_MARIO_YAHOO_WAHA_YIPPEE)
  else
    djui_popup_create(trans("kill_combo_" .. tostring(data.kills), data.name), 1)
  end
end

-- vote skip
iVoted = false
function skip_command(msg)
  local totalVotes = GST.votes
  if GST.mhMode ~= 2 then
    djui_chat_message_create(trans("wrong_mode"))
    return true
  elseif GST.mhState ~= 2 then
    djui_chat_message_create(trans("not_started"))
    return true
  elseif msg:lower() == "force" and has_mod_powers(0) then
    totalVotes = 98 -- force skip
  elseif iVoted then
    djui_chat_message_create(trans("already_voted"))
    return true
  end

  local playercolor = network_get_player_text_color_string(0)
  totalVotes = totalVotes + 1
  GST.votes = totalVotes
  iVoted = true
  network_send_include_self(true, {
    id = PACKET_VOTE,
    votes = totalVotes,
    voted = playercolor .. np0.name,
  })
  return true
end

hook_chat_command("skip", trans("menu_skip_desc"), skip_command)
function on_packet_vote(data, self)
  local count = network_player_connected_count() -- this includes spectators
  local maxVotes = count
  if count > 2 then
    maxVotes = math.ceil(count / 2) -- half the lobby
  elseif count == 1 then
    iVoted = false
    if GST.campaignCourse ~= 0 then
      GST.campaignCourse = GST.campaignCourse + 1
    end
    random_star(np0.currCourseNum, GST.campaignCourse)
    GST.votes = 0
    return
  end

  djui_chat_message_create(string.format("%s (%d/%d)", trans("vote_skip", data.voted), data.votes, maxVotes))
  if maxVotes <= data.votes then
    djui_chat_message_create(trans("vote_pass"))
    iVoted = false
    if self then
      if GST.campaignCourse ~= 0 then
        GST.campaignCourse = GST.campaignCourse + 1
      end
      random_star(np0.currCourseNum, GST.campaignCourse)
      GST.votes = 0
    end
  else
    djui_chat_message_create(trans("vote_info"))
  end
end

-- for global popups, so it appears in their language
function global_popup_lang(langID, format, format2_, lines)
  network_send(false, {
    id = PACKET_LANG_POPUP,
    langID = langID,
    format = format,
    format2 = format2_,
    lines = lines,
  })
  djui_popup_create(trans(langID, format, format2_), lines)
end

function on_packet_lang_popup(data, self)
  djui_popup_create(trans(data.langID, data.format, data.format2), data.lines)
  if data.langID == "rejoin_success" then
    leader, scoreboard = calculate_placement()
  end
end

-- popup for this player's role changing
function on_packet_role_change(data, self)
  local np = network_player_from_global_index(data.index)
  local playerColor = network_get_player_text_color_string(np.localIndex)
  local sMario = PST[np.localIndex]
  local roleName, color = get_role_name_and_color(sMario)
  djui_popup_create(trans("now_role", playerColor .. np.name, color .. roleName), 1)
  if np.localIndex == 0 and sMario.team == 1 then
    popup_sound(SOUND_GENERAL_SHORT_STAR)
  end
end

-- change name of this star for all players
function on_packet_omm_star_rename(data, self)
  local name = get_custom_star_name(data.course, data.act)
  _G.OmmApi.omm_register_star_behavior(data.obj_id, name, string.upper(name))
  popup_sound(SOUND_MENU_STAR_SOUND)
  if ommStarID == data.obj_id then
    ommRenameTimer = 10
  end
end

function on_packet_other_warp(data, self)
  local name = ROMHACK.levelNames and ROMHACK.levelNames[data.level * 10 + data.area]
  local np = network_player_from_global_index(data.index)
  local playerColor = network_get_player_text_color_string(np.localIndex)
  local sMario = PST[np.localIndex]

  local send = false
  --[[if name then
    djui_popup_create(trans("custom_enter",playerColor..np.name,name),1)
    send = true
  end]]
  local sound = nil
  local bowserFight = false
  if (data.course == COURSE_BITDW or data.course == COURSE_BITFS or data.course == COURSE_BITS) then
    local playSound = (data.course ~= data.prevCourse)

    if (data.level == LEVEL_BOWSER_1 or data.level == LEVEL_BOWSER_2 or data.level == LEVEL_BOWSER_3) then
      if name == nil then
        name = "Bowser 3"
        if data.level == LEVEL_BOWSER_1 then
          name = "Bowser 1"
        elseif data.level == LEVEL_BOWSER_2 then
          name = "Bowser 2"
        end
        if not self then
          djui_popup_create(trans("custom_enter", playerColor .. np.name, name), 1)
        end
      end
      bowserFight = true
      playSound = true
    end

    send = playSound
    if sMario.team == 1 and playSound then sound = SOUND_MOVING_ALMOST_DROWNING end
  end
  if ((data.course ~= data.prevCourse) or (bowserFight and sMario.team ~= 1)) then
    send = true
    if (not self) and (sMario.team ~= sMario0.team or sMario.team == 1) and sMario.spectator ~= 1 then
      if sMario.team == 1 then
        if data.course ~= 0 and (ROMHACK.hubStages == nil or ROMHACK.hubStages[data.course] == nil) and (data.course == np0.currCourseNum and data.act == np0.currActNum) then
          sound = SOUND_MENU_REVERSE_PAUSE + 61569 -- interesting unused sound
        elseif data.prevCourse ~= 0 and (ROMHACK.hubStages == nil or ROMHACK.hubStages[data.prevCourse] == nil) and data.prevCourse == np0.currCourseNum then
          sound = SOUND_MENU_MARIO_CASTLE_WARP2
        end
      elseif data.course ~= 0 and (ROMHACK.hubStages == nil or ROMHACK.hubStages[data.course] == nil) and (data.course == np0.currCourseNum and data.act == np0.currActNum) then
        sound = SOUND_OBJ_BOO_LAUGH_SHORT
      end
    end
  end
  if sound and not self then popup_sound(sound) end
  return send
end

-- packets
PACKET_RUNNER_COLLECT = 0
PACKET_KILL = 1
PACKET_MH_START = 2
PACKET_TC = 3
PACKET_GAME_END = 4
PACKET_STATS = 5
PACKET_KILL_COMBO = 6
PACKET_VOTE = 7
PACKET_LANG_POPUP = 8
PACKET_ROLE_CHANGE = 9
PACKET_OMM_STAR_RENAME = 10
PACKET_OTHER_WARP = 11
sPacketTable = {
  [PACKET_RUNNER_COLLECT] = on_packet_runner_collect,
  [PACKET_KILL] = on_packet_kill,
  [PACKET_MH_START] = do_game_start,
  [PACKET_TC] = on_packet_tc,
  [PACKET_GAME_END] = on_game_end,
  [PACKET_STATS] = on_packet_stats,
  [PACKET_KILL_COMBO] = on_packet_kill_combo,
  [PACKET_VOTE] = on_packet_vote,
  [PACKET_LANG_POPUP] = on_packet_lang_popup,
  [PACKET_ROLE_CHANGE] = on_packet_role_change,
  [PACKET_OMM_STAR_RENAME] = on_packet_omm_star_rename,
  [PACKET_OTHER_WARP] = on_packet_other_warp,
}

-- from arena
function on_packet_receive(dataTable)
  if sPacketTable[dataTable.id] ~= nil then
    sPacketTable[dataTable.id](dataTable, false)
  end
end

-- to update rom hack
function on_rom_hack_changed(tag, oldVal, newVal)
  if oldVal ~= nil and oldVal ~= newVal then
    print("Hack set to " .. newVal)
    local result = setup_hack_data()
    if result == "vanilla" then
      djui_popup_create(trans("vanilla"), 1)
    end
  end
end

-- display the change in mode
function on_mode_changed(tag, oldVal, newVal)
  if oldVal ~= nil and oldVal ~= newVal then
    if newVal == 0 then
      djui_popup_create(trans("mode_normal"), 1)
    elseif newVal == 1 then
      djui_popup_create(trans("mode_swap"), 1)
    else
      djui_popup_create(trans("mode_mini"), 1)
    end
    noSettingDisp = true

    if currMenu and currMenu.name == "settingsMenu" then
      menu_reload()
      menu_enter()
    end

    if network_is_server() then
      change_game_mode("", newVal)
    end
  end
end

-- starts background music again in state 0
function on_state_changed(tag, oldVal, newVal)
  if oldVal ~= newVal and newVal == 0 then
    set_lobby_music(month)
  end
end

-- displays a message when a setting is changed
function on_setting_changed(tag, oldVal, newVal)
  if oldVal == newVal then return end

  if (didFirstJoinStuff and not noSettingDisp) then
    local name, value, oldvalue
    name, value = get_setting_as_string(tag, newVal)
    name, oldvalue = get_setting_as_string(tag, oldVal)

    if value then
      if name then
        djui_chat_message_create(trans("change_setting"))
        djui_chat_message_create(trans(name) .. ": " .. oldvalue .. "\\#dcdcdc\\->" .. value)
      else
        djui_chat_message_create(trans("change_setting"))
        djui_chat_message_create(oldvalue .. "\\#dcdcdc\\->" .. value)
      end
    end
  end

  if tag == "menu_star_mode" then
    noSettingDisp = true
    load_settings(false, true)
  elseif tag == "menu_allow_stalk" then
    if newVal ~= true then
      update_chat_command_description("stalk", "- " .. trans("command_disabled"))
    else
      update_chat_command_description("stalk", trans("stalk_desc"))
    end
  elseif tag == "menu_allow_spectate" then
    if newVal ~= true then
      update_chat_command_description("spectate", "- " .. trans("command_disabled"))
    else
      update_chat_command_description("spectate", trans("spectate_desc"))
    end
  end
end

-- hooks
hook_event(HOOK_UPDATE, update)
hook_event(HOOK_MARIO_UPDATE, mario_update)
hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update)
hook_event(HOOK_BEFORE_SET_MARIO_ACTION, before_set_mario_action)
hook_event(HOOK_ALLOW_PVP_ATTACK, allow_pvp_attack)
hook_event(HOOK_ON_PVP_ATTACK, on_pvp_attack)
hook_event(HOOK_ON_PLAYER_DISCONNECTED, on_player_disconnected)
hook_event(HOOK_ON_PAUSE_EXIT, on_pause_exit)
hook_event(HOOK_ON_LEVEL_INIT, on_course_enter)
hook_event(HOOK_ON_WARP, on_warp)
hook_event(HOOK_ON_SYNC_VALID, on_course_sync)
hook_event(HOOK_ON_PACKET_RECEIVE, on_packet_receive)
hook_event(HOOK_ON_DEATH, on_death)
hook_event(HOOK_ON_INTERACT, on_interact)
hook_on_sync_table_change(GST, "romhackFile", "change_hack", on_rom_hack_changed)
hook_on_sync_table_change(GST, "mhMode", "change_mode", on_mode_changed)
hook_on_sync_table_change(GST, "mhState", "change_state", on_state_changed)

-- setting changes
local settings = { "runnerLives", "starMode", "runTime", "allowSpectate", "weak", "campaignCourse",
  "gameAuto", "dmgAdd", "anarchy", "nerfVanish", "firstTimer", "allowStalk", "starRun", "noBowser" }
local settingName = { "menu_run_lives", "menu_star_mode", "menu_time", "menu_allow_spectate", "menu_weak",
  "menu_campaign",
  "menu_auto", "menu_dmgAdd", "menu_anarchy", "menu_nerf_vanish", "menu_first_timer", "menu_allow_stalk", "menu_category",
  "menu_defeat_bowser" }
for i, setting in ipairs(settings) do
  hook_on_sync_table_change(GST, setting, settingName[i], on_setting_changed)
end

-- prevent constant error stream
if not trans then
  trans = function(_, _, _, _)
    return "LANGUAGE MODULE DID NOT LOAD"
  end
  trans_plural = trans
end
