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
    'client/teste.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/banco.lua',
    'server/main.lua',
}

files {
    'locales/*.json',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
