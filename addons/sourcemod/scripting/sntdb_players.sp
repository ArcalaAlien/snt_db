#include <sourcemod>
#include <dbi>
#include <files>
#include <keyvalues>
#include <tf2_stocks>
#include <tf2>
#include <clientprefs>
#include <clients>
#include <menu-stocks>

// Third Party Includes
#include <chat-processor>
#include <morecolors>

#define REQUIRE_PLUGIN
#include <sntdb_core>

public Plugin myinfo =
{
    name = "sntdb Rank Module",
    author = "Arcala the Gyiyg",
    description = "SNTDB Player Handling Module.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

/*
    TODO:
        Set up cookies:
            Does player have their rank displayed?

        Set up rank display:
            Check if user bought display rank server item
            if yes:
                Open rank display menu
                Allow user to enable / disable
                Allow user to change between displaying before and after name.
*/


// Settings
enum struct PSettings
{
    // Colors for displaying ranks before client names. Places NONE - 3rd, plus default color.
    char pl0clr[32];
    char pl1clr[32];
    char pl2clr[32];
    char pl3clr[32];
    char pldclr[32];

    // Red and blu team's colors. Used to color names in chat.
    char rtmclr[32];
    char btmclr[32];

    // How many points per kill, assist, and assist if you're med.
    float pntkill;
    float pntasst;
    float pntasstmed;

    void GetPlaceColor(int place = 0, char[] buffer, int maxlen)
    {
        switch (place)
        {
            case 0:
                strcopy(buffer, maxlen, this.pl0clr);
            case 1:
                strcopy(buffer, maxlen, this.pl1clr);
            case 2:
                strcopy(buffer, maxlen, this.pl2clr);
            case 3:
                strcopy(buffer, maxlen, this.pl3clr);
            default:
                strcopy(buffer, maxlen, this.pldclr);
        }
    }

    void GetTeamColor(int team, char[] buffer, int maxlen)
    {
        switch (team)
        {
            case 2:
                strcopy(buffer, maxlen, this.rtmclr);
            case 3:
                strcopy(buffer, maxlen, this.btmclr);
        }
    }

    float GetKillPts()
    {
        return this.pntkill;
    }

    float GetAsstPts()
    {
        return this.pntasst;
    }

    float GetAsstPtsMed()
    {
        return this.pntasstmed;
    }

    void SetPlaceColor(int place, char[] color)
    {
        switch (place)
        {
            case 0:
                strcopy(this.pl0clr, 32, color);
            case 1:
                strcopy(this.pl1clr, 32, color);
            case 2:
                strcopy(this.pl2clr, 32, color);
            case 3:
                strcopy(this.pl3clr, 32, color);
            default:
                strcopy(this.pldclr, 32, color);
        }
    }

    void SetTeamColor(int team, char[] color)
    {
        switch (team)
        {
            case 2:
                strcopy(this.rtmclr, 32, color);
            case 3:
                strcopy(this.btmclr, 32, color);
        }
    }

    void SetKillPts(float points)
    {
        this.pntkill = points;
    }

    void SetAsstPts(float points)
    {
        this.pntasst = points;
    }

    void SetAsstPtsMed(float points)
    {
        this.pntasstmed = points;
    }
}

enum struct KSSettings
{

    // Level 1 - 4 Display. EG: 'Player is %s' where %s is l1-4
    char l1[32];
    char l2[32];
    char l3[32];
    char l4[32];

    // The color to display %s above in
    char l1c[32];
    char l2c[32];
    char l3c[32];
    char l4c[32];

    // The amount of kills to get to each level.
    int l1k;
    int l2k;
    int l3k;
    int l4k;

    // Each level's point modifier.
    float l1m;
    float l2m;
    float l3m;
    float l4m;

    void GetLevelDisplay(int level, char[] buffer, int maxlen)
    {
        switch (level)
        {
            case 1:
                strcopy(buffer, maxlen, this.l1);
            case 2:
                strcopy(buffer, maxlen, this.l2);
            case 3:
                strcopy(buffer, maxlen, this.l3);
            case 4:
                strcopy(buffer, maxlen, this.l4);
        }
    }

    void GetLevelColor(int level, char[] buffer, int maxlen)
    {
        switch (level)
        {
            case 1:
                strcopy(buffer, maxlen, this.l1c);
            case 2:
                strcopy(buffer, maxlen, this.l2c);
            case 3:
                strcopy(buffer, maxlen, this.l3c);
            case 4:
                strcopy(buffer, maxlen, this.l4c);
        }
    }

    int GetKillsForLevel(int level)
    {
        switch (level)
        {
            case 1:
                return this.l1k;
            case 2:
                return this.l2k;
            case 3:
                return this.l3k;
            case 4:
                return this.l4k;
            default:
                return this.l1k;
        }
    }

    float GetMultiplier(int level)
    {
        switch (level)
        {
            case 1:
                return this.l1m;
            case 2:
                return this.l2m;
            case 3:
                return this.l3m;
            case 4:
                return this.l4m;
            default:
                return this.l1m;
        }
    }

    void SetLevelDisplay(int level, char[] display)
    {
        switch (level)
        {
            case 1:
                strcopy(this.l1, 32, display);
            case 2:
                strcopy(this.l2, 32, display);
            case 3:
                strcopy(this.l3, 32, display);
            case 4:
                strcopy(this.l4, 32, display);
            default:
                strcopy(this.l1, 32, display);
        }
    }

    void SetLevelColor(int level, char[] color)
    {
        switch (level)
        {
            case 1:
                strcopy(this.l1c, 32, color);
            case 2:
                strcopy(this.l2c, 32, color);
            case 3:
                strcopy(this.l3c, 32, color);
            case 4:
                strcopy(this.l4c, 32, color);
            default:
                strcopy(this.l1c, 32, color);
        }
    }

    void SetKillsForLevel(int level, int amt)
    {
        switch (level)
        {
            case 1:
                this.l1k = amt;
            case 2:
                this.l2k = amt;
            case 3:
                this.l3k = amt;
            case 4:
                this.l4k = amt;
            default:
                this.l1k = amt;
        }
    }

    void SetMultiplier(int level, float multi)
    {
        switch (level)
        {
            case 1:
                this.l1m = multi;
            case 2:
                this.l2m = multi;
            case 3:
                this.l3m = multi;
            case 4:
                this.l4m = multi;
            default:
                this.l1m = multi;
        }
    }
}

// Setup plugin settings
char DBConfName[64];
char SchemaName[64];
char StoreSchema[64]
char Prefix[96];
PSettings PointCfg;
KSSettings KSCfg;

// Setup Player Variables
SNT_ClientInfo Player[MAXPLAYERS + 1];
Cookie RankShown;
Cookie RankDisPos;

// Setup Database
Database DB_sntdb;

// Setup Convars

ConVar BroadcastKillstreaks;

public void OnPluginStart()
{
    LoadSQLConfigs(0, DBConfName, sizeof(DBConfName), Prefix, sizeof(Prefix), SchemaName, sizeof(SchemaName), "Ranks", 1, StoreSchema, sizeof(StoreSchema));
    LoadRankSettings();

    char error[255];
    DB_sntdb = SQL_Connect(DBConfName, true, error, sizeof(error));
    if (!StrEqual(error, ""))
    {
        ThrowError("[SNT] ERROR IN PLUGIN START: %s", error);
    }

    RankShown = RegClientCookie("snt_isrankshown", "Is the player displaying their rank?", CookieAccess_Public);
    RankDisPos = RegClientCookie("snt_rankdispos", "Does the user want to display their rank before or after thier tags / names?", CookieAccess_Public);

    BroadcastKillstreaks = CreateConVar("snt_broadcastks", "0", "Used to determine where to send messages. 0: All players, 1: Only killer / killed, 2: Nobody");

    HookEvent("player_death", OnPlayerDeath);
    HookEvent("player_team", OnPlayerChangedTeam);

    RegAdminCmd("sm_snt_reloadrcfg",    ADM_ReloadCFG,  ADMFLAG_ROOT,     "Use this to reload the config file after you've changed it.");
    RegAdminCmd("sm_snt_rtest1",        ADM_TestDB,     ADMFLAG_ROOT,     "Vomit player ranks to chat. Sorry not sorry.");
    RegAdminCmd("sm_snt_rtest2",        ADM_TestEnum,   ADMFLAG_ROOT,     "Vomit player info from the custom enums i made into the console wheee");
    RegAdminCmd("sm_snt_giverankitem",  ADM_GiveItem,   ADMFLAG_ROOT,     "Gives all players in the server the srvr_rank item. for testing purposes.");
    RegAdminCmd("sm_snt_rrefresh",      ADM_RefreshDB,  ADMFLAG_BAN,      "Refresh the database for every client in the server.");

    RegConsoleCmd("sm_ranks", USR_OpenRankMenu);
    RegConsoleCmd("sm_rank", USR_OpenRankMenu);
}

void LoadRankSettings()
{
    char FilePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, FilePath, sizeof(FilePath), "configs/sntdb/main_config.cfg");

    KeyValues ConfigFile;
    ConfigFile = new KeyValues("RankConfig");
    ConfigFile.ImportFromFile(FilePath);
    if (ConfigFile.JumpToKey("Ranks"))
    {
        if (ConfigFile.JumpToKey("Points"))
        {
            char NoColor[32];
            char Color1st[32];
            char Color2nd[32];
            char Color3rd[32];
            char RegColor[32];
            char RedColor[32];
            char BluColor[32];
            float KillPoints;
            float AssistPoints;
            float AssistMedPoints;

            ConfigFile.GetString("NotPlaced", NoColor, 32);
            ConfigFile.GetString("1stColor", Color1st, 32);
            ConfigFile.GetString("2ndColor", Color2nd, 32);
            ConfigFile.GetString("3rdColor", Color3rd, 32);
            ConfigFile.GetString("RegColor", RegColor, 32);
            ConfigFile.GetString("RedTeamColor", RedColor, 32);
            ConfigFile.GetString("BluTeamColor", BluColor, 32);
            KillPoints = ConfigFile.GetFloat("KillPts");
            AssistPoints = ConfigFile.GetFloat("AssistPts");
            AssistMedPoints = ConfigFile.GetFloat("AssistPtsMed");
            
            PointCfg.SetPlaceColor(0, NoColor);
            PointCfg.SetPlaceColor(1, Color1st);
            PointCfg.SetPlaceColor(2, Color2nd);
            PointCfg.SetPlaceColor(3, Color3rd);
            PointCfg.SetPlaceColor(4, RedColor);
            PointCfg.SetTeamColor(2, RedColor);
            PointCfg.SetTeamColor(3, BluColor);
            PointCfg.SetKillPts(KillPoints);
            PointCfg.SetAsstPts(AssistPoints);
            PointCfg.SetAsstPtsMed(AssistMedPoints);
        }
    }
    ConfigFile.Rewind();
    if (ConfigFile.JumpToKey("Ranks"))
    {
        if (ConfigFile.JumpToKey("Killstreaks"))
        {
            char Disp1[32];
            char Disp2[32];
            char Disp3[32];
            char Disp4[32];
            char Color1[32];
            char Color2[32];
            char Color3[32];
            char Color4[32];
            int Kills1;
            int Kills2;
            int Kills3;
            int Kills4;
            float Multi1;
            float Multi2;
            float Multi3;
            float Multi4;

            ConfigFile.GetString("L1Name", Disp1, 32);
            ConfigFile.GetString("L2Name", Disp2, 32);
            ConfigFile.GetString("L3Name", Disp3, 32);
            ConfigFile.GetString("L4Name", Disp4, 32);
            ConfigFile.GetString("L1Color", Color1, 32);
            ConfigFile.GetString("L2Color", Color2, 32);
            ConfigFile.GetString("L3Color", Color3, 32);
            ConfigFile.GetString("L4Color", Color4, 32);
            Kills1 = ConfigFile.GetNum("KillsToL1");
            Kills2 = ConfigFile.GetNum("KillsToL2");
            Kills3 = ConfigFile.GetNum("KillsToL3");
            Kills4 = ConfigFile.GetNum("KillsToL4");
            Multi1 = ConfigFile.GetFloat("L1Multip");
            Multi2 = ConfigFile.GetFloat("L2Multip");
            Multi3 = ConfigFile.GetFloat("L3Multip");
            Multi4 = ConfigFile.GetFloat("L4Multip");

            KSCfg.SetLevelDisplay(1, Disp1);
            KSCfg.SetLevelDisplay(2, Disp2);
            KSCfg.SetLevelDisplay(3, Disp3);
            KSCfg.SetLevelDisplay(4, Disp4);
            KSCfg.SetLevelColor(1, Color1);
            KSCfg.SetLevelColor(2, Color2);
            KSCfg.SetLevelColor(3, Color3);
            KSCfg.SetLevelColor(4, Color4);
            KSCfg.SetKillsForLevel(1, Kills1);
            KSCfg.SetKillsForLevel(2, Kills2);
            KSCfg.SetKillsForLevel(3, Kills3);
            KSCfg.SetKillsForLevel(4, Kills4);
            KSCfg.SetMultiplier(1, Multi1);
            KSCfg.SetMultiplier(2, Multi2);
            KSCfg.SetMultiplier(3, Multi3);
            KSCfg.SetMultiplier(4, Multi4);
        }
    }
    ConfigFile.Close();
}

// Forwards //

public void OnClientPutInServer(int client)
{
    PrintToServer("[SNT] Client joined the server");
    if (IsClientConnected(client) && !IsFakeClient(client))
    {
        if (AreClientCookiesCached(client))
        {
            PrintToServer("[SNT] Cookies for client are cached.");
            char Cookie1[10];
            char Cookie2[10];
            GetClientCookie(client, RankShown, Cookie1, sizeof(Cookie1));
            GetClientCookie(client, RankDisPos, Cookie2, sizeof(Cookie2));

            if (Cookie1[0] == '\0')
            {
                SetClientCookie(client, RankShown, "false");
                Player[client].SetDisplayingRank(false)
            }
            else
            {
                if (StrEqual(Cookie1, "true"))
                {
                    Player[client].SetDisplayingRank(true);
                }
                else
                {
                    Player[client].SetDisplayingRank(false);
                }
            }
            
            if (Cookie2[0] == '\0')
            {
                SetClientCookie(client, RankDisPos, "after");
                Player[client].SetRankDispPos(1);
            }
            else
            {
                if (StrEqual(Cookie2, "0"))
                {
                    Player[client].SetRankDispPos(0);
                }
                else
                {
                    Player[client].SetRankDispPos(1);
                }
            }
        }
        else
        {
            Player[client].SetRankDispPos(1);
            Player[client].SetDisplayingRank(false);
        }


        char SteamId[64];
        GetClientAuthId(client, AuthId_Steam3, SteamId, sizeof(SteamId));
        
        DataPack Client_Info;
        Client_Info = CreateDataPack();
        Client_Info.WriteCell(client);
        Client_Info.WriteString(SteamId);

        char sQuery[512];
        Format(sQuery, sizeof(sQuery), "SELECT SteamId, PlayerName, Points FROM %splayers ORDER BY Points DESC", SchemaName)
        SQL_TQuery(DB_sntdb, SQL_GetPlayerInfo, sQuery, Client_Info)
    }
}

public void OnClientDisconnect(int client)
{
    Player[client].Reset();
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    // Get our point values!
    float KillPts = PointCfg.GetKillPts();
    float AssistPts = PointCfg.GetAsstPts();
    float AssistPtsMed = PointCfg.GetAsstPtsMed();

    // UserIds
    int VictimId = GetEventInt(event, "userid");
    int AttackerId = GetEventInt(event, "attacker");
    int AssisterId = GetEventInt(event, "assister");

    // Gotta convert to client indexes
    int victim = GetClientOfUserId(VictimId);
    int attacker = GetClientOfUserId(AttackerId);
    int assister = GetClientOfUserId(AssisterId);

    if (attacker != 0 && attacker != victim && victim != 0)
    {
        if (!IsFakeClient(attacker) && !IsFakeClient(victim))
        {
            // We need our attacker's SteamId!
            char ASteamId[64];
            Player[attacker].GetAuthId(ASteamId, sizeof(ASteamId));

            char vname[128];
            Player[victim].GetName(vname, sizeof(vname));

            char aname[128];
            Player[attacker].GetName(aname, sizeof(aname));

            // Get our attacker's current points.
            float APts = Player[attacker].GetPoints();

            // Check the killstreak, send the correct message out, set the correct multiplier.
            HandleKillstreak(victim, attacker);

            // Get point multilpier.
            float Multi = Player[attacker].GetMultiplier();

            // Add our points and multiply it by the KS bonus.
            APts = APts + (KillPts * Multi);
            CPrintToChat(attacker, "%s You got %.1f points for killing {yellowgreen}%s{default}!", Prefix, aname, (KillPts*Multi), vname);

            // Update the player's points in the table.
            char uQuery[512];
            Format(uQuery, sizeof(uQuery), "UPDATE %splayers SET Points=%f WHERE SteamId=\'%s\'", SchemaName, APts, ASteamId);

            DataPack SentQuery;
            SentQuery = CreateDataPack();
            WritePackString(SentQuery, uQuery);
            SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery, SentQuery);

            // Create a datapack to send the client index and steamid through to the SQL function
            DataPack Attacker_Info;
            Attacker_Info = CreateDataPack();
            Attacker_Info.WriteCell(attacker);
            Attacker_Info.WriteString(ASteamId);

            // Get player's updated rank info
            char sQuery[512];
            Format(sQuery, sizeof(sQuery), "SELECT * FROM %splayers ORDER BY Points DESC", SchemaName);
            SQL_TQuery(DB_sntdb, SQL_GetPlayerRank, sQuery, Attacker_Info);

            // If AssisterId isn't 0
            if (assister != 0 && !IsFakeClient(assister))
            {
                
                // Get client's SteamId
                char SSteamId[64];
                Player[assister].GetAuthId(SSteamId, sizeof(SSteamId));

                DataPack Assister_Info;
                Assister_Info = CreateDataPack();
                Assister_Info.WriteCell(assister);
                Assister_Info.WriteString(SSteamId);

                char asname[128];
                Player[assister].GetName(asname, sizeof(asname));

                // Get client's Points
                float SPts = Player[assister].GetPoints();

                // assister doesn't get multiplied by their killstreak, because they didn't kill the person.
                // Is client a medic?
                if (TF2_GetPlayerClass(assister) == TFClass_Medic)
                {
                    // Yes, they get special treatment.
                    SPts = SPts + AssistPtsMed;            
                    CPrintToChat(attacker, "%s You got %.1f points for helping kill {yellowgreen}%s{default}!", Prefix, AssistPtsMed, vname);
                }
                else
                {
                    // No, they get regular treatment.
                    SPts = SPts + AssistPts;
                    CPrintToChat(attacker, "%s You got %.1f for points helping kill {yellowgreen}%s{default}!", Prefix, AssistPts, vname);
                }

                //Update the points on our side.
                Player[assister].SetPoints(SPts);
                
                //Update the points on the database's side.
                Format(uQuery, sizeof(uQuery), "UPDATE %splayers SET Points=%f WHERE SteamId=\'%s\'", SchemaName, SPts, SSteamId);
                DataPack SentQuery2;
                SentQuery2 = CreateDataPack();
                WritePackString(SentQuery2, uQuery);
                SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery, SentQuery2);

                // Get player's updated rank info
                Format(sQuery, sizeof(sQuery), "SELECT * FROM %splayers ORDER BY Points DESC", SchemaName);
                SQL_TQuery(DB_sntdb, SQL_GetPlayerRank, sQuery, Assister_Info);
            }
        }
    }
    if (attacker == victim)
    {
        HandleKillstreak(attacker, victim);
    }
}

public void OnPlayerChangedTeam(Event event, const char[] name, bool dontBroadcast)
{
    int User = GetClientOfUserId(GetEventInt(event, "userid"));
    int TeamNum = GetEventInt(event, "team");

    switch (TeamNum)
    {
        case 1:
            Player[User].SetTeam(TFTeam_Spectator);
        case 2:
            Player[User].SetTeam(TFTeam_Red);
        case 3:
            Player[User].SetTeam(TFTeam_Blue);
        default:
            Player[User].SetTeam(TFTeam_Unassigned);
    }
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
    bool IsDisplayed;
    int DispPos;

    IsDisplayed = Player[author].GetIfDisplayingRank();
    DispPos = Player[author].GetRankDispPos();

    if (IsDisplayed)
    {
        int pos;
        char pos_color[64];
        pos = Player[author].GetRank();

        PointCfg.GetPlaceColor(pos, pos_color, sizeof(pos_color));
        char temp_name[512];
        switch (DispPos)
        {
            case 0:
            {
                switch(pos)
                {
                    case 0:
                        Format(temp_name, 512, "%s[NA] {white}| {teamcolor}%s{default}", pos_color, name);
                    case 1:
                        Format(temp_name, 512, "%s[#1] {white}| {teamcolor}%s{default}", pos_color, name);
                    case 2:
                        Format(temp_name, 512, "%s[#2] {white}| {teamcolor}%s{default}", pos_color, name);
                    case 3:
                        Format(temp_name, 512, "%s[#3] {white}| {teamcolor}%s{default}", pos_color, name);
                    default:
                        Format(temp_name, 512, "%s[#%i] {white}| {teamcolor}%s{default}", pos_color, pos, name);
                }
            }
            case 1:
            {
                switch(pos)
                {
                    case 0:
                        Format(temp_name, 512, "{teamcolor}%s {white}| %s[NA]{default}", name, pos_color);
                    case 1:
                        Format(temp_name, 512, "{teamcolor}%s {white}| %s[#1]{default}", name, pos_color);
                    case 2:
                        Format(temp_name, 512, "{teamcolor}%s {white}| %s[#2]{default}", name, pos_color);
                    case 3:
                        Format(temp_name, 512, "{teamcolor}%s {white}| %s[#3]{default}", name, pos_color);
                    default:
                        Format(temp_name, 512, "{teamcolor}%s {white}| %s[#%i]{default}", name, pos_color, pos);
                }
            }
        }

        strcopy(name, 512, temp_name);
        return Plugin_Changed;
    }
    return Plugin_Changed;
}

// Custom functions

int KSMessage(int victim, int attacker, char[] string)
{
    int mode = GetConVarInt(BroadcastKillstreaks);
    switch (mode)
    {
        case 0:
        {
            CPrintToChatAll(string);
            return 1;
        }

        case 1:
        {
            CPrintToChat(victim, string);
            CPrintToChat(attacker, string);
            return 1;
        }

        default:
            return 0;
    }
} 

void HandleKillstreak(int victim, int attacker)
{
    if (!IsFakeClient(victim) && !IsFakeClient(attacker))
    {
        // Get the kills needed for each level of killstreak
        int Level1Kills;
        int Level2Kills;
        int Level3Kills;
        int Level4Kills;
        Level1Kills = KSCfg.GetKillsForLevel(1);
        Level2Kills = KSCfg.GetKillsForLevel(2);
        Level3Kills = KSCfg.GetKillsForLevel(3);
        Level4Kills = KSCfg.GetKillsForLevel(4);

        // Get the attacker and victim's teams.
        TFTeam VTeam = Player[victim].GetTeam();
        TFTeam ATeam = Player[attacker].GetTeam();

        // Get the attacker and victim's names.
        char VName[257];
        char AName[257];
        Player[victim].GetName(VName, sizeof(VName));
        Player[attacker].GetName(AName, sizeof(AName));

        // Get the attacker and victim's team colors for chat.
        char VTeamColor[64];
        char ATeamColor[64];
        if (VTeam == TFTeam_Red)
            PointCfg.GetTeamColor(2, VTeamColor, sizeof(VTeamColor));
        else if (VTeam == TFTeam_Blue)
            PointCfg.GetTeamColor(3, VTeamColor, sizeof(VTeamColor));
        else
            Format(VTeamColor, sizeof(VTeamColor), "{darkgrey}");
        
        if (ATeam == TFTeam_Red)
            PointCfg.GetTeamColor(2, ATeamColor, sizeof(ATeamColor));
        else if (ATeam == TFTeam_Blue)
            PointCfg.GetTeamColor(3, ATeamColor, sizeof(ATeamColor));
        else
            Format(ATeamColor, sizeof(ATeamColor), "{darkgrey}");

        // Get the value of each killstreak level. "Player is %s" where %s is the "name".
        char L1Name[32];
        char L2Name[32];
        char L3Name[32];
        char L4Name[32];
        KSCfg.GetLevelDisplay(1, L1Name, sizeof(L1Name));
        KSCfg.GetLevelDisplay(2, L2Name, sizeof(L2Name));
        KSCfg.GetLevelDisplay(3, L3Name, sizeof(L3Name));
        KSCfg.GetLevelDisplay(4, L4Name, sizeof(L4Name));

        // Get the color of each killstreak level's "name"
        char L1Color[32];
        char L2Color[32];
        char L3Color[32];
        char L4Color[32];
        KSCfg.GetLevelColor(1, L1Color, sizeof(L1Color));
        KSCfg.GetLevelColor(2, L2Color, sizeof(L2Color));
        KSCfg.GetLevelColor(3, L3Color, sizeof(L3Color));
        KSCfg.GetLevelColor(4, L4Color, sizeof(L4Color));

    // HOOH that's a lot of variables, oopsie?

        // Did they kill themselves?

        // Set up message to be broadcast.
        char msg[512];
        if (victim == attacker && Player[victim].GetKS() >= 5)
        {
            // Reset the victim's killstreak count please!
            Player[victim].ResetKS();

            // Format msg: "[SNT] Victim ended their own life"
            Format(msg, sizeof(msg), "%s %s%s {white}ended their own life!", Prefix, VTeamColor, VName);

            // Broadcast msg
            KSMessage(victim, attacker, msg);
        }

        // Were they killed by the server?
        else if (attacker == 0 && Player[victim].GetKS() >= 5)
        {
            Player[victim].ResetKS();

            // Format msg: "[SNT] Victim was smote by a mysterious force!"
            Format(msg, sizeof(msg), "%s %s%s {white}was smote by a mysterious force!", Prefix, VTeamColor, VName);
            KSMessage(victim, attacker, msg);
        }

        // Regular operation
        else
        {
            // If the victim had more than 5 kills, broadcast the killstreak message.
            if  (Player[victim].GetKS() >= 5)
            {
                // Format msg: "[SNT] Attacker ended Victim's killstreak!"
                Format(msg, sizeof(msg), "%s %s%s {white}ended %s%s's {white}killstreak!", Prefix, ATeamColor, AName, VTeamColor, VName);
                KSMessage(victim, attacker, msg);
            }

            // Reset the victim's killstreak count please!
            Player[victim].ResetKS();

            // Add 1 to the attacker's kill count.
            Player[attacker].AddKS();

            // Check how many kills the attacker has now
            if (Player[attacker].GetKS() == Level1Kills)
            {
                    // Format chat message. "[SNT] Player is <ks_name>"
                    Format(msg, sizeof(msg), "%s %s%s {white}is %s%s!", Prefix, ATeamColor, AName, L1Color, L1Name);

                    // Set player's multiplier for the appropriate level.
                    Player[attacker].SetMultiplier(KSCfg.GetMultiplier(1));
            }
            else if (Player[attacker].GetKS() == Level2Kills)
            {
                    Format(msg, sizeof(msg), "%s %s%s {white}is %s%s!", Prefix, ATeamColor, AName, L1Color, L1Name);
                    Player[attacker].SetMultiplier(KSCfg.GetMultiplier(2));
            }
            else if (Player[attacker].GetKS() == Level3Kills)
            {
                    Format(msg, sizeof(msg), "%s %s%s {white}is %s%s!", Prefix, ATeamColor, AName, L1Color, L1Name);
                    Player[attacker].SetMultiplier(KSCfg.GetMultiplier(3));
            }
            else if (Player[attacker].GetKS() == Level4Kills)
            {
                    Format(msg, sizeof(msg), "%s %s%s {white}is %s%s!", Prefix, ATeamColor, AName, L1Color, L1Name);
                    Player[attacker].SetMultiplier(KSCfg.GetMultiplier(4));
            }
            else if (Player[attacker].GetKS() > Level4Kills)
            {
                    Format(msg, sizeof(msg), "%s %s%s {white}is still %s%s!", Prefix, ATeamColor, AName, L1Color, L1Name);
                    Player[attacker].SetMultiplier(KSCfg.GetMultiplier(4));
            }
            // Broadcast the message
            KSMessage(victim, attacker, msg);
        }
    }
}

void BuildPlayerList(int client)
{
    PrintToServer("[SNT] BuildPlayerList: Init");
    PrintToServer("[SNT] BuildPlayerList: Build Menu");
    Menu PlayerList = new Menu(PlayerList_Handler, MENU_ACTIONS_DEFAULT);
    PlayerList.SetTitle("Choose a player to view:");
    SetMenuExitBackButton(PlayerList, true);

    for (int i = 0; i <= GetClientCount(); i++)
    {
        if (i == 0)
        {
            PrintToServer("[SNT] Server is not a valid client.)");
        }
        else
        {
            PrintToServer("[SNT] BuildPlayerList: Index %i", i);
            if (!IsFakeClient(i))
            {
                PrintToServer("[SNT] BuildPlayerList: Client %i", i);
                PrintToServer("[SNT] BuildPlayerList: player is real");
                char SteamId[64];
                char PlayerName[257];

                Player[i].GetAuthId(SteamId, sizeof(SteamId));
                Player[i].GetName(PlayerName, sizeof(PlayerName));

                PrintToServer("[SNT] BuildPlayerList: Updated steamid and name for player serverside");
                PlayerList.AddItem(SteamId, PlayerName);
                PrintToServer("[SNT] BuildPlayerList: Added %s, %s to menu", PlayerName, SteamId);
            }
            else
            {
                PrintToServer("[SNT] Client is fake.");
            }
        }
    }
    PrintToServer("[SNT] BuildPlayerList: Display menu to client");
    PlayerList.Display(client, MENU_TIME_FOREVER);
}

void BuildRankDispMenu(int client)
{
    if (Player[client].GetIfOwnsRank())
    {
        Panel DispPanel = CreatePanel(INVALID_HANDLE);
        DispPanel.SetTitle("Rank Display Settings");

        DispPanel.DrawText(" ");


        bool IsDisplayed;
        int DispPos;
        IsDisplayed = Player[client].GetIfDisplayingRank();
        DispPos = Player[client].GetRankDispPos();

        if (IsDisplayed)
            DispPanel.DrawText("Current status: Displaying");
        else
            DispPanel.DrawText("Current status: Hiding")

        DispPanel.DrawItem("Toggle rank display", 0);
        DispPanel.DrawText(" ");

        if (DispPos == 0)
            DispPanel.DrawText("Current position: Before name");
        else
            DispPanel.DrawText("Current position: After name");

        DispPanel.DrawItem("Toggle rank position", 0);
        DispPanel.DrawText(" ");
        DispPanel.DrawItem("Main Menu", 0);
        DispPanel.Send(client, PlacePanel_Handler, 15);
    }
    else
    {
        CPrintToChat(client, "{rblxreallyred}You have to buy this from the store first.\n\t  {white}Use {greenyellow}/store {white}to open the menu!", Prefix);
    }
}

void BuildPlayerInfoMenu(int client, DataPack data)
{
    char player_name[128];
    int  rank;
    float points;

    ResetPack(data);
    ReadPackString(data, player_name, 128);
    points = ReadPackFloat(data);
    rank = ReadPackCell(data);

    Panel InfoPanel = CreatePanel(INVALID_HANDLE);
    InfoPanel.SetTitle("Viewing Player Info:");

    char NameLine[196];
    char RankLine[32];
    char PointsLine[32];

    Format(NameLine, 196, "Player Name: %s", player_name);
    Format(RankLine, 32, "Player Rank: %i", rank);
    Format(PointsLine, 32, "Current Points: %.1f", points);

    InfoPanel.DrawText(" ");
    InfoPanel.DrawText(NameLine);
    InfoPanel.DrawText(RankLine);
    InfoPanel.DrawText(PointsLine);
    InfoPanel.DrawText(" ");
    InfoPanel.DrawItem("Player List");
    InfoPanel.DrawItem("Main Menu");
    InfoPanel.Send(client, InfoPanel_Handler, 30);
}

void BuildPage1Menu(int client)
{
    Menu Page1 = new Menu(Page1_Handler, MENU_ACTIONS_DEFAULT);
    Page1.SetTitle("SNT Ranks");
    Page1.AddItem("VYR", "View your stats!");
    Page1.AddItem("VPR", "View other player's stats!");
    Page1.AddItem("TOP", "Top 10 Players!");
    Page1.AddItem("DISP", "Toggle Rank Display!");
    Page1.Display(client, 10);
}

void TestEnums()
{
    for (int i = 1; i <= GetClientCount(); i++)
    {
        char Name[128];
        int client;
        int uid;
        char SteamId[64];
        int rank;
        float points;
        int ks;
        float multiplier;

        Player[i].GetName(Name, sizeof(Name));
        client = Player[i].GetClientId();
        uid = Player[i].GetUserId();
        Player[i].GetAuthId(SteamId, sizeof(SteamId));
        rank = Player[i].GetRank();
        points = Player[i].GetPoints();
        ks = Player[i].GetKS();
        multiplier = Player[i].GetMultiplier();

        PrintToServer("[    SNT PLAYER    ]");
        PrintToServer("* Name: %s", Name);
        PrintToServer("* ClientId: %i", client);
        PrintToServer("* UserId: %i", uid);
        PrintToServer("* AuthId: %s", SteamId);
        PrintToServer("* Rank: %i", rank);
        PrintToServer("* Points: %.1f", points);
        PrintToServer("* Killstreak: %i", ks);
        PrintToServer("* Multiplier: %.1f", multiplier);
        PrintToServer("[        END       ]");
    }
}

// SQL Functions //

public void SQL_ErrorHandler(Database db, DBResultSet results, const char[] error, any data)
{
    char offendingQuery[512];
    ResetPack(data);
    ReadPackString(data, offendingQuery, 512);

    if (db == null)
    {
        PrintToServer("[SNT] ERROR! DATABASE IS NULL!");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN QUERY! %s", error);
        PrintToServer("[SNT] OFFENDING QUERY: %s", error);
    }
}

public void SQL_GetPlayerInfo(Database db, DBResultSet results, const char[] error, any data)
{
    int client;
    char SteamId[64];

    ResetPack(data);
    client = ReadPackCell(data);
    ReadPackString(data, SteamId, sizeof(SteamId));
    CloseHandle(data);

    char PlayerName[128];
    char PlayerNameEsc[257];

    GetClientName(client, PlayerName, 128);
    SQL_EscapeString(db, PlayerName, PlayerNameEsc, 257);
    while (SQL_FetchRow(results))
    {
        char SQL_SteamId[64];
        SQL_FetchString(results, 0, SQL_SteamId, 64);

        if (StrEqual(SQL_SteamId, SteamId))
        {
            PrintToServer("[SNT] SQL_GetPlayerInfo: Found player in table.");
            char RetrievedName[128];
            SQL_FetchString(results, 1, RetrievedName, sizeof(RetrievedName));

            Player[client].SetPlayerName(RetrievedName);
            Player[client].SetClientId(client);
            Player[client].SetUserId(GetClientUserId(client));
            Player[client].SetAuthId(SteamId);
            Player[client].SetPoints(SQL_FetchFloat(results, 1));
            Player[client].ResetKS();
            Player[client].SetMultiplier(1.0);

            char uQuery[768];
            Format(uQuery, sizeof(uQuery), "UPDATE %splayers SET PlayerName=\'%s\' WHERE SteamId=\'%s\'", SchemaName, PlayerNameEsc, SteamId)

            DataPack SentQuery;
            SentQuery = CreateDataPack();
            WritePackString(SentQuery, uQuery);
            SQL_TQuery(db, SQL_ErrorHandler, uQuery, SentQuery);

            char sQuery1[256];
            Format(sQuery1, sizeof(sQuery1), "SELECT SteamId, Points FROM %splayers ORDER BY Points DESC", SchemaName);
            
            DataPack Relay_Info1;
            Relay_Info1 = CreateDataPack();
            WritePackCell(Relay_Info1, client);
            WritePackString(Relay_Info1, SteamId);
            SQL_TQuery(db, SQL_GetPlayerRank, sQuery1, Relay_Info1);

            char sQuery2[256];
            Format(sQuery2, sizeof(sQuery2), "SELECT SteamId, ItemId FROM %sInventories", StoreSchema, SteamId);
            
            DataPack Relay_Info2;
            Relay_Info2 = CreateDataPack();
            WritePackCell(Relay_Info2, client);
            WritePackString(Relay_Info2, SteamId);
            SQL_TQuery(db, SQL_CheckPlayerInventory, sQuery2, Relay_Info2);
            break;
        }

        if (!SQL_MoreRows(results))
        {
            PrintToServer("[SNT] SQL_GetPlayerInfo: Player is not in table.");
            char ClientName[128];
            char ClientNameEsc[257];

            GetClientName(client, ClientName, 128);
            SQL_EscapeString(db, ClientName, ClientNameEsc, 257);

            CPrintToChatAll("%s Welcome {rblxsunrise}%s {default}to the server!", Prefix, ClientName);

            Player[client].SetPlayerName(ClientName);
            Player[client].SetClientId(client);
            Player[client].SetUserId(GetClientUserId(client));
            Player[client].SetAuthId(SteamId);
            Player[client].SetPoints(0.0);
            Player[client].SetRank(0);
            Player[client].ResetKS();
            Player[client].SetMultiplier(1.0);
            Player[client].SetOwnsRank(false);
            Player[client].SetRankDispPos(1);

            char iQuery[512];
            Format(iQuery, sizeof(iQuery), "INSERT INTO %splayers (SteamId, PlayerName) VALUES (\'%s\', \'%s\')", SchemaName, SteamId, ClientNameEsc);

            DataPack SentQuery;
            SentQuery = CreateDataPack();
            WritePackString(SentQuery, iQuery);
            SQL_TQuery(db, SQL_ErrorHandler, iQuery, SentQuery);
        }
    }
}

public void SQL_GetPlayerRank(Database db, DBResultSet results, const char[] error, any data)
{
    int place;
    int client;
    char SteamId[64];

    ResetPack(data);
    client = ReadPackCell(data);
    ReadPackString(data, SteamId, sizeof(SteamId));

    while (SQL_FetchRow(results))
    {
        place++;
        char SQL_SteamId[64];
        float Points;

        SQL_FetchString(results, 0, SQL_SteamId, sizeof(SQL_SteamId));
        Points = SQL_FetchFloat(results, 1);

        if (StrEqual(SQL_SteamId, SteamId))
        {
            PrintToServer("[SNT] SQL_GetPlayerRank: Setting plugin-side rank and points for client.");
            Player[client].SetRank(place);
            Player[client].SetPoints(Points);
        }
    }

    CloseHandle(data);
}

public void SQL_TestDB(Database db, DBResultSet results, const char[] error, any data)
{
    int row;

    CPrintToChatAll("%s Values from Database:", Prefix);

    while (SQL_FetchRow(results))
    {
        float PlyrPoints;
        char PlyrName[128];
        SQL_FetchString(results, 0, PlyrName, sizeof(PlyrName));
        PlyrPoints = SQL_FetchFloat(results, 1);

        row++;
        CPrintToChatAll("%s {darkgrey}%i{cyan}| %s{white}: %.1f points.", Prefix, row, PlyrName, PlyrPoints);
        SQL_FetchMoreResults(results);
    }
}

public void SQL_GetPlayerInfoMenu(Database db, DBResultSet results, const char[] error, any data)
{
    int client;
    char SteamId[64];

    ResetPack(data);
    client = ReadPackCell(data);
    ReadPackString(data, SteamId, sizeof(SteamId));

    int row;
    while (SQL_FetchRow(results))
    {
        row++;
        char SQL_SteamId[64];
        SQL_FetchString(results, 0, SQL_SteamId, sizeof(SQL_SteamId));

        if (StrEqual(SteamId, SQL_SteamId))
        {
            char SQL_PlayerName[128];
            float SQL_PlayerPoints;
            SQL_FetchString(results, 1, SQL_PlayerName, sizeof(SQL_PlayerName));
            SQL_PlayerPoints = SQL_FetchFloat(results, 2);

            DataPack Info_Pack;
            Info_Pack = CreateDataPack();
            Info_Pack.WriteString(SQL_PlayerName);
            Info_Pack.WriteFloat(SQL_PlayerPoints);
            Info_Pack.WriteCell(row);

            BuildPlayerInfoMenu(client, Info_Pack);
        }
        else
        {
            PrintToServer("[SNT] SQL_GetPlayerInfoMenu: Unable to find a player match.");
        }
    }
}

public void SQL_BuildTop10(Database db, DBResultSet results, const char[] error, any data)
{
    int client;

    ResetPack(data);
    client = ReadPackCell(data);

    Menu Top10List = new Menu(PlayerList_Handler, MENU_ACTIONS_DEFAULT);
    Top10List.SetTitle("Top 10 Players:");
    SetMenuExitBackButton(Top10List, true);

    while (SQL_FetchRow(results))
    {
        char SQL_SteamId[64];
        char SQL_PlayerName[128];
        SQL_FetchString(results, 0, SQL_SteamId, sizeof(SQL_SteamId));
        SQL_FetchString(results, 1, SQL_PlayerName, sizeof(SQL_PlayerName));
        Top10List.AddItem(SQL_SteamId, SQL_PlayerName);
        SQL_FetchMoreResults(results);
    }

    Top10List.Display(client, MENU_TIME_FOREVER);
    CloseHandle(data);
}

public void SQL_CheckPlayerInventory(Database db, DBResultSet results, const char[] error, any data)
{
    int client;
    char SteamId[64];

    ResetPack(data);
    client = ReadPackCell(data);
    ReadPackString(data, SteamId, sizeof(SteamId));

    while (SQL_FetchRow(results))
    {
        char SQL_SteamId[64];
        SQL_FetchString(results, 0, SQL_SteamId, sizeof(SQL_SteamId));
        char ItemId[64];
        SQL_FetchString(results, 1, ItemId, sizeof(ItemId));

        if (StrEqual(SteamId, SQL_SteamId))
        {
            if (StrEqual(ItemId, "srv_rank"))
            {
                PrintToServer("[SNT] SQL_CheckPlayerInventory: Found rank item");
                Player[client].SetOwnsRank(true);
            }
        }
    }

    CloseHandle(data);
}

// Menus

public int PlacePanel_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            if (param2 == 1)
            {
                bool IsDisplayed = Player[param1].GetIfDisplayingRank();
                Player[param1].SetDisplayingRank(!IsDisplayed);
                if (IsDisplayed)
                {
                    // it's backwards, shit.
                    CPrintToChat(param1, "%s You are no longer displaying your rank!", Prefix)
                }
                else
                {
                    // here too
                    CPrintToChat(param1, "%s You are now displaying your rank!", Prefix)
                }

                BuildRankDispMenu(param1);
            }
            else if (param2 == 2)
            {
                int disp_pos;
                disp_pos = Player[param1].GetRankDispPos();

                switch (disp_pos)
                {
                    case 0:
                    {
                        // here too as well
                        CPrintToChat(param1, "%s Displaying your rank after your name.", Prefix)
                        Player[param1].SetRankDispPos(1);
                    }
                    case 1:
                    {
                        // and here :(
                        CPrintToChat(param1, "%s Displaying your rank before your name.", Prefix)
                        Player[param1].SetRankDispPos(0);
                    }
                }

                BuildRankDispMenu(param1);
            }
            else if (param2 == 3)
            {
                BuildPage1Menu(param1);
            }
        }
        case MenuAction_Cancel:
        {
            CloseHandle(menu);
        }
    }
    return 0;
}

public int Page1_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char SteamId[64];
            GetClientAuthId(param1, AuthId_Steam3, SteamId, sizeof(SteamId));

            DataPack Client_Info;
            Client_Info = CreateDataPack();
            Client_Info.WriteCell(param1);
            Client_Info.WriteString(SteamId);
            
            char Option[6];
            GetMenuItem(menu, param2, Option, sizeof(Option));

            if (StrEqual(Option, "VYR"))
            {
                Client_Info.WriteCell(menu);
                char sQuery[256];
                Format(sQuery, sizeof(sQuery), "SELECT * FROM %splayers ORDER BY Points DESC", SchemaName)
                SQL_TQuery(DB_sntdb, SQL_GetPlayerInfoMenu, sQuery, Client_Info);
            }
            else if (StrEqual(Option, "VPR"))
            {
                BuildPlayerList(param1);
            }
            else if (StrEqual(Option, "TOP"))
            {
                char sQuery[256];
                Format(sQuery, sizeof(sQuery), "SELECT * FROM %splayers ORDER BY Points DESC LIMIT 10", SchemaName)
                SQL_TQuery(DB_sntdb, SQL_BuildTop10, sQuery, Client_Info);
            }
            else if (StrEqual(Option, "DISP"))
            {
                BuildRankDispMenu(param1);
            }
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int InfoPanel_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            switch (param2)
            {
                case 1:
                {
                    BuildPlayerList(param1);
                    CloseHandle(menu);
                }   
                case 2:
                {
                    BuildPage1Menu(param1);
                    CloseHandle(menu);
                }
            }
        }
        case MenuAction_Cancel:
        {
            CloseHandle(menu);
        }
    }
    return 0;
}

public int PlayerList_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char SteamId[64];
            GetMenuItem(menu, param2, SteamId, sizeof(SteamId));

            DataPack Choice_Info;
            Choice_Info = CreateDataPack();
            Choice_Info.WriteCell(param1);
            Choice_Info.WriteString(SteamId);

            char sQuery[256];
            Format(sQuery, sizeof(sQuery), "SELECT * FROM %splayers ORDER BY Points DESC", SchemaName)
            SQL_TQuery(DB_sntdb, SQL_GetPlayerInfoMenu, sQuery, Choice_Info);
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuEnd_Exit)
            {
                delete menu;
            }
            else
            {
                BuildPage1Menu(param1);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

// Commands //

public Action ADM_ReloadCFG(int client, int args)
{
    LoadRankSettings()
    ReplyToCommand(client, "[SNT] Succesfully reloaded \'main_config.cfg\'", Prefix);
    return Plugin_Handled;
}

public Action ADM_TestDB(int client, int args)
{
    char sQuery[256];
    Format(sQuery, sizeof(sQuery), "SELECT PlayerName, Points FROM %splayers ORDER BY Points DESC", SchemaName)
    SQL_TQuery(DB_sntdb, SQL_TestDB, sQuery);
    return Plugin_Handled;
}

public Action ADM_TestEnum(int client, int args)
{
    TestEnums();
    return Plugin_Handled;
}

public Action ADM_GiveItem(int client, int args)
{
    for (int i = 1; i <= GetClientCount(); i++)
    {
        char SteamId[64];
        GetClientAuthId(i, AuthId_Steam3, SteamId, sizeof(SteamId));

        char ClientName[128];
        char ClientNameEsc[257];
        GetClientName(i, ClientName, sizeof(ClientName));
        SQL_EscapeString(DB_sntdb, ClientName, ClientNameEsc, sizeof(ClientNameEsc));

        char iQuery1[512];
        Format(iQuery1, sizeof(iQuery1), "INSERT INTO %splayers (SteamId, PlayerName) VALUES (\'%s\', \'%s\')", StoreSchema, SteamId, ClientNameEsc);
        char iQuery2[512];
        Format(iQuery2, sizeof(iQuery2), "INSERT INTO %splayeritems (SteamId, ItemId) VALUES (\'%s\', 'srv_rank')", StoreSchema, SteamId);

        DataPack SentQuery1;
        SentQuery1 = CreateDataPack();
        WritePackString(SentQuery1, iQuery1);
        SQL_TQuery(DB_sntdb, SQL_ErrorHandler, iQuery1, SentQuery1);
        
        DataPack SentQuery2;
        SentQuery2 = CreateDataPack();
        WritePackString(SentQuery2, iQuery2);
        SQL_TQuery(DB_sntdb, SQL_ErrorHandler, iQuery2, SentQuery2);
    }
    return Plugin_Handled;
}

public Action ADM_RefreshDB(int client, int args)
{
    for (int i = 1; i <= GetClientCount(); i++)
    {
        char SteamId[64];
        GetClientAuthId(i, AuthId_Steam3, SteamId, sizeof(SteamId));

        DataPack Client_Pack;
        Client_Pack = CreateDataPack();
        Client_Pack.WriteCell(i);
        Client_Pack.WriteString(SteamId);

        char sQuery[512];
        Format(sQuery, sizeof(sQuery), "SELECT SteamId, PlayerName, Points FROM %splayers WHERE SteamId=\'%s\'", SchemaName, SteamId);
        SQL_TQuery(DB_sntdb, SQL_GetPlayerInfo, sQuery, Client_Pack);
    }

    return Plugin_Handled;
}

public Action USR_OpenRankMenu(int client, int args)
{
    BuildPage1Menu(client);

    return Plugin_Handled;
}