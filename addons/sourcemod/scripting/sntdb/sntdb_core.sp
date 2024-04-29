#include <sourcemod>
#include <dbi>
#include <files>
#include <keyvalues>

public Plugin myinfo =
{
    name = "sntdb Map Module",
    author = "Arcala the Gyiyg",
    description = "(required) SNTDB Core Module.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{

    CreateNative("LoadMapSQLConfigs", CreateMapSQLConfigs);
    CreateNative("LoadRankSQLConfigs", CreateRankSQLConfigs);
    CreateNative("LoadStoreSQLConfigs", CreateStoreSQLConfigs);
    // CreateNative("ReturnSQLStatement",  SendSQLStatement);
    RegPluginLibrary("sntdb_core");

    return APLRes_Success;
}
/*
TODO:
    Add a command to add a user to a group ("SUPPORTER","CONTRIBUTOR","DONATOR")
    Set up other config functions
    Make this a required plugin
    Create a function to pass through data values to other plugins
*/

public void OnPluginStart() 
{
    CheckForCorePackages();
}

void CheckForCorePackages()
{
    if (!LibraryExists("sntdb_maps")) 
    {
        ThrowError("[SNT] stndb_maps.smx doesn't exist! Invalid install, aborting.");
    }
    /*else if (!LibraryExists("sntdb_ranks"))
    {
        ThrowError("[SNT] stndb_ranks.smx doesn't exist! Invalid install, aborting.");
    }
    else if (!LibraryExists("sntdb_trails"))
    {
        ThrowError("[SNT] stndb_trails.smx doesn't exist! Invalid install, aborting.");
    }
    else if (!LibraryExists("sntdb_sound"))
    {
        ThrowError("[SNT] stndb_sound.smx doesn't exist! Invalid install, aborting.");
    }
    else if (!LibraryExists("sntdb_tags"))
    {
        ThrowError("[SNT] stndb_tags.smx doesn't exist! Invalid install, aborting.");
    }
    else if (!LibraryExists("sntdb_store"))
    {
        ThrowError("[SNT] stndb_tags.smx doesn't exist! Invalid install, aborting.");
    }*/
}

int CreateMapSQLConfigs(Handle plugin, int numParams)
{

    PrintToServer("[SNT] Loading SQL configs for map module.");

    KeyValues ConfigFile = new KeyValues("ConfigFile");
    ConfigFile.ImportFromFile("addons/sourcemod/configs/sntdb/main_config.cfg");
    
    if (ConfigFile == null)
    {
        ThrowError("[SNT] ERROR! \"configs/sntdb/main_config.cfg\": file does not exist!");
        return 0;
    }

    if (!ConfigFile.JumpToKey("Maps"))
    {
        ThrowError("[SNT] ERROR! Missing \"Maps\" section from config file.");
        delete ConfigFile;
        return 0;
    }

    // Declare variables to store configs
    char dbconfig_name[32];
    char maplist_path[PLATFORM_MAX_PATH];
    
    // Gather values from config file and store it in the variables.
    ConfigFile.GetString("dbconfig",    dbconfig_name,  sizeof(dbconfig_name));
    ConfigFile.GetString("filepath",    maplist_path,    sizeof(maplist_path));

    // Print values gathered to server.
    PrintToServer("*************  MAPS  ************");
    PrintToServer("[SNT] dbconfig: %s", dbconfig_name);
    PrintToServer("[SNT] filepath: %s", maplist_path);
    PrintToServer("*********************************");

    // Return values back to the user through the function.
    SetNativeString(1, dbconfig_name, GetNativeCell(2));
    SetNativeString(3, maplist_path, GetNativeCell(4));

    delete ConfigFile;
    return 1;
}

int CreateRankSQLConfigs(Handle plugin, int numparams)
{

    PrintToServer ("[SNT] Loading SQL config for ranking module.");

    KeyValues ConfigFile = new KeyValues("ConfigFile");
    ConfigFile.ImportFromFile("addons/sourcemod/configs/sntdb/main_config.cfg");
    
    if (ConfigFile == null)
    {
        ThrowError("[SNT] ERROR! \"configs/sntdb/main_config.cfg\": file does not exist!");
        return 0;
    }

    if (!ConfigFile.JumpToKey("Ranks"))
    {
        ThrowError("[SNT] ERROR! Missing \"Ranks\" section from config file.");
        delete ConfigFile;
        return 0;
    }

    // Declare variables to store config values.
    char dbconfig_name[32];

    // Gather config values from file
    ConfigFile.GetString("dbconfig",    dbconfig_name,  sizeof(dbconfig_name));

    // Log values gathered.
    PrintToServer("*************  RANK  ************");
    PrintToServer("[SNT] dbconfig: %s", dbconfig_name);
    PrintToServer("*********************************");

    // Return values back to the user through the function.
    SetNativeString(1, dbconfig_name, GetNativeCell(2));

    delete ConfigFile;
    return 1;
}

int CreateStoreSQLConfigs(Handle plugin, int numparams)
{

    PrintToServer("[SNT] Loading SQL configs for store module.");

    KeyValues ConfigFile = new KeyValues("ConfigFile");
    ConfigFile.ImportFromFile("addons/sourcemod/configs/sntdb/main_config.cfg");
    
    if (ConfigFile == null)
    {
        ThrowError("[SNT] ERROR! \"configs/sntdb/main_config.cfg\": file does not exist!");
        return 0;
    }

    if (!ConfigFile.JumpToKey("Store"))
    {
        ThrowError("[SNT] ERROR! Missing \"Store\" section from config file.");
        delete ConfigFile;
        return 0;
    }

    char dbconfig_name[32];

    ConfigFile.GetString("dbconfig",    dbconfig_name,      sizeof(dbconfig_name));

    PrintToServer("************  STORE  ************");
    PrintToServer("[SNT] dbconfig : %s", dbconfig_name);
    PrintToServer("*********************************");

    SetNativeString(1, dbconfig_name, GetNativeCell(2));

    delete ConfigFile;
    return 1;
}