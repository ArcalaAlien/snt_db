#include <sourcemod>
#include <dbi>

#define REQUIRE_PLUGIN
#include <sntdb_core>

public Plugin myinfo =
{
    name = "sntdb Auto Add Early Supporter",
    author = "Arcala the Gyiyg",
    description = "Auto adds players that join the server to the early supporter group.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

char DBConfName[64];
char Prefix[96];
char SchemaName[64];
char StoreSchema[64];

Database DB_sntdb;

public void OnPluginStart()
{
    LoadSQLConfigs(DBConfName, 64, Prefix, 96, SchemaName, 64, "Auto Add Early Supporter", 1, StoreSchema, 64);
    
    char error[255];
    DB_sntdb = SQL_Connect(DBConfName, true, error, sizeof(error));
    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN STORE PLUGIN START: %s", error);
    }
}

public void OnClientPutInServer(int client)
{
    char SteamId[64];
    GetClientAuthId(client, AuthId_Steam3, SteamId, 64);

    char iQuery[512];
    Format(iQuery, 512, "INSERT INTO %splayergroups VALUES (\'%s\', 2) ON DUPLICATE KEY UPDATE SteamId=\'%s\'", StoreSchema, SteamId, SteamId);

    SQL_TQuery(DB_sntdb, SQL_ErrorHandler, iQuery);
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
