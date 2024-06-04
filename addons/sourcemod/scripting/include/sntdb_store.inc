#if defined _sntdb_store_included_
    #endinput
#endif
#define _sntdb_store_included_

public SharedPlugin __pl_sntdbstore = 
{
    name = "sntdb_store",
    file = "sntdb/sntdb_store.smx",
    #if defined REQUIRE_PLUGIN
        required = 1,
    #else
        required = 0,
    #endif
};

/**
 * 
 * Opens the store menu for a client
 *
 * @param client    Client index
 */
native void OpenStoreMenu(int client);

/**
 * Opens the inventory menu for a client.
 *
 * @param client    Client index
 */
native void OpenInventoryMenu(int client);


