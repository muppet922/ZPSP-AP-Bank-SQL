# -ZPSP-Ammo-Packs-Bank-SQL
This is an AMX Mod X plugin designed to work with Zombie Plague Special mod for Counter-Strike 1.6

# Features
Persistent ammo pack storage using MySQL database
Automatic saving of ammo packs on disconnect and round end
Admin command to give ammo packs to players
`amx_giveap <target> <amount>`
Bot support with fixed ammo pack amount
Compatible with Zombie Plague Special events (infection, humanization)
Multi-language support

# Requirements
AMX Mod X 1.8.2 or higher
Zombie Plague Special mod
MySQL database

# Installation
Compile the plugin using the AMX Mod X compiler.
Upload the compiled .amxx file to your addons/amxmodx/plugins/ directory.
Add the plugin to your plugins.ini file:
`zpsp_ammo_packs_saver.amxx`

# Configuration

Create a new file named zpsp_bank_mysql.cfg in your addons/amxmodx/configs/ directory.
Add the following lines to the file, replacing the values with your actual database information:

`zpsp_mysql_host "localhost"
zpsp_mysql_user "your_username"
zpsp_mysql_pass "your_password"
zpsp_mysql_db "your_database_name"`

Ensure that the MySQL module is loaded in your modules.ini file.
