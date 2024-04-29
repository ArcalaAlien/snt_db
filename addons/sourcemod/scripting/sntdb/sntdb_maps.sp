#include <sourcemod>
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
    /*if (!LibraryExists("sntdb_core")) {
        ThrowError("[SNT] stdb/sntdb_core.smx does not exist!");
    }*/

    PrintToServer("[SNT] Running 'LoadConfigs' function.");
    if (LoadMapSQLConfigs(gDBConfigName, sizeof(gDBConfigName), gMapListPath, sizeof(gMapListPath)))
    {
        PrintToServer("[SNT] Configs Loaded!");
    }
    else
    {
        ThrowError("[SNT] Uh oh! Configs didn't load for some reason.");
    }

    char _sError[255];
    gDB_sntdb = SQL_Connect(gDBConfigName, false, _sError, sizeof(_sError));
    if (IsCharAlpha(_sError[0]))
    {
        PrintToServer("[SQL] ERROR: %s", _sError);
    }


    BuildRegularMaps();
    BuildWeedMaps();

    gMenu_RegularMaps = new Menu(MapsRatingHandler, MENU_ACTIONS_DEFAULT);
    gMenu_WeedMaps = new Menu(MapsRatingHandler, MENU_ACTIONS_DEFAULT);

    RegAdminCmd("snt_buildmaps",    ADM_BuildTables,    ADMFLAG_ROOT,       "/snt_buildmaps: Use this to read a mapcycle.txt file and send all the map names to the database.");
    RegConsoleCmd("sm_mapreports",  ALL_MapReportMenu,                      "/snt_mapreprots: Use this to open the report menu to gather map info from the database");
    RegConsoleCmd("sm_ratemap",     USR_OpenRatingMenu,                     "/snt_rate: Use this to open the rating menu! DO NOT USE IN SERVER CONSOLE.");
}

void BuildRegularMaps()
{
    char sQuery[255];
    Format(sQuery, sizeof(sQuery), "SELECT MapName FROM snt_maps WHERE EventId=\"evnt_none\"");

    DBResultSet sQueryResults = SQL_Query(gDB_sntdb, sQuery);
    while (SQL_FetchRow(sQueryResults))
    {
        char MapName[64];
        SQL_FetchString(sQueryResults, 1, MapName, sizeof(MapName));

        gMenu_RegularMaps.AddItem(MapName, MapName);
    }
    
    gMenu_RegularMaps.SetTitle("Rate Which Map?");
}

void BuildWeedMaps()
{
    char sQuery[255];
    Format(sQuery, sizeof(sQuery), "SELECT MapName from snt_maps WHERE EventId=\"evnt_weed\"");

    DBResultSet sQueryResults = SQL_Query(gDB_sntdb, sQuery);
    while (SQL_FetchRow(sQueryResults))
    {
        char MapName[64];
        SQL_FetchString(sQueryResults, 1, MapName, sizeof(MapName));

        gMenu_WeedMaps.AddItem(MapName, MapName);
    }

    gMenu_WeedMaps.SetTitle("Rate Which Map?");
}

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
    }
}

public int MapsRatingHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            Menu RankMenu = new Menu(RankingMenuHandler, MENU_ACTIONS_DEFAULT);
            
            char SteamId[64];
            GetClientAuthId(param1, AuthId_Steam3, SteamId, sizeof(SteamId));

            char vQuery[255];
            Format(vQuery, sizeof(vQuery), "SELECT * FROM snt_playermaps WHERE SteamId=\"%s\"", SteamId);

            char SelectedMap[64];
            menu.GetItem(0, SelectedMap, sizeof(SelectedMap));

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
            
            DBResultSet ValidationResults = SQL_Query(gDB_sntdb, vQuery);
            if (SQL_MoreRows(ValidationResults))
            {
                int LastRating = SQL_FetchInt(ValidationResults, 0);
                
                switch (LastRating)
                {
                    case 0:
                    {
                        RankMenu.AddItem("NO", "Last Rating | None", ITEMDRAW_RAWLINE)
                    }
                    default:
                    {
                        char MenuChoice[32];
                        Format(MenuChoice, sizeof(MenuChoice), "Last Rating | %i star(s)", LastRating);
                        RankMenu.AddItem("NO", MenuChoice, ITEMDRAW_RAWLINE);
                    }
                }
            }
            RankMenu.SetTitle("What do you want to rate %s?", SelectedMap);
            RankMenu.AddItem("NO", "", ITEMDRAW_SPACER);
            RankMenu.AddItem(Rate1, "1 Star");
            RankMenu.AddItem(Rate2, "2 Stars");
            RankMenu.AddItem(Rate3, "3 Stars");
            RankMenu.AddItem(Rate4, "4 Stars");
            RankMenu.AddItem(Rate5, "5 Stars");
            RankMenu.Display(param1, MENU_TIME_FOREVER);
        }
    }
}

public int RankingMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {

            char ClientSteamId[64];
            GetClientAuthId(param1, AuthId_Steam3, ClientSteamId, sizeof(ClientSteamId));

            char MenuChoice[64];
            menu.GetItem(0, RatingChoice, sizeof(RatingChoice));

            char ExplodedSelection[2][64];
            ExplodeString(MenuChoice, ",", ExplodedSelection, 2, 64);

            char RatingOption[12];
            strcopy(RatingOption, sizeof(RatingOption), ExplodedSelection[1]);

            char MapName[64];
            strcopy(MapName, sizeof(MapName), ExplodeSelection[0]);

            delete ExplodedSelection;

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
}

public int ReportMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char MenuChoice[32];
            menu.GetItem(0, MenuChoice, sizeof(MenuChoice));

            if (StrEqual(MenuChoice, "TOP10"))
            {
                Menu Top10Menu = new Menu(MapInfoHandler, MENU_ACTIONS_DEFAULT);

                /*
                SELECT MapName, CAST(((Rating1+Rating2+Rating3+Rating4+Rating5)/SUM(NumVotes)) AS decimal(2,2)) Stars, SUM(NumVotes) TotalVotes
                FROM (
                    SELECT m.MapName, p.SteamId, Rating1, Rating2, Rating3, Rating4, Rating5, COUNT(*) NumVotes
                        FROM snt_maps m
                            JOIN snt_playermaps pm
                                ON m.MapName = pm.MapName
                                    JOIN snt_players p
                                        ON p.SteamId = pm.SteamId
                    GROUP BY p.SteamId, m.MapName, Rating1, Rating2, Rating3, Rating4, Rating5
                    ORDER BY SteamId
                ) AS votes_for_map
                GROUP BY MapName
                ORDER BY Stars DESC
                LIMIT 10;
                */
                char sQuery[255];
                Format(sQuery, sizeof(sQuery), "SELECT MapName, CAST(((Rating1+Rating2+Rating3+Rating4+Rating5)/SUM(NumVotes)) AS decimal(2,2)) Stars, SUM(NumVotes) TotalVotes FROM (SELECT m.MapName, p.SteamId, Rating1, Rating2, Rating3, Rating4, Rating5, COUNT(*) NumVotes FROM snt_maps m JOIN snt_playermaps pm ON m.MapName = pm.MapName JOIN snt_players p ON p.SteamId = pm.SteamId GROUP BY p.SteamId, m.MapName, Rating1, Rating2, Rating3, Rating4, Rating5 ORDER BY m.MapName) AS votes_for_map GROUP BY MapName ORDER BY Stars DESC LIMIT 10;");

                DBResultSet ListTop10 = SQL_Query(gDB_sntdb, sQuery);
                while (SQL_MoreRows(ListTop10))
                {
                    char MapName[64];
                    float MapRating;
                    int TotalVotes;

                    SQL_FetchString(ListTop10, 0, MapName, sizeof(MapName));
                    MapRating = SQL_FetchFloat(ListTop10, 1);
                    TotalVotes = SQL_FetchInt(ListTop10, 2);

                    Top10Menu.SetTitle("Top 10 Maps!")
                    Top10Menu.AddItem(MapName, MapName);

                }

                Top10Menu.Display(param1, MENU_TIME_FOREVER);
            }
            else if (StrEqual(MenuChoice, "BOT10"))
            {
                Menu Bot10Menu = new Menu(MapInfoHandler, MENU_ACTIONS_DEFAULT);

                /*
                    SELECT MapName, CAST(((Rating1+Rating2+Rating3+Rating4+Rating5)/SUM(NumVotes)) AS decimal(2,2)) Stars, SUM(NumVotes) TotalVotes
                    FROM (
                        SELECT m.MapName, p.SteamId, Rating1, Rating2, Rating3, Rating4, Rating5, COUNT(*) NumVotes
                            FROM snt_maps m
                                JOIN snt_playermaps pm
                                    ON m.MapName = pm.MapName
                                        JOIN snt_players p
                                            ON p.SteamId = pm.SteamId
                        GROUP BY p.SteamId, m.MapName, Rating1, Rating2, Rating3, Rating4, Rating5
                        ORDER BY m.MapName
                    ) AS votes_for_map
                    GROUP BY MapName
                    ORDER BY Stars ASC
                    LIMIT 10;
                */
                char sQuery[255];
                Format(sQuery, sizeof(sQuery), "SELECT MapName, CAST(((Rating1+Rating2+Rating3+Rating4+Rating5)/SUM(NumVotes)) AS decimal(2,2)) Stars, SUM(NumVotes) TotalVotes FROM (SELECT m.MapName, p.SteamId, Rating1, Rating2, Rating3, Rating4, Rating5, COUNT(*) NumVotes FROM snt_maps m JOIN snt_playermaps pm ON m.MapName = pm.MapName JOIN snt_players p ON p.SteamId = pm.SteamId GROUP BY p.SteamId, m.MapName, Rating1, Rating2, Rating3, Rating4, Rating5 ORDER BY m.MapName) AS votes_for_map GROUP BY MapName ORDER BY Stars ASC LIMIT 10;");

                DBResultSet ListBot10 = SQL_Query(gDB_sntdb, sQuery);
                while (SQL_MoreRows(ListBot10))
                {
                    char MapName[64];
                    float MapRating;
                    int TotalVotes;

                    SQL_FetchString(ListBot10, 0, MapName, sizeof(MapName));
                    MapRating = SQL_FetchFloat(ListBot10, 1);
                    TotalVotes = SQL_FetchInt(ListBot10, 2);

                    Bot10Menu.SetTitle("Bottom 10 Maps!")
                    Bot10Menu.AddItem(MapName, MapName);

                }

                Bot10Menu.Display(param1, MENU_TIME_FOREVER);
            }
            else if (StrEqual(MenuChoice, "MAPINFO"))
            {
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
}

public int MapInfoCategoryHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char MenuChoice[32];
            menu.GetItem(0, MenuChoice, sizeof(MenuChoice));

            if (StrEqual(MenuChoice, "evnt_none"))
            {
                Menu InfoRegularMapList = new Menu(MapInfoHandler, MENU_TIME_FOREVER);
                InfoRegularMapList.SetTitle("Choose a map to view!");

                char sQuery[255];
                Format(sQuery, sizeof(sQuery), "SELECT MapName FROM snt_maps WHERE EventId='evnt_none'");

                DBResultSet RegMapList = SQL_Query(gDB_sntdb, sQuery);
                while (SQL_MoreRows(RegMapList))
                {
                    char MapName[64];
                    SQL_FetchString(RegMapList, 0, MapName, sizeof(MapName));

                    InfoRegularMapList.AddItem(MapName, MapName);
                }

                InfoRegularMapList.Display(param1, MENU_TIME_FOREVER);
            }
            else if (StrEqual(MenuChoice, "evnt_weed"))
            {
                Menu InfoWeedMapList = new Menu(MapInfoHandler, MENU_TIME_FOREVER);
                InfoWeedMapList.SetTitle("Choose a map to view!");

                char sQuery[255];
                Format(sQuery, sizeof(sQuery), "SELECT MapName FROM snt_maps WHERE EventId='evnt_none'");

                DBResultSet RegMapList = SQL_Query(gDB_sntdb, sQuery);
                while (SQL_MoreRows(RegMapList))
                {
                    char MapName[64];
                    SQL_FetchString(RegMapList, 0, MapName, sizeof(MapName));

                    InfoWeedMapList.AddItem(MapName, MapName);
                }

                InfoWeedMapList.Display(param1, MENU_TIME_FOREVER);
            }
        }
        case MenuAction_End:
            delete menu;
    }
}

public int MapInfoHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char MapChoice[64];
            menu.GetItem(0, MapChoice, sizeof(MapChoice));

            char SteamId[64];
            GetClientAuthId(param1, AuthId_Steam3, SteamId, sizeof(SteamId));

            char voteQuery[255];
            Format(voteQuery, sizeof(voteQuery), "SELECT LastVote FROM snt_playermaps WHERE SteamId='%s'", SteamId);

            int LastVote;
            DBResultSet UsrLastVote = SQL_Query(gDB_sntdb, voteQuery);
            if (SQL_FetchRow(UsrLastVote))
            {
                LastVote = SQL_FetchInt(UsrLastVote, 0);
            }
            else
            {
                LastVote = 0;
            }
            
            Menu MapInfoMenu = new Menu(ListMapInfo, MENU_ACTIONS_DEFAULT);
            MapInfoMenu.SetTitle("%s", MapChoice);
            /*
            SELECT MapName, CAST(((Rating1+Rating2+Rating3+Rating4+Rating5)/SUM(NumVotes)) AS decimal(2,2)) Stars, SUM(NumVotes) TotalVotes
            FROM (
                SELECT m.MapName, p.SteamId, Rating1, Rating2, Rating3, Rating4, Rating5, COUNT(*) NumVotes
                    FROM snt_maps m
                        JOIN snt_playermaps pm
                            ON m.MapName = pm.MapName
                                JOIN snt_players p
                                    ON p.SteamId = pm.SteamId
                GROUP BY p.SteamId, m.MapName, Rating1, Rating2, Rating3, Rating4, Rating5
                ORDER BY SteamId
            ) AS votes_for_map
            WHERE MapName='%s'
            GROUP BY MapName
            ORDER BY Stars DESC;
            */
            char sQuery[255];
            Format(sQuery, sizeof(sQuery), "SELECT MapName, CAST(((Rating1+Rating2+Rating3+Rating4+Rating5)/SUM(NumVotes)) AS decimal(2,2)) Stars, SUM(NumVotes) TotalVotes FROM (SELECT m.MapName, p.SteamId, Rating1, Rating2, Rating3, Rating4, Rating5, COUNT(*) NumVotes FROM snt_maps m JOIN snt_playermaps pm ON m.MapName = pm.MapName JOIN snt_players p ON p.SteamId = pm.SteamId GROUP BY p.SteamId, m.MapName, Rating1, Rating2, Rating3, Rating4, Rating5 ORDER BY m.MapName) AS votes_for_map WHERE MapName='%s' GROUP BY MapName ORDER BY Stars;", MapChoice);

            char MapName[32];
            float MapRating;
            int TotalVotes;

            DBResultSet MapInfoResults = SQL_Query(gDB_sntdb, sQuery);
            if (SQL_FetchRow(MapInfoResults))
            {
                SQL_FetchString(MapInfoResults, 0, MapName, sizeof(MapName));
                MapRating = SQL_FetchFloat(MapInfoResults, 1);
                TotalVotes = SQL_FetchInt(MapInfoResults, 2);

                switch(LastVote)
                {
                    case 0:
                        MapInfoMenu.AddItem("NONE", "You have not voted for this map yet.", ITEMDRAW_RAWLINE);
                    default:
                        MapInfoMenu.AddItem("NONE", "You last voted: %i star(s)", ITEMDRAW_RAWLINE);
                }
                
                char FMapName[64];
                char FMapRating[64];
                char FTotalVotes[64];

                Format(FMapName, sizeof(FMapName), "NAME: %s", MapName);
                Format(FMapRating, sizeof(FMapRating), "RATING: %f stars", MapRating);
                Format(FTotalVotes, sizeof(FTotalVotes), "TOTAL VOTES: %i", TotalVotes);

                MapInfoMenu.AddItem("", "", ITEMDRAW_SPACER);
                MapInfoMenu.AddItem("Name", FMapName, ITEMDRAW_RAWLINE);
                MapInfoMenu.AddItem("Rating", FMapRating, ITEMDRAW_RAWLINE);
                MapInfoMenu.AddItem("Votes", FTotalVotes, ITEMDRAW_RAWLINE);
            }
            else
            {
                char MenuChoice[64];
                Format(MenuChoice, sizeof(MenuChoice), "%s", MapName)

                MapInfoMenu.AddItem("NOVOTES", "There have been no votes for this map yet.", ITEMDRAW_RAWLINE);
                MapInfoMenu.AddItem("NOVOTES", "Do you want to rate this map?", ITEMDRAW_RAWLINE);
                MapInfoMenu.AddItem("", "", ITEMDRAW_SPACER);
                MapInfoMenu.AddItem(MenuChoice, "Yes");
                MapInfoMenu.AddItem("N", "No");
            }

            MapInfoMenu.Display(param1, MENU_TIME_FOREVER);
        }
        case MenuAction_End:
            delete menu;
    }
}

public int ListMapInfo (Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char MenuChoice[6];
            menu.GetItem(0, MenuChoice, sizeof(MenuChoice));

            if (StrEqual(MenuChoice, "Y"))
            {
                
            }

            delete menu;
        }
        case MenuAction_End:
            delete menu;
    }
}

public void SQL_BuildMapTable(int client)
{
    PrintToServer("[SNT] Opening maplist file.");

    File MapListFile = OpenFile(gMapListPath, "rt");
    if (MapListFile == null)
    {
        ThrowError("[SNT] ERROR! \"%s\": file does not exist!", gMapListPath);
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
            ReplyToCommand("[SQL] ERROR! %s", SQLError);
        }
        else
        {
            ReplyToCommand(client, "[SNT] %s was succesfully added to the database.", mapname);
        }
    }

    MapListFile.Close();
}

public bool SQL_SubmitRating(char SteamId, char MapName, char RatingColumn, int RatingValue)
{
    char vQuery[255];
    Format(vQuery, sizeof(vQuery), "SELECT SteamId FROM snt_playermaps WHERE SteamId='%s'", SteamId);

    DBResultSet ValidateQueryResults = SQL_Query(gDB_sntdb, vQuery);
    if (!SQL_MoreRows(ValidateQueryResults))
    {
        char iPlyrMapQuery[255];
        char uMapQuery[255];

        Format(iPlyrMapQuery, sizeof(iPlyrMapQuery), "INSERT INTO snt_playermaps VALUES (%s, %s, %i)", SteamId, MapName, RatingValue);
        Format(uMapQuery, sizeof(uMapQuery), "UPDATE snt_maps SET %s=%s+%i WHERE MapId='%s'", RatingColumn, RatingColumn, RatingValue, MapName);

        if (!SQL_FastQuery(gDB_sntdb, iPlyrMapQuery))
        {
            char error[255];
            SQL_GetError(gDB_sntdb, error, sizeof(error));
            PrintToServer("[SQL] ERROR! %s", error);
        }
        
        if (!SQL_FastQuery(gDB_sntdb, uMapQuery))
        {
            char error[255];
            SQL_GetError(gDB_sntdb, error, sizeof(error));
            PrintToServer("[SQL] ERROR! %s", error);
        }
    }

    char uPlyrMapQuery[255];
    char uMapQuery[255];

    Format(uPlyrMapQuery, sizeof(uPlyrMapQuery), "UPDATE snt_playermaps SET LastVote=%i WHERE SteamId='%s' AND MapId='%s'", RatingValue, SteamId, MapName);
    Format(uMapQuery, sizeof(uMapQuery), "UPDATE snt_maps SET %s=%s+%i WHERE MapId='%s'", RatingColumn, RatingColumn, RatingValue, MapName);

    if (!SQL_FastQuery(gDB_sntdb, uPlyrMapQuery))
    {
        char error[255];
        SQL_GetError(gDB_sntdb, error, sizeof(error));
        PrintToServer("[SQL] ERROR! %s", error);
    }

    if (!SQL_FastQuery(gDB_sntdb, uMapQuery))
    {
        char error[255];
        SQL_GetError(gDB_sntdb, error, sizeof(error));
        PrintToServer("[SQL] ERROR! %s", error);
    }
}

bool ValidateMap(char[] MapName)
{
    char sQuery[32];
    Format(sQuery, sizeof(sQuery), "SELECT MapName FROM snt_maps");

    DBResultSet QueryResults = SQL_Query(gDB_sntdb, sQuery);
    if (QueryResults == null)
    {
        return false;
    }
    else
    {
        while (SQL_FetchRow(QueryResults))
        {
            char qReturnedMap[64];
            SQL_FetchString(QueryResults, 1, qReturnedMap, sizeof(qReturnedMap));
            if (StrEqual(MapName, qReturnedMap))
            {
                return true;
            }
        }
        return false;
    }
}

bool ValidateEvent(char[] EventName)
{
    char sQuery[64];
    Format(sQuery, sizeof(sQuery), "SELECT EventId FROM snt_maps GROUP BY EventId");

    DBResultSet QueryResults = SQL_Query(gDB_sntdb, sQuery);
    if (QueryResults == null)
    {
        return false;
    }
    else
    {
        while (SQL_FetchRow(QueryResults))
        {
            char qReturnedEvent[255];
            SQL_FetchString(QueryResults, 1, qReturnedEvent, sizeof(qReturnedEvent));
            if (StrEqual(EventName, qReturnedEvent))
            {
                return true;
            }
        }
        return false;
    }
}

public Action ADM_BuildTables(int client, int args)
{
    SQL_BuildMapTable(client);
    return Plugin_Handled;
}

public Action ALL_MapReportMenu(int client, int args)
{
    Menu MapReportMenu = new Menu(ReportMenuHandler, MENU_ACTIONS_DEFAULT);
    MapReportMenu.SetTitle("Choose a report to view:")
    MapReportMenu.AddItem("TOP10", "Top 10 Maps");
    MapReportMenu.AddItem("BOT10", "Bottom 10 Maps");
    MapReportMenu.AddItem("MAPINFO", "Map Specific Info");
    MapReportMenu.Display(client, MENU_TIME_FOREVER);
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
    }
    else
    {
        ReplyToCommand(client, "[SNT] /ratemap: Opens the map rating menu.");
        return Plugin_Handled;
    }
}