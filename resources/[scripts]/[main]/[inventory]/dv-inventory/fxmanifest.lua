fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dv-inventory'
author 'Dayverse Roleplay'
description 'Inventory met slepen, hotbar, kofferbak, dashboardkastje, grond en stashes'
version '1.0.0'

shared_script 'config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}
