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
 * @param   maxlength               size of dbconfig_name buffer
 * @param   sysstore                Is the system calling this or the store? (0 - System, 1 - Store);
 * @param   calledby                What module called this function
 * @return                          Returns 1 on success, 0 on fail.
 */
native int LoadSQLConfigs(char[] dbconfig_name, int maxlength, int sysstore, char[] calledby);
