#if defined _sntdb_core_included_
    #endinput
#endif
#define _sntdb_core_included_

#define ITEMDRAW_RAWTEXT ((1<<0)|(1<<1)) //RAWTEXT

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

enum struct SNT_ClientInfo
{
    // Important player info! Should always be set no matter the module calling it
    char    Name[257];
    int     ClientId;
    int     UserId;
    char    AuthId[64];

    // Player points / credits, doesn't always need to be called
    float   Points;
    int     Credits;

    // Player's customization settings.
    char    NameColor[64];
    char    TextColor[64];
    char    Tag[64];
    char    TagColor[64];

    // Player's ranking settings
    int     Position;
    int     KS;
    float   KSMult;
    bool    OwnsRankItem;
    bool    DisplayingRank;
    int     DisplayRankPos; // 0 for before, 1 for after.

    // General player settings
    TFTeam     Team;

    void SetPlayerName(const char[] plyr_name)
    {
        strcopy(this.Name, sizeof(this.Name), plyr_name);
    }

    void SetClientId(int cid)
    {
        this.ClientId = cid;
    }

    void SetUserId(int uid)
    {
        this.UserId = uid;
    }

    void SetAuthId(char[] auth_id)
    {
        strcopy(this.AuthId, sizeof(this.Name), auth_id);
    }

    void SetPoints(float num)
    {
        this.Points = num;
    }

    void AddPoints(float num)
    {
        this.Points = this.Points + num;
    }

    void RemovePoints(float num)
    {
        this.Points = this.Points - num;
    }

    void SetCredits(int num)
    {
        this.Credits = num;
    }

    void AddCredits(int num)
    {
        this.Credits = this.Credits + num
    }

    void RemoveCredits(int num)
    {
        this.Credits = this.Credits - num;
    }

    void SetNameColor(const char[] name_color)
    {
        strcopy(this.NameColor, sizeof(this.NameColor), name_color);
    }

    void SetTextColor(const char[] text_color)
    {
        strcopy(this.TextColor, sizeof(this.TextColor), text_color);
    }

    void SetTag(const char[] tag_name)
    {
        if (StrEqual(tag_name, "Unequip"))
        {
            strcopy(this.Tag, sizeof(this.Tag), "None");
        }
        else
        {
            strcopy(this.Tag, sizeof(this.Tag), tag_name);
        }
    }

    void SetTagColor(const char[] tag_color)
    {
        strcopy(this.TagColor, sizeof(this.TagColor), tag_color);
    }

    void SetRank(int place)
    {
        this.Position = place;
    }

    void AddKS()
    {
        this.KS = this.KS + 1;
    }

    void ResetKS()
    {
        this.KS = 0;
    }

    void SetMultiplier(float num)
    {
        this.KSMult = num;
    }

    void SetTeam(TFTeam new_team)
    {
        this.Team = new_team;
    }

    void SetOwnsRank(bool owns_rank)
    {
        this.OwnsRankItem = owns_rank;
    }

    void SetDisplayingRank(bool disp_rank)
    {
        this.DisplayingRank = disp_rank;
    }

    void SetRankDispPos(int pos)
    {
        this.DisplayRankPos = pos;
    }

    void GetName(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.Name);
    }

    int GetClientId()
    {
        return this.ClientId;
    }

    int GetUserId()
    {
        return this.UserId
    }

    void GetAuthId(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.AuthId);
    }

    float GetPoints()
    {
        return this.Points;
    }

    int GetCredits()
    {
        return this.Credits;
    }

    void GetNameColor(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.NameColor);
    }

    void GetTextColor(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TextColor);
    }

    void GetTag(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.Tag);
    }

    void GetTagColor(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TagColor);
    }

    int GetRank()
    {
        return this.Position;
    }

    int GetKS()
    {
        return this.KS;
    }

    float GetMultiplier()
    {
        return this.KSMult;
    }

    TFTeam GetTeam()
    {
        return this.Team;
    }

    bool GetIfOwnsRank()
    {
        return this.OwnsRankItem;

    }

    bool GetIfDisplayingRank()
    {
        return this.DisplayingRank;
    }

    int GetRankDispPos()
    {
        return this.DisplayRankPos;
    }

    void Reset()
    {
        strcopy(this.Name, sizeof(this.Name), "");
        this.ClientId = 0;
        this.UserId = 0;
        strcopy(this.AuthId, sizeof(this.AuthId), "");
        this.Points = 0.0;
        this.Credits = 0;
        strcopy(this.NameColor, sizeof(this.NameColor), "");
        strcopy(this.TextColor, sizeof(this.TextColor), "");
        strcopy(this.Tag, sizeof(this.Tag), "");
        strcopy(this.TagColor, sizeof(this.TagColor), "");
        this.Position = 0;
        this.KS = 0;
        this.KSMult = 1.0;
        this.OwnsRankItem=false;
        this.DisplayingRank=false;
        this.DisplayRankPos=0;
        this.Team = TFTeam_Unassigned;
        
    }
}

/**
 * Loads the configs for the map module from configs/sntdb/main_config.cfg
 * 
 * @param   sysornot                0 - System plugin called this, 1 - Store plugin called this
 * @param   dbconfig_name           char buffer to store the database profile name.
 * @param   maxlength               size of dbconfig_name buffer
 * @param   prefix                  The plugin's message prefix
 * @param   prefixlen               size of prefix buffer
 * @param   schema                  char array of what db schema to use
 * @param   schemalen               length of schema buffer
 * @param   calledby                What module called this function
 * @param   usingstore              0 - false, 1 - true. Used if the module needs to use the store schema too.
 * @param   store_schema            Optional buffer for the store schema
 * @param   storelen                size of store schema buffer
 * @return                          Returns 1 on success, 0 on fail.
 */
native int LoadSQLConfigs(int sysornot, const char[] dbconfig_name, int maxlength, const char[] prefix, int prefixlen, const char[] schema, int schemalen, const char[] calledby, int usingstore=0, const char[] store_schema=NULL_STRING, int storelen=0);
