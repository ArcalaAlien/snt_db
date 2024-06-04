#if defined _sntdb_trails_included_
    #endinput
#endif
#define _sntdb_trails_included_

public SharedPlugin __pl_sntdbtrails = 
{
    name = "sntdb_trails",
    file = "sntdb/sntdb_trails.smx",
    #if defined REQUIRE_PLUGIN
        required = 1,
    #else
        required = 0,
    #endif
};

enum struct TrailInfo
{
    int TrailIndex;
    char TrailId[64];
    char TrailName[64];

    void SetId(char[] new_id)
    {
        strcopy(this.TrailId, 64, new_id);
    }

    void SetName(char[] new_name)
    {
        strcopy(this.TrailName, 64, new_name);
    }

    void GetId(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TrailId);
    }

    void GetName(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TrailName);
    }
}

/**
 * Opens the trail menu for a client.
 * 
 * @param client    Client Index
 */
native void OpenTrailMenu(int client);

/**
 * Open's the equip menu for a client.
 *
 * @param client    Client Index
 */
native void OpenTrailEquip(int client);


