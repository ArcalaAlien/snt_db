#include <sourcemod>
#include <sdktools>
#include <events>
#include <clientprefs>
#include <adt_array>
#include <chat-processor>
#include <morecolors>

#include <sntdb_core>
#include <sntdb_store>

#define ICON_ON  "materials/icons/snt_mspam_on.vmt"
#define ICON_OFF "materials/icons/snt_mspam_off.vmt"


public Plugin myinfo =
{
    name = "SNT Micspam Module",
    author = "Arcala the Gyiyg",
    description = "Handles the micspam queue and timers",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

Database DB_sntdb;
char DBConfName[64];
char SchemaName[64];
char StoreSchema[64]
char Prefix[96];

ArrayList MicspamQueue;
bool PlayerSpamming  = false;
bool PlayerListening[MAXPLAYERS + 1];
bool WillAutoJoin[MAXPLAYERS + 1] = {false, ...};
bool OwnsMicspamItem[MAXPLAYERS + 1] = {false, ...};
bool BlockedByAdmin[MAXPLAYERS + 1] = {false, ...};

bool WarningSent30s;
bool WarningSent10s;

int PastSender;
int CurrentFrame;
float TimeLeft;
int TimesExtended;

Cookie ck_ListeningToSpam;
Cookie ck_AutoJoin;

ConVar cv_CheckEveryXFrames;
ConVar cv_Timelimit;
ConVar cv_ExtendTime;
ConVar cv_ExtendLimits;

Handle MSpam10sWarning = INVALID_HANDLE;
Handle MSpamMoveToEnd = INVALID_HANDLE;
Handle MicspamTimer = INVALID_HANDLE;
Handle PreventTimer[MAXPLAYERS + 1] = {INVALID_HANDLE, ...};

public void OnPluginStart()
{
    LoadSQLConfigs(DBConfName, 64, Prefix, 96, SchemaName, 64, "Micspam", 1, StoreSchema, 64);
    char error[255];
    DB_sntdb = SQL_Connect(DBConfName, true, error, sizeof(error));
    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN STORE PLUGIN START: %s", error);
    }

    ck_ListeningToSpam = RegClientCookie("snt_listening", "Is the player listening to the micspam?", CookieAccess_Protected);
    ck_AutoJoin = RegClientCookie("snt_autojoin", "Does the user want to autojoin the queue?", CookieAccess_Protected);

    cv_CheckEveryXFrames = CreateConVar("snt_searchframes", "2.0", "Checks the array list every x frames to update client status.", 0, true, 2.0);
    cv_Timelimit = CreateConVar("snt_mspam_timelimit", "300.0", "The time limit in seconds a player has to micspam.", 0, true, 60.0);
    cv_ExtendTime = CreateConVar("snt_mspam_extendtime", "300.0", "The time limit in seconds to extend a player's micspam time.", 0, true, 60.0);
    cv_ExtendLimits = CreateConVar("snt_mspam_extendlimits", "1.0", "How many times a player can extend their micspam time", 0, true, 0.0);

    // Start micspamming
    RegConsoleCmd("sm_start", USR_StartSpam, "/start Use this to start your micspam timer when it's your turn!");
    RegConsoleCmd("sm_play", USR_StartSpam, "/play Use this to start your micspam timer when it's your turn!")

    // Stop micspamming
    RegConsoleCmd("sm_stop", USR_EndSpam, "/stop Use this to end your timer and let the next person play!");
    RegConsoleCmd("sm_end", USR_EndSpam, "/end Use this to end your timer and let the next person play!");

    // Join micspam queue
    RegConsoleCmd("sm_join", USR_JoinQueue, "/join Use this to join the micspam queue!");

    // Leave micspam queue
    RegConsoleCmd("sm_leave", USR_LeaveQueue, "/leave Use this to leave the micspam queue!");

    // Open micspam menu.
    RegConsoleCmd("sm_micspam", USR_OpenMicspamMenu, "/micspam Use this to open the micspam menu!");
    // /micspam | opens menu
    // /micspam extend | opens extend vote for all users listening
    // /micspam admin Opens admin menu.
}

public void OnMapStart()
{
    MicspamQueue = CreateArray(1);
    if (PrecacheModel(ICON_ON) == 0)
        PrintToServer("[SNT] MICSPAM: Unable to precache ICON_ON.");
    if (PrecacheModel(ICON_OFF) == 0)
        PrintToServer("[SNT] MICSPAM: Unable to precache ICON_OFF.");

    AddFileToDownloadsTable(ICON_ON);
    AddFileToDownloadsTable("materials/icons/snt_mspam_on.vtf");
    AddFileToDownloadsTable(ICON_OFF);
    AddFileToDownloadsTable("materials/icons/snt_mspam_off.vtf");
}

public void OnClientPutInServer(int client)
{
    char SteamId[64];
    GetClientAuthId(client, AuthId_Steam3, SteamId, 64);

    char sQuery[256];
    Format(sQuery, 256, "SELECT ItemId FROM %sInventories WHERE SteamId=\'%s\' AND ItemId=\'srv_mspam\'", StoreSchema, SteamId)

    SQL_TQuery(DB_sntdb, SQL_CheckForItem, sQuery, client);

    if (AreClientCookiesCached(client))
    {
        char IsListening[6];
        char AutoJoin[6];
        GetClientCookie(client, ck_ListeningToSpam, IsListening, 6);
        GetClientCookie(client, ck_AutoJoin, AutoJoin, 6);

        if (IsListening[0] == '\0')
        {
            PlayerListening[client] = true;
            SetClientCookie(client, ck_ListeningToSpam, "true");
        }
        else
        {
            if (StrEqual(IsListening, "true"))
                PlayerListening[client] = true;
            else
                PlayerListening[client] = false;
        }

        if (AutoJoin[0] == '\0')
            SetClientCookie(client, ck_AutoJoin, "false");
        else
        {
            if (StrEqual(AutoJoin, "true"))
            {
                JoinSpamQ(client);
                WillAutoJoin[client] = true;
            }
            else
                WillAutoJoin[client] = false;
        }
    }
}

public void OnClientDisconnect(int client)
{
    int index = MicspamQueue.FindValue(client);
    if (index != -1)
    {
        MicspamQueue.Erase(index);
        if (index == 0)
        {
            if (MSpam10sWarning != INVALID_HANDLE)
            {
                KillTimer(MSpam10sWarning);
                MSpam10sWarning = INVALID_HANDLE;
            }
            
            if (MSpamMoveToEnd != INVALID_HANDLE)
            {
                KillTimer(MSpamMoveToEnd);
                MSpamMoveToEnd = INVALID_HANDLE;
            }
            
            if (MicspamTimer != INVALID_HANDLE)
            {
                KillTimer(MicspamTimer);
                MicspamTimer = INVALID_HANDLE;
            }

            if (PreventTimer[client] != INVALID_HANDLE)
            {
                KillTimer(MicspamTimer);
                PreventTimer[client] = INVALID_HANDLE;
            }

            PlayerSpamming = false;
            WarningSent30s = false;
            WarningSent10s = false;
        }
        for (int i = 0; i <= GetClientCount(); i++)
        {
            if (!IsFakeClient(i))
            {
                SetListenOverride(i, client, Listen_Default);
            }
        }
    }

    PlayerListening[client] = true;
    WillAutoJoin[client] = false;
    OwnsMicspamItem[client] = false;
    BlockedByAdmin[client] = false;
}

public Action OnPlayerRunCmd(int client)
{
    if (CurrentFrame != (cv_CheckEveryXFrames.IntValue - 1))
    {
        CurrentFrame++;
        return Plugin_Continue;
    }
    else
    {
        int index = MicspamQueue.FindValue(client);
        if (index == 0)
        {
            if (client == PastSender && WarningSent30s)
            {
                CurrentFrame = 0;
                return Plugin_Continue;
            }
            else if (client != PastSender && !WarningSent30s)
            {
                EmitSoundToClient(client, "snt_sounds/ypp_whistle.mp3");
                CPrintToChat(client, "%s Ye've got {greenyellow}30 seconds{default} to type {greenyellow}/start{default} before ye'll be moved to the back of the queue.", Prefix);
                WarningSent30s = true;
                MSpam10sWarning = CreateTimer(20.0, Timer_Show10sWarning, client);
                MSpamMoveToEnd = CreateTimer(30.0, Timer_MoveToEnd, client);
                CurrentFrame = 0;
                PastSender = client;
            }
        }
    }
    return Plugin_Continue;
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
    int index = MicspamQueue.FindValue(author);
    if (index != -1)
    {
        if (index == 0 && PlayerSpamming)
            Format(name, MAXLENGTH_NAME, "%s {limegreen}♫{default}", name);
        else if (index == 0 && !PlayerSpamming)
            Format(name, MAXLENGTH_NAME, "%s {immortal}♫{default}", name);
        else
            Format(name, MAXLENGTH_NAME, "%s {ancient}♫{default}", name);
    }
    return Plugin_Changed;
}

void BuildPage1(int client)
{
    int index = MicspamQueue.FindValue(client);
    int TotalWaiting = MicspamQueue.Length;

    char TotalWaitingStr[24];
    Format(TotalWaitingStr, 24, "Total In Queue: %i", TotalWaiting);

    Panel MicspamMenu = CreatePanel();
    MicspamMenu.SetTitle("Micspam Menu");
    
    switch (index)
    {
        case -1:
        {
            if (OwnsMicspamItem[client])
            {
                MicspamMenu.DrawText(" ");
                MicspamMenu.DrawText(TotalWaitingStr);
                MicspamMenu.DrawText("Place: N/A");
                MicspamMenu.DrawItem("Join Queue");
                MicspamMenu.DrawText(" ");
                (PlayerListening[client]) ? MicspamMenu.DrawText("You are listening to other's micspam.") : MicspamMenu.DrawText("You are not listening to other's micspam.");
                (PlayerListening[client]) ? MicspamMenu.DrawItem("Stop Listening") : MicspamMenu.DrawItem("Start Listening");
                MicspamMenu.DrawText(" ");
                (WillAutoJoin[client]) ? MicspamMenu.DrawText("You will join the queue when you connect.") : MicspamMenu.DrawText("You will not join the queue automatically when you connect.");
                MicspamMenu.DrawItem("Toggle AutoJoin");
                MicspamMenu.DrawText(" ");
                MicspamMenu.DrawItem("Exit");
            }
            else
            {
                MicspamMenu.DrawText(" ");
                MicspamMenu.DrawText(TotalWaitingStr);
                MicspamMenu.DrawText("Place: N/A");
                MicspamMenu.DrawText("You don't own micspam privileges!");
                MicspamMenu.DrawItem("Sail to the Tavern to buy them!");
                MicspamMenu.DrawText(" ");
                (PlayerListening[client]) ? MicspamMenu.DrawText("You are listening to other's micspam.") : MicspamMenu.DrawText("You are not listening to other's micspam.");
                (PlayerListening[client]) ? MicspamMenu.DrawItem("Stop Listening") : MicspamMenu.DrawItem("Start Listening");
                MicspamMenu.DrawText(" ");
                (WillAutoJoin[client]) ? MicspamMenu.DrawText("You will join the queue when you connect.") : MicspamMenu.DrawText("You will not join the queue automatically when you connect.");
                MicspamMenu.DrawItem("Toggle AutoJoin");
                MicspamMenu.DrawText(" ");
                MicspamMenu.DrawItem("Exit");
            }
        }
        case 0:
        {
            if (!PlayerSpamming)
            {
                char Place[32];
                Format(Place, 32, "Use /play, /start, or the button\nbelow to start spamming.");
                MicspamMenu.DrawText(" ");
                MicspamMenu.DrawText(TotalWaitingStr);
                MicspamMenu.DrawText(Place);
                MicspamMenu.DrawItem("Start Spam");
                MicspamMenu.DrawItem("Leave Queue");
                MicspamMenu.DrawText(" ");
                (PlayerListening[client]) ? MicspamMenu.DrawText("You are listening to other's micspam.") : MicspamMenu.DrawText("You are not listening to other's micspam.");
                (PlayerListening[client]) ? MicspamMenu.DrawItem("Stop Listening") : MicspamMenu.DrawItem("Start Listening");
                MicspamMenu.DrawText(" ");
                (WillAutoJoin[client]) ? MicspamMenu.DrawText("You will join the queue when you connect.") : MicspamMenu.DrawText("You will not join the queue automatically when you connect.");
                MicspamMenu.DrawItem("Toggle AutoJoin");
                MicspamMenu.DrawText(" ");
                MicspamMenu.DrawItem("Exit");
            }
            else
            {
                char Place[32];
                Format(Place, 32, "Use /stop, /end, or the button\nbelow to stop spamming.");
                MicspamMenu.DrawText(" ");
                MicspamMenu.DrawText(TotalWaitingStr);
                MicspamMenu.DrawText(Place);
                MicspamMenu.DrawText(" ")
                MicspamMenu.DrawItem("Stop Spam");
                MicspamMenu.DrawItem("Vote Extend Spam");
                MicspamMenu.DrawText(" ");
                (PlayerListening[client]) ? MicspamMenu.DrawText("You are listening to other's micspam.") : MicspamMenu.DrawText("You are not listening to other's micspam.");
                (PlayerListening[client]) ? MicspamMenu.DrawItem("Stop Listening") : MicspamMenu.DrawItem("Start Listening");
                MicspamMenu.DrawText(" ");
                (WillAutoJoin[client]) ? MicspamMenu.DrawText("You will join the queue when you connect.") : MicspamMenu.DrawText("You will not join the queue automatically when you connect.");
                MicspamMenu.DrawItem("Toggle AutoJoin");
                MicspamMenu.DrawText(" ");
                MicspamMenu.DrawItem("Exit");
            }
        }
        default:
        {
            MicspamMenu.DrawText(" ");
            MicspamMenu.DrawText(TotalWaitingStr);
            char Place[12];
            if (index == 1)
                MicspamMenu.DrawText("Place: Next");
            else
            {
                Format(Place, 12, "Place: %i", (index + 1));
                MicspamMenu.DrawText(Place)
            }
            MicspamMenu.DrawItem("Leave Queue");
            MicspamMenu.DrawText(" ");
            (PlayerListening[client]) ? MicspamMenu.DrawText("You are listening to other's micspam.") : MicspamMenu.DrawText("You are not listening to other's micspam.");
            (PlayerListening[client]) ? MicspamMenu.DrawItem("Stop Listening") : MicspamMenu.DrawItem("Start Listening");
            MicspamMenu.DrawText(" ");
            (WillAutoJoin[client]) ? MicspamMenu.DrawText("You will join the queue when you connect.") : MicspamMenu.DrawText("You will not join the queue automatically when you connect.");
            MicspamMenu.DrawItem("Toggle AutoJoin");
            MicspamMenu.DrawText(" ");
            MicspamMenu.DrawItem("Exit");
        }
    }

    MicspamMenu.Send(client, Page1_Handler, 0);
}

void BuildAdminPage1(int client)
{
    Panel AdminMenu = CreatePanel();
    AdminMenu.SetTitle("Micspam Admin Menu");

    AdminMenu.DrawItem("Stop current spammer");
    AdminMenu.DrawItem("Remove user from queue");
    AdminMenu.DrawItem("Temporarily prevent user from joining queue.");
    AdminMenu.DrawText(" ");
    AdminMenu.DrawItem("Exit");

    AdminMenu.Send(client, Page1Admin_Handler, 0);
}

void StartSpamming(int client)
{
    int index = MicspamQueue.FindValue(client);
    if (index == 0)
    {
        if (MSpam10sWarning != INVALID_HANDLE)
            KillTimer(MSpam10sWarning);
        if (MSpamMoveToEnd != INVALID_HANDLE)
            KillTimer(MSpamMoveToEnd);
        
        WarningSent30s = false;
        WarningSent10s = false;
        PlayerSpamming = true;
        CPrintToChat(client, "%s Started spamming! Ye've got 5 minutes!\nYe can ask yer crewmates to lengthen yer time by typing {greenyellow}/micspam extend{default} or sailing to the {greenyellow}/micspam{default} menu!", Prefix);

        for (int i = 1; i <= GetClientCount(); i++)
        {
            if (!IsFakeClient(i) && PlayerListening[i])
                SetListenOverride(i, client, Listen_Yes);
        }

        MicspamTimer = CreateTimer(1.0, Timer_MicspamTimer, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

        return;
    }
    else
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        if (index == -1)
        {
            CPrintToChat(client, "%s {fullred} Yer not part of the queue!\n{default}Use {greenyellow}/join{default} or visit the {greenyelllow}/micspam{default} menu to be added!", Prefix);
            return;
        }
        CPrintToChat(client, "%s {fullred} It's not yer turn to spam yet!\nYe be now number: %i/%i", (index + 1), MicspamQueue.Length);
        return;
    }
}

void StopSpamming(int client)
{
    TimesExtended = 0;
    int index = MicspamQueue.FindValue(client);
    if (index == 0 && PlayerSpamming)
    {
        PlayerSpamming = false;

        MicspamQueue.Erase(index);
        MicspamQueue.Push(client);
        MicspamQueue.ShiftUp(1);
        CPrintToChat(client, "%s Sucessfully moved ye to the aft o' the queue! Ye be now number: %i", Prefix, MicspamQueue.Length);

        if (MicspamTimer != INVALID_HANDLE)
        {
            KillTimer(MicspamTimer);
            MicspamTimer = INVALID_HANDLE;
        }

        for (int i = 1; i <= GetClientCount(); i++)
        {
            if (PlayerListening[i])
                SetListenOverride(i, client, Listen_No);
        }
    }
    else if (index == 0 && !PlayerSpamming)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Ye can't stop spamming if yer not already spamming!", Prefix);
    }
    else if (index != 0)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Ye can't stop spamming if yer not in the queue!", Prefix);
    }
}

void SendExtendVote(int sender)
{
    if (TimesExtended >= cv_ExtendLimits.IntValue)
    {
        EmitSoundToClient(sender, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(sender, "%s {fullred}Ye've reached the extension limit!");
        return;
    }

    if (IsVoteInProgress())
    {
        EmitSoundToClient(sender, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(sender, "%s {fullred}Thar's already a vote in progress!");
        return;
    }

    char PlayerName[128];
    GetClientName(sender, PlayerName, 128);

    Menu EVoteMenu = new Menu(EVoteMenu_Handler, MENU_ACTIONS_DEFAULT);
    EVoteMenu.SetTitle("Extend %s's micspam time?", PlayerName);
    EVoteMenu.AddItem("Y", "Yes");
    EVoteMenu.AddItem("N", "No");
    EVoteMenu.ExitButton = false;

    int Listeners[MAXPLAYERS + 1]
    for (int i = 0; i <= GetClientCount(); i++)
    {
        if (PlayerListening[i] && i != sender)
        {
            Listeners[i] = i;
        }
    }

    CPrintToChat(sender, "%s Sent a vote to all crewmates listenin to yer spam!", Prefix);

    EVoteMenu.DisplayVote(Listeners, MAXPLAYERS + 1, 30);
}

void SendStopVote(int sender)
{
    if (IsVoteInProgress())
    {
        EmitSoundToClient(sender, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(sender, "%s {fullred}Thar's already a vote in progress!");
        return;
    }

    int client = MicspamQueue.Get(0);

    char PlayerName[128];
    GetClientName(client, PlayerName, 128);

    Menu SVoteMenu = new Menu(SVoteMenu_Handler, MENU_ACTIONS_DEFAULT);
    SVoteMenu.SetTitle("Stop %s's micspam time?", PlayerName);
    SVoteMenu.AddItem("Y", "Yes");
    SVoteMenu.AddItem("N", "No");
    SVoteMenu.ExitButton = false;

    int Listeners[MAXPLAYERS + 1]
    for (int i = 1; i <= GetClientCount(); i++)
    {
        if (PlayerListening[i])
        {
            Listeners[i] = i;
        }
    }

    SVoteMenu.DisplayVote(Listeners, MAXPLAYERS + 1, 30);
}

void JoinSpamQ(int client)
{
    char SteamId[64];
    GetClientAuthId(client, AuthId_Steam3, SteamId, 64);

    char sQuery[256];
    Format(sQuery, 256, "SELECT ItemId FROM %sInventories WHERE SteamId=\'%s\' AND ItemId=\'srv_mspam\'", StoreSchema, SteamId);

    SQL_TQuery(DB_sntdb, SQL_CheckForItem, sQuery, client);
    
    if (MicspamQueue.FindValue(client) == -1 && OwnsMicspamItem[client])
    {
        MicspamQueue.Push(client);
        CPrintToChat(client, "%s Ye've been added to the micspam queue!", Prefix);
        for (int i = 1; i <= GetClientCount(); i++)
        {
            if (!IsFakeClient(i))
            {
                SetListenOverride(i, client, Listen_No);
            }
        }
    }
    else if (!OwnsMicspamItem[client])
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Ye don't own micspam privileges! Sail to the {greenyellow}/tavern {fullred}to buy them!", Prefix);
    }
    else
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Yer already in the micspam queue!", Prefix);
    }
}

void LeaveSpamQ(int client)
{
    int index = MicspamQueue.FindValue(client);
    if (index != -1)
    {
        if (index == 0)
        {
            if (MSpam10sWarning != INVALID_HANDLE)
                KillTimer(MSpam10sWarning);
            if (MSpamMoveToEnd != INVALID_HANDLE)
                KillTimer(MSpamMoveToEnd);
            PastSender = 0;
        }
        MicspamQueue.Erase(index);
        MicspamQueue.ShiftUp(1);
        CPrintToChat(client, "%s Ye've been removed from the miscpam queue!", Prefix);
        for (int i = 1; i <= GetClientCount(); i++)
        {
            if (!IsFakeClient(i))
            {
                SetListenOverride(i, client, Listen_Default);
            }
        }
    }
    else if (!OwnsMicspamItem[client])
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Ye don't own micspam privileges! Sail to the {greenyellow}/tavern {fullred}to buy them!", Prefix);
    }
    else
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred} Yer not part of the queue!\n{default}Use {greenyellow}/join{default} or visit the {greenyelllow}/micspam{default} menu to be added!", Prefix);
    }
}

void MuteAllSpammers(int client)
{
    for (int i = 1; i < GetClientCount(); i++)
    {
        if (!IsFakeClient(i))
        {
            int index = MicspamQueue.FindValue(i);
            if (index != -1)
                SetListenOverride(client, i, Listen_No);
        }
    }
}

void UnmuteAllSpammers(int client)
{
    for (int i = 1; i < GetClientCount(); i++)
    {
        if (!IsFakeClient(i))
        {
            int index = MicspamQueue.FindValue(i);
            if (index != -1)
                SetListenOverride(client, i, Listen_Default);
        }
    }
}

void GetTimeRemainingStr(char[] buffer, int maxlen)
{
    float MinsLeft = TimeLeft / 60;
    float SecsLeft = TimeLeft % 60;

    PrintToServer("%.0f:%.0f", MinsLeft, SecsLeft);

    if (SecsLeft < 10.0)
        Format(buffer, maxlen, "%.0f:0%.0f", MinsLeft, SecsLeft);
    else
        Format(buffer, maxlen, "%.0f:%.0f", MinsLeft, SecsLeft);
}

public int EVoteMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteEnd:
        {
            int Spammer = MicspamQueue.Get(0);
            char SpammerName[128];
            GetClientName(Spammer, SpammerName, 128);

            if (param1 == 0)
            {
                TimesExtended++;
                TimeLeft += cv_ExtendTime.FloatValue;
                for (int i = 0; i <= GetClientCount(); i++)
                {
                    if (PlayerListening[i])
                    {
                        EmitSoundToClient(i, "snt_sounds/correct.mp3");
                        CPrintToChat(i, "%s Vote went through! Extended %s's time by {greenyellow}%.0f {default}minutes!", Prefix, SpammerName, (cv_ExtendTime.FloatValue / 60));
                    }
                }
            }
            else
            {
                for (int i = 0; i <= GetClientCount(); i++)
                {
                    if (PlayerListening[i])
                    {
                        EmitSoundToClient(i, "snt_sounds/ypp_sting.mp3");
                        CPrintToChat(i, "%s Vote to extend %s's micspam failed!", Prefix, SpammerName);
                    }
                }
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

public int SVoteMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_VoteEnd:
        {
            int Spammer = MicspamQueue.Get(0);
            char SpammerName[128];
            GetClientName(Spammer, SpammerName, 128);

            if (param1 == 0)
            {
                StopSpamming(Spammer);
                for (int i = 0; i <= GetClientCount(); i++)
                {
                    if (PlayerListening[i])
                    {
                        EmitSoundToClient(i, "snt_sounds/correct.mp3");
                        CPrintToChat(i, "%s Vote went through! Stopping the %s's spam and moving them to the back of the queue.", Prefix, SpammerName);
                    }
                }
            }
            else
            {
                for (int i = 0; i <= GetClientCount(); i++)
                {
                    if (PlayerListening[i])
                    {
                        EmitSoundToClient(i, "snt_sounds/ypp_sting.mp3");
                        CPrintToChat(i, "%s Vote to stop the %s's micspam failed!", Prefix, SpammerName);
                    }
                }
            }
        }
        case MenuAction_End:
        {
            delete menu;
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
            int index = MicspamQueue.FindValue(param1);
            switch (index)
            {
                case -1:
                {
                    if (OwnsMicspamItem[param1])
                    {
                        switch (param2)
                        {
                            case 1:
                            {
                                EmitSoundToClient(param1, "buttons/button14.wav");
                                JoinSpamQ(param1);
                                BuildPage1(param1);
                            }
                            case 2:
                            {
                                EmitSoundToClient(param1, "buttons/button14.wav");
                                PlayerListening[param1] = !PlayerListening[param1];
                                if (!PlayerListening[param1])
                                {
                                    MuteAllSpammers(param1);
                                    SetClientCookie(param1, ck_ListeningToSpam, "false");
                                }
                                else
                                {
                                    UnmuteAllSpammers(param1);
                                    SetClientCookie(param1, ck_ListeningToSpam, "true");
                                }

                                BuildPage1(param1);
                            }
                            case 3:
                            {
                                EmitSoundToClient(param1, "buttons/button14.wav");
                                WillAutoJoin[param1] = !WillAutoJoin[param1];
                                if (!WillAutoJoin[param1])
                                    SetClientCookie(param1, ck_AutoJoin, "false");
                                else
                                    SetClientCookie(param1, ck_AutoJoin, "true");

                                BuildPage1(param1);
                            }
                            case 4:
                            {
                                delete menu;
                                return 0;
                            }
                        }
                    }
                    else
                    {
                        switch (param2)
                        {
                            case 1:
                            {
                                EmitSoundToClient(param1, "buttons/button14.wav");
                                OpenStoreMenu(param1);
                            }
                            case 2:
                            {
                                EmitSoundToClient(param1, "buttons/button14.wav");
                                PlayerListening[param1] = !PlayerListening[param1];
                                if (!PlayerListening[param1])
                                {
                                    MuteAllSpammers(param1);
                                    SetClientCookie(param1, ck_ListeningToSpam, "false");
                                }
                                else
                                {
                                    UnmuteAllSpammers(param1);
                                    SetClientCookie(param1, ck_ListeningToSpam, "true");
                                }

                                BuildPage1(param1);
                            }
                            case 3:
                            {
                                EmitSoundToClient(param1, "buttons/button14.wav");
                                WillAutoJoin[param1] = !WillAutoJoin[param1];
                                if (!WillAutoJoin[param1])
                                    SetClientCookie(param1, ck_AutoJoin, "false");
                                else
                                    SetClientCookie(param1, ck_AutoJoin, "true");

                                BuildPage1(param1);
                            }
                            case 4:
                            {
                                delete menu;
                                return 0;
                            }
                        }
                    }
                }
                case 0:
                {
                    if (!PlayerSpamming)
                    {
                        switch (param2)
                        {
                            case 1:
                            {
                                EmitSoundToClient(param1, "buttons/button14.wav");
                                StartSpamming(param1);
                                BuildPage1(param1);
                            }
                            case 2:
                            {
                                EmitSoundToClient(param1, "buttons/button14.wav");
                                LeaveSpamQ(param1);
                                BuildPage1(param1);
                            }
                            case 3:
                            {
                                EmitSoundToClient(param1, "buttons/button14.wav");
                                PlayerListening[param1] = !PlayerListening[param1];
                                if (!PlayerListening[param1])
                                {
                                    MuteAllSpammers(param1);
                                    SetClientCookie(param1, ck_ListeningToSpam, "false");
                                }
                                else
                                {
                                    UnmuteAllSpammers(param1);
                                    SetClientCookie(param1, ck_ListeningToSpam, "true");
                                }

                                BuildPage1(param1);
                            }
                            case 4:
                            {
                                EmitSoundToClient(param1, "buttons/button14.wav");
                                WillAutoJoin[param1] = !WillAutoJoin[param1];
                                if (!WillAutoJoin[param1])
                                    SetClientCookie(param1, ck_AutoJoin, "false");
                                else
                                    SetClientCookie(param1, ck_AutoJoin, "true");

                                BuildPage1(param1);
                            }
                            case 5:
                            {
                                EmitSoundToClient(param1, "buttons/combine_button7.wav");
                                delete menu;
                            }
                        }
                    }
                    else
                    {
                        switch (param2)
                        {
                            case 1:
                            {
                                EmitSoundToClient(param1, "buttons/button14.wav");
                                StopSpamming(param1);
                                BuildPage1(param1);
                            }
                            case 2:
                            {
                                EmitSoundToClient(param1, "buttons/button14.wav");
                                SendExtendVote(param1);
                                BuildPage1(param1);
                            }
                            case 3:
                            {
                                EmitSoundToClient(param1, "buttons/button14.wav");
                                PlayerListening[param1] = !PlayerListening[param1];
                                if (!PlayerListening[param1])
                                {
                                    MuteAllSpammers(param1);
                                    SetClientCookie(param1, ck_ListeningToSpam, "false");
                                }
                                else
                                {
                                    UnmuteAllSpammers(param1);
                                    SetClientCookie(param1, ck_ListeningToSpam, "true");
                                }
                                BuildPage1(param1);
                            }
                            case 4:
                            {
                                EmitSoundToClient(param1, "buttons/button14.wav");
                                WillAutoJoin[param1] = !WillAutoJoin[param1];
                                if (!WillAutoJoin[param1])
                                    SetClientCookie(param1, ck_AutoJoin, "false");
                                else
                                    SetClientCookie(param1, ck_AutoJoin, "true");

                                BuildPage1(param1);
                            }
                            case 5:
                            {
                                EmitSoundToClient(param1, "buttons/combine_button7.wav");
                                delete menu;
                            }
                        }
                    }
                }
                default:
                {
                    switch (param2)
                    {
                        case 1:
                        {
                            EmitSoundToClient(param1, "buttons/button14.wav");
                            LeaveSpamQ(param1);
                            BuildPage1(param1);
                        }
                        case 2:
                        {
                            EmitSoundToClient(param1, "buttons/button14.wav");
                            PlayerListening[param1] = !PlayerListening[param1];
                            if (!PlayerListening[param1])
                            {
                                MuteAllSpammers(param1);
                                SetClientCookie(param1, ck_ListeningToSpam, "false");
                            }
                            else
                            {
                                UnmuteAllSpammers(param1);
                                SetClientCookie(param1, ck_ListeningToSpam, "true");
                            }
                            BuildPage1(param1);
                        }
                        case 3:
                        {
                            EmitSoundToClient(param1, "buttons/button14.wav");
                            WillAutoJoin[param1] = !WillAutoJoin[param1];
                            if (!WillAutoJoin[param1])
                                SetClientCookie(param1, ck_AutoJoin, "false");
                            else
                                SetClientCookie(param1, ck_AutoJoin, "true");

                            BuildPage1(param1);
                        }
                        case 4:
                        {
                            EmitSoundToClient(param1, "buttons/combine_button7.wav");
                            delete menu;
                        }
                    }
                }
            }
        }
        case MenuAction_End:
        {
            delete menu;
            return 0;
        }
    }
    return 0;
}

public int RemovePlayer_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char ClientStr[5];
            GetMenuItem(menu, param2, ClientStr, 5);

            int ClientChose = StringToInt(ClientStr);
            char PlayerName[128];
            GetClientName(ClientChose, PlayerName, 128);

            LeaveSpamQ(ClientChose);
            CPrintToChat(param1, "%s Sucessfully removed {greenyellow}%s {default}from the micspam queue.", Prefix, PlayerName);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int PreventPlayerPage1_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char ClientStr[5];
            GetMenuItem(menu, param2, ClientStr, 5);

            int ClientChose = StringToInt(ClientStr);
            char PlayerName[128];
            GetClientName(ClientChose, PlayerName, 128);

            Menu TimeLimit = new Menu(PreventPlayerPage2_Handler, MENU_ACTIONS_DEFAULT);
            TimeLimit.SetTitle("Choose a duration");

            char Opt1[12];
            char Opt2[12];
            char Opt3[12];
            char Opt4[12];
            char Opt5[12];
            char Opt6[12];

            Format(Opt1, 12, "%i,5.0", ClientChose);
            Format(Opt2, 12, "%i,7.5", ClientChose);
            Format(Opt3, 12, "%i,10.0", ClientChose);
            Format(Opt4, 12, "%i,12.5", ClientChose);
            Format(Opt5, 12, "%i,15.0", ClientChose);
            Format(Opt5, 12, "%i,0.0", ClientChose);

            TimeLimit.AddItem(Opt1, "5 Minutes");
            TimeLimit.AddItem(Opt2, "7.5 Minutes");
            TimeLimit.AddItem(Opt3, "10 Minutes");
            TimeLimit.AddItem(Opt4, "12.5 Minutes");
            TimeLimit.AddItem(Opt5, "15 Minutes");
            TimeLimit.AddItem(Opt6, "End of Map");

            TimeLimit.Display(param1, 0);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int PreventPlayerPage2_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char OptChose[12];
            GetMenuItem(menu, param2, OptChose, 12);

            char ExpldChoice[2][8];
            ExplodeString(OptChose, ",", ExpldChoice, 2, 8);

            int client = StringToInt(ExpldChoice[0]);
            float Duration = StringToFloat(ExpldChoice[1]);

            char ClientName[128];
            GetClientName(client, ClientName, 128);

            BlockedByAdmin[client] = true;

            if (MicspamQueue.Get(0) == client)
            {
                if (PlayerSpamming)
                    StopSpamming(client);
                LeaveSpamQ(client);
            }

            if (Duration == 0.0)
                CPrintToChat(param1, "%s Preventing %s from rejoining the queue until the end of the map, and removed them if they were in the queue.", Prefix, ClientName);
            else
            {
                PreventTimer[client] = CreateTimer((Duration * 60), UnblockPlayer_Timer, client);
                CPrintToChat(param1, "%s Preventing %s from rejoining the queue for %.0f minutes, and removed them if they were in the queue.", Prefix, ClientName, Duration);
            }
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int Page1Admin_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            switch (param2)
            {
                case 1:
                {
                    StopSpamming(MicspamQueue.Get(0));
                    CPrintToChat(param1, "%s Stopped the current micspammer.", Prefix);
                }
                case 2:
                {
                    Menu PlayerList = new Menu(RemovePlayer_Handler, MENU_ACTIONS_DEFAULT);
                    PlayerList.SetTitle("Choose a player to remove");
                    
                    int ArraySize = GetArraySize(MicspamQueue);
                    for (int i = 0; i <= ArraySize; i++)
                    {
                        char PlayerName[128];
                        GetClientName(MicspamQueue.Get(i), PlayerName, 128);

                        char Client[5];
                        Format(Client, 5, "%i", MicspamQueue.Get(i));
                        PlayerList.AddItem(Client, PlayerName);
                    }

                    PlayerList.Display(param1, 0);
                }
                case 3:
                {
                    Menu PlayerList = new Menu(PreventPlayerPage1_Handler, MENU_ACTIONS_DEFAULT);
                    PlayerList.SetTitle("Choose a player to prevent joining the queue");
                    
                    for (int i = 1; i <= GetClientCount(); i++)
                    {
                        char PlayerName[128];
                        GetClientName(i, PlayerName, 128);

                        char Client[5];
                        Format(Client, 5, "%i", i);
                        PlayerList.AddItem(Client, PlayerName);
                    }

                    PlayerList.Display(param1, 0);
                }
                case 4:
                {
                    delete menu;
                    return 0;
                }
            }
        }
        case MenuAction_End:
        {
            delete menu;
            return 0;
        }
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

public void SQL_CheckForItem(Database db, DBResultSet results, const char[] error, any data)
{
    while (SQL_FetchRow(results))
    {
        char ItemId[64];
        SQL_FetchString(results, 0, ItemId, 64);

        if (StrEqual(ItemId, "srv_mspam"))
            OwnsMicspamItem[data] = true;
        else
            OwnsMicspamItem[data] = false;
    }
}

public Action UnblockPlayer_Timer(Handle timer, any client)
{
    BlockedByAdmin[client] = false;
    PreventTimer[client] = INVALID_HANDLE;
    CPrintToChat(client, "%s You are now able to rejoin the micspam queue!", Prefix);
    return Plugin_Continue;
}

public Action Timer_Show10sWarning(Handle timer, any client)
{
    if (!WarningSent10s)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting2.mp3");
        CPrintToChat(client, "%s {fullred}Ye've {greenyellow}10 seconds{fullred} to type {greenyellow}/start{fullred} before ye will be moved to the back of the queue.", Prefix);
        WarningSent10s = true;
        MSpam10sWarning = INVALID_HANDLE;
    }
    return Plugin_Continue;
}

public Action Timer_MoveToEnd(Handle timer, any client)
{
    if (WarningSent30s && WarningSent10s)
    {
        PrintToServer("[SNT] Both warnings were sent.");
        int index = MicspamQueue.FindValue(client)
        if (index != -1)
        {
            MicspamQueue.Erase(index);
            MicspamQueue.Push(client);
            WarningSent30s = false;
            WarningSent10s = false;
            EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
            CPrintToChat(client, "%s {fullred}Ye've been moved to the back of the queue fer not starting in time!", Prefix);
            MSpamMoveToEnd = INVALID_HANDLE;
            PastSender = 0;
        }
    }
    return Plugin_Continue;
}

public Action Timer_MicspamTimer(Handle timer, any client)
{
    int index = MicspamQueue.FindValue(client);
    if (index != -1)
    {
        if (TimeLeft != 0.0)
        {
            char TimeLeftStr[8];
            GetTimeRemainingStr(TimeLeftStr, 8);
            PrintHintText(client, "Time Left: %s", TimeLeftStr);

            if (TimeLeft == 60.0)
            {
                EmitSoundToClient(client, "snt_sounds/ypp_whistle.mp3");
                CPrintToChat(client, "%s Ye've got {greenyellow}1 minute{default} remaining!\nIf ye need more time, ask yer crew by typing {greenyellow}/micspam extend{default}!", Prefix);
            }
            TimeLeft--;
        }
        else
        {
            PlayerSpamming = false;
            MicspamTimer = INVALID_HANDLE;
            MicspamQueue.Erase(index);
            MicspamQueue.Push(client);
            CPrintToChat(client, "%s Thank ye fer spamming! Ye've been moved to the back of the queue!", Prefix);
            return Plugin_Stop;
        }
        return Plugin_Continue;
    }
    else
    {
        PlayerSpamming = false;
        return Plugin_Stop;
    }
}

public Action USR_OpenMicspamMenu(int client, int args)
{
    if (client == 0)
    {
        PrintToServer("[SNT] Server cannot micspam.");
        return Plugin_Handled;
    }

    char SteamId[64];
    GetClientAuthId(client, AuthId_Steam3, SteamId, 64);

    char sQuery[256];
    Format(sQuery, 256, "SELECT ItemId FROM %sInventories WHERE SteamId=\'%s\' AND ItemId=\'srv_mspam\'", StoreSchema, SteamId)

    SQL_TQuery(DB_sntdb, SQL_CheckForItem, sQuery, client);

    if (args == 0 && OwnsMicspamItem[client])
    {
        BuildPage1(client);
        return Plugin_Handled;
    }
    else if (args > 0 && OwnsMicspamItem[client])
    {
        char CommandMode[12];
        GetCmdArg(1, CommandMode, 12);

        if (StrEqual(CommandMode, "extend"))
        {
            if (MicspamQueue.Get(0) != client)
            {
                EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
                CPrintToChat(client, "%s {fullred}Ye can't call a vote to extend micspam if yer not spamming!", Prefix);
                return Plugin_Handled;
            }
            SendExtendVote(client);
        }
        else if (StrEqual(CommandMode, "votestop") && MicspamQueue.Get(0) != client)
            SendStopVote(client);
        else if (StrEqual(CommandMode, "admin") && GetUserAdmin(client) != INVALID_ADMIN_ID)
            BuildAdminPage1(client);
    }
    else
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Ye don't own micspam privileges! Sail to the {greenyellow}/tavern {fullred}to buy them!", Prefix);
    }
    return Plugin_Handled;
}

public Action USR_StartSpam(int client, int args)
{
    if (client == 0)
    {
        PrintToServer("[SNT] Server cannot micspam.");
        return Plugin_Handled;
    }

    TimeLeft = cv_Timelimit.FloatValue;
    StartSpamming(client);
    return Plugin_Handled;
}

public Action USR_EndSpam(int client, int args)
{
    if (client == 0)
    {
        PrintToServer("[SNT] Server cannot micspam.");
        return Plugin_Handled;
    }

    StopSpamming(client);
    return Plugin_Handled;
}

public Action USR_JoinQueue(int client, int args)
{
    if (client == 0)
    {
        PrintToServer("[SNT] Server cannot join the micspam queue.");
        return Plugin_Handled;
    }

    if (!BlockedByAdmin[client])
        JoinSpamQ(client);
    else
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}An admin has prevented you from joining the queue!", Prefix);
        return Plugin_Handled;
    }

    return Plugin_Handled;
}

public Action USR_LeaveQueue(int client, int args)
{
    if (client == 0)
    {
        PrintToServer("[SNT] Server cannot join or leave the micspam queue.");
        return Plugin_Handled;
    }

    LeaveSpamQ(client);

    return Plugin_Handled;
}