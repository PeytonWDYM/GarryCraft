-- Load in the owned Downtown lab, then run garrycraft_test_props.
concommand.Add("garrycraft_test_props", function(owner)
    assert(game.SinglePlayer() and game.GetMap() == "rp_downtown_tits_v2", "Prop probes require local Downtown Tits V2")
    local GC = GarryCraft
    GC.Stop()
    owner:SetPos(Vector(-2160, -1568, -196))
    GC.AlignGrid(owner)
    local probes = {}
    local function probe(name, center, offset)
        local from, to = center - offset, center + offset
        local ray = util.TraceLine({start=from,endpos=to,mask=MASK_PLAYERSOLID,filter=owner})
        local hull = util.TraceHull({start=from,endpos=to,mins=Vector(-9.6,-9.6,0),maxs=Vector(9.6,9.6,57.6),
            mask=MASK_PLAYERSOLID,filter=owner})
        assert(ray.Hit and hull.Hit, "The engine did not hit " .. name)
        probes[#probes+1] = {name=name,from=GC.ToMinecraft(from),to=GC.ToMinecraft(to),
            rayFraction=ray.Fraction,hullFraction=hull.Fraction}
    end
    probe("fountain-x",Vector(-1904,-1568,-146),Vector(192,0,0))
    probe("fountain-y",Vector(-1904,-1568,-146),Vector(0,192,0))
    probe("lamp-x",Vector(316,-1104,-164),Vector(64,0,0))
    probe("lamp-y",Vector(316,-1104,-164),Vector(0,64,0))
    local owned = {}
    timer.Simple(20,function() for _, entity in ipairs(owned) do if IsValid(entity) then entity:Remove() end end end)
    for index, mode in ipairs({"frozen", "rotated", "obb"}) do
        local entity = ents.Create(mode == "obb" and "prop_dynamic" or "prop_physics")
        entity:SetModel("models/props_junk/wood_crate001a.mdl")
        entity:SetPos(owner:GetPos()+Vector(64,224-index*160,32))
        entity:SetAngles(Angle(0,mode == "rotated" and 45 or 0,0))
        entity:Spawn()
        if mode == "obb" then
            entity:SetSolid(SOLID_OBB)
            entity:RemoveSolidFlags(FSOLID_NOT_SOLID)
            local lo, hi = entity:GetModelBounds()
            entity:SetCollisionBounds(lo,hi)
        else entity:GetPhysicsObject():EnableMotion(false) end
        owned[#owned+1] = entity
        probe(mode,entity:GetPos()-Vector(0,0,8),Vector(64,0,0))
    end
    local request = {request="props:" .. tostring(SysTime()),probes=probes}
    file.Write("garrycraft-map-probes-source.json",util.TableToJSON(request,true))
    GC.BeginTest(owner,"probe:" .. util.TableToJSON(request))
end)
