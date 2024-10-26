#include <sourcemod>
#include <dbi>
#include <files>
#include <keyvalues>
#include <tf2_stocks>
#include <tf2>
#include <clientprefs>
#include <clients>

// Third Party Includes
#include <chat-processor>
#include <morecolors>

#include <sntdb/ranks>

#undef REQUIRE_PLUGIN
#include <sntdb/core>
#include <sntdb/store>
#define REQUIRE_PLUGIN

public Plugin myinfo =
{
    name = "sntdb Rank Module",
    author = "Arcala the Gyiyg",
    description = "SNTDB Player Handling Module.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

// Setup plugin settings
char DBConfName[64];
char SchemaName[64];
char StoreSchema[64]
char CurrencyName[64];
char CurrencyColor[64];
char Prefix[96];
PSettings PointCfg;
KSSettings KSCfg;

// Date info!
char s1_start[12];
char s2_start[12];
char s3_start[12];
char s4_start[12];

bool seasonStart = false;
bool pointsUpdated = false;

// Setup Player Variables
SNT_ClientInfo Player[MAXPLAYERS + 1];

Cookie ck_RankShown;
Cookie ck_RankDisPos;

// Setup Database
Database DB_sntdb;

// Setup Convars
ConVar BroadcastKillstreaks;
ConVar SpawnProtectionEnabled;
ConVar CurrentMapType;

// Map types
bool isArenaMap = false;
bool isSkurfMap = false;

bool lateLoad;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("SNT_AddPoints", Native_AddPoints);
    lateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    SNT_LoadSQLConfigs(DBConfName, sizeof(DBConfName), Prefix, sizeof(Prefix), SchemaName, sizeof(SchemaName), "Ranks", 1, StoreSchema, sizeof(StoreSchema), CurrencyName, sizeof(CurrencyName), CurrencyColor, sizeof(CurrencyColor));
    LoadRankSettings();

    char error[255];
    DB_sntdb = SQL_Connect(DBConfName, true, error, sizeof(error));
    if (!StrEqual(error, ""))
    {
        ThrowError("[SNT] ERROR IN PLUGIN START: %s", error);
    }

    ck_RankShown = RegClientCookie("snt_isrankshown", "Is the player displaying their rank?", CookieAccess_Public);
    ck_RankDisPos = RegClientCookie("snt_rankdispos", "Does the user want to display their rank before or after thier tags / names?", CookieAccess_Public);

    BroadcastKillstreaks = CreateConVar("snt_broadcastks", "0", "Used to determine where to send messages. 0: All players, 1: Only killer / killed, 2: Nobody");
    CurrentMapType = FindConVar("snt_map_type");

    HookConVarChange(CurrentMapType, CVC_SetMapType);

    HookEvent("player_death", OnPlayerDeath);
    HookEvent("player_team", OnPlayerChangedTeam);

    RegAdminCmd("sm_snt_reloadrcfg",    ADM_ReloadCFG,  ADMFLAG_ROOT,     "Use this to reload the config file after you've changed it.");
    RegAdminCmd("sm_snt_rrefresh",      ADM_RefreshDB,  ADMFLAG_BAN,      "Refresh the database for every client in the server.");

    RegConsoleCmd("sm_ranks", USR_OpenRankMenu);

    RegConsoleCmd("sm_rank", USR_OpenRankMenu);

    SpawnProtectionEnabled = FindConVar("snt_sp_enabled");
    CurrentMapType = FindConVar("snt_map_type");

    if (lateLoad)
        for (int i = 1; i < MaxClients; i++)
            if (SNT_IsValidClient(i))
                OnClientPostAdminCheck(i);
}

public void OnMapStart()
{
    PrintToServer("The current map type is: %i", CurrentMapType.IntValue);
    CheckSeason();
}

public void OnMapEnd()
{
    isSkurfMap = false;
    isArenaMap = false;
}

public void OnClientPostAdminCheck(int client)
{
    if (IsClientConnected(client) && !IsFakeClient(client))
    {
        if (AreClientCookiesCached(client))
        {
            char Cookie1[10];
            char Cookie2[10];
            GetClientCookie(client, ck_RankShown, Cookie1, sizeof(Cookie1));
            GetClientCookie(client, ck_RankDisPos, Cookie2, sizeof(Cookie2));

            if (Cookie1[0] == '\0')
            {
                SetClientCookie(client, ck_RankShown, "false");
                Player[client].SetDisplayingRank(false)
            }
            else
            {
                if (StrEqual(Cookie1, "true"))
                    Player[client].SetDisplayingRank(true);
                else
                    Player[client].SetDisplayingRank(false);
            }
            
            if (Cookie2[0] == '\0')
            {
                SetClientCookie(client, ck_RankDisPos, "after");
                Player[client].SetRankDispPos(1);
            }
            else
            {
                if (StrEqual(Cookie2, "before"))
                    Player[client].SetRankDispPos(0);
                else
                    Player[client].SetRankDispPos(1);
            }
        }
        else
        {
            Player[client].SetRankDispPos(1);
            Player[client].SetDisplayingRank(false);
        }

        char SteamId[64];
        GetClientAuthId(client, AuthId_Steam3, SteamId, sizeof(SteamId));

        char PlayerName[128];
        char PlayerNameEsc[257];
        GetClientName(client, PlayerName, 128);
        SQL_EscapeString(DB_sntdb, PlayerName, PlayerNameEsc, 257);

        char uQuery[512];
        Format(uQuery, 512, "INSERT INTO %splayers (SteamId, PlayerName) VALUES (\'%s\', \'%s\') ON DUPLICATE KEY UPDATE PlayerName=\'%s\'", SchemaName, SteamId, PlayerNameEsc, PlayerNameEsc);
        SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);
        
        DataPack Client_Info;
        Client_Info = CreateDataPack();
        Client_Info.WriteCell(client);
        Client_Info.WriteString(SteamId);

        char sQuery[512];
        Format(sQuery, sizeof(sQuery), "SELECT SteamId, PlayerName, Points FROM %splayers ORDER BY Points DESC", SchemaName);
        SQL_TQuery(DB_sntdb, SQL_GetPlayerInfo, sQuery, Client_Info);
    }
}

public void OnClientDisconnect(int client)
{
    if (SNT_IsValidClient(client))
        Player[client].Reset();
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    // Get our point values!
    float KillPts = PointCfg.GetKillPts();
    float AssistPts = PointCfg.GetAsstPts();
    float AssistPtsMed = PointCfg.GetAsstPtsMed();
    int killCredits = PointCfg.GetKillCredits();
    int asstCredits = PointCfg.GetAssistCredits();
    int asstMedCredits = PointCfg.GetAssistMedCredits();

    // UserIds
    int VictimId = GetEventInt(event, "userid");
    int AttackerId = GetEventInt(event, "attacker");
    int AssisterId = GetEventInt(event, "assister");

    // Gotta convert to client indexes
    int victim = GetClientOfUserId(VictimId);
    int attacker = GetClientOfUserId(AttackerId);
    int assister = GetClientOfUserId(AssisterId);

    // Lower amount of points and credits if it's a skill surf map. 
    if (isSkurfMap)
    {
        //PrintToServer("It's a skurf map!");
        KillPts = 2.0;
        AssistPts = 1.0;
        AssistPtsMed = 2.0;
        killCredits = 1;
        asstCredits = 1;
        asstMedCredits = 1;
    }

    // Increase amount of points and credits if its an arena map.
    if (isArenaMap)
    {
        //PrintToServer("It's an arena map!");
        KillPts *= 2;
        AssistPts *= 2;
        AssistPtsMed *= 2;
        killCredits *= 2;
        asstCredits *= 2;
        asstMedCredits *= 2;
    }

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

            // Set multiplier to 1 if skurf map.
            if (isSkurfMap)
                Multi = 1.0;

            if (SpawnProtectionEnabled != null)
                if (SpawnProtectionEnabled.BoolValue == false && !SNT_CheckForWeekend())
                {
                    KillPts = 0.5;
                    AssistPts = 0.25;
                    AssistPtsMed = 0.5;
                }
                else if (SpawnProtectionEnabled.BoolValue == false && SNT_CheckForWeekend())
                {
                    KillPts = 2.0;
                    AssistPts = 1.0;
                    AssistPtsMed = 2.0;
                }

            // Add our points and multiply it by the KS bonus.
            float PtsToAdd = (KillPts) * (Multi);

            APts = APts + PtsToAdd;
            Player[attacker].AddPoints(PtsToAdd);
            SNT_AddCredits(attacker, killCredits);

            CPrintToChat(attacker, "%s You got {greenyellow}(%.2f points){default} and {unique}(%i %s){default} for killing {greenyellow}%s{default}!", Prefix, PtsToAdd, killCredits, CurrencyName, vname);

            // Update the player's points in the table.
            char uQuery[512];
            Format(uQuery, sizeof(uQuery), "UPDATE %splayers SET Points=%f WHERE SteamId=\'%s\'", SchemaName, APts, ASteamId);

            SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);

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

                // assister doesn't get multiplied by their killstreak, because they didn't kill the person. unless they're a medic.
                // Is client a medic?
                if (TF2_GetPlayerClass(assister) == TFClass_Medic)
                {
                    // Yes, they get special treatment.
                    SPts = SPts + AssistPtsMed;

                    HandleKillstreak(victim, assister);

                    Player[assister].AddPoints(AssistPtsMed);
                    SNT_AddCredits(assister, asstMedCredits);
                    CPrintToChat(assister, "%s You got {greenyellow}(%.2f points){default} and {unique}(%i %s){default} for helping kill {greenyellow}%s{default}!", Prefix, AssistPtsMed, asstMedCredits, CurrencyName, vname);
                }
                else
                {
                    // No, they get regular treatment.
                    SPts = SPts + AssistPts;

                    Player[assister].AddPoints(AssistPts);
                    SNT_AddCredits(assister, asstCredits);
                    CPrintToChat(assister, "%s You got {greenyellow}(%.2f points){default} and {unique}(%i %s){default} for helping kill {greenyellow}%s{default}!", Prefix, AssistPts, asstCredits, CurrencyName, vname);
                }
                //Update the points on the database's side.
                Format(uQuery, sizeof(uQuery), "UPDATE %splayers SET Points=%f WHERE SteamId=\'%s\'", SchemaName, SPts, SSteamId);

                SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);

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

public void CVC_SetMapType(ConVar convar, const char[] oldValue, const char[] newValue)
{
    int mode = StringToInt(newValue);
    switch (mode)
    {
        case 1:
            isSkurfMap = true;
        case 2:
            isArenaMap = true;
        default:
        {
            isSkurfMap = false;
            isArenaMap = false;
        }
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

        char nameColor[64];
        char chatColor[64];
        SNT_GetClientNameColor(author, nameColor, 64);
        SNT_GetClientChatColor(author, chatColor, 64);

        switch (DispPos)
        {
            case 0:
            {
                switch(pos)
                {
                    case 0:
                        Format(temp_name, 512, "%s[NA] %s%s%s", pos_color, nameColor, name, chatColor);
                    case 1:
                        Format(temp_name, 512, "%s[#1] %s%s%s", pos_color, nameColor, name, chatColor);
                    case 2:
                        Format(temp_name, 512, "%s[#2] %s%s%s", pos_color, nameColor, name, chatColor);
                    case 3:
                        Format(temp_name, 512, "%s[#3] %s%s%s", pos_color, nameColor, name, chatColor);
                    default:
                        Format(temp_name, 512, "%s[#%i] %s%s%s", pos_color, pos, nameColor, name, chatColor);
                }
            }
            case 1:
            {
                switch(pos)
                {
                    case 0:
                        Format(temp_name, 512, "%s%s %s[NA]%s", nameColor, name, pos_color, chatColor);
                    case 1:
                        Format(temp_name, 512, "%s%s %s[#1]%s", nameColor, name, pos_color, chatColor);
                    case 2:
                        Format(temp_name, 512, "%s%s %s[#2]%s", nameColor, name, pos_color, chatColor);
                    case 3:
                        Format(temp_name, 512, "%s%s %s[#3]%s", nameColor, name, pos_color, chatColor);
                    default:
                        Format(temp_name, 512, "%s%s %s[#%i]%s", nameColor, name, pos_color, pos, chatColor);
                }
            }
        }

        strcopy(name, 512, temp_name);
        return Plugin_Changed;
    }
    return Plugin_Changed;
}

public void Native_AddPoints (Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    float points = GetNativeCell(2);

    if (SNT_IsValidClient(client))
    {
        float currentPoints = Player[client].GetPoints();
        currentPoints += points;

        char steamId[64];
        GetClientAuthId(client, AuthId_Steam3, steamId, sizeof(steamId));

        Player[client].AddPoints(points);
        
        char uQuery[512];
        Format(uQuery, sizeof(uQuery), "UPDATE %splayers SET Points=%f WHERE SteamId=\'%s\'", SchemaName, currentPoints, steamId);

        SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);

        // Get player's updated rank info

        DataPack clientInfo = CreateDataPack();
        clientInfo.WriteCell(client);
        clientInfo.WriteString(steamId);

        char sQuery[512];
        Format(sQuery, sizeof(sQuery), "SELECT * FROM %splayers ORDER BY Points DESC", SchemaName);
        SQL_TQuery(DB_sntdb, SQL_GetPlayerRank, sQuery, clientInfo);
    }
} 

// Custom functions

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
            int killCredits;
            int assistCredits;
            int assistMedCredits;

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
            killCredits = ConfigFile.GetNum("CreditsPerKill");
            assistCredits = ConfigFile.GetNum("CreditsPerAssist");
            assistMedCredits = ConfigFile.GetNum("CreditsPerAssistMed");
            
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
            PointCfg.SetKillCredits(killCredits);
            PointCfg.SetAssistCredits(assistCredits);
            PointCfg.SetAssistMedCredits(assistMedCredits);
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
            int cMulti1;
            int cMulti2;
            int cMulti3;
            int cMulti4;

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
            cMulti1 = ConfigFile.GetNum("cL1Multi");
            cMulti2 = ConfigFile.GetNum("cL2Multi");
            cMulti3 = ConfigFile.GetNum("cL3Multi");
            cMulti4 = ConfigFile.GetNum("cL4Multi");

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
            KSCfg.SetCreditMulti(1, cMulti1);
            KSCfg.SetCreditMulti(2, cMulti2);
            KSCfg.SetCreditMulti(3, cMulti3);
            KSCfg.SetCreditMulti(4, cMulti4);

        }
    }
    ConfigFile.Rewind();
    if (ConfigFile.JumpToKey("Ranks"))
    {
        if (ConfigFile.JumpToKey("Dates"))
        {
            ConfigFile.GetString("season1_start", s1_start, sizeof(s1_start));
            ConfigFile.GetString("season2_start", s2_start, sizeof(s2_start));
            ConfigFile.GetString("season3_start", s3_start, sizeof(s3_start));
            ConfigFile.GetString("season4_start", s4_start, sizeof(s4_start));
        }
    }

    ConfigFile.Close();
}

void CheckSeason()
{
    int timestamp = GetTime();
    char curDate[12];
    FormatTime(curDate, sizeof(curDate), "%m/%d", timestamp);

    if (StrEqual(curDate, s1_start) || StrEqual(curDate, s2_start) || StrEqual(curDate, s3_start) || StrEqual(curDate, s4_start))
        seasonStart = true;
    else
        seasonStart = false;

    if (seasonStart && !pointsUpdated)
    {
        char uQuery[512];
        Format(uQuery, sizeof(uQuery), "UPDATE %splayers SET Points=0", SchemaName);

    }
}

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
        GetClientName(victim, VName, 257);
        GetClientName(attacker, AName, 257);

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
            // Play a sound.
            EmitSoundToAll("snt_sounds/ypp_sting.mp3");

            // Reset the victim's killstreak count please!
            Player[victim].ResetKS();

            // Format msg: "[SNT] Victim ended their own life"
            Format(msg, sizeof(msg), "%s %s%s {default}walked the plank, ending thar killstreak!", Prefix, VTeamColor, VName);

            // Broadcast msg
            KSMessage(victim, attacker, msg);
        }

        // Were they killed by the server?
        else if (attacker == 0 && Player[victim].GetKS() >= 5)
        {
            EmitSoundToAll("snt_sounds/ypp_sting.mp3");
            Player[victim].ResetKS();
            char msg2[256];
            // Format msg: "[SNT] Victim was smote by a mysterious force!"
            Format(msg2, sizeof(msg2), "%s %s%s {default}faced Poseidon's wrath, ending thar killstreak!", Prefix, VTeamColor, VName);
            KSMessage(victim, attacker, msg2);
        }

        // Regular operation
        else
        {
            // If the victim had more than 5 kills, broadcast the killstreak message.
            if  (Player[victim].GetKS() >= 5)
            {
                float APts = Player[attacker].GetPoints();
                float Multi = Player[victim].GetMultiplier();
                float KillPts = PointCfg.GetKillPts();
                char ASteamId[64];
                char vname[MAX_NAME_LENGTH];

                GetClientAuthId(attacker, AuthId_Steam3, ASteamId, 64);
                GetClientName(victim, vname, MAX_NAME_LENGTH);

                EmitSoundToAll("snt_sounds/ypp_sting.mp3");
                char msg2[256];
                // Format msg: "[SNT] Attacker ended Victim's killstreak!"
                Format(msg2, sizeof(msg2), "%s %s%s {default}made %s%s {default}walk the plank, ending thar killstreak!", Prefix, ATeamColor, AName, VTeamColor, VName);
                KSMessage(victim, attacker, msg2);

                if (isSkurfMap)
                {
                    KillPts = 1.0;
                    Multi = 1.0;
                }

                // Add our points and multiply it by the KS bonus.
                float PtsToAdd = (KillPts * 2.0) * (Multi);
                APts = APts + PtsToAdd;
                Player[attacker].AddPoints(PtsToAdd);

                int killCredits = PointCfg.GetKillCredits();
                int credsToAdd = ((killCredits * 2) * Player[victim].GetCreditMulti());
                SNT_AddCredits(attacker, credsToAdd);
                CPrintToChat(attacker, "%s You got {greenyellow}(%.2f points){default} and %s(%i %s){default} for ending {greenyellow}%s{default}'s killstreak!", Prefix, PtsToAdd, CurrencyColor, credsToAdd, CurrencyName, vname);

                // Update the player's points in the table.
                char uQuery[512];
                Format(uQuery, sizeof(uQuery), "UPDATE %splayers SET Points=%f WHERE SteamId=\'%s\'", SchemaName, APts, ASteamId);
                SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);

            }


            // Reset the victim's killstreak count please!
            Player[victim].ResetKS();

            // Add 1 to the attacker's kill count.
            Player[attacker].AddKS();

            // Check how many kills the attacker has now
            if (Player[attacker].GetKS() == Level1Kills)
            {
                    // Format chat message. "[SNT] Player is <ks_name>"
                    Format(msg, sizeof(msg), "%s %s%s {default}is %s%s!", Prefix, ATeamColor, AName, L1Color, L1Name);

                    // Set player's multiplier for the appropriate level.
                    Player[attacker].SetMultiplier(KSCfg.GetMultiplier(1));
            }
            else if (Player[attacker].GetKS() == Level2Kills)
            {
                    Format(msg, sizeof(msg), "%s %s%s {default}is %s%s!", Prefix, ATeamColor, AName, L2Color, L2Name);
                    Player[attacker].SetMultiplier(KSCfg.GetMultiplier(2));
            }
            else if (Player[attacker].GetKS() == Level3Kills)
            {
                    Format(msg, sizeof(msg), "%s %s%s {default}is %s%s!", Prefix, ATeamColor, AName, L3Color, L3Name);
                    Player[attacker].SetMultiplier(KSCfg.GetMultiplier(3));
            }
            else if (Player[attacker].GetKS() == Level4Kills)
            {
                    Format(msg, sizeof(msg), "%s %s%s {default}is %s%s!", Prefix, ATeamColor, AName, L4Color, L4Name);
                    Player[attacker].SetMultiplier(KSCfg.GetMultiplier(4));
            }
            // Broadcast the message
            KSMessage(victim, attacker, msg);
        }
    }
}

void BuildPlayerList(int client)
{
    Menu PlayerList = new Menu(PlayerList_Handler, MENU_ACTIONS_DEFAULT);
    PlayerList.SetTitle("Choose a crewmate to view:");
    SetMenuExitBackButton(PlayerList, true);

    for (int i = 1; i <= MaxClients; i++)
    {
        {
            if (SNT_IsValidClient(i))
            {
                char SteamId[64];
                char PlayerName[257];

                Player[i].GetAuthId(SteamId, sizeof(SteamId));
                Player[i].GetName(PlayerName, sizeof(PlayerName));
                PlayerList.AddItem(SteamId, PlayerName);
            }
        }
    }
    PlayerList.Display(client, MENU_TIME_FOREVER);
}

void BuildRankDispMenu(int client)
{
    char SteamId[64];
    GetClientAuthId(client, AuthId_Steam3, SteamId, 64);

    char sQuery[256];
    Format(sQuery, sizeof(sQuery), "SELECT ItemId FROM %sInventories WHERE SteamId=\'%s\'", StoreSchema, SteamId);
    SQL_TQuery(DB_sntdb, SQL_CheckPlayerInventory, sQuery, client);

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
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "{fullred}Ye have ta buy this from the tavern first!\n{default}Use {greenyellow}/tavern {default}to see their wares!", Prefix);
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
    Format(PointsLine, 32, "Current Points: %.2f", points);

    InfoPanel.DrawText(" ");
    InfoPanel.DrawText(NameLine);
    InfoPanel.DrawText(RankLine);
    InfoPanel.DrawText(PointsLine);
    InfoPanel.DrawText(" ");
    InfoPanel.DrawItem("Current Player List");
    InfoPanel.DrawItem("Top 10 Players");
    InfoPanel.DrawItem("Main Menu");
    InfoPanel.Send(client, InfoPanel_Handler, 30);
}

void BuildPage1Menu(int client)
{
    Menu Page1 = new Menu(Page1_Handler, MENU_ACTIONS_DEFAULT);
    Page1.SetTitle("SNT Ranks");
    Page1.AddItem("1", "View yer stats!");
    Page1.AddItem("2", "View yer crewmate's stats!");
    Page1.AddItem("3", "View the top 10 players!");
    Page1.AddItem("4", "Toggle yer rank display!");
    Page1.Display(client, 10);
}

public int PlacePanel_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            if (param2 == 1)
            {
                EmitSoundToClient(param1, "buttons/button14.wav");
                bool IsDisplayed = Player[param1].GetIfDisplayingRank();
                Player[param1].SetDisplayingRank(!IsDisplayed);
                if (IsDisplayed)
                {
                    // it's backwards, shit.
                    CPrintToChat(param1, "%s You are no longer displaying your rank!", Prefix)
                    SetClientCookie(param1, ck_RankShown, "false");
                }
                else
                {
                    // here too
                    CPrintToChat(param1, "%s You are now displaying your rank!", Prefix)
                    SetClientCookie(param1, ck_RankShown, "true");
                }

                BuildRankDispMenu(param1);
            }
            else if (param2 == 2)
            {
                EmitSoundToClient(param1, "buttons/button14.wav");
                int disp_pos;
                disp_pos = Player[param1].GetRankDispPos();

                switch (disp_pos)
                {
                    case 0:
                    {
                        // here too as well
                        CPrintToChat(param1, "%s Displaying your rank after your name.", Prefix)
                        Player[param1].SetRankDispPos(1);
                        SetClientCookie(param1, ck_RankDisPos, "after");
                    }
                    case 1:
                    {
                        // and here :(
                        CPrintToChat(param1, "%s Displaying your rank before your name.", Prefix)
                        Player[param1].SetRankDispPos(0);
                        SetClientCookie(param1, ck_RankDisPos, "before");
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
            EmitSoundToClient(param1, "buttons/combine_button7.wav");
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

            if (StrEqual(Option, "1"))
            {
                Client_Info.WriteCell(menu);
                char sQuery[256];
                Format(sQuery, sizeof(sQuery), "SELECT * FROM %splayers ORDER BY Points DESC", SchemaName)
                SQL_TQuery(DB_sntdb, SQL_GetPlayerInfoMenu, sQuery, Client_Info);
            }
            else if (StrEqual(Option, "2"))
            {
                BuildPlayerList(param1);
            }
            else if (StrEqual(Option, "3"))
            {
                char sQuery[256];
                Format(sQuery, sizeof(sQuery), "SELECT * FROM %splayers ORDER BY Points DESC LIMIT 10", SchemaName)
                SQL_TQuery(DB_sntdb, SQL_BuildTop10, sQuery, Client_Info);
            }
            else if (StrEqual(Option, "4"))
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
            EmitSoundToClient(param1, "buttons/button14.wav");
            switch (param2)
            {
                case 1:
                {
                    BuildPlayerList(param1);
                    CloseHandle(menu);
                }   
                case 2:
                {
                    DataPack Client_Info;
                    Client_Info = CreateDataPack();
                    Client_Info.WriteCell(param1);

                    char SteamId[64];
                    GetClientAuthId(param1, AuthId_Steam3, SteamId, 64);
                    Client_Info.WriteString(SteamId);
        
                    char sQuery[256];
                    Format(sQuery, sizeof(sQuery), "SELECT * FROM %splayers ORDER BY Points DESC LIMIT 10", SchemaName)
                    SQL_TQuery(DB_sntdb, SQL_BuildTop10, sQuery, Client_Info);
                }
                case 3:
                {
                    BuildPage1Menu(param1);
                    CloseHandle(menu);
                }
            }
        }
        case MenuAction_Cancel:
        {
            EmitSoundToClient(param1, "buttons/combine_button7.wav");
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

public void SQL_ErrorHandler(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] ERROR! DATABASE IS NULL!");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN QUERY: %s", error);
    }
}

public void SQL_GetPlayerInfo(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] ERROR! DATABASE IS NULL!");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN QUERY: %s", error);
    }

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

    int place;
    while (SQL_FetchRow(results))
    {
        place++;
        char SQL_SteamId[64];
        SQL_FetchString(results, 0, SQL_SteamId, 64);

        if (StrEqual(SQL_SteamId, SteamId))
        {
            char RetrievedName[128];
            SQL_FetchString(results, 1, RetrievedName, sizeof(RetrievedName));

            Player[client].SetPlayerName(RetrievedName);
            Player[client].SetClientId(client);
            Player[client].SetUserId(GetClientUserId(client));
            Player[client].SetAuthId(SteamId);
            Player[client].SetPoints(SQL_FetchFloat(results, 2));
            Player[client].SetRank(place);
            Player[client].ResetKS();
            Player[client].SetMultiplier(1.0);

            char sQuery2[256];
            Format(sQuery2, sizeof(sQuery2), "SELECT ItemId FROM %sInventories WHERE SteamId=\'%s\'", StoreSchema, SteamId);
            SQL_TQuery(db, SQL_CheckPlayerInventory, sQuery2, client);
            break;
        }
        else if (!StrEqual(SteamId, SQL_SteamId) && !SQL_MoreRows(results))
        {
            char ClientName[128];
            GetClientName(client, ClientName, 128);
            CPrintToChatAll("%s Welcome {orange}%s {default}to the server!", Prefix, ClientName);

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

        SQL_FetchString(results, 0, SQL_SteamId, sizeof(SQL_SteamId));

        if (StrEqual(SQL_SteamId, SteamId))
        {
            Player[client].SetRank(place);
            break;
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
        CPrintToChatAll("%s {darkgrey}%i{cyan}| %s{white}: %.2f points.", Prefix, row, PlyrName, PlyrPoints);
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
            break;
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
        if (StrEqual("SQL_SteamId", "ROOT"))
            continue;
        Top10List.AddItem(SQL_SteamId, SQL_PlayerName);
    }

    Top10List.Display(client, MENU_TIME_FOREVER);
    CloseHandle(data);
}

public void SQL_CheckPlayerInventory(Database db, DBResultSet results, const char[] error, any client)
{
    while (SQL_FetchRow(results))
    {
        char ItemId[64];
        SQL_FetchString(results, 0, ItemId, sizeof(ItemId));

        if (StrEqual(ItemId, "srv_rank"))
        {
            Player[client].SetOwnsRank(true);
            break;
        }
    }
}

public Action ADM_ReloadCFG(int client, int args)
{
    LoadRankSettings()
    ReplyToCommand(client, "[SNT] Succesfully reloaded \'main_config.cfg\'", Prefix);
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