fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vel_guincho'
description 'Guincho imersivo: plataforma (fixa ou que inclina), gancho, desvirar, pátio; tudo configurado no painel'
author 'Street Roleplay'
version '0.1.0'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/plataforma.lua',
}

client_scripts {
    'client/placement.lua',
    'client/teste.lua',
    'client/painel.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/banco.lua',
    'server/main.lua',
    'server/painel.lua',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/painel.html',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
