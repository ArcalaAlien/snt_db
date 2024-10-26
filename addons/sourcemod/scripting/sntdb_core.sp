#include <sourcemod>
#include <string>
#include <dbi>
#include <files>
#include <sdktools>
#include <keyvalues>
#include <tf2>
#include <chat-processor>

#include <morecolors>

#include <sntdb/core>
#include <sntdb/store>

#define MSG01 "Have an issue with a player? Report them to an admin on our discord server!Use {greenyellow}discord.gg/xnuHA5KsEU{default} to join us and make a post in #public-staff-chat!"
#define MSG02 "Are there no admins currently online? Use {greenyellow}/calladmin {default}to call an admin, or {greenyellow}/votemenu {default}to handle it yourself."
#define MSG03 "Welcome to {greenyellow}Surf'n'Turf!{default}\nJoin our discord community at {greenyellow}discord.gg/xnuHA5KsEU{default}!"
#define MSG04 "Want an easy way to set up your custom items? Do {greenyellow}/equip{default} to access all custom item menus easily!"
#define MSG05 "Want a change of scenery? Use {greenyellow}/rtv {default}to vote to change the map!"
#define MSG06 "We have a huge selection of maps! Check it out using {greenyellow}/nominate!"
#define MSG07 "Bored? Type {greenyellow}rtd{default} in chat to get a random effect!"
#define MSG08 "New to the server? Use {greenyellow}/info{default} to open the info menu!"
#define MSG09 "Ye want treasure? Sail yerself to the {greenyellow}/tavern{default} ta check out their wares!"
#define MSG10 "Wanna check to see what ye've got in yer coffers? Do {greenyellow}/treasure{default} to find out!"
#define MSG11 "Wanna know how to use those sounds you bought from the store?\nBind keys to {greenyellow}sm_playslot1, sm_playslot2, & sm_playslot3 {default}to use our in-server soundboard!"
#define MSG12 "Give us your feedback! Use {greenyellow}/rate {default}to give a map a rating of 1-5 stars!"
#define MSG13 "Missing out on a taunt? Do {greenyellow}/taunt {orange}<name> {default}to play the taunt on your character!"
#define MSG14 "Need a better view? Type {greenyellow}/tp{default} in chat to go into third person mode!"
#define MSG15 "Want to stop listening to someone's voicechat, but not miss out on what they're typing? Use {greenyellow}/ignore {orange}<playername>{default} to stop listening to a player!"


public Plugin myinfo =
{
    name = "sntdb Core Module",
    author = "Arcala the Gyiyg",
    description = "(required) SNTDB Core Module.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

/*
TODO:
    Player enter / leave messages.

    Add group verification function
    
    Events:
        /snt_events
        Events admins can throw:
            Double credits
            1/2 Store Prices?
            Mini-contest (Top 3 players): /snt_contest <timelimit in mins=5min> <award=1000> (min is 500)>
                Announce contest (5 min time limit)
                Set contest to true
                3, 2, 1, GO!
                Wait 5 mins
                Set contest to false
                SLCT * FRM snt_players ORDR BY Points DESC LMT 3;
                First place gets (award)
                Second place gets (award * .5) rounded down
                Third place gets (award * .25) rounded down
        switch (Holiday)
            case birthday:
                use birthday_mapcycle.txt
                2x credits
                2x points?
                free birthday tag for joining?
            case 420:
                use weed_mapcycle.txt
                2x credits
                free stoner tag?
            case halloween:
                Spooky holiday-themed tags

    Server items?
        Micspam privileges

    Add /snt_groupmod <gid> <name> (Admin Only Command)
        Adds / removes a user in the server to a group.
        GroupIds:
            1 REGULAR (Default, everyone is part of this group, cannot remove)
            2 SUPPORTER (For those with the Early Supporter tag in discord)
            3 CONTRIBUTOR (For advisors / users who have contributed something to the server.)
            4 DONATOR (For $$$, duh)

*/

char DBConfName[64];
char Prefix[96];
char SchemaName[64];
char StoreSchema[64];

Database DB_sntdb;

bool Weekend;
bool EventEnabled;
char CurrentHoliday[32] = "None";
char CurrentEvent[32] = "None";
int  TimeLeft;

int PlayerJoined[MAXPLAYERS+1];
Handle InfoTimer = INVALID_HANDLE;

bool lateLoad;

bool isSkurfMap;
bool isArenaMap;

// Convars
ConVar TimeBetweenMessages;
ConVar EventCooldown;
ConVar mapType;
ConVar isWeekendConVar;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{

    CreateNative("SNT_LoadSQLConfigs", Native_LoadSQLConfigs);
    CreateNative("SNT_LoadSQLStoreConfigs", Native_LoadSQLStoreConfigs);
    CreateNative("SNT_GetServerTime", Native_GetServerTime);
    CreateNative("SNT_GetServerDay", Native_GetServerDay);
    CreateNative("SNT_CheckForWeekend", CheckWeekend_Native);
    CreateNative("SNT_IsValidClient",   Native_IsValidClient);
    CreateNative("SNT_CheckMapType", Native_CheckForMap);
    //CreateNative("SNT_CopyPlayerInfo", Native_CopyPlayerInfo);
    RegPluginLibrary("sntdb_core");

    lateLoad = late;

    return APLRes_Success;
}

public void OnPluginStart()
{
    KeyValues ConfigFile = new KeyValues("ConfigFile");
    char ConfigFilePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, ConfigFilePath, sizeof(ConfigFilePath), "configs/sntdb/main_config.cfg");

    ConfigFile.ImportFromFile(ConfigFilePath);
    
    if (ConfigFile == null)
    {
        ThrowError("[SNT] ERROR! \"configs/sntdb/main_config.cfg\": file does not exist!");
    }

    if (ConfigFile.JumpToKey("System"))
    {
        ConfigFile.GetString("dbconfig", DBConfName, sizeof(DBConfName));
        ConfigFile.GetString("message_prefix", Prefix, sizeof(Prefix));
        ConfigFile.GetString("schema", SchemaName, sizeof(SchemaName));
        ConfigFile.GetString("store_schema", StoreSchema, sizeof(StoreSchema));
        PrintToServer("[SNT] Loaded core configs");
    }
    else
    {
        ThrowError("[SNT] ERROR! COULD NOT LOAD CORE CONFIG");
    }  

    PrintToServer("[SNT] Connecting to Database");
    char error[255];
    DB_sntdb = SQL_Connect(DBConfName, true, error, sizeof(error));
    if (!StrEqual(error, ""))
    {
        ThrowError("[SNT] ERROR IN PLUGIN START: %s", error);
    }

    HookEvent("player_team", OnPlayerTeam);

    EventCooldown = CreateConVar("snt_event_cooldown", "480", "The cooldown time in seconds between events.", 0, true, 300.0);
    TimeBetweenMessages = CreateConVar("snt_msg_cooldown", "300", "The amount in seconds between each info message in chat.", 0, true, 180.0);
    mapType = CreateConVar("snt_map_type", "0", "What type of map this is. 0 - Combat, 1 - Skill Surf, 2 - Arena Surf", 0, true, 0.0, true, 2.0);
    isWeekendConVar = CreateConVar("snt_is_weekend", "0", "Is it the weekend?", 0, true, 0.0, true, 1.0);

    RegConsoleCmd("sm_info", USR_OpenInfoMenu, "Usage: /info Opens the server info menu!");
    RegConsoleCmd("sm_r", USR_Respawn, "Usage: /r to respawn!");
    RegConsoleCmd("sm_respawn", USR_Respawn, "Usage: /respawn to respawn!");
    RegAdminCmd("sm_goto", ADM_GotoPlayer, ADMFLAG_GENERIC,"Usage: /goto <player>");
    //RegAdminCmd("sm_snt_events",    ADM_OpenEventsMenu,      ADMFLAG_GENERIC,    "/snt_events: Use this to open the events menu.");
    //RegAdminCmd("sm_datetest",     ADM_TestPlugin,          ADMFLAG_GENERIC,    "test this bitch");
    //RegAdminCmd("sm_snt_groupmod",  ADM_ModGroup,           ADMFLAG_BAN,        "/snt_groupmod <gid> <user>: Toggle a user's group id. Type list with no user to list all groups");

    if (lateLoad)
        OnMapStart();
}

public void OnMapStart()
{
    CheckMapType();
    SetWeekend();
}

public void OnMapEnd()
{
    mapType.SetInt(0, true);
    if (InfoTimer != INVALID_HANDLE)
        KillTimer(InfoTimer);
}

public void OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int uid = GetEventInt(event, "userid");
    int client = GetClientOfUserId(uid);

    if (ValidateClient(client))
        CreateTimer(5.0, Timer_WelcomeMessage, client);
}

public void OnClientDisconnect(int client)
{
    if (ValidateClient(client))
        PlayerJoined[client] = 0;
}

public void OnClientConnected(int client)
{
    // int timeLeft;
    // GetMapTimeLeft(timeLeft);

    // if (timeLeft < -1)
    //     ExtendMapTimeLimit((60 * 30));
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool & processcolors, bool & removecolors)
{
    char DateSent[32];
    FormatTime(DateSent, 32, "%D %R:%S", GetTime() - (4*60*60));

    char SteamId[64];
    GetClientAuthId(author, AuthId_Steam3, SteamId, 64);

    char NameEsc[257];
    char MessageEsc[513];
    SQL_EscapeString(DB_sntdb, name, NameEsc, 257);
    SQL_EscapeString(DB_sntdb, message, MessageEsc, 513);

    char iQuery[1024];
    Format(iQuery, 1024, "INSERT INTO %slogs VALUES (\'%s\', \'%s\', \'%s\', \'%s\')", SchemaName, DateSent, SteamId, NameEsc, MessageEsc);
    SQL_TQuery(DB_sntdb, SQL_ErrorHandler, iQuery);

    return Plugin_Changed;
}

void BuildInfo_Page1(int client)
{
    Menu InfoPage1 = new Menu(InfoPage1_Handler, MENU_ACTIONS_DEFAULT);
    InfoPage1.SetTitle("Info Menu");
    InfoPage1.AddItem("1", "Staff Members");
    InfoPage1.AddItem("2", "Discord Link");
    InfoPage1.AddItem("3", "Current Server Features");
    InfoPage1.AddItem("4", "How To Surf");
    InfoPage1.AddItem("5", "How To Use Sounds");
    InfoPage1.Display(client, 0);
}

bool ValidateClient(int client)
{
    if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
        return true;
    else
        return false;
}

void GetServerTime(int zone, char[] current_time, int maxlen)
{
    int currentTime = GetTime();

    switch (zone)
    {
        case 0:
        {
            //EST, -4 hours
            currentTime = currentTime - (4*60*60);
            FormatTime(current_time, maxlen, "%H:%M %p", currentTime);
        }
        case 1:
        {
            //PST -7 hours
            currentTime = currentTime - (7*60*60);
            FormatTime(current_time, maxlen, "%H:%M %p", currentTime);
        }
        case 2:
        {
            //CET +2 hours
            currentTime = currentTime + (2*60*60);
            FormatTime(current_time, maxlen, "%H:%M %p", currentTime);
        }
    }
}

void GetServerDay(char[] current_day, int maxlen)
{
    FormatTime(current_day, maxlen, "%A", GetTime() - (4*60*60));
}

bool CheckWeekend()
{
    char currentDay[16];
    GetServerDay(currentDay, 16);

    if (StrEqual(currentDay, "friday", false) || StrEqual(currentDay, "saturday", false) || StrEqual(currentDay, "sunday", false))
        return true;
    else
        return false;
}

void SetWeekend()
{
    if (CheckWeekend())
        isWeekendConVar.SetBool(true, true);
    else
        isWeekendConVar.SetBool(false, true);
}

void CheckMapType()
{
    char currentMap[256];
    char skurfListPath[PLATFORM_MAX_PATH];
    char arenaListPath[PLATFORM_MAX_PATH];
    GetCurrentMap(currentMap, sizeof(currentMap));
    Format(skurfListPath, sizeof(skurfListPath), "cfg/skurf_mapcycle.txt");
    Format(arenaListPath, sizeof(arenaListPath), "cfg/asurf_mapcycle.txt");

    InfoTimer = CreateTimer(TimeBetweenMessages.FloatValue, Timer_DisplayInfo, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    File skurfList = OpenFile(skurfListPath, "r");
    File arenaList = OpenFile(arenaListPath, "r");

    if (skurfList == null)
        PrintToServer("[SNT] ERROR! Unable to find skill surf maplist at cfg/skurf_mapcycle.txt");
    else if (arenaList == null)
        PrintToServer("[SNT] ERROR! Unable to find arena surf maplsit at cfg/asurf_mapcycle.txt");
    else
    {
        char line[256];
        do
        {
            TrimString(line);
            if (StrEqual(line, currentMap))
            {
                PrintToServer("Found a skurf map!");
                mapType.SetInt(1, true);
                skurfList.Close();
                arenaList.Close();
                break;
            }
        }
        while(skurfList.ReadLine(line, sizeof(line)));

        if (mapType.IntValue == 1)
            return;
        else
        {
            do
            {
                TrimString(line);
                if (StrEqual(line, currentMap))
                {
                    PrintToServer("Found an arena map!");
                    mapType.SetInt(2, true);
                    skurfList.Close();
                    arenaList.Close();
                    break;
                }
            }
            while(arenaList.ReadLine(line, sizeof(line)));
        }

        if (mapType.IntValue == 2)
            return;
    }

    PrintToServer("Map is a combat surf");
    mapType.SetInt(0, true);

    skurfList.Close();
    arenaList.Close();
}

public void Native_GetServerTime(Handle plugin, int params)
{
    int currentTime = GetTime();

    switch (GetNativeCell(1))
    {
        case 0:
        {
            //EST, -4 hours
            currentTime = currentTime - (4*60*60);
            char currentTimeStr[32];
            FormatTime(currentTimeStr, 32, "%H:%M %p", currentTime)

            SetNativeString(2, currentTimeStr, GetNativeCell(3));
        }
        case 1:
        {
            //PST -7 hours
            currentTime = currentTime - (7*60*60);
            char currentTimeStr[32];
            FormatTime(currentTimeStr, 32, "%H:%M %p", currentTime)

            SetNativeString(2, currentTimeStr, GetNativeCell(3));
        }
        case 2:
        {
            //CET +2 hours
            currentTime = currentTime + (2*60*60);
            char currentTimeStr[32];
            FormatTime(currentTimeStr, 32, "%H:%M %p", currentTime)

            SetNativeString(2, currentTimeStr, GetNativeCell(3));
        }
    }
}

public void Native_GetServerDay(Handle plugin, int params)
{
    int currentTime = GetTime() - (4*60*60);
    char currentDay[16];
    FormatTime(currentDay, 32, "%A", currentTime);

    SetNativeString(1, currentDay, GetNativeCell(2));
}

public any CheckWeekend_Native(Handle plugin, int params)
{
    char currentDay[16];
    GetServerDay(currentDay, 16);

    PrintToServer(currentDay);

    if (StrEqual(currentDay, "friday", false) || StrEqual(currentDay, "saturday", false) || StrEqual(currentDay, "sunday", false))
        return true;
    else
        return false;
}

public any Native_IsValidClient(Handle plugin, int params)
{
    int client = GetNativeCell(1)
    if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
        return true;
    else
        return false;
}

public any Native_LoadSQLConfigs(Handle plugin, int numParams)
{
    KeyValues ConfigFile = new KeyValues("ConfigFile");
    char ConfigFilePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, ConfigFilePath, sizeof(ConfigFilePath), "configs/sntdb/main_config.cfg");

    ConfigFile.ImportFromFile(ConfigFilePath);
    
    if (ConfigFile == null)
    {
        PrintToServer("[SNT] ERROR! \"configs/sntdb/main_config.cfg\": file does not exist!");
        return false;
    }

    char ModuleName[32];
    GetNativeString(7, ModuleName, sizeof(ModuleName));

    if (!ConfigFile.JumpToKey("System"))
    {
        PrintToServer("[SNT] ERROR! Missing \"System\" section from config file.");
        delete ConfigFile;
        return false;
    }
    else
    {
        // Declare variables to store configs
        char dbconfig_name[32];
        char prefix[96];
        char schema[64];
        char store_schema[64];
        char currency_name[64];
        char currency_color[64];
        
        // Gather values from config file and store it in the variables.
        ConfigFile.GetString("dbconfig", dbconfig_name, sizeof(dbconfig_name));
        ConfigFile.GetString("message_prefix", prefix, sizeof(prefix));
        ConfigFile.GetString("schema", schema, sizeof(schema));
        if (GetNativeCell(8) == 1)
        {
            ConfigFile.Rewind();
            if (!ConfigFile.JumpToKey("Store"))
            {
                PrintToServer("[SNT] ERROR! Missing \"Store\" section from config file.");
                delete ConfigFile;
                return false;
            }
            else
            {
                ConfigFile.GetString("schema", store_schema, sizeof(store_schema));
                ConfigFile.GetString("currency_name", currency_name, sizeof(currency_name));
                ConfigFile.GetString("currency_color", currency_color, sizeof(currency_color));
            }
        }


        // Print values gathered to server.
        PrintToServer("***********  SYSTEM  ************");
        PrintToServer("[SNT] Called By: %s", ModuleName);
        PrintToServer("[SNT] dbconfig: %s", dbconfig_name);
        PrintToServer("[SNT] schema: %s", schema);

        if (GetNativeCell(8) == 1)
        {
            PrintToServer("[SNT] store_schema: %s", store_schema);
        }

        PrintToServer("[SNT] prefix: %s", prefix);
        PrintToServer("*********************************");
        PrintToServer("");

        // Return values back to the user through the function.
        SetNativeString(1, dbconfig_name, GetNativeCell(2));
        SetNativeString(3, prefix, GetNativeCell(4));
        SetNativeString(5, schema, GetNativeCell(6));

        if (GetNativeCell(8) == 1)
        {
            SetNativeString(9, store_schema, GetNativeCell(10));
            SetNativeString(11, currency_name, GetNativeCell(12));
            SetNativeString(13, currency_name, GetNativeCell(14));
        }
    }
    return true;
}

public any Native_LoadSQLStoreConfigs(Handle plugin, int numParams)
{
    KeyValues ConfigFile = new KeyValues("ConfigFile");
    char ConfigFilePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, ConfigFilePath, sizeof(ConfigFilePath), "configs/sntdb/main_config.cfg");

    char ModuleName[32];
    GetNativeString(7, ModuleName, sizeof(ModuleName));

    ConfigFile.ImportFromFile(ConfigFilePath);
    
    if (ConfigFile == null)
    {
        PrintToServer("[SNT] ERROR! \"configs/sntdb/main_config.cfg\": file does not exist!");
        return false;
    }

    if (!ConfigFile.JumpToKey("Store"))
    {
        PrintToServer("[SNT] ERROR! Missing \"Store\" section from config file.");
        delete ConfigFile;
        return false;
    }
    else
    {
        // Declare variables to store configs
        char dbconfig_name[32];
        char prefix[96];
        char schema[64];
        char currency[64];
        char currencycolor[64];
        int credits_given;
        float over_time;

        // Gather values from config file and store it in the variables.
        ConfigFile.GetString("dbconfig", dbconfig_name, 32);
        ConfigFile.GetString("message_prefix", prefix, 96);
        ConfigFile.GetString("schema", schema, 64);
        ConfigFile.GetString("currency_name", currency, 64);
        ConfigFile.GetString("currency_color", currencycolor, 64);
        credits_given = ConfigFile.GetNum("amount_given", 50);
        over_time = ConfigFile.GetFloat("interval_in_mins", 15.0);

        // Print values gathered to server.
        PrintToServer("***********  Store  ************");
        PrintToServer("[SNT] Called By: %s", ModuleName);
        PrintToServer("[SNT] dbconfig: %s", dbconfig_name);
        PrintToServer("[SNT] schema: %s", schema);
        PrintToServer("[SNT] prefix: %s", prefix);
        PrintToServer("[SNT] Credits To Give: %i", credits_given);
        PrintToServer("[SNT] Time interval: %f", over_time);
        PrintToServer("*********************************");
        PrintToServer("");

        // Return values back to the user through the function.
        SetNativeString(1, dbconfig_name, GetNativeCell(2));
        SetNativeString(3, prefix, GetNativeCell(4));
        SetNativeString(5, schema, GetNativeCell(6));
        SetNativeString(8, currency, GetNativeCell(9));
        SetNativeString(10, currencycolor, GetNativeCell(11));
        SetNativeCellRef(12, credits_given);
        SetNativeCellRef(13, over_time);

        delete ConfigFile;
    }
    return true;
}

public int Native_CheckForMap(Handle plugin, int numParams)
{
    if (isSkurfMap)
        return 1;
    else if (isArenaMap)
        return 2;
    else
        return 0;
}

void BuildFeaturesMenu(int client)
{
    Menu FeaturesList_Menu = new Menu(FeaturesList_Handler, MENU_ACTIONS_DEFAULT);
    FeaturesList_Menu.SetTitle("Surf'n'Turf Features")
    FeaturesList_Menu.AddItem("1", "Store");
    FeaturesList_Menu.AddItem("2", "Soundboard");
    FeaturesList_Menu.AddItem("3", "Map Rating System");
    FeaturesList_Menu.AddItem("4", "Ranking System");
    FeaturesList_Menu.AddItem("5", "Micspam System (COMING SOON!)");
    FeaturesList_Menu.AddItem("6", "Ignore System");
    FeaturesList_Menu.AddItem("7", "Collision Plugin");
    FeaturesList_Menu.AddItem("8", "Killstreak Modifer");
    FeaturesList_Menu.AddItem("9", "Third Person Plugin");
    FeaturesList_Menu.AddItem("10", "RTD");
    FeaturesList_Menu.Display(client, 0);
}

public int StaffPanel_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            switch (param2)
            {
                case 1:
                {
                    CPrintToChat(param1, "%s LucasDoofus' Steam Profile: {greenyellow}https://steamcommunity.com/id/LucasDoofus/", Prefix);
                    delete menu;
                }
                case 2:
                {
                    CPrintToChat(param1, "%s WebmasterMatt's Steam Profile: {greenyellow}https://steamcommunity.com/id/pnelegonerd/", Prefix);
                    delete menu;
                }
                case 3:
                {
                    CPrintToChat(param1, "%s Arcala The Gyiyg's Steam Profile: {greenyellow}https://steamcommunity.com/id/ArcalaAlien/", Prefix);
                    delete menu;
                }
                case 4:
                {

                }
                case 5:
                {
                    CPrintToChat(param1, "%s weeabruh's Steam Profile: {greenyellow}https://steamcommunity.com/id/weeabruv/", Prefix);
                    delete menu;
                }
                case 6:
                {
                    CPrintToChat(param1, "%s twerp's Steam Profile: {greenyellow}https://steamcommunity.com/profiles/76561198347557315/", Prefix);
                    delete menu;
                }
                case 7:
                    BuildInfo_Page1(param1);
                case 8:
                    delete menu;
            }
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int PluginInfo_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            if (param2 == 1)
                BuildFeaturesMenu(param1);
        }
    }
    return 0;
}

public int FeaturesList_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char chosenOpt[32];
            GetMenuItem(menu, param2, chosenOpt, 32);
            int opt = StringToInt(chosenOpt);

            Panel pluginInfoPanel = CreatePanel();

            switch (opt)
            {
                case 1:
                {
                    pluginInfoPanel.SetTitle("Store Plugin");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawText("Use /tavern or /store to open up the server's\nin game store!");
                    pluginInfoPanel.DrawText("You earn dubloons just by playing the game!");
                    pluginInfoPanel.DrawText("View the items you've bought\nand your dubloons by using /treasure!");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawItem("Plugin Info Menu");
                    pluginInfoPanel.DrawItem("Exit");
                }
                case 2:
                {
                    pluginInfoPanel.SetTitle("Soundboard Plugin");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawText("After you purchase sounds in the store\nuse /sounds to open the soundboard menu!");
                    pluginInfoPanel.DrawText("To use your soundboard slots, bind 3 keys to\nsm_playslot1, sm_playslot2, and sm_playslot3.");
                    pluginInfoPanel.DrawText("Press the key you bound the\nsound to in game and it'll play the sound!");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawItem("Plugin Info Menu");
                    pluginInfoPanel.DrawItem("Exit");
                }
                case 3:
                {
                    pluginInfoPanel.SetTitle("Map Rating System");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawText("Use /rate to open up the map rating menu!\nHere you can rate a map 1-5 stars.");
                    pluginInfoPanel.DrawText("You can also view the top and bottom 10 rated maps!\nYou can use /ratemap as a shortcut to rate the current map.");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawItem("Plugin Info Menu");
                    pluginInfoPanel.DrawItem("Exit");
                }
                case 4:
                {
                    pluginInfoPanel.SetTitle("Ranking System");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawText("You get points for killing players on the server!\nThere's also an internal killstreak system that will\nmodify the amount of points you get, based on your ks.");
                    pluginInfoPanel.DrawText("Use /rank to access the menu and look at your\nand other player's ranks!");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawItem("Plugin Info Menu");
                    pluginInfoPanel.DrawItem("Exit");
                }
                case 5:
                {
                    pluginInfoPanel.SetTitle("Micspam System (COMING SOON)");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawText("Not implemented, this will create a micspam\nqueue that players will need to join\nusing /join. This is to prevent overspamming.");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawItem("Plugin Info Menu");
                    pluginInfoPanel.DrawItem("Exit");
                }
                case 6:
                {
                    pluginInfoPanel.SetTitle("Ignore System");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawText("Use /i or /ignore to open the ignore menu\nand ignore a player's voice chat only!");
                    pluginInfoPanel.DrawText("Working on adding a player targeting feature.");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawItem("Plugin Info Menu");
                    pluginInfoPanel.DrawItem("Exit");
                }
                case 7:
                {
                    pluginInfoPanel.SetTitle("Collision Plugin");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawText("Slam into your friends at high speeds and kill them!");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawItem("Plugin Info Menu");
                    pluginInfoPanel.DrawItem("Exit");
                }
                case 8:
                {
                    pluginInfoPanel.SetTitle("Killstreak Modifier");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawText("Use /ks <num> to set your TF2 killstreak to\nthe specified number! Useful if you have KS items.");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawItem("Plugin Info Menu");
                    pluginInfoPanel.DrawItem("Exit");
                }
                case 9:
                {
                    pluginInfoPanel.SetTitle("Third Person Plugin");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawText("Use /1, /fp, /firstperson\nor /3, /tp, /thirdperson to toggle between first and third person!");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawItem("Plugin Info Menu");
                    pluginInfoPanel.DrawItem("Exit");
                }
                case 10:
                {
                    pluginInfoPanel.SetTitle("Roll The Dice (RTD)");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawText("Say rtd in chat to get a random effect applied to you!\nIt could be good, or bad, you just gotta take a chance!");
                    pluginInfoPanel.DrawText(" ");
                    pluginInfoPanel.DrawItem("Plugin Info Menu");
                    pluginInfoPanel.DrawItem("Exit");
                }
            }
            pluginInfoPanel.Send(param1, PluginInfo_Handler, 0);
        }
    }
    return 0;
}

public int HowToSurf_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            if (param2 == 1)
                BuildInfo_Page1(param1);
        }
    }
    return 0;
}

public int InfoPage1_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char chosenOpt[32];
            GetMenuItem(menu, param2, chosenOpt, 32);
            int opt = StringToInt(chosenOpt);

            switch (opt)
            {
                case 1:
                {
                    // Menu StaffList_Menu = CreateMenu(StaffMenu_Handler);
                    // StaffList_Menu.SetTitle("Surf'n'Turf Staff Members");
                    // StaffList_Menu.AddItem("X", "Owners", ITEMDRAW_DISABLED);
                    // StaffList_Menu.AddItem("lucas", "LucasDoofus");
                    // StaffList_Menu.AddItem("linux", "WebmasterMatt");
                    // StaffList_Menu.AddItem("arcala", "Arcala The Gyiyg");
                    // StaffList_Menu.AddItem("X", "Admins", ITEMDRAW_DISABLED);
                    // StaffList_Menu.AddItem("twerp", "twerp");
                    // StaffList_Menu.AddItem("hexi", "Hexi");
                    // StaffList_Menu.AddItem("X", "Moderators", ITEMDRAW_DISABLED);



                    Panel StaffList_Panel = CreatePanel();
                    StaffList_Panel.SetTitle("Surf'n'Turf Staff Members");
                    StaffList_Panel.DrawText(" ");
                    StaffList_Panel.DrawText("Owners");
                    StaffList_Panel.DrawItem("LucasDoofus");
                    StaffList_Panel.DrawItem("Webmaster Matt");
                    StaffList_Panel.DrawItem("Arcala the Gyiyg");
                    StaffList_Panel.DrawText(" ");
                    StaffList_Panel.DrawText("Admins");
                    StaffList_Panel.DrawItem("twerp");
                    StaffList_Panel.DrawText(" ");
                    StaffList_Panel.DrawText("Moderators");
                    StaffList_Panel.DrawItem("Omega (M)");
                    
                    StaffList_Panel.DrawText(" ");
                    StaffList_Panel.DrawItem("Info Menu");
                    StaffList_Panel.DrawItem("Exit");
                    StaffList_Panel.Send(param1, StaffPanel_Handler, 0);
                }
                case 2:
                    CPrintToChat(param1, "%s You can join our discord community at {greenyellow}discord.gg/xnuHA5KsEU{default}!", Prefix);
                case 3:
                    BuildFeaturesMenu(param1);
                case 4:
                {
                    Panel HowToSurf_Panel = CreatePanel();
                    HowToSurf_Panel.SetTitle("How to Surf");
                    HowToSurf_Panel.DrawText(" ");
                    HowToSurf_Panel.DrawText("Pretend this is the ramp: /\\");
                    HowToSurf_Panel.DrawText("Depending on what side of the ramp you're on\nyou'll hold A or D");
                    HowToSurf_Panel.DrawText("");
                    HowToSurf_Panel.DrawText("D /\\ A");
                    HowToSurf_Panel.DrawText("");
                    HowToSurf_Panel.DrawText("Then you use your mouse to guide where you're going.\nTry to follow the curvature of the ramp as close as possible.");
                    HowToSurf_Panel.DrawText("Holding crouch is helpful to clear walls, and if you press S you'll stop in midair.");
                    HowToSurf_Panel.DrawText("DO NOT HOLD W!! YOU WILL FALL OFF THE RAMP IF YOU DO!");
                    HowToSurf_Panel.DrawItem("Info Menu");
                    HowToSurf_Panel.DrawItem("Exit");
                    HowToSurf_Panel.Send(param1, HowToSurf_Handler, 0);
                }
                case 5:
                {
                    CPrintToChat(param1, "%s First set your sounds using {greenyellow}/sound\nThen bind 3 keys to {greenyellow}sm_playslot1, sm_playslot2, and sm_playslot3\n{default}Then press the keys you bound the commands to play the sounds!", Prefix);
                }
            }
            
        }
    }
    return 0;
}

public int EventMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    return 0;
}

public void SQL_ErrorHandler(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
        PrintToServer("[SNT] ERROR! DATABASE IS NULL!");

    if (!StrEqual(error, ""))
        PrintToServer("[SNT] ERROR IN QUERY: %s", error);
}

public Action Timer_WelcomeMessage(Handle timer, any data)
{
    if (PlayerJoined[data] != 1 && ValidateClient(data))
    {
        char timeEST[16];
        char timePST[16];
        char timeCET[16];
        char currentDay[16];
        char currentDate[16];

        FormatTime(currentDate, 16, "%m/%d", GetTime() - (4*60*60));
        GetServerDay(currentDay, 16);
        GetServerTime(0, timeEST, 16);
        GetServerTime(1, timePST, 16);
        GetServerTime(2, timeCET, 16);

        char PlayerName[128];
        GetClientName(data, PlayerName, 128);
        EmitSoundToClient(data, "snt_sounds/ypp_login.mp3");
        CPrintToChat(data, "{yellowgreen}Ahoy! Welcome ye to the crew, {default}%s!", PlayerName);
        CPrintToChat(data, "%s The date is: {orange}%s %s", Prefix, currentDay, currentDate);
        CPrintToChat(data, "%s EST: {orange}%s{default} PST: {orange}%s{default} CET: {orange}%s{default}", Prefix, timeEST, timePST, timeCET);
        CPrintToChat(data, "%s We have a huge variety of maps! Use {greenyellow}/nominate{default} to check them out!", Prefix);
        //CPrintToChat(data, "The current time is {rblxlightblue}%i:%s %s CEST\n{yellowgreen}%i:%s %s EST, {orange}%i:%s %s PST", CESTHour, CurrentMinute, CESTAMPM, ESTHour, CurrentMinute, ESTAMPM, PSTHour, CurrentMinute, PSTAMPM);
        PlayerJoined[data] = 1;
    }
    return Plugin_Stop;
}

public Action Timer_DisplayInfo(Handle timer, any data)
{
    int MsgList = GetRandomInt(1, 2);


    char HintMessage[256];
    switch (MsgList)
    {
        case 1:
        {
            int MsgToDisplay = GetRandomInt(1, 8);
            switch (MsgToDisplay)
            {
                case 1:
                    Format(HintMessage, 256, "%s %s", Prefix, MSG01);
                case 2:
                    Format(HintMessage, 256, "%s %s", Prefix, MSG02);
                case 3:
                    Format(HintMessage, 256, "%s %s", Prefix, MSG03);
                case 4:
                    Format(HintMessage, 256, "%s %s", Prefix, MSG04);
                case 5:
                    Format(HintMessage, 256, "%s %s", Prefix, MSG05);
                case 6:
                    Format(HintMessage, 256, "%s %s", Prefix, MSG06);
                case 7:
                    Format(HintMessage, 256, "%s %s", Prefix, MSG07);
                case 8:
                    Format(HintMessage, 256, "%s %s", Prefix, MSG08);
            }
        }
        case 2:
        {
            int MsgToDisplay = GetRandomInt(1, 7);
            switch (MsgToDisplay)
            {
                case 1:
                    Format(HintMessage, 256, "%s %s", Prefix, MSG09);
                case 2:
                    Format(HintMessage, 256, "%s %s", Prefix, MSG10);
                case 3:
                    Format(HintMessage, 256, "%s %s", Prefix, MSG11);
                case 4:
                    Format(HintMessage, 256, "%s %s", Prefix, MSG12);
                case 5:
                    Format(HintMessage, 256, "%s %s", Prefix, MSG13);
                case 6:
                    Format(HintMessage, 256, "%s %s", Prefix, MSG14);
                case 7:
                    Format(HintMessage, 256, "%s %s", Prefix, MSG15);
            }
        }
    }

    CPrintToChatAll(HintMessage);
    return Plugin_Continue;
}

public Action ADM_OpenEventsMenu(int client, int args)
{
    Menu EventMenu = new Menu(EventMenuHandler, MENU_ACTIONS_DEFAULT);

    char DisplayEvent[64];

    //MinsLeft = RoundToFloor((TimeLeft / 60));
    //SecsLeft = (TimeLeft - (MinsLeft*60));

    Format(DisplayEvent, sizeof(DisplayEvent), "Current Event: %s", CurrentEvent);


    EventMenu.SetTitle("Choose an event!");
    EventMenu.AddItem("CURRENT", DisplayEvent, ITEMDRAW_DISABLED);
    
    if (EventEnabled == true)
    {
        char TimeRemaining[64];
        //Format(TimeRemaining, sizeof(TimeRemaining), "Time left: %i mins %i seconds", MinsLeft, SecsLeft);
        EventMenu.AddItem("X", TimeRemaining, ITEMDRAW_RAWLINE);
        EventMenu.AddItem("X", "(2x) Credits until the end of the map!", ITEMDRAW_RAWLINE);
        EventMenu.AddItem("X", "Half off store prices for 5 mins!", ITEMDRAW_RAWLINE);
        EventMenu.AddItem("X", "Mini Contest!", ITEMDRAW_RAWLINE);
    }
    else
    {
        EventMenu.AddItem("2XCRED", "(2x) Credits until the end of the map!");
        EventMenu.AddItem("HALFOFF", "Half off store prices for 5 mins!");
        EventMenu.AddItem("CONTEST", "Mini Contest!");
    }

    EventMenu.Display(client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public Action USR_OpenInfoMenu (int client, int args)
{
    if (client == 0)
        return Plugin_Handled;

    if (args > 0)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s Usage: {greenyellow}/info{default} Opens the info menu!", Prefix);
        return Plugin_Handled;
    }

    if (ValidateClient(client))
        BuildInfo_Page1(client)
    return Plugin_Handled;
}

public Action USR_Respawn (int client, int args)
{
    if (client == 0)
        return Plugin_Handled;

    if (ValidateClient(client))
        TF2_RespawnPlayer(client);

    return Plugin_Handled;
}

public Action ADM_GotoPlayer(int client, int args)
{
    if (client == 0)
        return Plugin_Handled;

    char arg[MAX_NAME_LENGTH];
    GetCmdArg(1, arg, sizeof(arg));

    int targs[MAXPLAYERS + 1]
    bool tn_is_ml;
    if (ProcessTargetString(arg, client, targs, sizeof(targs), COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_BOTS, arg, sizeof(arg), tn_is_ml) == COMMAND_TARGET_AMBIGUOUS)
    {
        CPrintToChat(client, "%s Unable to teleport, multiple targets.", Prefix);
    }
    else
    {
        if (SNT_IsValidClient(targs[0]))
        {
            float targPos[3];
            GetClientAbsOrigin(targs[0], targPos);

            targPos[2] += 96.0;
            TeleportEntity(client, targPos);
        }
    }

    return Plugin_Handled;
}