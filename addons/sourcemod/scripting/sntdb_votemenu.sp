#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <basecomm>
#include <tf2>
#include <dbi>

#include <morecolors>

#define REQUIRE_PLUGIN
#include <sntdb_core>

public Plugin myinfo =
{
    name = "SNT Votemenu",
    author = "Arcala the Gyiyg",
    description = "A vote menu for players to use when admins aren't online.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
}

Database DB_sntdb;
char DBConfName[64];
char SchemaName[64];
char Prefix[96];

bool isVoteOnCooldown;
bool isPlayerWarned[MAXPLAYERS + 1];
bool playerHasVotePerms[MAXPLAYERS + 1] = { true, ... };

ConVar CooldownTime;
ConVar GagTime;
ConVar MuteTime;
ConVar BanTime;

ArrayList GaggedPlayers;
ArrayList MutedPlayers;

char prevMap[512];

Handle GagTimer[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};
Handle MuteTimer[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};

public void OnPluginStart()
{
    GetCurrentMap(prevMap, 512);
    LoadSQLConfigs(DBConfName, 64, Prefix, 96, SchemaName, 64, "VoteMenu");
    
    char error[255];
    DB_sntdb = SQL_Connect(DBConfName, true, error, sizeof(error));
    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN PLUGIN START: %s", error);
    }

    CooldownTime = CreateConVar("snt_vote_cooldown", "300.0", "Set the time in seconds before another vote can be called.", 0, true, 0.0);
    GagTime = CreateConVar("snt_votegag_length", "15.0", "The amount of time in minutes for a player to be gagged.", 0, true, 5.0);
    MuteTime = CreateConVar("snt_votemute_length", "15.0", "The amount of time in minutes for a player to be muted.", 0, true, 5.0);
    BanTime = CreateConVar("snt_voteban_length", "15.0", "The amount of time in minutes for a player to be banned.", 0, true, 5.0);

    GaggedPlayers = CreateArray(1);
    MutedPlayers = CreateArray(1);

    HookEvent("player_team", Event_OnPlayerTeam);

    RegConsoleCmd("sm_votemenu", USR_OpenVoteMenu, "Use /votemenu to open the votemenu.");
    RegConsoleCmd("sm_votekick", USR_OpenVoteKick, "Use /votekick to start a vote to kick a player.");
    RegConsoleCmd("sm_voteban", USR_OpenVoteBan, "Use /voteban to start a vote to ban a player for 15 mins.");
    RegConsoleCmd("sm_votemute", USR_OpenVoteMute, "Use /votemute to start a vote to mute a player for 15 mins.");
    RegConsoleCmd("sm_votegag", USR_OpenVoteGag, "Use /votegag to start a vote to mute a gag a player for 15 mins.");
    RegConsoleCmd("sm_votekill", USR_OpenVoteSlay, "Use /votekill to start a vote to slay a player.");

    RegAdminCmd("sm_voteperms", ADM_ModVotePerms, ADMFLAG_GENERIC, "Use /voteperms [add | rmv] (opt: Steam3ID) to give / remove a player's votemenu permissions");
}

public void OnClientPostAdminCheck(int client)
{
    if (!IsFakeClient(client))
    {
        char AuthID[64];
        GetClientAuthId(client, AuthId_Steam3, AuthID, 64);

        char sQuery[512];
        Format(sQuery, 512, "SELECT VotePerms FROM %splayers WHERE SteamId=\'%s\'", SchemaName, AuthID);
        SQL_TQuery(DB_sntdb, SQL_CheckForPerms, sQuery, client);

        if (GaggedPlayers.FindValue(GetClientUserId(client)) != -1)
        {
            BaseComm_SetClientGag(client, true);
            GagTimer[client] = CreateTimer((GagTime.FloatValue * 60.0), Timer_UngagPlayer, client);
        }

        if (MutedPlayers.FindValue(GetClientUserId(client)) != -1)
        {
            BaseComm_SetClientMute(client, true);
            MuteTimer[client] = CreateTimer((MuteTime.FloatValue * 60.0), Timer_UnmutePlayer, client);
        }
    }
}

public void OnClientDisconnect(int client)
{
    if (GagTimer[client] != INVALID_HANDLE)
        KillTimer(GagTimer[client]);
    
    if (MuteTimer[client] != INVALID_HANDLE)
        KillTimer(MuteTimer[client]);

    isPlayerWarned[client] = false;
    playerHasVotePerms[client] = true;
}

public Action Event_OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    char currentMap[512];
    GetCurrentMap(currentMap, 512);

    if (StrEqual(currentMap, prevMap))
    {
        int uid = GetEventInt(event, "userid");
        int client = GetClientOfUserId(uid);
        if (GaggedPlayers.FindValue(uid) != -1 || MutedPlayers.FindValue(uid) != -1)
        {
            if (!isPlayerWarned)
            {
                isPlayerWarned[client] = true;

                if (GaggedPlayers.FindValue(uid) != -1)
                {
                    EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
                    CPrintToChat(client, "%s Your gag has been reset for another 15 minutes for trying to avoid it.", Prefix);
                }

                if (MutedPlayers.FindValue(uid) != -1)
                {
                    EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
                    CPrintToChat(client, "%s Your mute has been reset for another 15 minutes for trying to avoid it.", Prefix);
                }
            }
        }
    }
    return Plugin_Changed;
}

public void OnMapEnd()
{
    GetCurrentMap(prevMap, 512);
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
    VoteMenu_Page1.AddItem("SLAY", "Vote kill player");
    VoteMenu_Page1.AddItem("GAG", GagOpt);
    VoteMenu_Page1.AddItem("MUTE", MuteOpt);
    VoteMenu_Page1.AddItem("KICK", "Vote kick player");
    VoteMenu_Page1.AddItem("BAN", BanOpt);
    VoteMenu_Page1.Display(client, 0);
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
            VoteSlay_Menu.SetTitle("Kill %s?", playerName);
            VoteSlay_Menu.AddItem(YesOpt, "Yes");
            VoteSlay_Menu.AddItem("X", "No");
            VoteSlay_Menu.ExitButton = false;
            return VoteSlay_Menu;
        }
        case 1:
        {
            Menu VoteGag_Menu = new Menu(VoteGag_Handler);
            VoteGag_Menu.SetTitle("Gag %s for 15 mins?", playerName);
            VoteGag_Menu.AddItem(YesOpt, "Yes");
            VoteGag_Menu.AddItem("X", "No");
            VoteGag_Menu.ExitButton = false;
            return VoteGag_Menu;
        }
        case 2:
        {
            Menu VoteMute_Menu = new Menu(VoteMute_Handler);
            VoteMute_Menu.SetTitle("Mute %s for 15 mins?", playerName);
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
            VoteBan_Menu.SetTitle("Ban %s for 15 mins?", playerName);
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
            PlayerList.SetTitle("Choose a player to kill:");
        case 1:
            PlayerList.SetTitle("Choose a player to gag:");
        case 2:
            PlayerList.SetTitle("Choose a player to mute:");
        case 3:
            PlayerList.SetTitle("Choose a player to kick:");
        case 4:
            PlayerList.SetTitle("Choose a player to ban:");
    }

    for (int i = 1; i <= GetClientCount(); i++)
    {
        if (type == 0 && IsPlayerAlive(i) && !IsFakeClient(i) && i != client)
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
        else if (!IsFakeClient(i) && i != client)
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
    }
    
    PlayerList.Display(client, 0);
}

public int VoteSlay_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    isVoteOnCooldown = true;
    CreateTimer(GetConVarFloat(CooldownTime), Timer_VoteCooldown);

    switch (action)
    {
        case MenuAction_VoteEnd:
        {
            char ClientIDStr[12];
            GetMenuItem(menu, param1, ClientIDStr, 12);
            int PunishedClient = StringToInt(ClientIDStr);

            char PunishedClientName[128];
            GetClientName(PunishedClient, PunishedClientName, 128);

            if (param1 == 0)
            {
                int ClientHealth = GetClientHealth(PunishedClient);
                float ClientDamage = (ClientHealth * 6.0);
                SDKHooks_TakeDamage(PunishedClient, 0, 0, ClientDamage);

                CPrintToChatAll("%s Vote to kill {orange}%s {default}passed.", Prefix, PunishedClientName);
            }
            else
                CPrintToChatAll("%s Vote to kill {orange}%s {default}failed.", Prefix, PunishedClientName);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int VoteGag_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    isVoteOnCooldown = true;
    CreateTimer(GetConVarFloat(CooldownTime), Timer_VoteCooldown);

    switch (action)
    {
        case MenuAction_VoteEnd:
        {
            char ClientIDStr[12];
            GetMenuItem(menu, param1, ClientIDStr, 12);
            int PunishedClient = StringToInt(ClientIDStr);

            char PunishedClientName[128];
            GetClientName(PunishedClient, PunishedClientName, 128);

            if (param1 == 0)
            {
                int ClientUID = GetClientUserId(PunishedClient);
                GaggedPlayers.Push(ClientUID);

                BaseComm_SetClientGag(PunishedClient, true);
                GagTimer[PunishedClient] = CreateTimer((GagTime.FloatValue * 60.0), Timer_UngagPlayer, PunishedClient);

                CPrintToChatAll("%s Vote to gag {orange}%s {default}passed.", Prefix, PunishedClientName);
            }
            else
                CPrintToChatAll("%s Vote to gag {orange}%s {default}failed.", Prefix, PunishedClientName);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int VoteMute_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    isVoteOnCooldown = true;
    CreateTimer(GetConVarFloat(CooldownTime), Timer_VoteCooldown);

    switch (action)
    {
        case MenuAction_VoteEnd:
        {
            char ClientIDStr[12];
            GetMenuItem(menu, param1, ClientIDStr, 12);
            int PunishedClient = StringToInt(ClientIDStr);

            char PunishedClientName[128];
            GetClientName(PunishedClient, PunishedClientName, 128);

            if (param1 == 0)
            {
                int ClientUID = GetClientUserId(PunishedClient);
                GaggedPlayers.Push(ClientUID);
                BaseComm_SetClientMute(PunishedClient, true);

                MuteTimer[PunishedClient] = CreateTimer((MuteTime.FloatValue * 60.0), Timer_UnmutePlayer, PunishedClient);

                CPrintToChatAll("%s Vote to mute {orange}%s {default}passed.", Prefix, PunishedClientName);
            }
            else
                CPrintToChatAll("%s Vote to mute {orange}%s {default}failed.", Prefix, PunishedClientName);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int VoteKick_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    isVoteOnCooldown = true;
    CreateTimer(GetConVarFloat(CooldownTime), Timer_VoteCooldown);

    switch (action)
    {
        case MenuAction_VoteEnd:
        {
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
                CPrintToChatAll("%s Vote to kick {orange}%s {default}failed.", Prefix, PunishedClientName);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int VoteBan_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    isVoteOnCooldown = true;
    CreateTimer(GetConVarFloat(CooldownTime), Timer_VoteCooldown);

    switch (action)
    {
        case MenuAction_VoteEnd:
        {
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
                CPrintToChatAll("%s Vote to ban {orange}%s {default}failed.", Prefix, PunishedClientName);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int PlayerList_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
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
            FormatTime(VoteTimestamp, 64, "%c", GetTime());

            GetClientAuthId(param1, AuthId_Steam3, VoterAuth, 64);
            GetClientName(param1, VoterName, 128);
            GetClientName(StringToInt(ExplodedOpt[1]), VoteeName, 128);

            SQL_EscapeString(DB_sntdb, VoterName, VoterNameEsc, 257);
            SQL_EscapeString(DB_sntdb, VoteeName, VoteeNameEsc, 257);

            char iQuery[512];
            switch (StringToInt(ExplodedOpt[0]))
            {
                case 0:
                {
                    Format(iQuery, 512, "INSERT INTO %svotes VALUES (\'%s\', \'%s\', \'%s\', \'%s\', \'%s\', \'%s\')", SchemaName, VoteTimestamp, VoterAuth, ExplodedOpt[2], "SLAY", VoterNameEsc, VoteeNameEsc);
                    VoteMenuToAll(BuildVoteMenu(0, VoteeName, StringToInt(ExplodedOpt[1])), 20);
                }
                case 1:
                {
                    Format(iQuery, 512, "INSERT INTO %svotes VALUES (\'%s\', \'%s\', \'%s\', \'%s\', \'%s\', \'%s\')", SchemaName, VoteTimestamp, VoterAuth, ExplodedOpt[2], "GAG", VoterNameEsc, VoteeNameEsc);
                    VoteMenuToAll(BuildVoteMenu(1, VoteeName, StringToInt(ExplodedOpt[1])), 20);
                }
                case 2:
                {
                    Format(iQuery, 512, "INSERT INTO %svotes VALUES (\'%s\', \'%s\', \'%s\', \'%s\', \'%s\', \'%s\')", SchemaName, VoteTimestamp, VoterAuth, ExplodedOpt[2], "MUTE", VoterNameEsc, VoteeNameEsc);
                    VoteMenuToAll(BuildVoteMenu(2, VoteeName, StringToInt(ExplodedOpt[1])), 20);
                }
                case 3:
                {
                    Format(iQuery, 512, "INSERT INTO %svotes VALUES (\'%s\', \'%s\', \'%s\', \'%s\', \'%s\', \'%s\')", SchemaName, VoteTimestamp, VoterAuth, ExplodedOpt[2], "KICK", VoterNameEsc, VoteeNameEsc);
                    VoteMenuToAll(BuildVoteMenu(3, VoteeName, StringToInt(ExplodedOpt[1])), 20);
                }
                case 4:
                {
                    Format(iQuery, 512, "INSERT INTO %svotes VALUES (\'%s\', \'%s\', \'%s\', \'%s\', \'%s\', \'%s\')", SchemaName, VoteTimestamp, VoterAuth, ExplodedOpt[2], "BAN", VoterNameEsc, VoteeNameEsc);
                    VoteMenuToAll(BuildVoteMenu(4, VoteeName, StringToInt(ExplodedOpt[1])), 20);
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
            char ChosenOpt[8];
            GetMenuItem(menu, param2, ChosenOpt, 8);
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

public Action Timer_VoteCooldown(Handle timer, any data)
{
    isVoteOnCooldown = false;
    return Plugin_Continue;
}

public Action Timer_UngagPlayer(Handle timer, any client)
{
    int UID = GetClientUserId(client);
    if (GaggedPlayers.FindValue(UID) != -1)
    {
        GaggedPlayers.Erase(GaggedPlayers.FindValue(UID));
        BaseComm_SetClientGag(client, false);
        CPrintToChat(client, "%s You've been ungagged.", Prefix);
        EmitSoundToClient(client, "snt_sounds/ypp_whistle.mp3");
    }
    return Plugin_Continue;
}

public Action Timer_UnmutePlayer(Handle timer, any client)
{
    int UID = GetClientUserId(client);
    if (MutedPlayers.FindValue(UID) != -1)
    {
        MutedPlayers.Erase(MutedPlayers.FindValue(UID));
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
    if (client == 0)
    {
        PrintToServer("The server cannot start votes.");
        return Plugin_Handled;
    }

    char AuthID[64];
    GetClientAuthId(client, AuthId_Steam3, AuthID, 64);

    char sQuery[512];
    Format(sQuery, 512, "SELECT VotePerms FROM %splayers WHERE SteamId=\'%s\'", SchemaName, AuthID);
    SQL_TQuery(DB_sntdb, SQL_CheckForPerms, sQuery, client);

    if (!playerHasVotePerms[client])
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Your vote privileges have been revoked by an admin!", Prefix);
        return Plugin_Handled;
    }

    if (GetClientCount() == 1)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote as the only person in the server.", Prefix);
        return Plugin_Handled;
    }

    if (isVoteOnCooldown)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote while the vote system is on cooldown!", Prefix);
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

public Action USR_OpenVoteKick(int client, int args)
{
    if (client == 0)
    {
        PrintToServer("The server cannot start votes.");
        return Plugin_Handled;
    }

    char AuthID[64];
    GetClientAuthId(client, AuthId_Steam3, AuthID, 64);

    char sQuery[512];
    Format(sQuery, 512, "SELECT VotePerms FROM %splayers WHERE SteamId=\'%s\'", SchemaName, AuthID);
    SQL_TQuery(DB_sntdb, SQL_CheckForPerms, sQuery, client);

    if (!playerHasVotePerms[client])
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Your vote privileges have been revoked by an admin!", Prefix);
        return Plugin_Handled;
    }

    if (GetClientCount() == 1)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote as the only person in the server.", Prefix);
        return Plugin_Handled;
    }

    if (isVoteOnCooldown)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote while the vote system is on cooldown!", Prefix);
        return Plugin_Handled;
    }

    if (IsVoteInProgress())
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote while another vote is in progress!", Prefix);
        return Plugin_Handled;
    }

    BuildPlayerList(client, 3);
    return Plugin_Handled;
}

public Action USR_OpenVoteBan(int client, int args)
{
    if (client == 0)
    {
        PrintToServer("The server cannot start votes.");
        return Plugin_Handled;
    }

    char AuthID[64];
    GetClientAuthId(client, AuthId_Steam3, AuthID, 64);

    char sQuery[512];
    Format(sQuery, 512, "SELECT VotePerms FROM %splayers WHERE SteamId=\'%s\'", SchemaName, AuthID);
    SQL_TQuery(DB_sntdb, SQL_CheckForPerms, sQuery, client);

    if (!playerHasVotePerms[client])
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Your vote privileges have been revoked by an admin!", Prefix);
        return Plugin_Handled;
    }

    if (GetClientCount() == 1)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote as the only person in the server.", Prefix);
        return Plugin_Handled;
    }

    if (isVoteOnCooldown)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote while the vote system is on cooldown!", Prefix);
        return Plugin_Handled;
    }

    if (IsVoteInProgress())
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote while another vote is in progress!", Prefix);
        return Plugin_Handled;
    }

    BuildPlayerList(client, 4);
    return Plugin_Handled;
}

public Action USR_OpenVoteMute(int client, int args)
{
    if (client == 0)
    {
        PrintToServer("The server cannot start votes.");
        return Plugin_Handled;
    }

    char AuthID[64];
    GetClientAuthId(client, AuthId_Steam3, AuthID, 64);

    char sQuery[512];
    Format(sQuery, 512, "SELECT VotePerms FROM %splayers WHERE SteamId=\'%s\'", SchemaName, AuthID);
    SQL_TQuery(DB_sntdb, SQL_CheckForPerms, sQuery, client);

    if (!playerHasVotePerms[client])
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Your vote privileges have been revoked by an admin!", Prefix);
        return Plugin_Handled;
    }

    if (GetClientCount() == 1)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote as the only person in the server.", Prefix);
        return Plugin_Handled;
    }

    if (isVoteOnCooldown)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote while the vote system is on cooldown!", Prefix);
        return Plugin_Handled;
    }

    if (IsVoteInProgress())
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote while another vote is in progress!", Prefix);
        return Plugin_Handled;
    }

    BuildPlayerList(client, 2);
    return Plugin_Handled;
}

public Action USR_OpenVoteGag(int client, int args)
{
    if (client == 0)
    {
        PrintToServer("The server cannot start votes.");
        return Plugin_Handled;
    }

    char AuthID[64];
    GetClientAuthId(client, AuthId_Steam3, AuthID, 64);

    char sQuery[512];
    Format(sQuery, 512, "SELECT VotePerms FROM %splayers WHERE SteamId=\'%s\'", SchemaName, AuthID);
    SQL_TQuery(DB_sntdb, SQL_CheckForPerms, sQuery, client);

    if (!playerHasVotePerms[client])
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Your vote privileges have been revoked by an admin!", Prefix);
        return Plugin_Handled;
    }

    if (GetClientCount() == 1)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote as the only person in the server.", Prefix);
        return Plugin_Handled;
    }

    if (isVoteOnCooldown)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote while the vote system is on cooldown!", Prefix);
        return Plugin_Handled;
    }

    if (IsVoteInProgress())
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote while another vote is in progress!", Prefix);
        return Plugin_Handled;
    }

    BuildPlayerList(client, 1);
    return Plugin_Handled;
}

public Action USR_OpenVoteSlay(int client, int args)
{
    if (client == 0)
    {
        PrintToServer("The server cannot start votes.");
        return Plugin_Handled;
    }

    char AuthID[64];
    GetClientAuthId(client, AuthId_Steam3, AuthID, 64);

    char sQuery[512];
    Format(sQuery, 512, "SELECT VotePerms FROM %splayers WHERE SteamId=\'%s\'", SchemaName, AuthID);
    SQL_TQuery(DB_sntdb, SQL_CheckForPerms, sQuery, client);

    if (!playerHasVotePerms[client])
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Your vote privileges have been revoked by an admin!", Prefix);
        return Plugin_Handled;
    }

    if (GetClientCount() == 1)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote as the only person in the server.", Prefix);
        return Plugin_Handled;
    }

    if (isVoteOnCooldown)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote while the vote system is on cooldown!", Prefix);
        return Plugin_Handled;
    }

    if (IsVoteInProgress())
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}You cannot start a vote while another vote is in progress!", Prefix);
        return Plugin_Handled;
    }

    BuildPlayerList(client, 0);
    return Plugin_Handled;
}