-- Real-engine aiming and bot lifecycle probe, for an isolated build only.
local frames=0
local generation
local fired=0
djui_hud_get_mouse_buttons_down=function() return 0 end
djui_hud_get_raw_mouse_x=function() return 0 end
djui_hud_get_raw_mouse_y=function() return 0 end
hook_event(HOOK_BEFORE_MARIO_UPDATE,function(m)
 if m.playerIndex~=0 or not gNetworkPlayers[0].currAreaSyncValid then return end
 frames=frames+1
 m.controller.buttonDown,m.controller.buttonPressed=0,0
 local bot=FpsBots.bots[1]
 if frames==30 then FpsBots.count=1; FpsBots.reset() end
 if bot and bot.hp>0 and frames<260 then
  generation=generation or bot.generation
  local dx,dz=bot.x-m.pos.x,bot.z-m.pos.z
  local distance=math.sqrt(dx*dx+dz*dz)
  ThirdPersonCamera.yaw=math.atan(dx,dz)+math.asin(math.min(0.95,65/distance))
  ThirdPersonCamera.pitch=math.atan(bot.y+80-(m.pos.y+155),math.sqrt(math.max(1,distance*distance-65*65)))
  if frames>=180 and frames<=240 and frames%30==0 then m.controller.buttonDown=B_BUTTON; fired=fired+1 end
 end
 if frames==270 then
  assert(fired==3 and bot and bot.hp==0,'three aimed shots did not eliminate bot')
  assert(gGlobalSyncTable.tpsKills0==1,'bot kill not credited')
  assert(#FpsRagdoll.bodies==1 and FpsRagdoll.bodies[1].koopa,'Koopa parts ragdoll missing')
  print('TPS_BOT_PROBE PASS: reticle aiming, three hits, score and Koopa ragdoll')
 end
 if frames==450 then
  assert(bot and bot.hp==3 and bot.generation==generation+1,'bot respawn failed')
  print('TPS_BOT_PROBE PASS: bot respawns with full health and new generation')
 end
end)
