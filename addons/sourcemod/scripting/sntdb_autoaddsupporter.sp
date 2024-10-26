#include <sourcemod>
#include <sdkhooks>
#include <dbi>

#define REQUIRE_PLUGIN
#include <sntdb/core>

public Plugin myinfo =
{
    name = "sntdb Auto Add Items",
    author = "Arcala the Gyiyg",
    description = "Gives players the new 3.0 items!",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

char DBConfName[64];
char Prefix[96];
char SchemaName[64];
char StoreSchema[64];

bool lateLoad

Database DB_sntdb;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    lateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    SNT_LoadSQLConfigs(DBConfName, 64, Prefix, 96, SchemaName, 64, "3.0 Items", 1, StoreSchema, 64);
    
    char error[255];
    DB_sntdb = SQL_Connect(DBConfName, true, error, sizeof(error));
    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN STORE PLUGIN START: %s", error);
    }
    if (lateLoad)
        for (int i = 1; i < MaxClients; i++)
            OnClientPutInServer(i);
}

public void OnClientPutInServer(int client)
{
    if (SNT_IsValidClient(client))
    {
        char SteamId[64];
        GetClientAuthId(client, AuthId_Steam3, SteamId, 64);

        char iQuery[512];
        Format(iQuery, 512, "INSERT INTO %splayeritems (SteamId, ItemId) VALUES (\'%s\', 'tag_evnt_tpo') ON DUPLICATE KEY UPDATE SteamId=\'%s\';", StoreSchema, SteamId, SteamId);
        SQL_TQuery(DB_sntdb, SQL_ErrorHandler, iQuery);

        Format(iQuery, 512, "INSERT INTO %splayeritems (SteamId, ItemId) VALUES (\'%s\', 'trl_logo_orng') ON DUPLICATE KEY UPDATE SteamId=\'%s\';", StoreSchema, SteamId, SteamId);
        SQL_TQuery(DB_sntdb, SQL_ErrorHandler, iQuery);

        Format(iQuery, 512, "INSERT INTO %splayeritems (SteamId, ItemId) VALUES (\'%s\', 'trl_logo_blue') ON DUPLICATE KEY UPDATE SteamId=\'%s\';", StoreSchema, SteamId, SteamId);
        SQL_TQuery(DB_sntdb, SQL_ErrorHandler, iQuery);

        Format(iQuery, 512, "INSERT INTO %splayeritems (SteamId, ItemId) VALUES (\'%s\', 'snd_evnt_twrp') ON DUPLICATE KEY UPDATE SteamId=\'%s\';", StoreSchema, SteamId, SteamId);
        SQL_TQuery(DB_sntdb, SQL_ErrorHandler, iQuery);
    }
}

public void SQL_ErrorHandler(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] ERROR! DATABASE IS NULL!");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN QUERY: %s", error);
    }
}
