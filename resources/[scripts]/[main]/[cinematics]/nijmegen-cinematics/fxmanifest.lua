fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'nijmegen-cinematics'
author 'Nijmegen Scripts'
description 'Cinematic maker: freecam, keyframes, smooth paths, filters, letterbox and saved scenes'
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
