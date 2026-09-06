-- Three-process fixture: host remains at the castle while two clients fight in BOB.
local frames=0
local warped=false
local initialized=false
djui_hud_get_mouse_buttons_down=function() return 0 end
djui_hud_get_raw_mouse_x=function() return 0 end
djui_hud_get_raw_mouse_y=function() return 0 end
hook_event(HOOK_BEFORE_MARIO_UPDATE,function(m)
 if m.playerIndex~=0 then return end
 local me=gNetworkPlayers[0]
 if not me.currAreaSyncValid then return end
 if network_is_server() then
  if not initialized then FpsBots.count=0; FpsBots.reset(); initialized=true end
  local a,b=network_player_from_global_index(1),network_player_from_global_index(2)
  if a and b and a.connected and b.connected and a.currLevelNum==LEVEL_BOB and b.currLevelNum==LEVEL_BOB then
   gGlobalSyncTable.tpsProbeReady=true
  end
 elseif not warped then warped=true; warp_to_level(LEVEL_BOB,1,1); return end
 if not gGlobalSyncTable.tpsProbeReady then return end
 frames=frames+1
 if network_is_server() then
  if frames==600 then
   assert(me.currLevelNum==LEVEL_CASTLE_GROUNDS,'lobby host unexpectedly traveled')
   assert(gGlobalSyncTable.tpsKills1==1 and gGlobalSyncTable.tpsDeaths2==1,'remote-area score not received by host')
   print('TPS_MULTIAREA PASS host: scores from BOB while host stays at castle')
  end
  return
 end
 local id=me.globalIndex
 if frames<310 and not FpsMatch.dead then
  m.pos.x,m.pos.z=id==1 and -6558 or -6258,6464
  m.pos.y=find_floor_height(m.pos.x,300,m.pos.z)
  m.vel.x,m.vel.y,m.vel.z,m.forwardVel=0,0,0,0
  set_mario_action(m,ACT_IDLE,0)
  ThirdPersonCamera.yaw=(id==1 and math.pi/2 or -math.pi/2)+math.asin(65/300)
  ThirdPersonCamera.pitch=math.atan(-55,math.sqrt(300*300-65*65))
 end
 m.controller.buttonDown,m.controller.buttonPressed=0,0
 if frames==120 and id==2 then m.controller.buttonDown=B_BUTTON end
 if id==1 and frames>=210 and frames<=300 and frames%30==0 then m.controller.buttonDown=B_BUTTON end
 if frames==450 then
  assert(FpsArena.referee_for(me).globalIndex==1,'wrong area referee')
  assert(gGlobalSyncTable.tpsKills1==1 and gGlobalSyncTable.tpsDeaths2==1,'remote-area match score failed')
  assert(not FpsMatch.dead,'remote-area respawn failed')
  if id==1 then assert(m.health<0x880,'shot to elected referee did not apply') end
  print('TPS_MULTIAREA PASS client='..id..': shots both ways, kill, score and respawn away from host')
 end
end)
