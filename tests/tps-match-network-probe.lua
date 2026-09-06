-- Isolated two-process integration fixture; never ship in the normal mod.
local frames=0
local sawRagdoll=false
local initial=false
djui_hud_get_mouse_buttons_down=function() return 0 end
djui_hud_get_raw_mouse_x=function() return 0 end
djui_hud_get_raw_mouse_y=function() return 0 end
hook_event(HOOK_BEFORE_MARIO_UPDATE,function(m)
 if m.playerIndex~=0 or not gNetworkPlayers[0].currAreaSyncValid then return end
 local other
 for i=1,MAX_PLAYERS-1 do if gNetworkPlayers[i].connected and is_player_active(gMarioStates[i])~=0 then other=i; break end end
 if not other then return end
 frames=frames+1
 if not initial then
  initial=true; m.health=0x880; m.invincTimer=0
  if network_is_server() then FpsBots.count=0; FpsBots.reset() end
 end
 if frames<280 and not FpsMatch.dead then
  m.pos.x,m.pos.y,m.pos.z=-1328,260,network_is_server() and 4664 or 4964
  m.vel.x,m.vel.y,m.vel.z,m.forwardVel=0,0,0,0
  set_mario_action(m,ACT_IDLE,0)
  ThirdPersonCamera.pitch=math.atan(-55,math.sqrt(300*300-65*65))
  ThirdPersonCamera.yaw=(network_is_server() and 0 or math.pi)+math.asin(65/300)
 end
 m.controller.buttonDown,m.controller.buttonPressed=0,0
 if network_is_server() and frames>=180 and frames<=270 and frames%30==0 then
  m.controller.buttonDown=B_BUTTON
  print('TPS_MATCH_NET shot='..frames)
 end
 if FpsMatch.dead then sawRagdoll=sawRagdoll or m.marioBodyState.tpsRagdoll end
 if frames==420 then
  assert(gGlobalSyncTable.tpsKills0==1 and gGlobalSyncTable.tpsDeaths1==1,'network score mismatch')
  assert(not FpsMatch.dead and m.health==0x880,'network respawn failed')
  if not network_is_server() then assert(sawRagdoll,'victim did not render character ragdoll') end
  print('TPS_MATCH_NET PASS local='..gNetworkPlayers[0].globalIndex..' lethal shots, score, ragdoll, respawn')
 end
 if frames==450 and network_is_server() then
  gGlobalSyncTable.tpsStageLevel=LEVEL_BOB
  gGlobalSyncTable.tpsStageSerial=(gGlobalSyncTable.tpsStageSerial or 0)+1
 end
 if frames==550 then
  assert(gNetworkPlayers[0].currLevelNum==LEVEL_BOB,'match stage travel failed')
  assert(not FpsMatch.dead and not m.marioBodyState.tpsRagdoll,'ragdoll leaked across stage')
  print('TPS_MATCH_NET PASS local='..gNetworkPlayers[0].globalIndex..' synchronized stage travel')
 end
end)
