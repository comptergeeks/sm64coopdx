local showScores=true
hook_chat_command('scores','Show or hide the scoreboard.',function() showScores=not showScores; return true end)
hook_chat_command('join','Travel to the host\'s current stage and area.',function()
    for i=0,MAX_PLAYERS-1 do
        local np=gNetworkPlayers[i]
        if np.connected and np.type==NPT_SERVER then
            warp_to_level(np.currLevelNum,np.currAreaIndex,np.currActNum)
            return true
        end
    end
    return true
end)
local stages={castle=LEVEL_CASTLE_GROUNDS,bob=LEVEL_BOB,wf=LEVEL_WF,jrb=LEVEL_JRB,
    ccm=LEVEL_CCM,bbh=LEVEL_BBH,hmc=LEVEL_HMC,lll=LEVEL_LLL,ssl=LEVEL_SSL,ddd=LEVEL_DDD,
    sl=LEVEL_SL,wdw=LEVEL_WDW,ttm=LEVEL_TTM,thi=LEVEL_THI,ttc=LEVEL_TTC,rr=LEVEL_RR}
local stageSerial
hook_chat_command('stage','[castle/bob/wf/jrb/ccm/bbh/hmc/lll/ssl/ddd/sl/wdw/ttm/thi/ttc/rr] Move the match.',function(name)
    if not network_is_server() then djui_chat_message_create('Only the host can move the match. Use /join to follow.'); return true end
    local level=stages[string.lower(name):match('^%s*(.-)%s*$')]
    if not level then djui_chat_message_create('Stages: castle bob wf jrb ccm bbh hmc lll ssl ddd sl wdw ttm thi ttc rr'); return true end
    gGlobalSyncTable.tpsStageLevel=level
    gGlobalSyncTable.tpsStageSerial=(gGlobalSyncTable.tpsStageSerial or 0)+1
    return true
end)
hook_event(HOOK_UPDATE,function()
    local serial=gGlobalSyncTable.tpsStageSerial
    if serial and serial~=stageSerial and gNetworkPlayers[0].currLevelSyncValid then
        stageSerial=serial
        warp_to_level(gGlobalSyncTable.tpsStageLevel,1,1)
    end
end)
hook_event(HOOK_ON_HUD_RENDER,function()
    if not ThirdPersonCamera.enabled or djui_is_chatbox_open() or djui_hud_is_pause_menu_created() then return end
    djui_hud_set_resolution(RESOLUTION_N64)
    djui_hud_set_font(FONT_NORMAL)
    local w,h=djui_hud_get_screen_width(),djui_hud_get_screen_height()
    if showScores then
        local rows={}
        for i=0,MAX_PLAYERS-1 do
            local np=gNetworkPlayers[i]
            if np.connected then rows[#rows+1]={name=np.name or ('Player '..np.globalIndex),
                kills=gGlobalSyncTable['tpsKills'..np.globalIndex] or 0,
                deaths=gGlobalSyncTable['tpsDeaths'..np.globalIndex] or 0,id=np.globalIndex} end
        end
        for i=1,(gGlobalSyncTable.fpsBotCount or 0) do
            local id=MAX_PLAYERS+i-1
            rows[#rows+1]={name='Koopa '..i,kills=gGlobalSyncTable['tpsKills'..id] or 0,
                deaths=gGlobalSyncTable['tpsDeaths'..id] or 0,id=id}
        end
        table.sort(rows,function(a,b) if a.kills~=b.kills then return a.kills>b.kills end return a.id<b.id end)
        local count=math.min(#rows,8)
        djui_hud_set_color(12,20,34,190); djui_hud_render_rect(w-110,47,105,14+count*12)
        djui_hud_set_color(255,215,100,255); djui_hud_print_text('PLAYER             K / D',w-106,50,0.30)
        for i=1,count do
            local r=rows[i]
            djui_hud_set_color(255,255,255,240)
            -- Strip palette escape codes before shortening the display name.
            local name=r.name:gsub('\\#[%x]+\\',''):sub(1,14)
            djui_hud_print_text(name,w-106,50+i*12,0.30)
            djui_hud_print_text(r.kills..' / '..r.deaths,w-32,50+i*12,0.30)
        end
    end
    if FpsMatch.dead then
        djui_hud_set_color(12,20,34,210); djui_hud_render_rect(w/2-74,74,148,28)
        djui_hud_set_color(255,225,140,255)
        djui_hud_print_text('RESPAWNING IN '..math.max(1,math.ceil((FpsMatch.respawnAt-get_global_timer())/30)),w/2-63,81,0.45)
    end
end)

hook_event(HOOK_ON_HUD_RENDER,function()
    if not ThirdPersonCamera.enabled or not FpsBots.in_area() or FpsMatch.dead
        or djui_is_chatbox_open() or djui_hud_is_pause_menu_created() then return end
    djui_hud_set_resolution(RESOLUTION_N64)
    for _,target in ipairs(FpsBots.targets()) do
        local pos={x=target.pos.x,y=target.pos.y+170,z=target.pos.z}
        local out={x=0,y=0,z=0}
        if djui_hud_world_pos_to_screen_pos(pos,out) then
            local camera=ThirdPersonCamera.pos
            local hit=collision_find_surface_on_ray(camera.x,camera.y,camera.z,pos.x-camera.x,pos.y-camera.y,pos.z-camera.z)
            if not hit.surface then
                local hp=gGlobalSyncTable['fpsBot'..(target.id-MAX_PLAYERS+1)..'hp'] or 0
                djui_hud_set_color(12,20,34,220); djui_hud_render_rect(out.x-12,out.y,24,5)
                djui_hud_set_color(255,190,75,255)
                for i=1,hp do djui_hud_render_rect(out.x-11+(i-1)*8,out.y+1,6,3) end
            end
        end
    end
end)
