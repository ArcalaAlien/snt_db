#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <basecomm>
#include <mapchooser>
#include <tf2>
#include <tf2_stocks>
#include <dbi>
#include <morecolors>

#define REQUIRE_PLUGIN
#include <sntdb_core>

#define VOTE_NO "###no###"
#define VOTE_YES "###yes###"

public Plugin myinfo =
{
    name = "SNT Votemenu",
    author = "Arcala the Gyiyg",
    description = "A vote menu for players to use when admins aren't online.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
}

bool lateLoad;

Database DB_sntdb;
char DBConfName[64];
char SchemaName[64];
char Prefix[96];

bool isEnabled = true;
bool isVoteOnCooldown;
bool isSlayOnCooldown;
bool isMuteOnCooldown;
bool isScrambleOnCooldown;
bool isSPOnCooldown;
int  mapTimeLeft;
int  CooldownLeft;
int  SlayCooldownLeft;
int  MuteCooldownLeft;
int  ScrambleCooldownLeft;
int  SpawnProtectionLeft;
int  VoteCountdown = 5;
bool isPlayerWarnedGag[MAXPLAYERS + 1];
bool isPlayerWarnedMute[MAXPLAYERS + 1];
bool playerHasVotePerms[MAXPLAYERS + 1] = { true, ... };

ConVar CooldownTime;
ConVar SlayCooldownTime;
ConVar MuteCooldownTime;
ConVar ScrambleCooldownTime;
ConVar SpawnProtectionCooldownTime;
ConVar GagTime;
ConVar MuteTime;
ConVar BanTime;
ConVar SPEnabled;
ConVar isSkillSurfConVar;

Handle GagTimer[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};
Handle MuteTimer[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};
int GagTimerLeft[MAXPLAYERS + 1];
int MuteTimerLeft[MAXPLAYERS + 1];

Handle CooldownTimer = INVALID_HANDLE;
Handle SlayVoteTimer = INVALID_HANDLE;
Handle MuteVoteTimer = INVALID_HANDLE;
Handle ScrambleVoteTimer = INVALID_HANDLE;
Handle SPVoteTimer = INVALID_HANDLE;
Handle CountdownTimer = INVALID_HANDLE;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    lateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadSQLConfigs(DBConfName, 64, Prefix, 96, SchemaName, 64, "VoteMenu");
    
    char error[255];
    DB_sntdb = SQL_Connect(DBConfName, true, error, sizeof(error));
    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN PLUGIN START: %s", error);
    }

    CooldownTime = CreateConVar("snt_vote_cooldown", "300.0", "Set the time in seconds before another vote can be called.", 0, true, 60.0);
    SlayCooldownTime = CreateConVar("snt_slay_vote_cooldown", "120.0", "Set the time in seconds before another slay vote can be called.", 0, true, 60.0);
    MuteCooldownTime = CreateConVar("snt_mute_vote_cooldown", "180.0", "Set the time in seconds before another mute vote can be called.", 0, true, 60.0);
    ScrambleCooldownTime = CreateConVar("snt_scramble_vote_cooldown", "180.0", "set the time in seconds before another scramble vote can be called", 0, true, 60.0);
    SpawnProtectionCooldownTime = CreateConVar("snt_sp_vote_delay", "300.0", "Set the time in seconds before a vote to disable spawnprotection can be called.", 0, true, 60.0);

    GagTime = CreateConVar("snt_votegag_length", "10.0", "The amount of time in minutes for a player to be gagged.", 0, true, 5.0);
    MuteTime = CreateConVar("snt_votemute_length", "10.0", "The amount of time in minutes for a player to be muted.", 0, true, 5.0);
    BanTime = CreateConVar("snt_voteban_length", "10.0", "The amount of time in minutes for a player to be banned.", 0, true, 5.0);
    isSkillSurfConVar = CreateConVar("snt_sp_is_skurf", "0.0", "Change spawnprotection modes between skill-surf and combat surf.", 0, true, 0.0, true, 1.0);

    CooldownLeft = CooldownTime.IntValue;
    SlayCooldownLeft = SlayCooldownTime.IntValue;
    MuteCooldownLeft = MuteCooldownTime.IntValue;
    ScrambleCooldownLeft = ScrambleCooldownTime.IntValue;
    SpawnProtectionLeft = SpawnProtectionCooldownTime.IntValue;

    RegConsoleCmd("sm_votemenu", USR_OpenVoteMenu, "Use /votemenu to open the votemenu.");

    RegAdminCmd("sm_voteperms", ADM_ModVotePerms, ADMFLAG_GENERIC, "Use /voteperms [add | rmv] (opt: Steam3ID) to give / remove a player's votemenu permissions");

    if (lateLoad)
    {
        OnMapStart();
        for (int i = 1; i < MaxClients; i++)
            if (SNT_IsValidClient(i))
                OnClientPostAdminCheck(i);
    }

}

public void OnClientPostAdminCheck(int client)
{
    if (SNT_IsValidClient(client))
    {
        char AuthID[64];
        GetClientAuthId(client, AuthId_Steam3, AuthID, 64);

        char sQuery[512];
        Format(sQuery, 512, "SELECT VotePerms FROM %splayers WHERE SteamId=\'%s\'", SchemaName, AuthID);
        SQL_TQuery(DB_sntdb, SQL_CheckForPerms, sQuery, client);
    }
}

public void OnClientDisconnect(int client)
{
    if (SNT_IsValidClient(client))
    {
        if (GagTimer[client] != INVALID_HANDLE)
            KillTimer(GagTimer[client]);
        
        if (MuteTimer[client] != INVALID_HANDLE)
            KillTimer(MuteTimer[client]);

        isPlayerWarnedGag[client] = false;
        isPlayerWarnedMute[client] = false;
        playerHasVotePerms[client] = true;
        GagTimerLeft[client] = GagTime.IntValue * 60;
        MuteTimerLeft[client] = MuteTime.IntValue * 60;
    }
}

public void OnMapStart()
{
    isVoteOnCooldown = false;
    CooldownLeft = CooldownTime.IntValue;
    SlayCooldownLeft = SlayCooldownTime.IntValue;
    MuteCooldownLeft = MuteCooldownTime.IntValue;
    ScrambleCooldownLeft = ScrambleCooldownTime.IntValue;
    SpawnProtectionLeft = SpawnProtectionCooldownTime.IntValue;
    VoteCountdown = 5;
    isSPOnCooldown = true;
    SPEnabled = FindConVar("snt_sp_enabled");
    SPVoteTimer = CreateTimer(1.0, Timer_SpawnProtectionCooldownTimer, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
    if (CooldownTimer != INVALID_HANDLE)
        KillTimer(CooldownTimer);
    
    if (SlayVoteTimer != INVALID_HANDLE)
        KillTimer(SlayVoteTimer);

    if (MuteVoteTimer != INVALID_HANDLE)
        KillTimer(MuteVoteTimer);

    if (ScrambleVoteTimer != INVALID_HANDLE)
        KillTimer(ScrambleVoteTimer);

    if (SPVoteTimer != INVALID_HANDLE)
        KillTimer(SPVoteTimer);
}

void SendScrambleVote(int client)
{

    if (isScrambleOnCooldown)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Vote Scramble is on cooldown! You have: %i seconds until you can start a vote.", Prefix, ScrambleCooldownLeft);
        return;
    }

    isScrambleOnCooldown = true;
    ScrambleVoteTimer = CreateTimer(1.0, Timer_ScrambleTimer, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

    char VoteTimestamp[64];
    FormatTime(VoteTimestamp, 64, "%D %R:%S", GetTime() - (4*60*60));
    
    char SteamId[64];
    GetClientAuthId(client, AuthId_Steam3, SteamId, 64);

    char ClientName[128];
    char ClientNameEsc[257];
    GetClientName(client, ClientName, 128);
    SQL_EscapeString(DB_sntdb, ClientName, ClientNameEsc, 257);

    char iQuery[512];

    CPrintToChatAll("%s {yellowgreen}%s {default}has started a vote to {orange}scramble teams!", Prefix, ClientName);
    CooldownTimer = CreateTimer(1.0, Timer_ScrambleTimer, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    Format(iQuery, 512, "INSERT INTO %svotes VALUES (\'%s\', \'%s\', \'%s\', \'%s\', \'%s\', \'%s\')", SchemaName, VoteTimestamp, SteamId, "N/A", "SCRAMBLE", ClientNameEsc, "N/A");
    SQL_TQuery(DB_sntdb, SQL_ErrorHandler, iQuery);

    Menu VoteScramble_Menu = new Menu(VoteScramble_Handler);
    VoteScramble_Menu.SetTitle("Scramble teams?");
    VoteScramble_Menu.AddItem("Y", "Yes");
    VoteScramble_Menu.AddItem("X", "No");
    VoteScramble_Menu.ExitButton = false;

    if (CountdownTimer == INVALID_HANDLE)
        CountdownTimer = CreateTimer(1.0, Timer_CountdownTimer, VoteScramble_Menu, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

void SendSPVote(int client)
{
    if (isSPOnCooldown)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Voting to toggle Spawn Protection is on cooldown! You have: %i seconds until you can start a vote.", Prefix, SpawnProtectionLeft);
        return;
    }

    isSPOnCooldown = true;
    SPVoteTimer = CreateTimer(1.0, Timer_SpawnProtectionCooldownTimer, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

    char VoteTimestamp[64];
    FormatTime(VoteTimestamp, 64, "%D %R:%S", GetTime() - (4*60*60));
    
    char SteamId[64];
    GetClientAuthId(client, AuthId_Steam3, SteamId, 64);

    char ClientName[128];
    char ClientNameEsc[257];
    GetClientName(client, ClientName, 128);
    SQL_EscapeString(DB_sntdb, ClientName, ClientNameEsc, 257);

    char iQuery[512];

    if (SPEnabled != null)
    {
        if (SPEnabled.IntValue == 0)
        {
            CPrintToChatAll("%s {yellowgreen}%s {default}has started a vote to {orange}enable spawn protection!", Prefix, ClientName);
            Format(iQuery, 512, "INSERT INTO %svotes VALUES (\'%s\', \'%s\', \'%s\', \'%s\', \'%s\', \'%s\')", SchemaName, VoteTimestamp, SteamId, "N/A", "SPAWNPROTECTION", ClientNameEsc, "N/A");
            SQL_TQuery(DB_sntdb, SQL_ErrorHandler, iQuery);

            Menu VoteSP_Menu = new Menu(VoteSP_Handler);
            VoteSP_Menu.SetTitle("Enable Spawn Protection?");
            VoteSP_Menu.AddItem("Y", "Yes");
            VoteSP_Menu.AddItem("X", "No");
            VoteSP_Menu.ExitButton = false;
            if (CountdownTimer == INVALID_HANDLE)
                CountdownTimer = CreateTimer(1.0, Timer_CountdownTimer, VoteSP_Menu, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        }
        else
        {
            CPrintToChatAll("%s {yellowgreen}%s {default}has started a vote to {orange}disable spawn protection!", Prefix, ClientName);
            Format(iQuery, 512, "INSERT INTO %svotes VALUES (\'%s\', \'%s\', \'%s\', \'%s\', \'%s\', \'%s\')", SchemaName, VoteTimestamp, SteamId, "N/A", "SPAWNPROTECTION", ClientNameEsc, "N/A");
            SQL_TQuery(DB_sntdb, SQL_ErrorHandler, iQuery);

            Menu VoteSP_Menu = new Menu(VoteSP_Handler);
            VoteSP_Menu.SetTitle("Disable Spawn Protection?");
            VoteSP_Menu.AddItem("Y", "Yes");
            VoteSP_Menu.AddItem("X", "No");
            VoteSP_Menu.ExitButton = false;
            if (CountdownTimer == INVALID_HANDLE)
                CountdownTimer = CreateTimer(1.0, Timer_CountdownTimer, VoteSP_Menu, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        }
    }
    else
        PrintToServer("Unable to find cvar");
}

void BuildPage1(int client)
{
    char GagOpt[64];
    char MuteOpt[64];
    char BanOpt[64];

    Format(GagOpt, 64, "Vote gag player for %i minutes", GagTime.IntValue);
    Format(MuteOpt, 64, "Vote mute player for %i minutes", MuteTime.IntValue);
    Format(BanOpt, 64, "Vote ban player for %i minutes", BanTime.IntValue);

    Menu VoteMenu_Page1 = new Menu(Page1_Handler, MENU_ACTIONS_DEFAULT);
    VoteMenu_Page1.SetTitle("Choose a category");
    VoteMenu_Page1.AddItem("GAG", GagOpt);
    VoteMenu_Page1.AddItem("MUTE", MuteOpt);
    VoteMenu_Page1.AddItem("KICK", "Vote kick player");
    VoteMenu_Page1.AddItem("BAN", BanOpt);
    //VoteMenu_Page1.AddItem("SCRAMBLE", "Scramble Teams");
    
    if (SPEnabled != null && isSkillSurfConVar != null)
    {
        if (isSkillSurfConVar.IntValue != 1)
        {
            VoteMenu_Page1.AddItem("SLAY", "Vote slay player");
            if (SPEnabled.IntValue == 0)
                VoteMenu_Page1.AddItem("SP", "Enable Spawn Protection");
            else
                VoteMenu_Page1.AddItem("SP", "Disable Spawn Protection");
        }
    }
    else
        PrintToServer("Unable to find Spawn Protection CVARS");

    VoteMenu_Page1.Display(client, 25);
}

Menu BuildVoteMenu(int type, char[] playerName, int playerClientId)
{
    char YesOpt[6];
    Format(YesOpt, 6, "%i", playerClientId);

    switch (type)
    {
        case 0:
        {
            Menu VoteSlay_Menu = new Menu(VoteSlay_Handler);
            VoteSlay_Menu.SetTitle("Slay %s?", playerName);
            VoteSlay_Menu.AddItem(YesOpt, "Yes");
            VoteSlay_Menu.AddItem("X", "No");
            VoteSlay_Menu.ExitButton = false;
            return VoteSlay_Menu;
        }
        case 1:
        {
            Menu VoteGag_Menu = new Menu(VoteGag_Handler);
            VoteGag_Menu.SetTitle("Gag %s?", playerName);
            VoteGag_Menu.AddItem(YesOpt, "Yes");
            VoteGag_Menu.AddItem("X", "No");
            VoteGag_Menu.ExitButton = false;
            return VoteGag_Menu;
        }
        case 2:
        {
            Menu VoteMute_Menu = new Menu(VoteMute_Handler);
            VoteMute_Menu.SetTitle("Mute %s?", playerName);
            VoteMute_Menu.AddItem(YesOpt, "Yes");
            VoteMute_Menu.AddItem("X", "No");
            VoteMute_Menu.ExitButton = false;
            return VoteMute_Menu;
        }
        case 3:
        {
            Menu VoteKick_Menu = new Menu(VoteKick_Handler);
            VoteKick_Menu.SetTitle("Kick %s?", playerName);
            VoteKick_Menu.AddItem(YesOpt, "Yes");
            VoteKick_Menu.AddItem("X", "No");
            VoteKick_Menu.ExitButton = false;
            return VoteKick_Menu;
        }
        case 4:
        {
            Menu VoteBan_Menu = new Menu(VoteBan_Handler);
            VoteBan_Menu.SetTitle("Ban %s?", playerName);
            VoteBan_Menu.AddItem(YesOpt, "Yes");
            VoteBan_Menu.AddItem("X", "No");
            VoteBan_Menu.ExitButton = false;
            return VoteBan_Menu;
        }
        default:
        {
            Menu VoteSlay_Menu = new Menu(VoteSlay_Handler);
            VoteSlay_Menu.SetTitle("Slay %s?", playerName);
            VoteSlay_Menu.AddItem(YesOpt, "Yes");
            VoteSlay_Menu.AddItem("X", "No");
            VoteSlay_Menu.ExitButton = false;
            return VoteSlay_Menu;
        }
    }
}

void BuildPlayerList(int client, int type)
{
    Menu PlayerList = new Menu(PlayerList_Handler, MENU_ACTIONS_DEFAULT);

    switch (type)
    {
        case 0:
            PlayerList.SetTitle("Choose a player to slay:");
        case 1:
            PlayerList.SetTitle("Choose a player to gag:");
        case 2:
            PlayerList.SetTitle("Choose a player to mute:");
        case 3:
            PlayerList.SetTitle("Choose a player to kick:");
        case 4:
            PlayerList.SetTitle("Choose a player to ban:");
    }

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
        {
            char PlayerAuth[64];
            char PlayerName[128];
            GetClientName(i, PlayerName, 128);
            GetClientAuthId(i, AuthId_Steam3, PlayerAuth, 64);

            char MenuOpt[80];
            switch (type)
            {
                case 0:
                    Format(MenuOpt, 80, "0,%i,%s", i, PlayerAuth);
                case 1:
                    Format(MenuOpt, 80, "1,%i,%s", i, PlayerAuth);
                case 2:
                    Format(MenuOpt, 80, "2,%i,%s", i, PlayerAuth);
                case 3:
                    Format(MenuOpt, 80, "3,%i,%s", i, PlayerAuth);
                case 4:
                    Format(MenuOpt, 80, "4,%i,%s", i, PlayerAuth);
            }
            
            PlayerList.AddItem(MenuOpt, PlayerName);
        }
        else if (!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i))
            continue;
    }
    
    PlayerList.Display(client, 0);
}

public int VoteSP_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteEnd:
        {
            // Thanks sourcemod team <3
            char item[64];
            float percent;
            int votes;
            int winningVotes, totalVotes;

            // param2 of menu, votes of winning option, total votes entered.
            GetMenuVoteInfo(param2, winningVotes, totalVotes);

            // Get the winning item (yes / no) from the vote
            menu.GetItem(param1, item, sizeof(item));

            votes = (totalVotes - winningVotes); // Set votes equal to the amount NO gets?? I'm not sure

            percent = float(winningVotes) / float(totalVotes);

            if ((strcmp(item, VOTE_YES) == 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
                CPrintToChatAll("%s Vote to toggle spawn protection {fullred}failed!{default}(%i {greenyellow}YES{default} | %i {fullred}NO{default})", Prefix, winningVotes, votes);
            else
            {
                if (SPEnabled != null)
                {
                    if (SPEnabled.IntValue == 0)
                    {
                        CPrintToChatAll("%s {orange}SPAWN PROTECTION IS NOW ENABLED! {default}(%i {greenyellow}YES{default} | %i {fullred}NO{default})", Prefix, winningVotes, votes);
                        SetConVarInt(SPEnabled, 1);
                    }
                    else
                    {
                        CPrintToChatAll("%s {orange}SPAWN PROTECTION IS NOW DISABLED {default}(%i {greenyellow}YES{default} | %i {fullred}NO{default})", Prefix, winningVotes, votes);
                        SetConVarInt(SPEnabled, 0);
                    }
                }
                else
                    PrintToServer("Could not find cvar.");
            }
        }
    }
    return 0;
}

public int VoteScramble_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteEnd:
        {
            if (!isEnabled)
            {
                CancelVote();
                return 0;
            }

            if (param1 == 0)
            {
                int mapTime;
                GetMapTimeLeft(mapTime)
                CPrintToChatAll("%s Vote to scramble team {greenyellow}passed!", Prefix);
                ServerCommand("mp_scrambleteams");
                
                int minsLeft = (mapTime / 60);
                if (minsLeft < 1)
                    minsLeft = 1;
                ServerCommand("mp_timelimit %i", minsLeft);
            }
            else
            {
                CPrintToChatAll("%s Vote to scramble teams {fullred}failed.", Prefix);
            }
        }
    }
    return 0;
}

public int VoteSlay_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteEnd:
        {
            if (!isEnabled)
            {
                CancelVote();
                return 0;
            }

            char ClientIDStr[12];
            GetMenuItem(menu, param1, ClientIDStr, 12);
            int PunishedClient = StringToInt(ClientIDStr);

            char PunishedClientName[128];
            GetClientName(PunishedClient, PunishedClientName, 128);

            if (param1 == 0)
            {
                if (TF2_IsPlayerInCondition(PunishedClient, TFCond_PreventDeath))
                    TF2_RemoveCondition(PunishedClient, TFCond_PreventDeath);

                ForcePlayerSuicide(PunishedClient);

                CPrintToChatAll("%s Vote to slay {orange}%s {default}passed.", Prefix, PunishedClientName);
            }
            else
                CPrintToChatAll("%s Vote to slay the player failed.", Prefix, PunishedClientName);
        }
    }
    return 0;
}

public int VoteGag_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteEnd:
        {
            if (!isEnabled)
            {
                CancelVote();
                return 0;
            }

            char ClientIDStr[12];
            GetMenuItem(menu, param1, ClientIDStr, 12);
            int PunishedClient = StringToInt(ClientIDStr);

            char PunishedClientName[128];
            GetClientName(PunishedClient, PunishedClientName, 128);

            if (param1 == 0)
            {
                BaseComm_SetClientGag(PunishedClient, true);
                GagTimer[PunishedClient] = CreateTimer((GagTime.FloatValue * 60.0), Timer_UngagPlayer, PunishedClient);

                CPrintToChatAll("%s Vote to gag {orange}%s {default}passed.", Prefix, PunishedClientName);
            }
            else
                CPrintToChatAll("%s Vote to gag player failed.", Prefix, PunishedClientName);
        }
    }
    return 0;
}

public int VoteMute_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteEnd:
        {
            if (!isEnabled)
            {
                CancelVote();
                return 0;
            }

            char ClientIDStr[12];
            GetMenuItem(menu, param1, ClientIDStr, 12);
            int PunishedClient = StringToInt(ClientIDStr);

            char PunishedClientName[128];
            GetClientName(PunishedClient, PunishedClientName, 128);

            if (param1 == 0)
            {
                BaseComm_SetClientMute(PunishedClient, true);

                MuteTimer[PunishedClient] = CreateTimer((MuteTime.FloatValue * 60.0), Timer_UnmutePlayer, PunishedClient);

                CPrintToChatAll("%s Vote to mute {orange}%s {default}passed.", Prefix, PunishedClientName);
            }
            else
                CPrintToChatAll("%s Vote to mute player failed.", Prefix, PunishedClientName);
        }
    }
    return 0;
}

public int VoteKick_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteEnd:
        {
            if (!isEnabled)
            {
                CancelVote();
                return 0;
            }

            char ClientIDStr[12];
            GetMenuItem(menu, param1, ClientIDStr, 12);
            int PunishedClient = StringToInt(ClientIDStr);

            char PunishedClientName[128];
            GetClientName(PunishedClient, PunishedClientName, 128);

            if (param1 == 0)
            {
                KickClient(PunishedClient, "[SNT] You were vote kicked from the server.");
                CPrintToChatAll("%s Vote to kick {orange}%s {default}passed.", Prefix, PunishedClientName);
            }
            else
                CPrintToChatAll("%s Vote to kick player failed.", Prefix, PunishedClientName);
        }
    }
    return 0;
}

public int VoteBan_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteEnd:
        {   

            if (!isEnabled)
            {
                CancelVote();
                return 0;
            }

            char ClientIDStr[12];
            GetMenuItem(menu, param1, ClientIDStr, 12);
            int PunishedClient = StringToInt(ClientIDStr);

            char PunishedClientName[128];
            GetClientName(PunishedClient, PunishedClientName, 128);

            if (param1 == 0)
            {
                char KickMessage[256];
                Format(KickMessage, 256, "[SNT] You have been vote banned from the server for %i minutes.", BanTime.IntValue);

                BanClient(PunishedClient, BanTime.IntValue, BANFLAG_AUTHID | BANFLAG_AUTO, "Vote banned", KickMessage);
                CPrintToChatAll("%s Vote to ban {orange}%s {default}passed.", Prefix, PunishedClientName);
            }
            else
                CPrintToChatAll("%s Vote to ban player failed.", Prefix, PunishedClientName);
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
            if (!isEnabled)
            {
                CancelVote();
                return 0;
            }
            char ChosenOpt[192];
            // 0 - Mode
            // 1 - ClientID of player being voted against.
            // 2 - SteamID of player being voted against.
            char ExplodedOpt[3][64];

            char VoterAuth[64];
            char VoterName[128];
            char VoterNameEsc[257];
            char VoteeName[128];
            char VoteeNameEsc[257];

            char VoteTimestamp[64];

            GetMenuItem(menu, param2, ChosenOpt, 192);
            ExplodeString(ChosenOpt, ",", ExplodedOpt, 3, 64);
            FormatTime(VoteTimestamp, 64, "%D %R:%S", GetTime() - (4*60*60));

            GetClientAuthId(param1, AuthId_Steam3, VoterAuth, 64);
            GetClientName(param1, VoterName, 128);
            GetClientName(StringToInt(ExplodedOpt[1]), VoteeName, 128);

            SQL_EscapeString(DB_sntdb, VoterName, VoterNameEsc, 257);
            SQL_EscapeString(DB_sntdb, VoteeName, VoteeNameEsc, 257);

            char iQuery[512];

            Menu voteMenuToSend;
            switch (StringToInt(ExplodedOpt[0]))
            {
                case 0:
                {
                    if (isSlayOnCooldown)
                    {
                        EmitSoundToClient(param1, "snt_sounds/ypp_sting.mp3");
                        CPrintToChat(param1, "%s {fullred}You cannot voteslay someone right now! You have: {default}%i seconds {fullred}until you can start a vote.", Prefix, SlayCooldownLeft);
                        return 0;
                    }

                    isSlayOnCooldown = true;
                    SlayVoteTimer = CreateTimer(1.0, Timer_SlayTimer, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
                    CPrintToChatAll("%s {yellowgreen}%s {default}has started a vote to slay {orange}%s!", Prefix, VoterName, VoteeName);
                    Format(iQuery, 512, "INSERT INTO %svotes VALUES (\'%s\', \'%s\', \'%s\', \'%s\', \'%s\', \'%s\')", SchemaName, VoteTimestamp, VoterAuth, ExplodedOpt[2], "SLAY", VoterNameEsc, VoteeNameEsc);
                    voteMenuToSend = BuildVoteMenu(0, VoteeName, StringToInt(ExplodedOpt[1]));
                    if (CountdownTimer == INVALID_HANDLE)
                        CountdownTimer = CreateTimer(1.0, Timer_CountdownTimer, voteMenuToSend, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
                }
                case 1:
                {
                    if (isVoteOnCooldown)
                    {
                        EmitSoundToClient(param1, "snt_sounds/ypp_sting.mp3");
                        CPrintToChat(param1, "%s {fullred}You cannot votegag someone right now! You have: {default}%i seconds {fullred}until you can start a vote.", Prefix, CooldownLeft);
                        return 0;
                    }
                    isVoteOnCooldown = true;
                    CPrintToChatAll("%s {yellowgreen}%s {default}has started a vote to gag {orange}%s!", Prefix, VoterName, VoteeName);
                    CooldownTimer = CreateTimer(1.0, Timer_CooldownTimer, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
                    Format(iQuery, 512, "INSERT INTO %svotes VALUES (\'%s\', \'%s\', \'%s\', \'%s\', \'%s\', \'%s\')", SchemaName, VoteTimestamp, VoterAuth, ExplodedOpt[2], "GAG", VoterNameEsc, VoteeNameEsc);
                    voteMenuToSend = BuildVoteMenu(1, VoteeName, StringToInt(ExplodedOpt[1]));
                    if (CountdownTimer == INVALID_HANDLE)
                        CountdownTimer = CreateTimer(1.0, Timer_CountdownTimer, voteMenuToSend, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
                }
                case 2:
                {
                    if (isMuteOnCooldown)
                    {
                        EmitSoundToClient(param1, "snt_sounds/ypp_sting.mp3");
                        CPrintToChat(param1, "%s {fullred}You cannot votemute someone right now! You have: {default}%i seconds {fullred}until you can start a vote.", Prefix, MuteCooldownLeft);
                        return 0;
                    }

                    isMuteOnCooldown = true;
                    MuteVoteTimer = CreateTimer(1.0, Timer_MuteTimer, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
                    CPrintToChatAll("%s {yellowgreen}%s {default}has started a vote to mute {orange}%s!", Prefix, VoterName, VoteeName);
                    Format(iQuery, 512, "INSERT INTO %svotes VALUES (\'%s\', \'%s\', \'%s\', \'%s\', \'%s\', \'%s\')", SchemaName, VoteTimestamp, VoterAuth, ExplodedOpt[2], "MUTE", VoterNameEsc, VoteeNameEsc);
                    voteMenuToSend = BuildVoteMenu(2, VoteeName, StringToInt(ExplodedOpt[1]));
                    if (CountdownTimer == INVALID_HANDLE)
                        CountdownTimer = CreateTimer(1.0, Timer_CountdownTimer, voteMenuToSend, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
                }
                case 3:
                {
                    if (isVoteOnCooldown)
                    {
                        EmitSoundToClient(param1, "snt_sounds/ypp_sting.mp3");
                        CPrintToChat(param1, "%s {fullred}You cannot votekick someone right now! You have: {default}%i seconds {fullred}until you can start a vote.", Prefix, CooldownLeft);
                        return 0;
                    }
                    isVoteOnCooldown = true;
                    CPrintToChatAll("%s {yellowgreen}%s {default}has started a vote to kick {orange}%s!", Prefix, VoterName, VoteeName);
                    CooldownTimer = CreateTimer(1.0, Timer_CooldownTimer, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
                    Format(iQuery, 512, "INSERT INTO %svotes VALUES (\'%s\', \'%s\', \'%s\', \'%s\', \'%s\', \'%s\')", SchemaName, VoteTimestamp, VoterAuth, ExplodedOpt[2], "KICK", VoterNameEsc, VoteeNameEsc);
                    voteMenuToSend = BuildVoteMenu(3, VoteeName, StringToInt(ExplodedOpt[1]));
                    if (CountdownTimer == INVALID_HANDLE)
                        CountdownTimer = CreateTimer(1.0, Timer_CountdownTimer, voteMenuToSend, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
                }
                case 4:
                {
                    if (isVoteOnCooldown)
                    {
                        EmitSoundToClient(param1, "snt_sounds/ypp_sting.mp3");
                        CPrintToChat(param1, "%s {fullred}You cannot voteban someone right now! You have: {default}%i seconds {fullred}until you can start a vote.", Prefix, CooldownLeft);
                        return 0;
                    }
                    isVoteOnCooldown = true;
                    CPrintToChatAll("%s {yellowgreen}%s {default}has started a vote to ban {orange}%s!", Prefix, VoterName, VoteeName);
                    CooldownTimer = CreateTimer(1.0, Timer_CooldownTimer, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
                    Format(iQuery, 512, "INSERT INTO %svotes VALUES (\'%s\', \'%s\', \'%s\', \'%s\', \'%s\', \'%s\')", SchemaName, VoteTimestamp, VoterAuth, ExplodedOpt[2], "BAN", VoterNameEsc, VoteeNameEsc);
                    voteMenuToSend = BuildVoteMenu(4, VoteeName, StringToInt(ExplodedOpt[1]));
                    if (CountdownTimer == INVALID_HANDLE)
                        CountdownTimer = CreateTimer(1.0, Timer_CountdownTimer, voteMenuToSend, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
                }
            }

            SQL_TQuery(DB_sntdb, SQL_ErrorHandler, iQuery);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int Page1_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char ChosenOpt[10];
            GetMenuItem(menu, param2, ChosenOpt, 10);
            if (StrEqual(ChosenOpt, "SLAY"))
                BuildPlayerList(param1, 0);
            else if (StrEqual(ChosenOpt, "GAG"))
                BuildPlayerList(param1, 1);
            else if (StrEqual(ChosenOpt, "MUTE"))
                BuildPlayerList(param1, 2);
            else if (StrEqual(ChosenOpt, "KICK"))
                BuildPlayerList(param1, 3);
            else if (StrEqual(ChosenOpt, "BAN"))
                BuildPlayerList(param1, 4);
            else if (StrEqual(ChosenOpt, "SCRAMBLE"))
                //CPrintToChat(param1, "%s Coming Soon!", Prefix);
                SendScrambleVote(param1);
            else if (StrEqual(ChosenOpt, "SP"))
                SendSPVote(param1);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int AddPerms_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char SteamId[64];
            char uQuery[512];

            GetMenuItem(menu, param2, SteamId, 64);
            Format(uQuery, 512, "UPDATE %splayers SET VotePerms=\'1\' WHERE SteamId=\'%s\'", SchemaName, SteamId);
            SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);

            CPrintToChat(param1, "%s Sucessfully added voteperms for SteamId {greenyellow}%s", Prefix, SteamId);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int RmvPerms_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char SteamId[64];
            char uQuery[512];

            GetMenuItem(menu, param2, SteamId, 64);
            Format(uQuery, 512, "UPDATE %splayers SET VotePerms=\'0\' WHERE SteamId=\'%s\'", SchemaName, SteamId);
            SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);

            CPrintToChat(param1, "%s Sucessfully removed voteperms for SteamId {greenyellow}%s", Prefix, SteamId);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public void SQL_ErrorHandler(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
        PrintToServer("[SNT] ERROR! DATABASE IS NULL!");

    if (!StrEqual(error, ""))
        PrintToServer("[SNT] ERROR IN QUERY: %s", error);
}

public void SQL_CheckForPerms(Database db, DBResultSet results, const char[] error, any data)
{
    while (SQL_FetchRow(results))
    {
        if (!SQL_IsFieldNull(results, 0))
        {
            if (SQL_FetchInt(results, 0) != 1)
            {
                playerHasVotePerms[data] = false;
            }
        }
    }
}

public Action Timer_CountdownTimer(Handle timer, any menu)
{
    if (VoteCountdown == 0)
    {
        VoteMenuToAll(menu, 10);
        CountdownTimer = INVALID_HANDLE;
        VoteCountdown = 5;
        return Plugin_Stop;
    }

    PrintCenterTextAll("[SNT] A vote is starting in %i second(s)!", VoteCountdown);
    VoteCountdown--;
    return Plugin_Continue;
}

public Action Timer_CooldownTimer(Handle timer, any data)
{
    if (CooldownLeft == 0)
    {
        CooldownLeft = CooldownTime.IntValue;
        isVoteOnCooldown = false;
        CooldownTimer = INVALID_HANDLE;
        return Plugin_Stop;
    }

    CooldownLeft--;
    return Plugin_Continue;
}

public Action Timer_SpawnProtectionCooldownTimer(Handle timer, any data)
{
    if (SpawnProtectionLeft == 0)
    {
        SpawnProtectionLeft = SpawnProtectionCooldownTime.IntValue;
        isSPOnCooldown = false;
        SPVoteTimer = INVALID_HANDLE;
        return Plugin_Stop;
    }

    SpawnProtectionLeft--;
    return Plugin_Continue;
}

public Action Timer_SlayTimer(Handle timer, any data)
{
    if (SlayCooldownLeft == 0)
    {
        SlayCooldownLeft = SlayCooldownTime.IntValue;
        isSlayOnCooldown = false;
        SlayVoteTimer = INVALID_HANDLE;
        return Plugin_Stop;
    }

    SlayCooldownLeft--;
    return Plugin_Continue;
}

public Action Timer_MuteTimer(Handle timer, any data)
{
    if (MuteCooldownLeft == 0)
    {
        MuteCooldownLeft = MuteCooldownTime.IntValue;
        isMuteOnCooldown = false;
        MuteVoteTimer = INVALID_HANDLE;
        return Plugin_Stop;
    }

    MuteCooldownLeft--;
    return Plugin_Continue;
}

public Action Timer_ScrambleTimer(Handle timer, any data)
{
    if (ScrambleCooldownLeft == 0)
    {
        ScrambleCooldownLeft = ScrambleCooldownTime.IntValue;
        isScrambleOnCooldown = false;
        ScrambleVoteTimer = INVALID_HANDLE;
        return Plugin_Stop;
    }

    ScrambleCooldownLeft--;
    return Plugin_Continue;
}

public Action Timer_UngagPlayer(Handle timer, any client)
{
    if (SNT_IsValidClient(client))
    {
        BaseComm_SetClientGag(client, false);
        CPrintToChat(client, "%s You've been ungagged.", Prefix);
        EmitSoundToClient(client, "snt_sounds/ypp_whistle.mp3");
    }
    return Plugin_Continue;
}

public Action Timer_UnmutePlayer(Handle timer, any client)
{
    if (SNT_IsValidClient(client))
    {
        BaseComm_SetClientMute(client, false);
        CPrintToChat(client, "%s You've been unmuted.", Prefix);
        EmitSoundToClient(client, "snt_sounds/ypp_whistle.mp3");
    }
    return Plugin_Continue;
}

public Action ADM_ModVotePerms(int client, int args)
{
    if (args < 1 && client != 0)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s Use {greenyellow}/voteperms <add | rmv> {orange}[Steam3ID] {default}to give / remove a player's votemenu permissions", Prefix);
        return Plugin_Handled;
    }
    else if (args < 2 && client == 0)
    {
        PrintToServer("Use sm_voteperms <add | rmv> [Steam3ID] to give / remove a player's votemenu permissions");
        return Plugin_Handled;
    }

    if (args == 1 && client != 0)
    {
        char ChosenOpt[4];
        GetCmdArg(1, ChosenOpt, 4);

        if (StrEqual(ChosenOpt, "add"))
        {
            Menu AddPermsMenu = new Menu(AddPerms_Handler, MENU_ACTIONS_DEFAULT);
            AddPermsMenu.SetTitle("Choose a player to give perms")

            int ClientCount;

            for (int i = 1; i <= GetClientCount(); i++)
            {
                if (i == client || IsFakeClient(i) || playerHasVotePerms[i])
                    continue;
                
                char SteamId[64];
                GetClientAuthId(i, AuthId_Steam3, SteamId, 64);

                char PlayerName[128];
                GetClientName(i, PlayerName, 128);

                ClientCount++;
                AddPermsMenu.AddItem(SteamId, PlayerName);
            }

            if (ClientCount == 0)
            {
                EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
                CPrintToChat(client, "%s {fullred}No players lack voting perms!", Prefix);
                return Plugin_Handled;
            }
            else
                AddPermsMenu.Display(client, 0);
        }
        else if (StrEqual(ChosenOpt, "rmv"))
        {
            Menu RmvPermsMenu = new Menu(RmvPerms_Handler, MENU_ACTIONS_DEFAULT);
            RmvPermsMenu.SetTitle("Choose a player to remove perms")

            int ClientCount;

            for (int i = 1; i <= GetClientCount(); i++)
            {
                if (i == client || IsFakeClient(i))
                    continue;
                
                char SteamId[64];
                GetClientAuthId(i, AuthId_Steam3, SteamId, 64);

                char PlayerName[128];
                GetClientName(i, PlayerName, 128);

                ClientCount++;
                RmvPermsMenu.AddItem(SteamId, PlayerName);
            }

            if (ClientCount == 0)
            {
                EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
                CPrintToChat(client, "%s {fullred}No players have voting perms!", Prefix);
                return Plugin_Handled;
            }
            else
                RmvPermsMenu.Display(client, 0);
        }
    }
    else if (args == 2 && client != 0)
    {
        char CmdBuffer[256];
        char CmdMode[32];
        char AuthID[64];

        GetCmdArgString(CmdBuffer, 256);

        int len, total_len;

        if ((len = BreakString(CmdBuffer, CmdMode, 32)) != -1)
            total_len += len;
        else
        {
            EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
            CPrintToChat(client, "%s Use {greenyellow}/voteperms <add | rmv> {orange}[Steam3ID] {default}to give / remove a player's votemenu permissions", Prefix);
            return Plugin_Handled;
        }

        if ((len = BreakString(CmdBuffer[total_len], AuthID, 64)) != -1)
            total_len += len;
        else
        {
            total_len = 0;
            CmdBuffer[0] = '\0';
            EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
            CPrintToChat(client, "%s Use {greenyellow}/voteperms <add | rmv> {orange}[Steam3ID] {default}to give / remove a player's votemenu permissions", Prefix);
            return Plugin_Handled;
        }

        bool isValid = false;
        if (!strncmp(AuthID, "[U:", 3))
            isValid = true;
        
        if (!isValid)
        {
            EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
            CPrintToChat(client, "%s {fullred}Invalid Steam3 ID.", Prefix);
            return Plugin_Handled;
        }
        else
        {
            if (StrEqual(CmdMode, "add"))
            {
                char uQuery[512];
                Format(uQuery, 512, "UPDATE %splayers SET VotePerms=\'1\' WHERE SteamId=\'%s\'", SchemaName, AuthID);
                SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);
                CPrintToChat(client, "%s Sucessfully gave Steam3ID {greenyellow}%s {default}voteperms.", Prefix, AuthID);
                return Plugin_Handled;
            }
            else if (StrEqual(CmdMode, "rmv"))
            {
                char uQuery[512];
                Format(uQuery, 512, "UPDATE %splayers SET VotePerms=\'0\' WHERE SteamId=\'%s\'", SchemaName, AuthID);
                SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);
                CPrintToChat(client, "%s Sucessfully removed Steam3ID {greenyellow}%s's {default}voteperms.", Prefix, AuthID);
                return Plugin_Handled;
            }
            else
            {
                EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
                CPrintToChat(client, "%s {fullred}Invalid command mode.", Prefix);
                return Plugin_Handled;
            }
        }
    }
    return Plugin_Handled;
}

public Action USR_OpenVoteMenu(int client, int args)
{
    GetMapTimeLeft(mapTimeLeft)
    char AuthID[64];
    GetClientAuthId(client, AuthId_Steam3, AuthID, 64);

    char sQuery[512];
    Format(sQuery, 512, "SELECT VotePerms FROM %splayers WHERE SteamId=\'%s\'", SchemaName, AuthID);
    SQL_TQuery(DB_sntdb, SQL_CheckForPerms, sQuery, client);

    if (client == 0)
    {
        PrintToServer("The server cannot start votes.");
        return Plugin_Handled;
    }

    if (!playerHasVotePerms[client])
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Your vote privileges have been revoked by an admin!", Prefix);
        return Plugin_Handled;
    }

    if (mapTimeLeft <= 360 && !HasEndOfMapVoteFinished())
    {
        isEnabled = false;
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote when the mapvote is about to happen.", Prefix);
        return Plugin_Handled;
    }
    else if (mapTimeLeft <= 360 && HasEndOfMapVoteFinished())
        isEnabled = true;

    if (GetClientCount() == 1)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote as the only person in the server.", Prefix);
        return Plugin_Handled;
    }

    if (IsVoteInProgress())
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote while another vote is in progress!", Prefix);
        return Plugin_Handled;
    }

    BuildPage1(client);
    return Plugin_Handled;
}