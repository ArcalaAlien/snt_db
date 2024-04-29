#if defined _sntdb_core_included_
    #endinput
#endif
#define _sntdb_core_included_

public SharedPlugin __pl_sntdbcore = 
{
    name = "sntdb_core",
    file = "sntdb/sntdb_core.smx",
    #if defined REQUIRE_PLUGIN
        required = 1,
    #else
        required = 0,
    #endif
};

/**
 * Loads the configs for the map module from configs/sntdb/main_config.cfg
 * 
 * @param   dbconfig_name           char buffer to store the database profile name.
 * @param   maxlen_confbuffer       size of dbconfig_name buffer
 * @param   maplist_path            char buffer to store the file path to a map list.
 * @param   maxlen_mlbuffer         size of maplist_path buffer
 * @return                          Returns true on success, false on fail.
 */
native void LoadMapSQLConfigs(char[] dbconfig_name, int maxlen_confbuffer, char[] maplist_path, int maxlen_mlbuffer);

/**
 * Loads the configs for the ranking module from configs/sntdb/main_config.cfg
 * 
 * @param   dbconfig_name           char buffer to store the database profile name.
 * @param   maxlen_confbuffer       size of dbconfig_name buffer
 * @return                          Returns true on success, false on fail.
 */
native void LoadRankSQLConfigs(char[] dbconfig_name, int maxlen_confbuffer);

/**
 * Loads the configs for the store module from configs/sntdb/main_config.cfg
 * 
 * @param   dbconfig_name           char buffer to store the database profile name.
 * @param   maxlen_confbuffer       size of dbconfig_name buffer
 * @return                          Returns true on success, false on fail.
 */
native void LoadStoreSQLConfigs(char[] dbconfig_name, int maxlen_confbuffer);





