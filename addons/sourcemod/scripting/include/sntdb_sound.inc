#if defined _sntdb_sound_included_
    #endinput
#endif
#define _sntdb_sound_included_

public SharedPlugin __pl_sntdbsound = 
{
    name = "sntdb_sound",
    file = "sntdb/sntdb_sound.smx",
    #if defined REQUIRE_PLUGIN
        required = 1,
    #else
        required = 0,
    #endif
};

/**
 * 
 * Opens the sound menu for a client
 *
 * @param client    Client index
 */
native void OpenSoundMenu(int client);

/**
 * Open the sound equip menu for a client
 * 
 * @param client      Client Index
 */
native void OpenSoundEquip(int client);