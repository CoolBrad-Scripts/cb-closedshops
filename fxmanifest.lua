fx_version 'cerulean'
game 'gta5'

name "cb-closedshops"
description "A closed shop system for FiveM RP servers"
author "Cool Brad Scripts"
version "1.1.0"

lua54 'yes'
use_experimental_fxv2_oal 'yes'

shared_scripts {
	'@ox_lib/init.lua',
	'shared/config.lua'
}

client_scripts {
	'@qbx_core/modules/playerdata.lua', -- For QBOX users
	'client/framework.lua',
	'client/main.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'server/framework.lua',
	'server/main.lua'
}