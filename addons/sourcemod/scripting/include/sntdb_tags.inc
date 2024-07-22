#if defined _sntdb_tags_included_
    #endinput
#endif
#define _sntdb_tags_included_

public SharedPlugin __pl_sntdbtags = 
{
    name = "sntdb_tags",
    file = "sntdb/sntdb_tags.smx",
    #if defined REQUIRE_PLUGIN
        required = 1,
    #else
        required = 0,
    #endif
};

enum struct TagSettings
{
    bool IsTagDisplayed;
    char TagId[64];
    char TagName[64];
    char TagDisplay[64];
    char TagColor[64];
    int TagPosition;

    void SetShowingTag(bool enabled)
    {
        this.IsTagDisplayed = enabled;
    }

    void SetTagId(char[] tag_id)
    {
        strcopy(this.TagId, 64, tag_id);
    }

    void SetTagName(char[] tag_name)
    {
        strcopy(this.TagName, 64, tag_name);
    }

    void SetTagDisplay(char[] tag_display)
    {
        strcopy(this.TagDisplay, 64, tag_display);
    }

    void SetTagColor(char[] tag_color)
    {
        strcopy(this.TagColor, 64, tag_color);
    }

    void SetTagPos(int pos)
    {
        this.TagPosition = pos;
    } 

    bool GetShowingTag()
    {
        return this.IsTagDisplayed;
    }

    void GetTagId(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TagId);
    }

    void GetTagName(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TagName);
    }

    void GetTagDisplay(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TagDisplay);
    }

    void GetTagColor(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TagColor);
    }

    int GetTagPos()
    {
        return this.TagPosition;
    }
}

/**
 * 
 * Opens the tag menu for a client
 *
 * @param client    Client index
 */
native void OpenTagMenu(int client);


/**
 * Opens the tag equip menu for a client
 * 
 * @param client    Client index
 */
native void OpenTagEquip(int client);

/**
 * Sends if the player is displaying a tag
 * 
 * @param client    Client index
 * 
 * @return true - Player is displaying, false - Player is not displaying.
 */
native bool GetPlayerTagBool(int client);