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
native void SNT_OpenStoreMenu(int client);

/**
 * Opens the inventory menu for a client.
 *
 * @param client    Client index
 */
native void SNT_OpenInventoryMenu(int client);

/**
 * Get a client's name color.
 * 
 * @param client        Client index
 * @param colorBuffer   char buffer for client's name color.
 * @param maxlen        length of char buffer
 */
native void SNT_GetClientNameColor(int client, char[] colorBuffer, int maxlen);

/**
 * Get a client's chat color.
 * 
 * @param client        Client index
 * @param colorBuffer   char buffer for client's chat color.
 * @param maxlen        length of char buffer
 */
native void SNT_GetClientChatColor(int client, char[] colorBuffer, int maxlen);

/**
 *  Add credits to a client
 * 
 *  @param client       Client index
 *  @param amount       Amount to add
 * 
 *  @noreturn
 */
native void SNT_AddCredits(int client, int amount);