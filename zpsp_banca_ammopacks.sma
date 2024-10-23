#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <zombie_plague_special>

#define PLUGIN "ZP Special: Enhanced Ammo Packs Saver"
#define VERSION "3.0.1"
#define AUTHOR "X"

#define ADMIN_FLAG ADMIN_LEVEL_H
#define MAX_PLAYERS 32
#define BOT_AMMO_PACKS 200

// Database connection
new Handle:g_hDatabase;
new bool:g_bLoaded[MAX_PLAYERS + 1];
new g_iAmmoPacks[MAX_PLAYERS + 1];
new g_iPlayerId[MAX_PLAYERS + 1];

// Database configuration
new g_pCvarHost, g_pCvarUser, g_pCvarPass, g_pCvarDbName;
new g_pCvarCharset, g_pCvarTablePrefix;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    
    g_pCvarHost = create_cvar("zpsp_mysql_host", "localhost", FCVAR_PROTECTED);
    g_pCvarUser = create_cvar("zpsp_mysql_user", "root", FCVAR_PROTECTED);
    g_pCvarPass = create_cvar("zpsp_mysql_pass", "", FCVAR_PROTECTED);
    g_pCvarDbName = create_cvar("zpsp_mysql_db", "amx", FCVAR_PROTECTED);
    g_pCvarCharset = create_cvar("zpsp_mysql_charset", "utf8mb4", FCVAR_PROTECTED);
    g_pCvarTablePrefix = create_cvar("zpsp_mysql_prefix", "zpsp_", FCVAR_PROTECTED);
    
    register_concmd("amx_giveap", "CmdGiveAP", ADMIN_FLAG, "<target> <amount>");
    register_event("HLTV", "EventNewRound", "a", "1=0", "2=0");
    
    set_task(1.0, "InitDatabase");
    register_dictionary("zpsp_ammo_packs.txt");
}

public plugin_cfg()
{
    new cfgdir[64];
    get_configsdir(cfgdir, charsmax(cfgdir));
    server_cmd("exec %s/zpsp_bank_mysql.cfg", cfgdir);
    server_exec();
}

public InitDatabase()
{
    new szHost[64], szUser[32], szPass[32], szDbName[32], szCharset[32], szPrefix[32];
    get_pcvar_string(g_pCvarHost, szHost, charsmax(szHost));
    get_pcvar_string(g_pCvarUser, szUser, charsmax(szUser));
    get_pcvar_string(g_pCvarPass, szPass, charsmax(szPass));
    get_pcvar_string(g_pCvarDbName, szDbName, charsmax(szDbName));
    get_pcvar_string(g_pCvarCharset, szCharset, charsmax(szCharset));
    get_pcvar_string(g_pCvarTablePrefix, szPrefix, charsmax(szPrefix));
    
    g_hDatabase = SQL_MakeDbTuple(szHost, szUser, szPass, szDbName);
    
    // Set charset
    new szQuery[2048];
    formatex(szQuery, charsmax(szQuery), "SET NAMES '%s'", szCharset);
    SQL_ThreadQuery(g_hDatabase, "IgnoreHandle", szQuery);
    
    // Create players table with all identification methods
    formatex(szQuery, charsmax(szQuery), "\
        CREATE TABLE IF NOT EXISTS `%splayers` (\
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,\
            `steamid` VARCHAR(35),\
            `ip` VARCHAR(32),\
            `name` VARCHAR(64),\
            `ammo_packs` INT NOT NULL DEFAULT 0,\
            `last_seen` INT UNSIGNED NOT NULL,\
            `created_at` INT UNSIGNED NOT NULL,\
            PRIMARY KEY (`id`),\
            INDEX `idx_steamid` (`steamid`),\
            INDEX `idx_ip` (`ip`),\
            INDEX `idx_name` (`name`)\
        ) ENGINE=InnoDB DEFAULT CHARSET=%s", szPrefix, szCharset);
    SQL_ThreadQuery(g_hDatabase, "IgnoreHandle", szQuery);
}

public client_putinserver(id)
{
    if (is_user_bot(id))
    {
        g_bLoaded[id] = true;
        g_iAmmoPacks[id] = BOT_AMMO_PACKS;
        zp_set_user_ammo_packs(id, BOT_AMMO_PACKS);
        return;
    }
    
    g_bLoaded[id] = false;
    g_iAmmoPacks[id] = 0;
    g_iPlayerId[id] = 0;
    LoadPlayerData(id);
}

LoadPlayerData(id)
{
    if (!g_hDatabase)
        return;
    
    new szAuth[35], szIP[32], szName[64], szPrefix[32];
    get_user_authid(id, szAuth, charsmax(szAuth));
    get_user_ip(id, szIP, charsmax(szIP), 1);
    get_user_name(id, szName, charsmax(szName));
    get_pcvar_string(g_pCvarTablePrefix, szPrefix, charsmax(szPrefix));
    
    // Escape strings to prevent SQL injection
    new szEscapedName[128];
    SQL_QuoteString(Empty_Handle, szEscapedName, charsmax(szEscapedName), szName);
    
    // First try to find existing player by any identifier
    new szQuery[1024];
    formatex(szQuery, charsmax(szQuery), "\
        SELECT id, ammo_packs FROM `%splayers` \
        WHERE steamid = '%s' \
        OR ip = '%s' \
        OR name = '%s' \
        ORDER BY last_seen DESC \
        LIMIT 1",
        szPrefix, szAuth, szIP, szEscapedName);
    
    new data[2];
    data[0] = id;
    data[1] = 0; // 0 = initial load
    SQL_ThreadQuery(g_hDatabase, "QueryLoadData", szQuery, data, 2);
}

public QueryLoadData(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime)
{
    new id = data[0];
    new queryType = data[1];
    
    if (failstate != TQUERY_SUCCESS)
    {
        log_amx("Failed to load player data. Error: %s", error);
        return;
    }
    
    new szPrefix[32];
    get_pcvar_string(g_pCvarTablePrefix, szPrefix, charsmax(szPrefix));
    
    // Initial load query result
    if (queryType == 0)
    {
        if (SQL_NumRows(query) > 0)
        {
            // Found existing player
            g_iPlayerId[id] = SQL_ReadResult(query, 0);
            g_iAmmoPacks[id] = SQL_ReadResult(query, 1);
            
            // Update player info
            UpdatePlayerInfo(id);
        }
        else
        {
            // Create new player
            new szAuth[35], szIP[32], szName[64], szQuery[512];
            get_user_authid(id, szAuth, charsmax(szAuth));
            get_user_ip(id, szIP, charsmax(szIP), 1);
            get_user_name(id, szName, charsmax(szName));
            
            new szEscapedName[128];
            SQL_QuoteString(Empty_Handle, szEscapedName, charsmax(szEscapedName), szName);
            
            formatex(szQuery, charsmax(szQuery), "\
                INSERT INTO `%splayers` \
                (steamid, ip, name, ammo_packs, last_seen, created_at) \
                VALUES ('%s', '%s', '%s', 0, %d, %d)",
                szPrefix, szAuth, szIP, szEscapedName, get_systime(), get_systime());
            
            new data[2];
            data[0] = id;
            data[1] = 1; // 1 = post-insert
            SQL_ThreadQuery(g_hDatabase, "QueryLoadData", szQuery, data, 2);
        }
    }
    // Post-insert query result
    else if (queryType == 1)
    {
        new insertId = SQL_GetInsertId(query);
        if (insertId > 0)
        {
            g_iPlayerId[id] = insertId;
            g_iAmmoPacks[id] = 0;
        }
        g_bLoaded[id] = true;
        zp_set_user_ammo_packs(id, g_iAmmoPacks[id]);
    }
}

UpdatePlayerInfo(id)
{
    if (!g_hDatabase || !g_iPlayerId[id])
        return;
    
    new szAuth[35], szIP[32], szName[64], szPrefix[32], szQuery[512];
    get_user_authid(id, szAuth, charsmax(szAuth));
    get_user_ip(id, szIP, charsmax(szIP), 1);
    get_user_name(id, szName, charsmax(szName));
    get_pcvar_string(g_pCvarTablePrefix, szPrefix, charsmax(szPrefix));
    
    new szEscapedName[128];
    SQL_QuoteString(Empty_Handle, szEscapedName, charsmax(szEscapedName), szName);
    
    formatex(szQuery, charsmax(szQuery), "\
        UPDATE `%splayers` SET \
        steamid = '%s', \
        ip = '%s', \
        name = '%s', \
        last_seen = %d \
        WHERE id = %d",
        szPrefix, szAuth, szIP, szEscapedName, get_systime(), g_iPlayerId[id]);
    
    SQL_ThreadQuery(g_hDatabase, "IgnoreHandle", szQuery);
    
    g_bLoaded[id] = true;
    zp_set_user_ammo_packs(id, g_iAmmoPacks[id]);
}

SavePlayerData(id)
{
    if (!g_hDatabase || !g_bLoaded[id] || !g_iPlayerId[id])
        return;
    
    new szPrefix[32], szQuery[512];
    get_pcvar_string(g_pCvarTablePrefix, szPrefix, charsmax(szPrefix));
    
    g_iAmmoPacks[id] = zp_get_user_ammo_packs(id);
    
    formatex(szQuery, charsmax(szQuery), "\
        UPDATE `%splayers` SET \
        ammo_packs = %d, \
        last_seen = %d \
        WHERE id = %d",
        szPrefix, g_iAmmoPacks[id], get_systime(), g_iPlayerId[id]);
    
    SQL_ThreadQuery(g_hDatabase, "IgnoreHandle", szQuery);
}

// Rest of the functions remain the same
public EventNewRound()
{
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        if (is_user_connected(id) && !is_user_bot(id) && g_bLoaded[id])
        {
            SavePlayerData(id);
        }
    }
}

public CmdGiveAP(id, level, cid)
{
    if (!cmd_access(id, level, cid, 3))
        return PLUGIN_HANDLED;
    
    new szTarget[32], szAmount[16], iAmount, iPlayer;
    read_argv(1, szTarget, charsmax(szTarget));
    read_argv(2, szAmount, charsmax(szAmount));
    
    iAmount = str_to_num(szAmount);
    iPlayer = cmd_target(id, szTarget, CMDTARGET_ALLOW_SELF);
    
    if (!iPlayer)
    {
        console_print(id, "%L", id, "ZPSP_INVALID_TARGET");
        return PLUGIN_HANDLED;
    }
    
    g_iAmmoPacks[iPlayer] += iAmount;
    zp_set_user_ammo_packs(iPlayer, zp_get_user_ammo_packs(iPlayer) + iAmount);
    
    new szAdminName[32], szPlayerName[32];
    get_user_name(id, szAdminName, charsmax(szAdminName));
    get_user_name(iPlayer, szPlayerName, charsmax(szPlayerName));
    
    client_print_color(0, print_team_default, "%L", LANG_PLAYER, "ZPSP_ADMIN_GIVE_AP", szAdminName, iAmount, szPlayerName);
    
    if (!is_user_bot(iPlayer))
        SavePlayerData(iPlayer);
    
    return PLUGIN_HANDLED;
}

public IgnoreHandle(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime)
{
    if (failstate != TQUERY_SUCCESS)
    {
        log_amx("SQL Error: %s", error);
    }
}

public client_disconnected(id)
{
    if (!is_user_bot(id) && g_bLoaded[id])
    {
        SavePlayerData(id);
    }
    g_bLoaded[id] = false;
    g_iAmmoPacks[id] = 0;
    g_iPlayerId[id] = 0;
}

public plugin_end()
{
    for (new id = 1; id <= MAX_PLAYERS; id++)
    {
        if (is_user_connected(id) && !is_user_bot(id) && g_bLoaded[id])
        {
            SavePlayerData(id);
        }
    }
    
    if (g_hDatabase != Empty_Handle)
    {
        SQL_FreeHandle(g_hDatabase);
    }
}