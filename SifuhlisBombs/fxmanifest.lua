fx_version 'cerulean'
game 'gta5'

author 'Sifuhlis@CalibreRoleplay'
description 'Bomb arming and disarming with silly lil disarming mini-game'
version '1.0.0'

lua54 'yes' -- Enable Lua 5.4

shared_script '@ox_lib/init.lua'

server_scripts {
    '@qb-core/server/main.lua', -- Ensure this line is present
    'server/main.lua',
}

client_scripts {
    '@qb-core/client/main.lua', -- Ensure this line is present
    'client/main.lua',
}

dependencies {
    'ps-ui'
}
