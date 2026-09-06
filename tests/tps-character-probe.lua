-- Cycle all built-in characters through aiming, death and respawn in-engine.
local frames=0
local checked={}
djui_hud_get_mouse_buttons_down=function() return 0 end
djui_hud_get_raw_mouse_x=function() return 0 end
djui_hud_get_raw_mouse_y=function() return 0 end
hook_event(HOOK_BEFORE_MARIO_UPDATE,function(m)
 if m.playerIndex~=0 or not gNetworkPlayers[0].currAreaSyncValid then return end
 frames=frames+1
 local kind=math.floor((frames-1)/240)
 local phase=(frames-1)%240+1
 if kind>=5 then return end
 if frames==1 then FpsBots.count=0; FpsBots.reset() end
 if phase==1 then
  gNetworkPlayers[0].overrideModelIndex=kind
  m.health=0x880; set_mario_action(m,ACT_IDLE,0)
 end
 if phase==50 then
  assert(m.character.type==kind,'character model did not change')
  assert(m.marioObj.header.gfx.animInfo.animID==get_character_anim(m,MARIO_ANIM_IDLE_WITH_LIGHT_OBJ),'character did not use holding animation')
 end
 if phase==70 then m.health=0xFF end
 if phase==100 then
  assert(FpsMatch.dead and m.marioBodyState.tpsRagdoll,'character ragdoll missing')
  for i=1,11 do
   local p=m.marioBodyState.tpsRagdollNodes[i]
   assert(FpsCombat.finite(p.x) and FpsCombat.finite(p.y) and FpsCombat.finite(p.z),'non-finite ragdoll node')
  end
 end
 if phase==200 then
  assert(not FpsMatch.dead and m.health==0x880 and not m.marioBodyState.tpsRagdoll,'character respawn failed')
  checked[kind]=true
  print('TPS_CHARACTER_PROBE PASS: '..m.character.name..' holding pose, ragdoll, respawn')
 end
end)
