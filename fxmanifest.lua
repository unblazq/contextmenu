fx_version 'cerulean'
game 'gta5'

version '7.4.3'

lua54 'yes'

name 'Context Menu'
author 'unblazq'

escrow_ignore {
    '**/*',
}


shared_scripts {
    'config.lua',
    'config/permissions.lua',
    'shared/bridge.lua',
    'shared/permissions.lua',
}

client_scripts {
    'client/core/framework.lua',
    'client/core/permissions.lua',
    'client/core/screen.lua',
    'client/core/menu.lua',
    'client/features/default.lua',
    'client/features/sky.lua',
}

server_scripts {
    'server/core/framework.lua',
    'server/core/permissions.lua',
}

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/assets/**',
}

dependency '/assetpacks'
