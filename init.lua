core.register_mapgen_script(core.get_modpath("v8") .. "/mapgen.lua")

core.register_on_generated(function(minp, maxp, _)
    core.fix_light(minp, maxp)
end)