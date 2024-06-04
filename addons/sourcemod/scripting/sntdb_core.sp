#include <sourcemod>
#include <clients>
#include <string>
#include <dbi>
#include <files>
#include <sdktools>
#include <keyvalues>
#include <tf2>

#include <morecolors>

public Plugin myinfo =
{
    name = "sntdb Core Module",
    author = "Arcala the Gyiyg",
    description = "(required) SNTDB Core Module.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{

    CreateNative("LoadSQLConfigs", ReadSQLConfigs);
    CreateNative("LoadSQLStoreConfigs", ReadSQLStoreConfigs);
    RegPluginLibrary("sntdb_core");

    return APLRes_Success;
}

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

        OnMapLoad:
            Use GetTime() to get current time/date as unix timestamp
            Use FormatTime() to format the unix timestamp into something readable.
            Use https://cplusplus.com/reference/ctime/strftime/ as reference for format syntax.

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
        Colored names (expensive)
        Colored chat (very expensive)

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

// Convars
ConVar EventCooldown;

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

    // PrintToServer("[SNT] Connecting to Database");
    // char error[255];
    // DB_sntdb = SQL_Connect(DBConfName, true, error, sizeof(error));
    // if (!StrEqual(error, ""))
    // {
    //     ThrowError("[SNT] ERROR IN PLUGIN START: %s", error);
    // }

    HookEvent("player_team", OnPlayerTeam);

    EventCooldown = CreateConVar("snt_event_cooldown", "480", "The cooldown time in seconds between events.", 0, true, 300.0);
    
    RegAdminCmd("sm_snt_events",    ADM_OpenEventsMenu,      ADMFLAG_GENERIC,    "/snt_events: Use this to open the events menu.");
    RegAdminCmd("sm_datetest",     ADM_TestPlugin,          ADMFLAG_GENERIC,    "test this bitch");
    //RegAdminCmd("sm_snt_groupmod",  ADM_ModGroup,           ADMFLAG_BAN,        "/snt_groupmod <gid> <user>: Toggle a user's group id. Type list with no user to list all groups");
}

public void OnPlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int uid = GetEventInt(event, "userid");
    int client = GetClientOfUserId(uid);

    if (!IsFakeClient(client))
    {
        CreateTimer(5.0, Timer_WelcomeMessage, client);
    }
}

public void OnClientDisconnect(int client)
{
    PlayerJoined[client] = 0;
}

bool CheckWeekend(char[] day)
{
    if (StrEqual(day, "friday", false) || StrEqual(day, "saturday", false) || StrEqual(day, "sunday", false))
    {
        return true;
    }
    else
    {
        return false;
    }
}

void CheckHoliday(char[] cur_month, char[] cur_day)
{
    int month = StringToInt(cur_month);
    int day = StringToInt(cur_day);
    switch (month)
    {
        case 4:
        {
            if (day == 20)
            {
                CurrentHoliday = "420";
            }
        }
        case 7:
        {
            if (day == 14)
            {
                CurrentHoliday = "Birthday";
            }
        }
        case 10:
        {
            if (day == 31)
            {
                CurrentHoliday = "Halloween";
            }
        }
    }
}

int ReadSQLConfigs(Handle plugin, int numParams)
{
    PrintToServer("[SNT] Loading SQL configs");

    KeyValues ConfigFile = new KeyValues("ConfigFile");
    char ConfigFilePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, ConfigFilePath, sizeof(ConfigFilePath), "configs/sntdb/main_config.cfg");

    ConfigFile.ImportFromFile(ConfigFilePath);
    
    if (ConfigFile == null)
    {
        ThrowError("[SNT] ERROR! \"configs/sntdb/main_config.cfg\": file does not exist!");
        return 0;
    }

    char ModuleName[32];
    GetNativeString(7, ModuleName, sizeof(ModuleName));

    if (!ConfigFile.JumpToKey("System"))
    {
        ThrowError("[SNT] ERROR! Missing \"System\" section from config file.");
        delete ConfigFile;
        return 0;
    }
    else
    {
        // Declare variables to store configs
        char dbconfig_name[32];
        char prefix[96];
        char schema[64];
        char store_schema[64];
        
        // Gather values from config file and store it in the variables.
        ConfigFile.GetString("dbconfig", dbconfig_name, sizeof(dbconfig_name));
        ConfigFile.GetString("message_prefix", prefix, sizeof(prefix));
        ConfigFile.GetString("schema", schema, sizeof(schema));
        if (GetNativeCell(8) == 1)
        {
            ConfigFile.GetString("store_schema", store_schema, sizeof(store_schema));
        }


        // Print values gathered to server.
        PrintToServer("***********  SYSTEM  ************");
        PrintToServer("[SNT] Called By: %s", ModuleName);
        PrintToServer("[SNT] dbconfig: %s", dbconfig_name);
        PrintToServer("[SNT] schema: %s", schema);

        if (GetNativeCell(9) == 1)
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
        }
    }
    return 1;
}

int ReadSQLStoreConfigs(Handle plugin, int numParams)
{
    PrintToServer("[SNT] Loading SQL configs");

    KeyValues ConfigFile = new KeyValues("ConfigFile");
    char ConfigFilePath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, ConfigFilePath, sizeof(ConfigFilePath), "configs/sntdb/main_config.cfg");

    char ModuleName[32];
    GetNativeString(7, ModuleName, sizeof(ModuleName));

    ConfigFile.ImportFromFile(ConfigFilePath);
    
    if (ConfigFile == null)
    {
        ThrowError("[SNT] ERROR! \"configs/sntdb/main_config.cfg\": file does not exist!");
        return 0;
    }

    if (!ConfigFile.JumpToKey("Store"))
    {
        ThrowError("[SNT] ERROR! Missing \"Store\" section from config file.");
        delete ConfigFile;
        return 0;
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
    return 1;
}

public int EventMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    return 0;
}

public Action Timer_WelcomeMessage(Handle timer, any data)
{
    char CurrentHour[4];
    char CurrentMinute[4];
    char AMPM[4];
    char CurrentMonth[4];
    char CurrentDay[4];
    char DayOfWeek[16];

    FormatTime(CurrentHour, 4, "%I", GetTime());
    FormatTime(CurrentMinute, 4, "%M", GetTime());
    FormatTime(AMPM, 4, "%p", GetTime());
    FormatTime(CurrentMonth, 4, "%m", GetTime());
    FormatTime(CurrentDay, 4, "%d", GetTime());
    FormatTime(DayOfWeek, 16, "%A", GetTime());

    int CESTHour = StringToInt(CurrentHour);
    int ESTHour = StringToInt(CurrentHour);
    int PSTHour = StringToInt(CurrentHour);
    CESTHour += 2;
    ESTHour -= 4;
    PSTHour -= 7;

    char CESTAMPM[4];
    char ESTAMPM[4];
    char PSTAMPM[4];

    // if (CESTHour > StringToInt(CurrentHour) && StringToInt(CurrentHour) < 12 && StrEqual(AMPM, "AM"))
    //     strcopy(CESTAMPM, 4, "PM");
    // else if (CESTHour < StringToInt(CurrentHour) && StringToInt(CurrentHour) < 12 && StrEqual(AMPM, "PM"))
    //     strcopy(CESTAMPM, 4, "AM");

    // if (CESTHour > ESTHour && ESTHour < 12 && StrEqual(AMPM, "PM"))
    //     strcopy(ESTAMPM, 4, "AM");
    // else if (CESTHour > ESTHour && ESTHour < 12 && StrEqual(AMPM, "AM"))
    //     strcopy(ESTAMPM, 4, "PM");

    // if (ESTHour > PSTHour && PSTHour < 12 && StrEqual(AMPM, "PM"))
    //     strcopy(PSTAMPM, 4, "AM");
    // else if (ESTHour > PSTHour && PSTHour < 12 && StrEqual(AMPM, "AM"))
    //     strcopy(PSTAMPM, 4, "PM");

    CheckHoliday(CurrentMonth, CurrentDay);

    if (PlayerJoined[data] != 1)
    {
        char PlayerName[128];
        GetClientName(data, PlayerName, 128);
        EmitSoundToClient(data, "snt_sounds/ypp_login.mp3");
        CPrintToChat(data, "{yellowgreen}Ahoy! Welcome ye to the crew, {default}%s!", PlayerName);
        CPrintToChat(data, "%s The date is: {orange}%s %s/%s", Prefix, DayOfWeek, CurrentMonth, CurrentDay);
        //CPrintToChat(data, "The current time is {rblxlightblue}%i:%s %s CEST\n{yellowgreen}%i:%s %s EST, {orange}%i:%s %s PST", CESTHour, CurrentMinute, CESTAMPM, ESTHour, CurrentMinute, ESTAMPM, PSTHour, CurrentMinute, PSTAMPM);
        PlayerJoined[data] = 1;
    }
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

public Action ADM_TestPlugin(int client, int args)
{
    return Plugin_Handled;
}