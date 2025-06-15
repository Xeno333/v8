local stone = core.get_content_id("mapgen_stone")
local water = core.get_content_id("mapgen_water_source")
local air = core.get_content_id("air")

-- Settings

local settings = {}
local mg_flags = core.get_mapgen_setting("mg_flags")
for flag in string.gmatch(mg_flags, "([^, ]+)") do
    settings[flag] = true
end


-- Params

local internal_scale = 10

local noise_params = {
    offset = -0.5,
    seed = 345876,
    scale = 1,
    spread = vector.new(128, 128, 128),
    octaves = 4,
    persistence = 0.75,
    lacunarity = 1.5,
    flags = "eased"
}
local noise = core.get_value_noise_map(noise_params, vector.new(80, 80, 80))

local caves_noise_params = nil
local caves_noise = nil

if settings.caves then
    caves_noise_params = {
        offset = 0,
        seed = 345876,
        scale = 1,
        spread = vector.new(128, 32, 128),
        octaves = 4,
        persistence = 0.75,
        lacunarity = 1.5,
        flags = "eased"
    }
    caves_noise = core.get_value_noise_map(caves_noise_params, vector.new(80, 80, 80))
end


-- Biomes

local biomes = {}
local biomes_fields = {
    node_dust = true,
    node_top = true,
    depth_top = true,
    node_filler = true,
    depth_filler = true,
    node_stone = true,
    node_water_top = true,
    depth_water_top = true,
    node_water = true
}

for name, v in pairs(core.registered_biomes) do
    local id = core.get_biome_id(name)

    -- Make table and defaults
    biomes[id] = {
        depth_top = 1,
        depth_filler = 3
    }

    for k, i in pairs(v) do
        if biomes_fields[k] then
            local t = type(i)
            if t == "number" then
                biomes[id][k] = i
            elseif t == "string" then
                if core.registered_aliases[i] then
                    biomes[id][k] = core.get_content_id(core.registered_aliases[i])
                else
                    biomes[id][k] = core.get_content_id(i)
                end
            end
        end
    end
end



-- Generate

core.register_on_generated(function(vm, minp, maxp, seed)
    local emin, emax = vm:get_emerged_area()
    local area = VoxelArea(emin, emax)
    local data = vm:get_data()

    local noise_map = noise:get_2d_map(vector.new(minp.x, minp.z, 0))

    local cave_noise_map = nil
    if caves_noise ~= nil then
        cave_noise_map = caves_noise:get_3d_map(vector.new(minp.x, minp.y, minp.z))
    end

    local lx = 0
    for x = minp.x, maxp.x do
        lx = lx + 1
        local lz = 0
        for z = minp.z, maxp.z do
            lz = lz + 1

            local point_noise = noise_map[lz][lx] * internal_scale
            local yt = math.floor(point_noise)
            local biome = biomes[core.get_biome_data({x=x, y=yt, z=z}).biome]

            local ly = 0
            for y = minp.y, maxp.y do
                ly = ly + 1
                if cave_noise_map ~= nil and cave_noise_map[lz][ly][lx] <= -0.9 then
                    goto skip
                end

                local vi = area:index(x, y, z)
                if y < yt - biome.depth_filler then
                    data[vi] = biome.node_stone or stone

                elseif biome.node_filler and y < yt then
                    data[vi] = biome.node_filler or stone

                elseif biome.node_top and (y < yt + biome.depth_top) then
                    data[vi] = biome.node_top

                elseif y < 2 then
                    if biome.node_water_top and biome.depth_water_top and y > 2 - biome.node_water_top then
                        data[vi] = biome.node_water_top
                    else
                        data[vi] = biome.node_water or water
                    end

                elseif biome.node_dust and y == yt + biome.depth_top then
                    data[vi] = biome.node_dust
                end

                ::skip::
            end
        end
    end

    vm:set_data(data)

    if settings.decorations then
        core.generate_decorations(vm, emin, emax)
    end
    if settings.ores then
        core.generate_ores(vm, emin, emax)
    end

    vm:update_liquids()
end)