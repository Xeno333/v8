local stone = core.get_content_id("mapgen_stone")
local water = core.get_content_id("mapgen_water_source")
local air = core.get_content_id("air")

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





core.register_on_generated(function(vm, minp, maxp, seed)
    local emin, emax = vm:get_emerged_area()
    local area = VoxelArea(emin, emax)
    local data = vm:get_data()

    local noise_map = noise:get_2d_map(vector.new(minp.x, minp.z, 0))

    local lx = 0
    for x = minp.x, maxp.x do
        lx = lx + 1
        local lz = 0
        for z = minp.z, maxp.z do
            lz = lz + 1

            local point_noise = noise_map[lz][lx] * internal_scale
            local yt = math.floor(point_noise)
            local biome = biomes[core.get_biome_data({x=x, y=yt, z=z}).biome]

            for y = minp.y, maxp.y do
                local vi = area:index(x, y, z)

                if y < yt - biome.depth_filler then
                    data[vi] = biome.node_stone or stone

                elseif biome.node_filler and y < yt then
                    data[vi] = biome.node_filler or stone

                elseif biome.node_top and (y < yt + biome.depth_top) then
                    data[vi] = biome.node_top

                elseif y < 2 then
                    if biome.node_water_top and biome.depth_water_top and y > 2 - node_water_top then
                        data[vi] = biome.node_water_top
                    else
                        data[vi] = biome.node_water or water
                    end

                elseif biome.node_dust and y == yt + biome.depth_top then
                    data[vi] = biome.node_dust
                end
            end
        end
    end

    vm:set_data(data)

    core.generate_ores(vm, emin, emax)
    core.generate_decorations(vm, emin, emax)
end)