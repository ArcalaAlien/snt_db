#include <sourcemod>
#include <clients>
#include <string>
#include <menus>
#include <dbi>
#include <files>
#include <keyvalues>

#define REQUIRE_PLUGIN
#include <sntdb_core>

public Plugin myinfo =
{
    name = "sntdb Map Module",
    author = "Arcala the Gyiyg",
    description = "(required) SNTDB Module for dealing with maps.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

//********** TODO **********//
//ADD FUNCTION THAT AUTOMATICALLY REMOVES MAPS FROM THE DATABASE

// Config variables
char gDBConfigName[32];
char gMapListPath[PLATFORM_MAX_PATH];

//  DB Variables
Database gDB_sntdb;

// Menus
Menu gMenu_RegularMaps;
Menu gMenu_WeedMaps;

public void OnPluginStart() 
{
    PrintToServer("[SNT] Running 'LoadConfigs' function.");
    if (LoadMapSQLConfigs(gDBConfigName, sizeof(gDBConfigName), gMapListPath, sizeof(gMapListPath)))
    {
        PrintToServer("[SNT] Configs Loaded!");
    }
    else
    {
        PrintToServer("[SNT] Uh oh! Configs didn't load for some reason.");
    }

    PrintToServer("[SNT] Connecting to Database");
    char error[255];
    gDB_sntdb = SQL_Connect(gDBConfigName, true, error, sizeof(error));
    if (IsCharAlpha(error[0]))
    {
        PrintToServer("[SQL] ERROR IN PLUGIN START: %s", error);
    }
    else
    {
        PrintToServer("[SNT] Connected to Database!");
    }

    gMenu_RegularMaps = new Menu(MapsRatingHandler, MENU_ACTIONS_DEFAULT);
    gMenu_WeedMaps = new Menu(MapsRatingHandler, MENU_ACTIONS_DEFAULT);
    BuildRegularMaps(gMenu_RegularMaps);
    BuildWeedMaps(gMenu_WeedMaps);
    PrintToServer("[SNT] Built map lists");

    PrintToServer("[SNT] Set up Menus");

    RegAdminCmd("snt_buildmaps",    ADM_BuildTables,        ADMFLAG_ROOT,       "!snt_buildmaps: Use this to read a mapcycle.txt file and send all the map names to the database.");
    RegAdminCmd("snt_rmvmap",       ADM_RemoveMaps,         ADMFLAG_ROOT,       "!snt_rmvmap <mapname>: Use this to remove all mismatched maps from the ");
    RegConsoleCmd("sm_mapinfo",     ALL_MapReportMenu,                          "/mapinfo: Use this to open the report menu to gather map info from the database");
    RegConsoleCmd("sm_ratemap",     USR_OpenRatingMenu,                         "/rate: Use this to open the rating menu! DO NOT USE IN SERVER CONSOLE.");

    PrintToServer("[SNT] Registered Commands");
}

void BuildRegularMaps(Menu menu)
{
    PrintToServer("[SNT] Building regular map list");
    char sQuery[255];
    Format(sQuery, sizeof(sQuery), "SELECT MapName FROM snt_maps WHERE EventId=\"evnt_none\"");

    SQL_TQuery(gDB_sntdb, SQL_BuildMapMenu, sQuery, menu);
}

void BuildWeedMaps(Menu menu)
{
    PrintToServer("[SNT] Building weed map list");
    char sQuery[255];
    Format(sQuery, sizeof(sQuery), "SELECT MapName from snt_maps WHERE EventId=\"evnt_weed\"");
    
    SQL_TQuery(gDB_sntdb, SQL_BuildMapMenu, sQuery, menu);
}

/* MENU HANDLERS */

public int MapCategoriesHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char MenuCategory[64];
            menu.GetItem(param2, MenuCategory, sizeof(MenuCategory));
            
            if (StrEqual(MenuCategory, "evnt_none"))
            {
                gMenu_RegularMaps.Display(param1, MENU_TIME_FOREVER);
            }
            else if (StrEqual(MenuCategory, "evnt_weed"))
            {
                gMenu_WeedMaps.Display(param1, MENU_TIME_FOREVER);
            }
        }
        case MenuAction_End:
            delete menu;
    }

    return 0;
}

public int MapsRatingHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            Menu RateMenu = new Menu(RatingMenuHandler, MENU_ACTIONS_DEFAULT);
            
            char SteamId[64];
            if (IsClientConnected(param1))
                GetClientAuthId(param1, AuthId_Steam3, SteamId, sizeof(SteamId));

            char vQuery[255];
            Format(vQuery, sizeof(vQuery), "SELECT LastVote FROM snt_playermaps WHERE SteamId=\"%s\"", SteamId);

            char SelectedMap[64];
            menu.GetItem(param2, SelectedMap, sizeof(SelectedMap));

            if (StrEqual(SelectedMap, "N"))
            {
                delete menu;
            }

            char Rate1[64];
            char Rate2[64];
            char Rate3[64];
            char Rate4[64];
            char Rate5[64];

            Format(Rate1, sizeof(Rate1), "%s,RATE1", SelectedMap);
            Format(Rate2, sizeof(Rate2), "%s,RATE2", SelectedMap);
            Format(Rate3, sizeof(Rate3), "%s,RATE3", SelectedMap);
            Format(Rate4, sizeof(Rate4), "%s,RATE4", SelectedMap);
            Format(Rate5, sizeof(Rate5), "%s,RATE5", SelectedMap);
            
            SQL_TQuery(gDB_sntdb, SQL_GetLastRatingForMenu, vQuery, RateMenu);

            RateMenu.SetTitle("What do you want to rate %s?", SelectedMap);
            RateMenu.AddItem("NO", "", ITEMDRAW_SPACER);
            RateMenu.AddItem(Rate1, "1 Star");
            RateMenu.AddItem(Rate2, "2 Stars");
            RateMenu.AddItem(Rate3, "3 Stars");
            RateMenu.AddItem(Rate4, "4 Stars");
            RateMenu.AddItem(Rate5, "5 Stars");
            RateMenu.Display(param1, MENU_TIME_FOREVER);
        }
        case MenuAction_End:
            delete menu;
    }

    return 0;
}

public int RatingMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {

            char ClientSteamId[64];
            if (IsClientConnected(param1))
                GetClientAuthId(param1, AuthId_Steam3, ClientSteamId, sizeof(ClientSteamId));

            char MenuChoice[64];
            menu.GetItem(param2, MenuChoice, sizeof(MenuChoice));

            char ExplodedSelection[2][64];
            ExplodeString(MenuChoice, ",", ExplodedSelection, 2, 64);

            char RatingOption[12];
            strcopy(RatingOption, sizeof(RatingOption), ExplodedSelection[1]);

            char MapName[64];
            strcopy(MapName, sizeof(MapName), ExplodedSelection[0]);

            if (StrEqual(RatingOption, "RATE1"))
            {
                SQL_SubmitRating(ClientSteamId, MapName, "Rating1", 1);
            }
            else if (StrEqual(RatingOption, "RATE2"))
            {
                SQL_SubmitRating(ClientSteamId, MapName, "Rating2", 2);
            }
            else if (StrEqual(RatingOption, "RATE3"))
            {
                SQL_SubmitRating(ClientSteamId, MapName, "Rating3", 3);
            }
            else if (StrEqual(RatingOption, "RATE4"))
            {
                SQL_SubmitRating(ClientSteamId, MapName, "Rating4", 4);
            }
            else if (StrEqual(RatingOption, "RATE5"))
            {
                SQL_SubmitRating(ClientSteamId, MapName, "Rating5", 5);
            }
            else
            {
                delete menu;
            }
        }

        case MenuAction_End:
            delete menu;
    }

    return 0;
}

public int ReportMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char MenuChoice[32];
            menu.GetItem(param2, MenuChoice, sizeof(MenuChoice));

            PrintToServer("MenuChoice: %s", MenuChoice);

            if (StrEqual(MenuChoice, "TOP10"))
            {
                PrintToServer("[SNT] Choice: Top 10");
                Menu Top10Menu = new Menu(MapInfoHandler, MENU_ACTIONS_DEFAULT);

                char sQuery[1024];
                Format(sQuery, sizeof(sQuery), "SELECT MapName, CAST(((Rating1+Rating2+Rating3+Rating4+Rating5)/SUM(NumVotes)) AS decimal(2,2)) Stars, SUM(NumVotes) TotalVotes FROM (SELECT m.MapName, p.SteamId, Rating1, Rating2, Rating3, Rating4, Rating5, COUNT(*) NumVotes FROM snt_maps m JOIN snt_playermaps pm ON m.MapName = pm.MapName JOIN snt_players p ON p.SteamId = pm.SteamId GROUP BY p.SteamId, m.MapName, Rating1, Rating2, Rating3, Rating4, Rating5 ORDER BY m.MapName) AS votes_for_map GROUP BY MapName ORDER BY Stars DESC LIMIT 10;");

                PrintToServer("[SNT] Query Ran: %s", sQuery);

                SQL_TQuery(gDB_sntdb, SQL_Build10MapList, sQuery, Top10Menu);
                Top10Menu.SetTitle("Top 10 Rated Maps:");
                Top10Menu.Display(param1, MENU_TIME_FOREVER);
            }
            else if (StrEqual(MenuChoice, "BOT10"))
            {
                PrintToServer("[SNT] Choice: Bottom 10");
                Menu Bot10Menu = new Menu(MapInfoHandler, MENU_ACTIONS_DEFAULT);

                char sQuery[1024];
                Format(sQuery, sizeof(sQuery), "SELECT MapName, CAST(((Rating1+Rating2+Rating3+Rating4+Rating5)/SUM(NumVotes)) AS decimal(2,2)) Stars, SUM(NumVotes) TotalVotes FROM (SELECT m.MapName, p.SteamId, Rating1, Rating2, Rating3, Rating4, Rating5, COUNT(*) NumVotes FROM snt_maps m JOIN snt_playermaps pm ON m.MapName = pm.MapName JOIN snt_players p ON p.SteamId = pm.SteamId GROUP BY p.SteamId, m.MapName, Rating1, Rating2, Rating3, Rating4, Rating5 ORDER BY m.MapName) AS votes_for_map GROUP BY MapName ORDER BY Stars ASC LIMIT 10;");
                
                PrintToServer("[SNT] Query Ran: %s");

                SQL_TQuery(gDB_sntdb, SQL_Build10MapList, sQuery, Bot10Menu);
                Bot10Menu.SetTitle("Bottom 10 Ranked Maps:");
                Bot10Menu.Display(param1, MENU_TIME_FOREVER);
            }
            else if (StrEqual(MenuChoice, "MAPINFO"))
            {
                PrintToServer("[SNT] Choice: Map Info")
                Menu MapInfoCategory = new Menu(MapInfoCategoryHandler, MENU_ACTIONS_DEFAULT);
                MapInfoCategory.SetTitle("Choose a category!");
                MapInfoCategory.AddItem("evnt_none", "Regular Maps");
                MapInfoCategory.AddItem("evnt_weed", "420 Event Maps");
                MapInfoCategory.Display(param1, MENU_TIME_FOREVER);
            }
        }

        case MenuAction_End:
            delete menu;
    }

    return 0;
}

public int MapInfoCategoryHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char MenuChoice[32];
            menu.GetItem(param2, MenuChoice, sizeof(MenuChoice));

            PrintToServer("MenuChoice: %s", MenuChoice);

            if (StrEqual(MenuChoice, "evnt_none"))
            {
                PrintToServer("[SNT] Choice: Regular Maps");

                Menu InfoRegularMapList = new Menu(MapInfoHandler, MENU_ACTIONS_DEFAULT);
                InfoRegularMapList.SetTitle("Choose a map to view!");

                char sQuery[255];
                Format(sQuery, sizeof(sQuery), "SELECT MapName FROM snt_maps WHERE EventId=\"evnt_none\"");
                PrintToServer("[SNT] Query Ran: %s", sQuery);
                
                SQL_TQuery(gDB_sntdb, SQL_BuildMapMenu, sQuery, InfoRegularMapList);

                InfoRegularMapList.Display(param1, MENU_TIME_FOREVER);
            }
            else if (StrEqual(MenuChoice, "evnt_weed"))
            {
                PrintToServer("[SNT] Choice: Weed Event Maps");
                Menu InfoWeedMapList = new Menu(MapInfoHandler, MENU_ACTIONS_DEFAULT);
                InfoWeedMapList.SetTitle("Choose a map to view!");

                char sQuery[255];
                Format(sQuery, sizeof(sQuery), "SELECT MapName FROM snt_maps WHERE EventId=\"evnt_weed\"");
                PrintToServer("[SNT] Query Ran: %s", sQuery);
                
                SQL_TQuery(gDB_sntdb, SQL_BuildMapMenu, sQuery, InfoWeedMapList);

                InfoWeedMapList.Display(param1, MENU_TIME_FOREVER);
            }
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int MapInfoHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char MapChoice[64];
            menu.GetItem(param2, MapChoice, sizeof(MapChoice));

            char SteamId[64];
            if (IsClientConnected(param1))
                GetClientAuthId(param1, AuthId_Steam3, SteamId, sizeof(SteamId));

            char InfoQuery[1024];
            Format(InfoQuery, sizeof(InfoQuery), "SELECT MapName, CAST(((Rating1+Rating2+Rating3+Rating4+Rating5)/SUM(NumVotes)) AS decimal(2,2)) Stars, SUM(NumVotes) TotalVotes FROM (SELECT m.MapName, p.SteamId, Rating1, Rating2, Rating3, Rating4, Rating5, COUNT(*) NumVotes FROM snt_maps m JOIN snt_playermaps pm ON m.MapName = pm.MapName JOIN snt_players p ON p.SteamId = pm.SteamId GROUP BY p.SteamId, m.MapName, Rating1, Rating2, Rating3, Rating4, Rating5 ORDER BY m.MapName) AS votes_for_map WHERE MapName=\"%s\" GROUP BY MapName ORDER BY Stars;", MapChoice);
            SQL_TQuery(gDB_sntdb, SQL_GetMapInfo, InfoQuery);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

// SQL FUNCTIONS //

public void SQL_BuildMapTable(int client)
{
    PrintToServer("[SNT] Opening maplist file.");

    File MapListFile = OpenFile(gMapListPath, "rt");
    if (MapListFile == null)
    {
        PrintToServer("[SNT] ERROR! \"%s\": file does not exist!", gMapListPath);
    }

    char mapname[255];

    PrintToServer("[SNT] Reading %s", gMapListPath);
    while (!MapListFile.EndOfFile() && MapListFile.ReadLine(mapname, sizeof(mapname)))
    {
        if (mapname[0] == ';' || !IsCharAlpha(mapname[0]))
        {
            continue;
        }

        int len = strlen(mapname);
        for (int i = 0; i < len; i++)
        {
            if (IsCharSpace(mapname[i]))
            {
                mapname[i] = '\0';
                break;
            }
        }

        if (!IsMapValid(mapname))
        {
            PrintToServer("[SM] ERROR! %s map is not valid.", mapname);
            continue;
        }

        char iQuery[255];
        Format(iQuery, sizeof(iQuery), "INSERT INTO snt_maps(MapName) VALUES (\"%s\")", mapname);
        
        if (!SQL_FastQuery(gDB_sntdb, iQuery))
        {
            char SQLError[255];
            SQL_GetError(gDB_sntdb, SQLError, sizeof(SQLError));
            ReplyToCommand(client, "[SQL] ERROR! %s", SQLError);
        }
        else
        {
            ReplyToCommand(client, "[SNT] %s was succesfully added to the database.", mapname);
        }
    }

    MapListFile.Close();
}

public void SQL_RemoveMaps()
{

}

public void SQL_IsMapInTable(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SQL] ERROR! Database is null.");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SQL] ERROR WHEN VALIDATING MAPS: %s", error);
    }

    if (SQL_FetchRow(results))
    {
        data = true;
    }
    else
    {
        data = false; 
    }
}

public void SQL_BuildMapMenu(Database db, DBResultSet results, const char[] error, any data)
{
    PrintToServer("[SNT] Running sql query to build map menu.");

    // Menu is passed through data
    if (db == null)
    {
        PrintToServer("[SQL] ERROR! Database is null.");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SQL] ERROR WHEN BUILDING MAP MENU: %s", error);
    }

    while (SQL_FetchRow(results))
    {
        if (SQL_MoreRows(results))
        {
            char MapName[64];
            SQL_FetchString(results, 0, MapName, sizeof(MapName));
            PrintToServer("[SNT] Found Map: %s", MapName);
            AddMenuItem(data, MapName, MapName);
            SQL_FetchMoreResults(results);
        }
    }

    PrintToServer("[SNT] Finished adding maps to menu.");
}

public void SQL_GetLastRatingForMenu(Database db, DBResultSet results, const char[] error, any data)
{
    // Menu is passed through data
    if (db == null)
    {
        PrintToServer("[SQL] ERROR! Database is null.");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SQL] ERROR WHEN GETTING LAST RATING FOR MAP(MENU): %s", error);
    }

    PrintToServer("[SNT] Getting the player's last rating");

    if (SQL_FetchRow(results))
    {
        int LastRating = SQL_FetchInt(results, 0);
        PrintToServer("[SNT] User's last rating was %i", LastRating);
        switch (LastRating)
        {
            case 0:
            {
                AddMenuItem(data, "NO", "Last Rating | None", ITEMDRAW_RAWLINE)
            }
            default:
            {
                char MenuChoice[32];
                Format(MenuChoice, sizeof(MenuChoice), "Last Rating | %i star(s)", LastRating);
                AddMenuItem(data, "NO", MenuChoice, ITEMDRAW_RAWLINE);
            }
        }
    }
    else
    {
        PrintToServer("[SNT] Unable to get player's last rating.");
    }
}

public void SQL_GetLastRating(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SQL] ERROR! Database is null.");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SQL] ERROR WHEN GETTING LAST RATING FOR MAP: %s", error);
    }

    PrintToServer("[SNT] Getting player's last rating");

    if (SQL_FetchRow(results))
    {
        int LastRating = SQL_FetchInt(results, 0);
        PrintToServer("[SNT] Player's last rating was %i", LastRating);
        data = LastRating;
    }
    else
    {
        PrintToServer("[SNT] Unable to fetch the player's last rating.");
    }
}

public void SQL_Build10MapList(Database db, DBResultSet results, const char[] error, any data)
{
    // Menu is passed through data
    if (db == null)
    {
        PrintToServer("[SQL] ERROR! Database is null.");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SQL] ERROR BUILDING 10 MAP LIST: %s", error);
    }

    PrintToServer("[SNT] Building top 10 list");
    while (SQL_FetchRow(results))
    {
        if (SQL_MoreRows(results))
        {
            char MapName[64];
            SQL_FetchString(results, 0, MapName, sizeof(MapName));
            AddMenuItem(data, MapName, MapName);
            PrintToServer("[SNT] Added Item: %s", MapName);
            SQL_FetchMoreResults(results);
        }
    }
}


public void SQL_GetMapInfo(Database db, DBResultSet results, const char[] error, any data)
{
    // client is passed through data
    if (db == null)
    {
        PrintToServer("[SQL] ERROR! Database is null.");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SQL] ERROR GETTING MAP INFO: %s", error);
    }

    PrintToServer("[SNT] Declaring Variables");

    Menu MapInfoMenu = new Menu(MapsRatingHandler, MENU_ACTIONS_DEFAULT);
    char ClientAuthId[32];
    char MapName[32];
    float MapRating;
    int TotalVotes;

    SQL_FetchString(results, 0, MapName, sizeof(MapName));
    MapRating = SQL_FetchFloat(results, 1);
    TotalVotes = SQL_FetchInt(results, 2);
    PrintToServer("*    RESULTS    *\n,Name: %s\n,Stars: %f\n, NumVotes: %i", MapName, MapRating, TotalVotes);

    PrintToServer("[SNT] Getting Map Info");
    if (SQL_FetchRow(results))
    {
        if (IsClientConnected(data))
            GetClientAuthId(data, AuthId_Steam3, ClientAuthId, sizeof(ClientAuthId));
    
        char sQuery[255];
        Format(sQuery, sizeof(sQuery), "SELECT LastVote FROM snt_playermaps WHERE SteamId=\"%s\"", ClientAuthId);
        SQL_TQuery(db, SQL_GetLastRatingForMenu, sQuery, MapInfoMenu);
        
        char FMapName[64];
        char FMapRating[64];
        char FTotalVotes[64];

        Format(FMapName, sizeof(FMapName), "NAME: %s", MapName);
        Format(FMapRating, sizeof(FMapRating), "RATING: %f stars", MapRating);
        Format(FTotalVotes, sizeof(FTotalVotes), "TOTAL VOTES: %i", TotalVotes);

        PrintToServer("[SNT] Formatted menu options");

        AddMenuItem(data, "", "", ITEMDRAW_SPACER);
        AddMenuItem(data, "Name", FMapName, ITEMDRAW_RAWLINE);
        AddMenuItem(data, "Rating", FMapRating, ITEMDRAW_RAWLINE);
        AddMenuItem(data, "Votes", FTotalVotes, ITEMDRAW_RAWLINE);

        PrintToServer("[SNT] Added map info to menu");
    }
    else
    {
        PrintToServer("Map has not been voted for yet.");
        char MenuChoice[64];
        Format(MenuChoice, sizeof(MenuChoice), "%s", MapName)

        AddMenuItem(data, "NOVOTES", "There have been no votes for this map yet.", ITEMDRAW_RAWLINE);
        AddMenuItem(data, "NOVOTES", "Do you want to rate this map?", ITEMDRAW_RAWLINE);
        AddMenuItem(data, "", "", ITEMDRAW_SPACER);
        AddMenuItem(data, MenuChoice, "Yes");
        AddMenuItem(data, "N", "No");
    }
}

public void SQL_IsPlayerInTable(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SQL] ERROR! Database is null.");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SQL] ERROR WHEN CHECKING IF PLAYER IS IN TABLE: %s", error);
    }

    PrintToServer("[SNT] Checking if player is in table.");

    if (SQL_FetchRow(results))
    {
        PrintToServer("[SNT] Player is in table");
        data = true;
    }
    else
    {
        PrintToServer("[SNT] Player is not in table");
        data = false;
    }
}

public void SQL_RemoveMap(Database db, DBResultSet results, const char[] error, any data)
{

}

public bool SQL_SubmitRating(char[] SteamId, char[] MapName, char[] RatingColumn, int RatingValue)
{
    char vQuery[255];
    Format(vQuery, sizeof(vQuery), "SELECT SteamId FROM snt_playermaps WHERE SteamId='%s'", SteamId);

    bool PlayerExistsInTable;
    SQL_TQuery(gDB_sntdb, SQL_IsPlayerInTable, vQuery, PlayerExistsInTable);
    
    PrintToServer("[SNT] Adding rating to map for player");

    if (!PlayerExistsInTable)
    {
        PrintToServer("[SNT] Player is not already in table.");
        char iPlyrMapQuery[255];
        char uMapQuery[255];

        Format(iPlyrMapQuery, sizeof(iPlyrMapQuery), "INSERT INTO snt_playermaps VALUES (%s, %s, %i)", SteamId, MapName, RatingValue);
        Format(uMapQuery, sizeof(uMapQuery), "UPDATE snt_maps SET %s=%s+%i WHERE MapId='%s'", RatingColumn, RatingColumn, RatingValue, MapName);

        PrintToServer("[SNT] Inserted player into table and updated maps table.");

        if (!SQL_FastQuery(gDB_sntdb, iPlyrMapQuery))
        {
            char error[255];
            SQL_GetError(gDB_sntdb, error, sizeof(error));
            PrintToServer("[SQL] ERROR! %s", error);
            return false;
        }
        
        if (!SQL_FastQuery(gDB_sntdb, uMapQuery))
        {
            char error[255];
            SQL_GetError(gDB_sntdb, error, sizeof(error));
            PrintToServer("[SQL] ERROR! %s", error);
            return false;
        }
    }
    else
    {
        PrintToServer("[SNT] Player was in table.");
        char uPlyrMapQuery[255];
        char uMapQuery[255];

        Format(uPlyrMapQuery, sizeof(uPlyrMapQuery), "UPDATE snt_playermaps SET LastVote=%i WHERE SteamId='%s' AND MapId='%s'", RatingValue, SteamId, MapName);
        Format(uMapQuery, sizeof(uMapQuery), "UPDATE snt_maps SET %s=%s+%i WHERE MapId='%s'", RatingColumn, RatingColumn, RatingValue, MapName);

        PrintToServer("[SNT] Updating playermaps table and maps table.");

        if (!SQL_FastQuery(gDB_sntdb, uPlyrMapQuery))
        {
            char error[255];
            SQL_GetError(gDB_sntdb, error, sizeof(error));
            PrintToServer("[SQL] ERROR! %s", error);
            return false;
        }

        if (!SQL_FastQuery(gDB_sntdb, uMapQuery))
        {
            char error[255];
            SQL_GetError(gDB_sntdb, error, sizeof(error));
            PrintToServer("[SQL] ERROR! %s", error);
            return false;
        }
        return true;
    }
    return true;
}

public Action ADM_BuildTables(int client, int args)
{
    SQL_BuildMapTable(client);
    return Plugin_Handled;
}

public Action ADM_RemoveMaps(int client, int args)
{
    if (client == 0)
    {
        if (args != 1)
        {
            ReplyToCommand(client, "[SNT] snt_rmvmaps <mapname>: Specify a map name to remove it from the database.")
        }

        
    }
    else
    {
        if (args != 0)
        {
            ReplyToCommand(client, "[SNT] !snt_rmvmaps: Use this to open the remove map menu.");
        }
        Menu UsrCatMenu = new Menu(MapCategoriesHandler, MENU_ACTIONS_DEFAULT);
        UsrCatMenu.SetTitle("Choose a category!");
        UsrCatMenu.AddItem("evnt_none", "Regular Surf Maps");
        UsrCatMenu.AddItem("evnt_weed", "420 Event Maps");
        UsrCatMenu.Display(client, 20);
        return Plugin_Handled;
    }
}

public Action ALL_MapReportMenu(int client, int args)
{
    Menu MapReportMenu = new Menu(ReportMenuHandler, MENU_ACTIONS_DEFAULT);
    MapReportMenu.SetTitle("Choose a report to view:")
    MapReportMenu.AddItem("TOP10", "Top 10 Maps");
    MapReportMenu.AddItem("BOT10", "Bottom 10 Maps");
    MapReportMenu.AddItem("MAPINFO", "Map Specific Info");
    MapReportMenu.Display(client, MENU_TIME_FOREVER);

    return Plugin_Handled;
}

public Action USR_OpenRatingMenu(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "[SNT] ERROR! SERVER USER CANNOT USE THIS COMMAND!");
        return Plugin_Handled;
    }

    if (args == 0)
    {
        Menu UsrCatMenu = new Menu(MapCategoriesHandler, MENU_ACTIONS_DEFAULT);
        UsrCatMenu.SetTitle("Choose a category!");
        UsrCatMenu.AddItem("evnt_none", "Regular Surf Maps");
        UsrCatMenu.AddItem("evnt_weed", "420 Event Maps");
        UsrCatMenu.Display(client, 20);
        return Plugin_Handled;
    }
    else
    {
        ReplyToCommand(client, "[SNT] /ratemap: Opens the map rating menu.");
        return Plugin_Handled;
    }
}