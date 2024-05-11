#include <sourcemod>
#include <clients>
#include <string>
#include <dbi>
#include <files>
#include <keyvalues>

public Plugin myinfo =
{
    name = "sntdb Map Module",
    author = "Arcala the Gyiyg",
    description = "(required) SNTDB Core Module.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{

    CreateNative("LoadSQLConfigs", ReadSQLConfigs);
    RegPluginLibrary("sntdb_core");

    return APLRes_Success;
}

/*
TODO:
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

bool Weekend;
bool EventEnabled;
char CurrentEvent[32] = "None";

// Convars
ConVar CurrentHoliday;
ConVar IsWeekend;
ConVar EventCooldown;


public void OnPluginStart()
{
    CurrentHoliday = CreateConVar("snt_current_holiday", "None", "This shows what holiday it is for the server");
    IsWeekend = CreateConVar("snt_is_weekend", "false", "This shows whether it is the weekend");
    EventCooldown = CreateConVar("snt_event_cooldown", "480", "The cooldown time in seconds between events.", 0, true, 300.0)
    
    RegAdminCmd("sm_snt_events",    ADM_OpenEventsMenu,      ADMFLAG_GENERIC,    "/snt_events: Use this to open the events menu.");
    RegAdminCmd("sm_snt_etest",     ADM_TestPlugin,          ADMFLAG_GENERIC,    "test this bitch");
    //RegAdminCmd("sm_snt_groupmod",  ADM_ModGroup,           ADMFLAG_BAN,        "/snt_groupmod <gid> <user>: Toggle a user's group id. Type list with no user to list all groups");
}

public void OnMapStart()
{
    char CurrentMonth[8];
    char CurrentDay[8];
    char DayOfWeek[16];
    FormatTime(CurrentMonth, sizeof(CurrentMonth), "%m");
    FormatTime(CurrentDay, sizeof(CurrentDay), "%d");
    FormatTime(DayOfWeek, sizeof(DayOfWeek), "%A"); 

    Weekend = CheckWeekend(DayOfWeek);
    CheckHoliday(CurrentMonth, CurrentDay);
}

bool CheckWeekend(char[] day)
{
    if (StrEqual(day, "friday", false) | StrEqual(day, "saturday", false) | StrEqual(day, "sunday", false))
    {
        IsWeekend.SetString("true");
        return true;
    }
    else
    {
        IsWeekend.SetString("false");
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
                CurrentHoliday.SetString("420");
            }
        }
        case 7:
        {
            if (day == 14)
            {
                CurrentHoliday.SetString("Birthday");
            }
        }
        case 10:
        {
            if (day == 31)
            {
                CurrentHoliday.SetString("Halloween");
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

    int SYSstore = GetNativeCell(3);
    char ModuleName[32];
    GetNativeString(4, ModuleName, sizeof(ModuleName));

    if (SYSstore == 0)
    {
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
            
            // Gather values from config file and store it in the variables.
            ConfigFile.GetString("dbconfig",    dbconfig_name,  sizeof(dbconfig_name));

            // Print values gathered to server.
            PrintToServer("***********  SYSTEM  ************");
            PrintToServer("[SNT] Called By:\t%s", ModuleName)
            PrintToServer("[SNT] dbconfig:\t%s", dbconfig_name);
            PrintToServer("*********************************");

            // Return values back to the user through the function.
            SetNativeString(1, dbconfig_name, GetNativeCell(2));

            delete ConfigFile;
            return 1;
        }
    }
    else
    {
        if (!ConfigFile.JumpToKey("Store"))
        {
            ThrowError("[SNT] ERROR! Missing \"Maps\" section from config file.");
            delete ConfigFile;
            return 0;
        }
        else
        {
            // Declare variables to store configs
            char dbconfig_name[32];
            
            // Gather values from config file and store it in the variables.
            ConfigFile.GetString("dbconfig",    dbconfig_name,  sizeof(dbconfig_name));

            // Print values gathered to server.
            PrintToServer("*************  STORE  ************");
            PrintToServer("[SNT] Called By:\t%s", ModuleName);
            PrintToServer("[SNT] dbconfig:\t%s", dbconfig_name);
            PrintToServer("*********************************");

            // Return values back to the user through the function.
            SetNativeString(1, dbconfig_name, GetNativeCell(2));

            delete ConfigFile;
            return 1;
        }
    }
}

public int EventMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    return 0;
}

public Action ADM_OpenEventsMenu(int client, int args)
{
    Menu EventMenu = new Menu(EventMenuHandler, MENU_ACTIONS_DEFAULT);

    char DisplayEvent[64];
    Format(DisplayEvent, sizeof(DisplayEvent), "Current Event: %s", CurrentEvent);
 
    EventMenu.SetTitle("Choose an event!");
    EventMenu.AddItem("CURRENT", DisplayEvent, ITEMDRAW_DISABLED);
    
    if (EventEnabled == true)
    {
        EventMenu.AddItem("", "", ITEMDRAW_SPACER);
        EventMenu.AddItem("X", "(2x) Credits for 5 mins!");
        EventMenu.AddItem("X", "Half off store prices for 5 mins!");
        EventMenu.AddItem("X", "Mini Contest!");
    }
    else
    {
        EventMenu.AddItem("", "", ITEMDRAW_SPACER);
        EventMenu.AddItem("2XCRED", "(2x) Credits for 5 mins!");
        EventMenu.AddItem("HALFOFF", "Half off store prices for 2 mins!");
        EventMenu.AddItem("CONTEST", "Mini Contest!");
    }

    EventMenu.Display(client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public Action ADM_TestPlugin(int client, int args)
{
    EventEnabled = !EventEnabled;
    if (EventEnabled)
    {
        strcopy(CurrentEvent, sizeof(CurrentEvent), "Birthday");
    }
    else
    {
        strcopy(CurrentEvent, sizeof(CurrentEvent), "None");
    }
    PrintToServer("Done");
    return Plugin_Handled;
}