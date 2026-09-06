-- Optional isolated runtime test. Copy into build mod as a-probe.lua.
local frames=0
local killed=false
local firstDeath
local walkingFrames={}
djui_hud_get_mouse_buttons_down=function() return 0 end
djui_hud_get_raw_mouse_x=function() return 0 end
djui_hud_get_raw_mouse_y=function() return 0 end
hook_event(HOOK_BEFORE_MARIO_UPDATE,function(m)
 if m.playerIndex~=0 or not gNetworkPlayers[0].currAreaSyncValid then return end
 frames=frames+1
 if frames==30 then FpsBots.count=0; FpsBots.reset() end
 if frames==60 then
  FpsMatch.record_hit(gNetworkPlayers[0].globalIndex,1,gNetworkPlayers[0].currLevelAreaSeqId,{x=1,y=0,z=0})
  m.health=0xFF; killed=true
 end
 if killed and FpsMatch.dead and not firstDeath then firstDeath=frames end
 if frames==160 then
  assert(firstDeath,'death not detected')
  assert(not FpsMatch.dead and m.health==0x880,'respawn failed')
  assert(gGlobalSyncTable.tpsDeaths0==1 and gGlobalSyncTable.tpsKills1==1,'score failed')
  print('TPS_MATCH_PROBE PASS: death, score, timed respawn and full health')
 end
 if frames>180 and frames<230 then
  m.controller.stickX=0; m.controller.stickY=64; m.controller.stickMag=64
 end
end)
hook_event(HOOK_UPDATE,function()
 if frames>185 and frames<230 then walkingFrames[gMarioStates[0].marioObj.header.gfx.animInfo.animFrame]=true end
 if frames==235 then
  local n=0; for _ in pairs(walkingFrames) do n=n+1 end
  assert(n>3,'walking animation did not advance')
  print('TPS_MATCH_PROBE PASS: walking animation advances through '..n..' frames')
 end
end)
