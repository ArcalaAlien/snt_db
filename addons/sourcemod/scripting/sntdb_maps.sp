#include <sourcemod>
#include <clients>
#include <string>
#include <menus>
#include <dbi>
#include <files>
#include <keyvalues>

// Third party includes
#include <morecolors>

#define REQUIRE_PLUGIN
#include <sntdb_core>

public Plugin myinfo =
{
    name = "sntdb Map Module",
    author = "Arcala the Gyiyg",
    description = "SNTDB Module for dealing with maps.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

// Debug stuff
bool DebugMode = true;
char DebugFile[PLATFORM_MAX_PATH];


// Config variables
char DBConfName[32];

//  DB Variables
Database gDB_sntdb;

// Menus
Menu Menu_RegularMaps;
Menu Menu_WeedMaps;

// Arrays
ArrayList AL_RegularMaps;
ArrayList AL_WeedMaps;

// Array Serials
char MapSerialPath[PLATFORM_MAX_PATH];
int ReturnedSerials[2];

public void OnPluginStart() 
{
    if (DebugMode)
    {
        BuildPath(Path_SM, DebugFile, sizeof(DebugFile), "logs/sntdb_maps.log");
    }

    LoadSQLConfigs(DBConfName, sizeof(DBConfName), 0, "Maps");

    PrintToServer("[SNT] Connecting to Database");
    char error[255];
    gDB_sntdb = SQL_Connect(DBConfName, true, error, sizeof(error));
    if (!StrEqual(error, ""))
    {
        ThrowError("[SNT] ERROR IN PLUGIN START: %s", error);
    }

    BuildPath(Path_SM, MapSerialPath, sizeof(MapSerialPath), "configs/sntdb/maplist_serials.out");

    AL_RegularMaps = CreateArray(64);
    AL_WeedMaps = CreateArray(64);

    Menu_RegularMaps = new Menu(MapsRatingHandler, MENU_ACTIONS_DEFAULT);
    Menu_WeedMaps = new Menu(MapsRatingHandler, MENU_ACTIONS_DEFAULT);

    DataPack Reg_Pack;
    DataPack Weed_Pack;

    Reg_Pack = CreateDataPack();
    Weed_Pack = CreateDataPack();
    WritePackCell(Reg_Pack, Menu_RegularMaps);
    WritePackCell(Reg_Pack, 0);
    WritePackCell(Weed_Pack, Menu_WeedMaps);
    WritePackCell(Weed_Pack, 0);

    SQL_TQuery(gDB_sntdb, SQL_BuildMapMenu, "SELECT MapName FROM snt_maps WHERE EventId=\'evnt_none\'", Reg_Pack);
    SQL_TQuery(gDB_sntdb, SQL_BuildMapMenu, "SELECT MapName FROM snt_maps WHERE EventId=\'evnt_weed\'", Weed_Pack);

    RegAdminCmd("sm_snt_buildtable",   ADM_BuildTables,        ADMFLAG_ROOT,       "/snt_buildtable: Use this to read a mapcycle.txt file and send all the map names to the database.");
    RegAdminCmd("sm_snt_syncmaps",     ADM_SyncMapMenus,       ADMFLAG_ROOT,       "/snt_syncmaps: Use this to sync the maplists with the database.");
    RegConsoleCmd("sm_rate",        USR_OpenRatingMenu,                         "/rate: Use this to open the rating menu!");
    RegConsoleCmd("sm_ratemaps",    USR_OpenRatingMenu,                         "/ratemaps: Use this to open the rating menu!")
    RegConsoleCmd("sm_ratemap",     USR_RateMap,                                "/ratemap: Use this to rate the current map!");

    PrintToServer("[SNT] Registered Commands");
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
                Menu_RegularMaps.Display(param1, MENU_TIME_FOREVER);
            }
            else if (StrEqual(MenuCategory, "evnt_weed"))
            {
                Menu_WeedMaps.Display(param1, MENU_TIME_FOREVER);
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
            char SteamId[64];
            if (IsClientConnected(param1))
                GetClientAuthId(param1, AuthId_Steam3, SteamId, sizeof(SteamId));

            char SelectedMap[64];
            char SelectedMapEsc[129];
            menu.GetItem(param2, SelectedMap, sizeof(SelectedMap));
            SQL_EscapeString(gDB_sntdb, SelectedMap, SelectedMapEsc, sizeof(SelectedMapEsc));

            if (StrEqual(SelectedMap, "N"))
            {
                return 0;
            }

            DataPack MapInfo_Pack;
            MapInfo_Pack = CreateDataPack();
            MapInfo_Pack.WriteString(SelectedMapEsc);
            MapInfo_Pack.WriteCell(param1);

            char vQuery[255];
            Format(vQuery, sizeof(vQuery), "SELECT LastVote FROM snt_playermaps WHERE SteamId=\'%s\' AND MapName=\'%s\'", SteamId, SelectedMapEsc);
            SQL_TQuery(gDB_sntdb, SQL_GetLastRatingForMenu, vQuery, MapInfo_Pack);
        }
        case MenuAction_End:
            return 0;
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
            char MapNameEsc[129];
            strcopy(MapName, sizeof(MapName), ExplodedSelection[0]);
            SQL_EscapeString(gDB_sntdb, MapName, MapNameEsc, sizeof(MapNameEsc));

            char sQuery[255];
            Format(sQuery, sizeof(sQuery), "SELECT * FROM snt_playermaps WHERE SteamId=\'%s\' AND MapName=\'%s\'", ClientSteamId, MapNameEsc);

            DataPack Rating_Info;
            Rating_Info = CreateDataPack();
            Rating_Info.WriteString(ClientSteamId);
            Rating_Info.WriteString(MapName);
            Rating_Info.WriteCell(param1);

            if (StrEqual(RatingOption, "RATE1"))
            {
                Rating_Info.WriteCell(1);
            }
            else if (StrEqual(RatingOption, "RATE2"))
            {
                Rating_Info.WriteCell(2);
            }
            else if (StrEqual(RatingOption, "RATE3"))
            {
                Rating_Info.WriteCell(3);
            }
            else if (StrEqual(RatingOption, "RATE4"))
            {
                Rating_Info.WriteCell(4);
            }
            else if (StrEqual(RatingOption, "RATE5"))
            {
                Rating_Info.WriteCell(5);
            }
            
            SQL_TQuery(gDB_sntdb, SQL_SubmitRating, sQuery, Rating_Info);
            return 0;
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                PrintToServer("Back button pressed");
            }
            else
            {
                delete menu;
            }
        }
        case MenuAction_End:
            return 0;
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

            DataPack Client_Pack;
            Client_Pack = CreateDataPack();
            Client_Pack.WriteCell(param1);

            if (StrEqual(MenuChoice, "RATEAMAP"))
            {
                PrintToServer("[SNT] User chose to rate other map");
                Menu UsrCatMenu = new Menu(MapCategoriesHandler, MENU_ACTIONS_DEFAULT);
                UsrCatMenu.SetTitle("Choose a category!");
                UsrCatMenu.AddItem("evnt_none", "Non-Event Maps");
                UsrCatMenu.AddItem("evnt_weed", "420 Event Maps");
                UsrCatMenu.Display(param1, 20);
            }
            else if (StrEqual(MenuChoice, "RATETHISMAP"))
            {
                PrintToServer("[SNT] User chose to rate this map");
                char SteamId[64];
                GetClientAuthId(param1, AuthId_Steam3, SteamId, sizeof(SteamId));

                char CurrentMap[64];
                char CurrentMapEsc[129];
                GetCurrentMap(CurrentMap, sizeof(CurrentMap));
                SQL_EscapeString(gDB_sntdb, CurrentMap, CurrentMapEsc, sizeof(CurrentMapEsc));

                DataPack MapInfo_Pack;
                MapInfo_Pack = CreateDataPack();
                MapInfo_Pack.WriteString(CurrentMap);
                MapInfo_Pack.WriteCell(param1);

                char vQuery[255];
                Format(vQuery, sizeof(vQuery), "SELECT LastVote FROM snt_playermaps WHERE SteamId=\'%s\' AND MapName=\'%s\'", SteamId, CurrentMapEsc);
                SQL_TQuery(gDB_sntdb, SQL_GetLastRatingForMenu, vQuery, MapInfo_Pack);
            }
            else if (StrEqual(MenuChoice, "SEEMAPINFO"))
            {
                char SteamId[64];
                GetClientAuthId(param1, AuthId_Steam3, SteamId, sizeof(SteamId));

                char CurrentMap[64];
                char CurrentMapEsc[129];
                GetCurrentMap(CurrentMap, sizeof(CurrentMap));
                SQL_EscapeString(gDB_sntdb, CurrentMap, CurrentMapEsc, sizeof(CurrentMapEsc));

                PrintToServer("[SNT] User wants to see this map's rating.");
                DataPack MapInfo_Pack;
                MapInfo_Pack = CreateDataPack();
                MapInfo_Pack.WriteString(CurrentMapEsc);
                MapInfo_Pack.WriteCell(param1);

                char vQuery[255];
                Format(vQuery, sizeof(vQuery), "SELECT * FROM snt_playermaps WHERE MapName=\'%s\'", CurrentMapEsc);
                SQL_TQuery(gDB_sntdb, SQL_GetMapInfo, vQuery, MapInfo_Pack);
            }
            else if (StrEqual(MenuChoice, "OTHERMAPINFO"))
            {
                PrintToServer("[SNT] User wants to see other map's ratings.");
                Menu MapInfoCategory = new Menu(MapInfoCategoryHandler, MENU_ACTIONS_DEFAULT);
                MapInfoCategory.SetTitle("Choose a category!");
                MapInfoCategory.AddItem("evnt_none", "Non-Event Maps");
                MapInfoCategory.AddItem("evnt_weed", "420 Event Maps");
                MapInfoCategory.Display(param1, MENU_TIME_FOREVER);
            }
            else if (StrEqual(MenuChoice, "TOP10"))
            {
                PrintToServer("[SNT] User wants to see the top 10 maps");
                Client_Pack.WriteCell(1);
                char sQuery[1024];
                Format(sQuery, sizeof(sQuery), "SELECT * FROM MapRatings ORDER BY Stars DESC LIMIT 10;");
                SQL_TQuery(gDB_sntdb, SQL_Build10MapList, sQuery, Client_Pack);
            }
            else if (StrEqual(MenuChoice, "BOT10"))
            {
                PrintToServer("[SNT] User wants to see the bottom 10 maps.");
                Client_Pack.WriteCell(2);
                char sQuery[1024];
                Format(sQuery, sizeof(sQuery), "SELECT * FROM MapRatings ORDER BY Stars ASC LIMIT 10;");
                SQL_TQuery(gDB_sntdb, SQL_Build10MapList, sQuery, Client_Pack);
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
                Format(sQuery, sizeof(sQuery), "SELECT MapName FROM snt_maps WHERE EventId=\'evnt_none\'");
                PrintToServer("[SNT] Query Ran: %s", sQuery);

                DataPack Client_Pack;
                Client_Pack = CreateDataPack();
                Client_Pack.WriteCell(InfoRegularMapList);
                Client_Pack.WriteCell(param1);
                
                SQL_TQuery(gDB_sntdb, SQL_BuildMapMenu, sQuery, Client_Pack);
            }
            else if (StrEqual(MenuChoice, "evnt_weed"))
            {
                PrintToServer("[SNT] Choice: Weed Event Maps");
                Menu InfoWeedMapList = new Menu(MapInfoHandler, MENU_ACTIONS_DEFAULT);
                InfoWeedMapList.SetTitle("Choose a map to view!");

                DataPack Client_Pack;
                Client_Pack = CreateDataPack();
                Client_Pack.WriteCell(InfoWeedMapList);
                Client_Pack.WriteCell(param1);

                char sQuery[255];
                Format(sQuery, sizeof(sQuery), "SELECT MapName FROM snt_maps WHERE EventId=\'evnt_weed\'");
                PrintToServer("[SNT] Query Ran: %s", sQuery);
                
                SQL_TQuery(gDB_sntdb, SQL_BuildMapMenu, sQuery, Client_Pack);
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
            char MapChoiceEsc[129];
            menu.GetItem(param2, MapChoice, sizeof(MapChoice));
            SQL_EscapeString(gDB_sntdb, MapChoice, MapChoiceEsc, sizeof(MapChoiceEsc));

            char SteamId[64];
            if (IsClientConnected(param1))
                GetClientAuthId(param1, AuthId_Steam3, SteamId, sizeof(SteamId));

            DataPack Map_Info;
            Map_Info = CreateDataPack();
            Map_Info.WriteString(MapChoice);
            Map_Info.WriteCell(param1);

            char sQuery[512];
            Format(sQuery, sizeof(sQuery), "SELECT * FROM MapRatings WHERE MapName=\'%s\'", MapChoiceEsc);
            SQL_TQuery(gDB_sntdb, SQL_GetMapInfo, sQuery, Map_Info);
        }
        case MenuAction_End:
            return 0;
    }
    return 0;
}

// SQL FUNCTIONS //

public void SQL_ErrorHandler(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] ERROR! DATABASE IS NULL!");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN QUERY! %s", error);
    }
}

public void SQL_FillMapTable(Database db, int client)
{
    if (AL_RegularMaps)
    {
        ReadMapList(AL_RegularMaps, ReturnedSerials[0], "snt_regularmaps");
        for (int i = 0; i < GetArraySize(AL_RegularMaps); i++)
        {
            DataPack Pack_RegMap;
            Pack_RegMap = CreateDataPack();
            Pack_RegMap.Reset(true);

            char sQuery[512];
            char MapName[64];
            char MapNameEsc[129];

            AL_RegularMaps.GetString(i, MapName, sizeof(MapName));
            PrintToServer("[SNT] MapName: %s", MapName);
            SQL_EscapeString(db, MapName, MapNameEsc, sizeof(MapNameEsc));
        
            Pack_RegMap.WriteString(MapName);
            Pack_RegMap.WriteString("evnt_none");

            Format(sQuery, sizeof(sQuery), "SELECT * FROM snt_maps WHERE MapName=\'%s\' AND EventId=\'evnt_none\'", MapNameEsc);
            SQL_TQuery(db, SQL_InsertMaps, sQuery, Pack_RegMap);
        }
        ReplyToCommand(client, "[SNT] %i regular maps retrieved.", GetArraySize(AL_RegularMaps));
    }
    else
    {
        ReplyToCommand(client, "[SNT] No regular maps retrieved.");
    }
    
    if (AL_WeedMaps)
    {
        ReadMapList(AL_WeedMaps, ReturnedSerials[1], "snt_weedmaps");
        for (int i = 0; i < GetArraySize(AL_WeedMaps); i++)
        {
            DataPack Pack_WeedMap;
            Pack_WeedMap = CreateDataPack();
            Pack_WeedMap.Reset(true);

            char sQuery[512];
            char MapName[64];
            char MapNameEsc[129];

            AL_WeedMaps.GetString(i, MapName, sizeof(MapName));
            SQL_EscapeString(db, MapName, MapNameEsc, sizeof(MapNameEsc));
        
            Pack_WeedMap.WriteString(MapName);
            Pack_WeedMap.WriteString("evnt_weed");
            PrintToServer("[SNT] Map found: %s", MapName);
            Format(sQuery, sizeof(sQuery), "SELECT * FROM snt_maps WHERE MapName=\'%s\' AND EventId=\'evnt_weed\'", MapNameEsc);
            SQL_TQuery(db, SQL_InsertMaps, sQuery, Pack_WeedMap);
        }
        ReplyToCommand(client, "[SNT] %i weed maps retrieved.", GetArraySize(AL_WeedMaps));
    }
    else
    {
        ReplyToCommand(client, "[SNT] No weed maps retrieved.");
    }
}

public void SQL_InsertMaps(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("SQL_IsMapInTable: DATABASE IS NULL");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("SQL_IsMapInTable: ERROR WHEN VALIDATING MAPS: %s", error);
    }

    if (data)
    {
        char PassedName[64];
        char PassedEvent[64];
        ResetPack(data);
        ReadPackString(data, PassedName, 64);
        ReadPackString(data, PassedEvent, 64);

        if (!SQL_MoreRows(results))
        {
            
            char iQuery[255];
            char PassedNameEsc[129];
            char PassedEventEsc[129];
            SQL_EscapeString(db, PassedName, PassedNameEsc, sizeof(PassedNameEsc));
            SQL_EscapeString(db, PassedEvent, PassedEventEsc, sizeof(PassedEventEsc));

            Format(iQuery, sizeof(iQuery), "INSERT INTO snt_maps(MapName, EventId) VALUES (\'%s\', \'%s\')", PassedNameEsc, PassedEventEsc);
            SQL_TQuery(db, SQL_ErrorHandler, iQuery);
        }
    }

    CloseHandle(data);
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

    ResetPack(data);

    Menu MapList;
    int client;

    MapList = ReadPackCell(data);
    client = ReadPackCell(data);

    CloseHandle(data);

    int MapCount;
    int TotalRows;

    while (SQL_FetchRow(results))
    {
        char MapName[64];
        SQL_FetchString(results, 0, MapName, sizeof(MapName));

        //PrintToServer("[SNT] Found Map: %s", MapName);
        MapList.AddItem(MapName, MapName);
        
        MapCount++;

        SQL_FetchMoreResults(results);
    }

    PrintToServer("[SNT] Total maps found: %i", MapCount);
    TotalRows = SQL_GetRowCount(results)
    PrintToServer("[SNT] Total rows in results: %i", TotalRows);

    if (client != 0)
        MapList.Display(client, MENU_TIME_FOREVER);
    else
        PrintToServer("[SNT] Built maplist.");
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

    char SelectedMap[64];
    int client;
    ResetPack(data);
    ReadPackString(data, SelectedMap, sizeof(SelectedMap));
    client = ReadPackCell(data);

    Menu RateMapMenu = new Menu(RatingMenuHandler, MENU_ACTIONS_DEFAULT);

    if (SQL_FetchRow(results))
    {
        int LastRating = SQL_FetchInt(results, 0);
        PrintToServer("[SNT] User's last rating was %i", LastRating);
        switch (LastRating)
        {
            case 0:
            {
                RateMapMenu.AddItem("NO", "Last Rating: None", ITEMDRAW_DISABLED);
            }
            default:
            {
                char MenuChoice[32];
                Format(MenuChoice, sizeof(MenuChoice), "Last Rating: %i star(s)", LastRating);
                RateMapMenu.AddItem("NO", MenuChoice, ITEMDRAW_DISABLED);
            }
        }
    }
    else
    {
        PrintToServer("[SNT] Player has not voted for this map yet.");
        RateMapMenu.AddItem("NO", "Last Rating: None", ITEMDRAW_DISABLED);
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

    RateMapMenu.SetTitle("What do you want to rate %s?", SelectedMap);
    RateMapMenu.AddItem(Rate1, "1 Star");
    RateMapMenu.AddItem(Rate2, "2 Stars");
    RateMapMenu.AddItem(Rate3, "3 Stars");
    RateMapMenu.AddItem(Rate4, "4 Stars");
    RateMapMenu.AddItem(Rate5, "5 Stars");
    RateMapMenu.Display(client, MENU_TIME_FOREVER);
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

    int client;
    int type;
    
    ResetPack(data);
    client = ReadPackCell(data);
    type = ReadPackCell(data);

    Menu List10Menu = new Menu(MapInfoHandler, MENU_ACTIONS_DEFAULT);

    switch(type)
    {
        case 1:
            List10Menu.SetTitle("Top 10 Maps:")
        case 2:
            List10Menu.SetTitle("Bottom 10 Maps:");
        default:
            List10Menu.SetTitle("Maps?");
    }

    while (SQL_FetchRow(results))
    {
        PrintToServer(" [SNT] Found row")
        if (SQL_MoreRows(results))
        {
            char MapName[64];
            SQL_FetchString(results, 0, MapName, sizeof(MapName));
            AddMenuItem(List10Menu, MapName, MapName);
            PrintToServer("[SNT] Added Item: %s", MapName);
            SQL_FetchMoreResults(results);
        }
    }

    List10Menu.Display(client, MENU_TIME_FOREVER);
    CloseHandle(data);
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

    Menu MapInfoMenu = new Menu(MapsRatingHandler, MENU_ACTIONS_DEFAULT);

    char MapName[64];
    int client;

    ResetPack(data);
    ReadPackString(data, MapName, sizeof(MapName));
    client = ReadPackCell(data);

    PrintToServer("[SNT] Getting Map Info");
    PrintToServer("[SNT] Map Name: %s", MapName);

    if (SQL_FetchRow(results))
    {
        PrintToServer("[SNT] Map Retrieved");
        float MapRating;
        int TotalVotes;

        char ClientAuthId[64];
        if (IsClientInGame(client) && IsClientConnected(client))
            GetClientAuthId(client, AuthId_Steam3, ClientAuthId, sizeof(ClientAuthId));

        TotalVotes = SQL_FetchInt(results, 1);
        MapRating = SQL_FetchFloat(results, 2);
        PrintToServer("*    RESULTS    *\nName: %s\nStars: %f\nNumVotes: %i", MapName, MapRating, TotalVotes);

        char FMapName[64];
        char FMapRating[64];
        char FTotalVotes[64];

        Format(FMapName, sizeof(FMapName), "Name: %s", MapName);
        Format(FMapRating, sizeof(FMapRating), "Rating: %1.2f stars", MapRating);
        Format(FTotalVotes, sizeof(FTotalVotes), "Total Votes: %i", TotalVotes);

        MapInfoMenu.SetTitle("Viewing Map: %s", MapName);
        MapInfoMenu.AddItem("Name", FMapName, ITEMDRAW_DISABLED);
        MapInfoMenu.AddItem("Rating", FMapRating, ITEMDRAW_DISABLED);
        MapInfoMenu.AddItem("Votes", FTotalVotes, ITEMDRAW_DISABLED);
        MapInfoMenu.AddItem("", "", ITEMDRAW_SPACER);
        MapInfoMenu.AddItem(MapName, "Vote for this map!");
        MapInfoMenu.Display(client, MENU_TIME_FOREVER);
    }
    else
    {
        MapInfoMenu.SetTitle("Viewing Map: %s", MapName);
        MapInfoMenu.AddItem("NOVOTES", "There have been no votes for this map yet.", ITEMDRAW_DISABLED);
        MapInfoMenu.AddItem("NOVOTES", "Do you want to rate this map?", ITEMDRAW_DISABLED);
        MapInfoMenu.AddItem("", "", ITEMDRAW_SPACER);
        MapInfoMenu.AddItem(MapName, "Yes");
        MapInfoMenu.AddItem("N", "No");
        MapInfoMenu.Display(client, MENU_TIME_FOREVER);
    }
    CloseHandle(data);
}

public void SQL_SubmitRating(Database db, DBResultSet results, const char[] error, any data)
{
    char SteamId[64];
    char MapName[64];
    char MapNameEsc[129];
    int  client;
    int  PlayerVote;
    
    char SQL_SteamId[64];
    char SQL_MapName[64];
    int  SQL_LastVote;

    ResetPack(data);
    ReadPackString(data, SteamId, sizeof(SteamId));
    ReadPackString(data, MapName, sizeof(MapName));
    client = ReadPackCell(data);
    PlayerVote = ReadPackCell(data);

    SQL_EscapeString(db, MapName, MapNameEsc, sizeof(MapNameEsc));

    PrintToServer("[SNT] VALUES TO SUBMIT: %s, %s, %i", SteamId, MapName, PlayerVote);

    int RowCount;

    if (SQL_FetchRow(results))
    {
        SQL_FetchString(results, 0, SQL_SteamId, sizeof(SQL_SteamId));
        SQL_FetchString(results, 1, SQL_MapName, sizeof(SQL_MapName));
        SQL_LastVote = SQL_FetchInt(results, 2);

        PrintToServer("[SNT] Player vote is already in table.");
        char uPlyrMapQuery[255];
        char uMapQuery1[255];
        char uMapQuery2[255];

        switch(SQL_LastVote)
        {
            case 1:
                Format(uMapQuery1, sizeof(uMapQuery1), "UPDATE snt_maps SET Rating1=Rating1-1 WHERE MapName=\'%s\'", MapNameEsc);
            case 2:
                Format(uMapQuery1, sizeof(uMapQuery1), "UPDATE snt_maps SET Rating2=Rating2-2 WHERE MapName=\'%s\'", MapNameEsc);
            case 3:
                Format(uMapQuery1, sizeof(uMapQuery1), "UPDATE snt_maps SET Rating3=Rating3-3 WHERE MapName=\'%s\'", MapNameEsc);
            case 4:
                Format(uMapQuery1, sizeof(uMapQuery1), "UPDATE snt_maps SET Rating4=Rating4-4 WHERE MapName=\'%s\'", MapNameEsc);
            case 5:
                Format(uMapQuery1, sizeof(uMapQuery1), "UPDATE snt_maps SET Rating5=Rating5-5 WHERE MapName=\'%s\'", MapNameEsc);
        }

        switch (PlayerVote)
        {
            case 1:
            {
                Format(uPlyrMapQuery, sizeof(uPlyrMapQuery), "UPDATE snt_playermaps SET LastVote=1 WHERE SteamId=\'%s\' AND MapName=\'%s\'", SteamId, MapNameEsc);
                Format(uMapQuery2, sizeof(uMapQuery2), "UPDATE snt_maps SET Rating1=Rating1+1 WHERE MapName=\'%s\'", MapNameEsc);
            }
            case 2:
            {
                Format(uPlyrMapQuery, sizeof(uPlyrMapQuery), "UPDATE snt_playermaps SET LastVote=2 WHERE SteamId=\'%s\' AND MapName=\'%s\'", SteamId, MapName);
                Format(uMapQuery2, sizeof(uMapQuery2), "UPDATE snt_maps SET Rating2=Rating2+2 WHERE MapName=\'%s\'", MapNameEsc);
            }
            case 3:
            {
                Format(uPlyrMapQuery, sizeof(uPlyrMapQuery), "UPDATE snt_playermaps SET LastVote=3 WHERE SteamId=\'%s\' AND MapName=\'%s\'", SteamId, MapName);
                Format(uMapQuery2, sizeof(uMapQuery2), "UPDATE snt_maps SET Rating3=Rating3+3 WHERE MapName=\'%s\'", MapNameEsc);
            }
            case 4:
            {
                Format(uPlyrMapQuery, sizeof(uPlyrMapQuery), "UPDATE snt_playermaps SET LastVote=4 WHERE SteamId=\'%s\' AND MapName=\'%s\'", SteamId, MapName);
                Format(uMapQuery2, sizeof(uMapQuery2), "UPDATE snt_maps SET Rating4=Rating4+4 WHERE MapName=\'%s\'", MapNameEsc);
            }
            case 5:
            {
                Format(uPlyrMapQuery, sizeof(uPlyrMapQuery), "UPDATE snt_playermaps SET LastVote=5 WHERE SteamId=\'%s\' AND MapName=\'%s\'", SteamId, MapName);
                Format(uMapQuery2, sizeof(uMapQuery2), "UPDATE snt_maps SET Rating5=Rating5+5 WHERE MapName=\'%s\'", MapNameEsc);
            }
        }
        PrintToServer("[SNT] Query: %s", uPlyrMapQuery);
        PrintToServer("[SNT] Query: %s", uMapQuery1);
        PrintToServer("[SNT] Query: %s", uMapQuery2);

        SQL_TQuery(gDB_sntdb, SQL_ErrorHandler, uPlyrMapQuery);
        SQL_TQuery(gDB_sntdb, SQL_ErrorHandler, uMapQuery1);
        SQL_TQuery(gDB_sntdb, SQL_ErrorHandler, uMapQuery2);

        CPrintToChat(client, "{white}[{greenyellow}SNT{white}] Updated your rating for {greenyellow}%s {white}from {gold}%i {white}to {gold}%i {white}star(s)!", MapName, SQL_LastVote, PlayerVote);
        PrintToServer("[SNT] Updated player in table and updated maps table.");
    }
    else
    {
        PrintToServer("[SNT] Player vote is not already in table.");
        char iPlyrMapQuery[255];
        char uMapQuery[255];
        switch (PlayerVote)
        {
            case 1:
            {
                Format(iPlyrMapQuery, sizeof(iPlyrMapQuery), "INSERT INTO snt_playermaps VALUES (\'%s\', \'%s\', 1)", SteamId, MapNameEsc);
                Format(uMapQuery, sizeof(uMapQuery), "UPDATE snt_maps SET Rating1=Rating1+1 WHERE MapName=\'%s\'", MapNameEsc);
            }
            case 2:
            {
                Format(iPlyrMapQuery, sizeof(iPlyrMapQuery), "INSERT INTO snt_playermaps VALUES (\'%s\', \'%s\', 2)", SteamId, MapNameEsc);
                Format(uMapQuery, sizeof(uMapQuery), "UPDATE snt_maps SET Rating2=Rating2+2 WHERE MapName=\'%s\'", MapNameEsc);
            }
            case 3:
            {
                Format(iPlyrMapQuery, sizeof(iPlyrMapQuery), "INSERT INTO snt_playermaps VALUES (\'%s\', \'%s\', 3)", SteamId, MapNameEsc);
                Format(uMapQuery, sizeof(uMapQuery), "UPDATE snt_maps SET Rating3=Rating3+3 WHERE MapName=\'%s\'", MapNameEsc);
            }
            case 4:
            {
                Format(iPlyrMapQuery, sizeof(iPlyrMapQuery), "INSERT INTO snt_playermaps VALUES (\'%s\', \'%s\', 4)", SteamId, MapNameEsc);
                Format(uMapQuery, sizeof(uMapQuery), "UPDATE snt_maps SET Rating4=Rating4+4 WHERE MapName=\'%s\'", MapNameEsc);
            }
            case 5:
            {
                Format(iPlyrMapQuery, sizeof(iPlyrMapQuery), "INSERT INTO snt_playermaps VALUES (\'%s\', \'%s\', 5)", SteamId, MapNameEsc);
                Format(uMapQuery, sizeof(uMapQuery), "UPDATE snt_maps SET Rating5=Rating5+5 WHERE MapName=\'%s\'", MapNameEsc);
            }
        }
        PrintToServer("[SNT] Query: %s", iPlyrMapQuery);
        PrintToServer("[SNT] Query: %s", uMapQuery);

        SQL_TQuery(gDB_sntdb, SQL_ErrorHandler, iPlyrMapQuery);
        SQL_TQuery(gDB_sntdb, SQL_ErrorHandler, uMapQuery);

        CPrintToChat(client, "{white}[{greenyellow}SNT{white}] You rated {greenyellow}%s {gold}%i {white}star(s)!", MapName, PlayerVote);
        PrintToServer("[SNT] Inserted player vote into table and updated maps table.");
    }
    PrintToServer("[SNT] %i maps found", RowCount);
    CloseHandle(data);
}

public Action ADM_BuildTables(int client, int args)
{
    SQL_FillMapTable(gDB_sntdb, client);
    return Plugin_Handled;
}

public Action ADM_SyncMapMenus(int client, int args)
{
    Menu_RegularMaps = null;
    Menu_WeedMaps = null;

    Menu_RegularMaps = new Menu(MapsRatingHandler, MENU_ACTIONS_DEFAULT);
    Menu_WeedMaps = new Menu(MapsRatingHandler, MENU_ACTIONS_DEFAULT);

    DataPack Reg_Pack;
    DataPack Weed_Pack;
    Reg_Pack = CreateDataPack();
    Weed_Pack = CreateDataPack();
    WritePackCell(Reg_Pack, Menu_RegularMaps);
    WritePackCell(Reg_Pack, client);
    WritePackCell(Weed_Pack, Menu_WeedMaps);
    WritePackCell(Weed_Pack, client);

    SQL_TQuery(gDB_sntdb, SQL_BuildMapMenu, "SELECT MapName FROM snt_maps WHERE EventId=\'evnt_none\'", Reg_Pack);
    SQL_TQuery(gDB_sntdb, SQL_BuildMapMenu, "SELECT MapName FROM snt_maps WHERE EventId=\'evnt_weed\'", Weed_Pack);

    return Plugin_Handled;
}

public Action USR_OpenRatingMenu(int client, int args)
{
    Menu MapReportMenu = new Menu(ReportMenuHandler, MENU_ACTIONS_DEFAULT);
    MapReportMenu.SetTitle("Map Rating Menu:")
    MapReportMenu.AddItem("RATEAMAP", "Rate a map!");
    MapReportMenu.AddItem("RATETHISMAP", "Rate this map!");
    MapReportMenu.AddItem("TOP10", "Top 10 Maps!");
    MapReportMenu.AddItem("BOT10", "Bottom 10 Maps!");
    MapReportMenu.AddItem("SEEMAPINFO", "See this map's rating!")
    MapReportMenu.AddItem("OTHERMAPINFO", "See other map's ratings!");
    MapReportMenu.Display(client, MENU_TIME_FOREVER);
    return Plugin_Handled;
}

public Action USR_RateMap(int client, int args)
{
    char SteamId[64];
    GetClientAuthId(client, AuthId_Steam3, SteamId, sizeof(SteamId));

    char CurrentMap[64];
    char CurrentMapEsc[129];
    GetCurrentMap(CurrentMap, sizeof(CurrentMap));
    SQL_EscapeString(gDB_sntdb, CurrentMap, CurrentMapEsc, sizeof(CurrentMapEsc));

    DataPack MapInfo_Pack;
    MapInfo_Pack = CreateDataPack();
    MapInfo_Pack.WriteString(CurrentMap);
    MapInfo_Pack.WriteCell(client);

    char vQuery[255];
    Format(vQuery, sizeof(vQuery), "SELECT LastVote FROM snt_playermaps WHERE SteamId=\'%s\' AND MapName=\'%s\'", SteamId, CurrentMapEsc);
    SQL_TQuery(gDB_sntdb, SQL_GetLastRatingForMenu, vQuery, MapInfo_Pack);

    return Plugin_Handled;
}