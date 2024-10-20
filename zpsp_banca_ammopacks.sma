#include <amxmodx>
#include <amxmisc>
#include <sqlx>
#include <zombie_plague_special>

#define PLUGIN "ZP Special: Compact Ammo Packs Saver"
#define VERSION "2.3.0"
#define AUTHOR "X"

#define ADMIN_FLAG ADMIN_LEVEL_H
#define MAX_PLAYERS 32
#define BOT_AMMO_PACKS 200

new Handle:g_hDatabase;
new bool:g_bLoaded[MAX_PLAYERS + 1];
new g_iAmmoPacks[MAX_PLAYERS + 1];

new g_pCvarHost, g_pCvarUser, g_pCvarPass, g_pCvarDbName;

public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR);
    
    g_pCvarHost = create_cvar("zpsp_mysql_host", "localhost", FCVAR_PROTECTED);
    g_pCvarUser = create_cvar("zpsp_mysql_user", "root", FCVAR_PROTECTED);
    g_pCvarPass = create_cvar("zpsp_mysql_pass", "", FCVAR_PROTECTED);
    g_pCvarDbName = create_cvar("zpsp_mysql_db", "amx", FCVAR_PROTECTED);
    
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
    new szHost[64], szUser[32], szPass[32], szDbName[32];
    get_pcvar_string(g_pCvarHost, szHost, charsmax(szHost));
    get_pcvar_string(g_pCvarUser, szUser, charsmax(szUser));
    get_pcvar_string(g_pCvarPass, szPass, charsmax(szPass));
    get_pcvar_string(g_pCvarDbName, szDbName, charsmax(szDbName));
    
    g_hDatabase = SQL_MakeDbTuple(szHost, szUser, szPass, szDbName);
    
    SQL_ThreadQuery(g_hDatabase, "IgnoreHandle", "CREATE TABLE IF NOT EXISTS zp_ammopacks (auth_id VARCHAR(35) PRIMARY KEY, name VARCHAR(32), ammo_packs INT, is_bot BOOL, last_seen INT)");
}

public client_putinserver(id)
{
    g_bLoaded[id] = false;
    g_iAmmoPacks[id] = is_user_bot(id) ? BOT_AMMO_PACKS : 0;
    
    if (!is_user_bot(id))
    {
        LoadPlayerData(id);
    }
    else
    {
        g_bLoaded[id] = true;
        zp_set_user_ammo_packs(id, BOT_AMMO_PACKS);
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
}

LoadPlayerData(id)
{
    if (!g_hDatabase)
        return;
    
    new szAuth[35], szQuery[256];
    get_user_authid(id, szAuth, charsmax(szAuth));
    formatex(szQuery, charsmax(szQuery), "SELECT ammo_packs FROM zp_ammopacks WHERE auth_id = '%s'", szAuth);
    
    new data[1];
    data[0] = id;
    SQL_ThreadQuery(g_hDatabase, "QueryLoadData", szQuery, data, 1);
}

public QueryLoadData(failstate, Handle:query, error[], errnum, data[], size, Float:queuetime)
{
    new id = data[0];
    
    if (failstate != TQUERY_SUCCESS)
    {
        log_amx("Failed to load player data. Error: %s", error);
        return;
    }
    
    if (SQL_NumResults(query) > 0)
    {
        g_iAmmoPacks[id] = SQL_ReadResult(query, 0);
    }
    else
    {
        g_iAmmoPacks[id] = 0;
        new szAuth[35], szName[32], szQuery[256];
        get_user_authid(id, szAuth, charsmax(szAuth));
        get_user_name(id, szName, charsmax(szName));
        formatex(szQuery, charsmax(szQuery), "INSERT INTO zp_ammopacks (auth_id, name, ammo_packs, is_bot, last_seen) VALUES ('%s', '%s', 0, 0, %d)", 
            szAuth, szName, get_systime());
        SQL_ThreadQuery(g_hDatabase, "IgnoreHandle", szQuery);
    }
    
    zp_set_user_ammo_packs(id, g_iAmmoPacks[id]);
    g_bLoaded[id] = true;
}

SavePlayerData(id)
{
    if (!g_hDatabase)
        return;
    
    new szAuth[35], szName[32], szQuery[256];
    get_user_authid(id, szAuth, charsmax(szAuth));
    get_user_name(id, szName, charsmax(szName));
    
    g_iAmmoPacks[id] = zp_get_user_ammo_packs(id);
    
    formatex(szQuery, charsmax(szQuery), "UPDATE zp_ammopacks SET name = '%s', ammo_packs = %d, last_seen = %d WHERE auth_id = '%s'", 
        szName, g_iAmmoPacks[id], get_systime(), szAuth);
    SQL_ThreadQuery(g_hDatabase, "IgnoreHandle", szQuery);
}

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

public zp_user_humanized_post(id)
{
    if (is_user_connected(id) && !is_user_bot(id))
    {
        zp_set_user_ammo_packs(id, g_iAmmoPacks[id]);
    }
}

public zp_user_infected_post(id)
{
    if (is_user_connected(id) && !is_user_bot(id))
    {
        zp_set_user_ammo_packs(id, g_iAmmoPacks[id]);
    }
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