#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <dbi>
#include <clientprefs>
#include <files>
#include <keyvalues>

#include <morecolors>
#include <stocksoup/entity_tools>
#include <sntdb/store>
#include <sntdb/trails>

#define REQUIRE_PLUGIN 
#include <sntdb/core>

public Plugin myinfo =
{
    name = "sntdb Sound Module",
    author = "Arcala the Gyiyg",
    description = "(required) SNTDB Sound Module.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

bool lateLoad;

Database DB_sntdb;
char DBConfName[64];
char Prefix[96];
char StoreSchema[64];
char CurrencyName[64];
char CurrencyColor[64];
int credits_given;
float over_mins;

Cookie ck_ShowingTrail;
Cookie ck_TrailId;
Cookie ck_TrailName;
Cookie ck_TrailVMT;
Cookie ck_TrailColor;
Cookie ck_TrailWidth;

PlayerTrail EqpdTrail[MAXPLAYERS + 1];
TrailInfo Trails[64];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("SNT_OpenTrailMenu", SendPage1_Native);
    CreateNative("SNT_OpenTrailEquip", SendEquipMenu_Native);
    RegPluginLibrary("sntdb_trails");

    lateLoad = late;
    return APLRes_Success;
}

public void OnPluginStart()
{
    SNT_LoadSQLStoreConfigs(DBConfName, 64, Prefix, 96, StoreSchema, 64, "Trails", CurrencyName, 64, CurrencyColor, 64, credits_given, over_mins);

    PrintToServer("[SNT] Connecting to Database");
    char error[255];
    DB_sntdb = SQL_Connect(DBConfName, true, error, sizeof(error));
    if (!StrEqual(error, ""))
    {
        ThrowError("[SNT] ERROR IN STORE PLUGIN START: %s", error);
    }

    HookEvent("post_inventory_application", OnPlayerSpawn);
    HookEvent("player_death", OnPlayerDeath);

    ck_ShowingTrail = RegClientCookie("trail_displaying", "Is a user showing their trail?", CookieAccess_Protected);
    ck_TrailId = RegClientCookie("trail_id", "The TrailID of a user.", CookieAccess_Protected);
    ck_TrailName = RegClientCookie("trail_name", "The name of the trail that a user has equipped.", CookieAccess_Protected);
    ck_TrailVMT = RegClientCookie("trail_vmt", "The vmt file the trail a user has equipped uses.", CookieAccess_Protected);
    ck_TrailColor = RegClientCookie("trail_color", "r,g,b,a RGBA values separated by columns, used to color a trail.", CookieAccess_Protected);
    ck_TrailWidth = RegClientCookie("trail_width", "The width in hammer units of a player's trail.", CookieAccess_Protected);

    RegAdminCmd("sm_refreshtrail", ADM_RefreshTrails, ADMFLAG_KICK, "Refresh all of the current trails in the server.");
    RegConsoleCmd("sm_trails", USR_OpenTrailMenu, "Use this to open the trail menu!");
    RegConsoleCmd("sm_trail", USR_OpenTrailMenu, "Use this to open the trail menu!");

    if (lateLoad)
    {
        OnMapStart();
        for (int i = 1; i < MaxClients; i++)
            if (SNT_IsValidClient(i))
            {
                OnClientPutInServer(i);
                if (IsPlayerAlive(i))
                    if (EqpdTrail[i].Showing)
                        if (EqpdTrail[i].EntityIndex != -1)
                            UpdateTrail(i);
                        else
                        {
                            CreateTrail(i);
                            CreateTimer(0.1, Timer_ShowSprite, i);
                        }
            }
    }

}

public void OnMapStart()
{
    char sQueryTrails[130];
    Format(sQueryTrails, 130, "SELECT ItemId, TrailName, TextureVMT, TextureVTF FROM %strails", StoreSchema);
    SQL_TQuery(DB_sntdb, SQL_CacheFiles, sQueryTrails);
}

public void OnClientPutInServer(int client)
{
    EqpdTrail[client].EntityIndex = -1;
    GetCookies(client);
}

public void OnClientDisconnect(int client)
{
    if (SNT_IsValidClient(client))
    {
        if (EqpdTrail[client].EntityIndex != -1 && IsValidEdict(EqpdTrail[client].EntityIndex))
            KillTrail(client);
        EqpdTrail[client].Reset();
    }
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int uid = GetEventInt(event, "userid");
    int client = GetClientOfUserId(uid);
    if (IsPlayerAlive(client))
    {
        if (EqpdTrail[client].Showing)
        {
            if (EqpdTrail[client].EntityIndex != -1)
                UpdateTrail(client);
            else
            {
                CreateTrail(client);
                CreateTimer(0.1, Timer_ShowSprite, client);
            }
        }
    }

}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    // Disable trail when player dies
    int uid = GetEventInt(event, "userid");
    int client = GetClientOfUserId(uid);
    if (EqpdTrail[client].TrailIndex != -1)
        KillTrail(client);
}

public void TF2_OnConditionAdded(int client, TFCond condition)
{
    if (condition == TFCond_Cloaked && EqpdTrail[client].TrailIndex != -1)
        KillTrail(client);
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
    if (condition == TFCond_Cloaked && EqpdTrail[client].TrailIndex == -1)
        CreateTrail(client);
}

void CreateTrail(int client)
{
    if (SNT_IsValidClient(client) && IsPlayerAlive(client))
    {
        float PlayerOrigin[3];
        GetClientAbsOrigin(client, PlayerOrigin);

        PlayerOrigin[2] = PlayerOrigin[2] + 8.0;

        char TrailVMT[256];
        EqpdTrail[client].GetVMT(TrailVMT, 256);

        int RGB[3];
        EqpdTrail[client].GetRGB(RGB)

        char RGBStr[16];
        Format(RGBStr, 16, "%i %i %i", RGB[0], RGB[1], RGB[2]);

        int Alpha = EqpdTrail[client].GetAlpha();

        int ent_trail = CreateEntityByName("env_spritetrail");
        if (!IsValidEdict(ent_trail))
        {
            EqpdTrail[client].EntityIndex = -1;
            PrintToServer("CreateTrail: Unable to create valid edict. %i", ent_trail);
            return;
        }
        else
        {
            DispatchKeyValueFloat(ent_trail, "lifetime", 2.0);
            DispatchKeyValueFloat(ent_trail, "startwidth", EqpdTrail[client].Width);
            DispatchKeyValueFloat(ent_trail, "endwidth", 0.0);
            DispatchKeyValue(ent_trail, "spritename",TrailVMT);
            DispatchKeyValue(ent_trail, "rendercolor", RGBStr);
            DispatchKeyValue(ent_trail, "framerate", "30");
            DispatchKeyValue(ent_trail, "animate", "true");
            DispatchKeyValueInt(ent_trail, "renderamt", Alpha);
            DispatchKeyValueInt(ent_trail, "rendermode", 5);
            DispatchKeyValue(ent_trail, "disablereceiveshadows", "true");

            char trail_name[32];
            Format(trail_name, 32, "snt_trail_%i", client);
            DispatchKeyValue(ent_trail, "targetname", trail_name);

            if (!DispatchSpawn(ent_trail))
            {
                PrintToServer("[SNT] Unable to spawn trail for some reason!");
            }
            else
            {
                EqpdTrail[client].EntityIndex = ent_trail;

                TeleportEntity(ent_trail, PlayerOrigin, NULL_VECTOR);

                SetVariantString("!activator");
                if (ent_trail != -1)
                    AcceptEntityInput(ent_trail, "SetParent", client);

                SetEntPropFloat(ent_trail, Prop_Send, "m_flTextureRes", 0.05);
            }
        }
    }
}

void UpdateTrail(int client)
{
    if (EqpdTrail[client].EntityIndex != -1)
    {
        KillTrail(client);
        CreateTimer(0.1, Timer_CreateTrail, client);
    }
}

public Action Timer_CreateTrail(Handle timer, any client)
{
    CreateTrail(client);
    return Plugin_Continue;
}

public Action Timer_ShowSprite(Handle timer, any client)
{
    if (EqpdTrail[client].EntityIndex != -1)
        if (IsValidEdict(EqpdTrail[client].EntityIndex))
            AcceptEntityInput(EqpdTrail[client].EntityIndex, "ShowSprite");

    return Plugin_Continue;
}

void KillTrail(int client)
{
    if (EqpdTrail[client].EntityIndex != -1)
    {
        if (IsValidEdict(EqpdTrail[client].EntityIndex))
        {
            char classname[64];
            GetEdictClassname(EqpdTrail[client].EntityIndex, classname, sizeof(classname));

            if (StrEqual(classname, "env_spritetrail"))
            {
                if (AcceptEntityInput(EqpdTrail[client].EntityIndex, "Kill"))
                {
                    EqpdTrail[client].EntityIndex = -1;
                }
                else
                    PrintToServer("KillTrail: Unable to kill trail");
            }
        }
        else
            PrintToServer("KillTrail: Not a valid trail index");
    }
}

void GetCookies(int client)
{
    if (AreClientCookiesCached(client))
    {
        char ShowingTrail[8];
        char TrailId[64];
        char TrailName[64];
        char TrailVMT[256];
        char TrailColor[48];
        char TrailWidth[6];

        GetClientCookie(client, ck_ShowingTrail, ShowingTrail, 8);
        GetClientCookie(client, ck_TrailId, TrailId, 64);
        GetClientCookie(client, ck_TrailName, TrailName, 64);
        GetClientCookie(client, ck_TrailVMT, TrailVMT, 256);
        GetClientCookie(client, ck_TrailColor, TrailColor, 48);
        GetClientCookie(client, ck_TrailWidth, TrailWidth, 6);

        if (ShowingTrail[0] == '\0')
        {
            EqpdTrail[client].Showing = false;
            SetClientCookie(client, ck_ShowingTrail, "false");
        }
        else
        {
            if (StrEqual(ShowingTrail, "true"))
                EqpdTrail[client].Showing = true;
            else
                EqpdTrail[client].Showing = false;
        }

        if (TrailId[0] == '\0')
        {
            EqpdTrail[client].SetId("NONE");
            SetClientCookie(client, ck_TrailId, "NONE");
        }
        else
            EqpdTrail[client].SetId(TrailId);

        if (TrailName[0] == '\0')
        {
            EqpdTrail[client].SetName("NONE");
            SetClientCookie(client, ck_TrailName, "NONE");
        }
        else
            EqpdTrail[client].SetName(TrailName);

        if (TrailVMT[0] == '\0')
        {
            EqpdTrail[client].SetVMT("");
            SetClientCookie(client, ck_TrailVMT, "");
        }
        else
            EqpdTrail[client].SetVMT(TrailVMT);

        if (TrailColor[0] == '\0' || StrEqual(TrailColor, "0,0,0,0"))
        {
            EqpdTrail[client].StrToColor4("255,255,255,150");
            SetClientCookie(client, ck_TrailColor, "255,255,255,150");
        }
        else
        {
            EqpdTrail[client].StrToColor4(TrailColor);
        }
        
        if (TrailWidth[0] == '\0')
        {
            EqpdTrail[client].Width = 12.0;
            SetClientCookie(client, ck_TrailWidth, "12.0");
        }
        else
            EqpdTrail[client].Width = StringToFloat(TrailWidth); 
    }
}

void SetCookies(int client, int slot, char[] value)
{
    switch (slot)
    {
        case 0:
        {
            SetClientCookie(client, ck_ShowingTrail, value);
        }
        case 2:
        {
            SetClientCookie(client, ck_TrailId, value);
        }
        case 3:
        {
            SetClientCookie(client, ck_TrailName, value);
        }
        case 4:
        {
            SetClientCookie(client, ck_TrailVMT, value);
        }
        case 5:
        {
            SetClientCookie(client, ck_TrailColor, value);
        }
        case 6:
        {
            SetClientCookie(client, ck_TrailWidth, value);
        }
    }
}

void SendPage1(int client)
{
    Panel Page1Panel = CreatePanel();
    Page1Panel.SetTitle("Trail Menu");

    char TrailName[96];
    EqpdTrail[client].GetName(TrailName, 96);
    Format(TrailName, 96, "Equipped: %s", TrailName);

    char targetname[32];
    Format(targetname, sizeof(targetname), "snt_trail_%i", client);
    EqpdTrail[client].TrailIndex = FindEntityByTargetName(-1, targetname, "env_spritetrail");

    Page1Panel.DrawItem("Equip a trail!");
    Page1Panel.DrawText(" ");
    Page1Panel.DrawItem("Trail Settings");
    Page1Panel.DrawItem("Plugin Settings");
    Page1Panel.DrawText(" ");
    Page1Panel.DrawItem("Yer Treasure");
    Page1Panel.DrawItem("The Tavern");
    Page1Panel.DrawItem("Exit");
    Page1Panel.Send(client, MainPage1_Handler, 0);
}

void SendPage1_Native(Handle plugin, int params)
{
    int client = GetNativeCell(1);

    Panel Page1Panel = CreatePanel();
    Page1Panel.SetTitle("Trail Menu");

    char TrailName[96];
    EqpdTrail[GetNativeCell(1)].GetName(TrailName, 96);
    Format(TrailName, 96, "Equipped: %s", TrailName);

    char targetname[32];
    Format(targetname, sizeof(targetname), "snt_trail_%i", client);
    EqpdTrail[client].TrailIndex = FindEntityByTargetName(-1, targetname, "env_spritetrail");

    Page1Panel.DrawItem("Equip a trail!");
    Page1Panel.DrawText(" ");
    Page1Panel.DrawItem("Trail Settings");
    Page1Panel.DrawItem("Plugin Settings");
    Page1Panel.DrawText(" ");
    Page1Panel.DrawItem("Yer Treasure");
    Page1Panel.DrawItem("The Tavern");
    Page1Panel.DrawItem("Exit");
    Page1Panel.Send(client, MainPage1_Handler, 0);
}

void SendEquipMenu_Native(Handle plugin, int params)
{
    char SteamId[64];
    GetClientAuthId(GetNativeCell(1), AuthId_Steam3, SteamId, 64);

    char sQuery[512];
    Format(sQuery, 512, "SELECT ItemId, TrailName FROM %sInventories WHERE SteamId=\'%s\' ORDER BY TrailName ASC", StoreSchema, SteamId);
    SQL_TQuery(DB_sntdb, SQL_FillEquipMenu, sQuery, GetNativeCell(1));
}

void BuildPluginSettings(int client)
{
    Panel SettingPanel = CreatePanel();
    SettingPanel.SetTitle("Plugin Settings");
    SettingPanel.DrawText(" ");
    (EqpdTrail[client].Showing) ? SettingPanel.DrawText("Current Status: Showing") : SettingPanel.DrawText("Current Status: Hiding");
    SettingPanel.DrawItem("Toggle Your Trail");
    SettingPanel.DrawText(" ");
    SettingPanel.DrawItem("Main Menu");
    SettingPanel.DrawItem("Exit");
    SettingPanel.Send(client, PluginSettingsPage_Handler, 0);
}

void BuildTrailSettings(int client)
{
    Panel TrailSettings = CreatePanel();
    TrailSettings.SetTitle("Trail Settings");
    
    char CurrColor[64];
    EqpdTrail[client].ColorToStr(CurrColor, 64);
    char RGBA[4][4]
    ExplodeString(CurrColor, ",", RGBA, 4, 4);

    Format(CurrColor, 64, "R: %s G: %s\nB: %s A: %s", RGBA[0], RGBA[1], RGBA[2], RGBA[3]);
    TrailSettings.DrawText(CurrColor);
    TrailSettings.DrawItem("Change the color / alpha of your trail!"); // Item 1
    TrailSettings.DrawText(" ");
    
    char CurrWidth[24];
    Format(CurrWidth, 24, "Current Width: %i", RoundFloat(EqpdTrail[client].Width));
    TrailSettings.DrawText(CurrWidth);
    TrailSettings.DrawItem("Change your trail width!");
    TrailSettings.DrawText(" ");
    (EqpdTrail[client].Showing) ? TrailSettings.DrawText("Currently: Displaying Trail") : TrailSettings.DrawText("Currently: Hiding Trail");
    TrailSettings.DrawItem("Toggle Trail");
    TrailSettings.DrawText(" ");
    TrailSettings.DrawItem("Main Menu");
    TrailSettings.DrawItem("Exit");
    TrailSettings.Send(client, TrailSettingsPage_Handler, 0);
}

void SendTrailColors_Page1(int client)
{
    Panel ColorPage1 = CreatePanel();
    ColorPage1.SetTitle("Choose a color!");
    ColorPage1.DrawText(" ");
    ColorPage1.DrawText("You can also use /trail color to manually\nset the color of your trail. Just enter 4 numbers\nseparated by commas. (10,20,30,40)\n");
    ColorPage1.DrawText(" ");
    ColorPage1.DrawItem("Alpha");
    ColorPage1.DrawItem("Red");
    ColorPage1.DrawItem("Orange");
    ColorPage1.DrawItem("Yellow");
    ColorPage1.DrawText(" ");
    ColorPage1.DrawItem("Next");
    ColorPage1.DrawItem("Main Menu");
    ColorPage1.DrawItem("Exit");
    ColorPage1.Send(client, TCPage1_Handler, 0);
}

void SendTrailColors_Page2(int client)
{
    Panel ColorPage2 = CreatePanel();
    ColorPage2.SetTitle("Choose a color!");
    ColorPage2.DrawItem("Yellow Green");
    ColorPage2.DrawItem("Green");
    ColorPage2.DrawItem("Green Blue");
    ColorPage2.DrawItem("Cyan");
    ColorPage2.DrawItem("Blue Green");
    ColorPage2.DrawText(" ");
    ColorPage2.DrawItem("Back");
    ColorPage2.DrawItem("Next");
    ColorPage2.DrawItem("Main Menu");
    ColorPage2.DrawItem("Exit");
    ColorPage2.Send(client, TCPage2_Handler, 0);
}

void SendTrailColors_Page3(int client)
{
    Panel ColorPage3 = CreatePanel();
    ColorPage3.SetTitle("Choose a color!");
    ColorPage3.DrawItem("Blue");
    ColorPage3.DrawItem("Purple");
    ColorPage3.DrawItem("Pink");
    ColorPage3.DrawItem("Magenta");
    ColorPage3.DrawItem("Grey");
    ColorPage3.DrawItem("White");
    ColorPage3.DrawText(" ");
    ColorPage3.DrawItem("Back");
    ColorPage3.DrawItem("Main Menu");
    ColorPage3.DrawItem("Exit");
    ColorPage3.Send(client, TCPage3_Handler, 0);
}

void SendTrailAlphaMenu(int client)
{
    Menu AlphaMenu = new Menu(AlphaMenu_Handler, MENU_ACTIONS_DEFAULT);
    AlphaMenu.ExitBackButton = true;
    AlphaMenu.SetTitle("Choose an alpha level!");
    AlphaMenu.AddItem("10", "10%");
    AlphaMenu.AddItem("20", "20%");
    AlphaMenu.AddItem("30", "30%");
    AlphaMenu.AddItem("40", "40%");
    AlphaMenu.AddItem("50", "50%");
    AlphaMenu.AddItem("60", "60%");
    AlphaMenu.AddItem("70", "70%");
    AlphaMenu.AddItem("80", "80%");
    AlphaMenu.AddItem("90", "90%");
    AlphaMenu.AddItem("100", "100%");
    AlphaMenu.Display(client, 0);
}

void SendWidthMenu(int client)
{
    Menu WidthMenu = new Menu(WidthMenu_Handler, MENU_ACTIONS_DEFAULT);
    WidthMenu.ExitBackButton = true;
    WidthMenu.SetTitle("Choose a size!");
    WidthMenu.AddItem("2.0", "2hu");
    WidthMenu.AddItem("4.0", "4hu");
    WidthMenu.AddItem("6.0", "6hu");
    WidthMenu.AddItem("8.0", "8hu");
    WidthMenu.AddItem("10.0", "10hu");
    WidthMenu.AddItem("12.0", "12hu");
    WidthMenu.AddItem("14.0", "14hu");
    WidthMenu.AddItem("16.0", "16hu");
    WidthMenu.AddItem("18.0", "18hu");
    WidthMenu.AddItem("20.0", "20hu");
    WidthMenu.AddItem("22.0", "22hu");
    WidthMenu.Display(client, 0);
}

public int WidthMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char option[6];
            GetMenuItem(menu, param2, option, 6);

            float temp_width = StringToFloat(option);

            EqpdTrail[param1].Width = temp_width;
            UpdateTrail(param1);

            char WidthStr[6];
            Format(WidthStr, 6, "%.1f", temp_width);
            SetCookies(param1, 6, WidthStr);
            CPrintToChat(param1, "%s Sucessfully changed your trail's width to {greenyellow}%i hu{default}!", Prefix, RoundFloat(temp_width));
            SendWidthMenu(param1);
        }
        case MenuAction_Cancel:
            BuildTrailSettings(param1);
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int AlphaMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char option[4];
            GetMenuItem(menu, param2, option, 4);

            float percent = (StringToFloat(option)/100);
            int alpha = RoundFloat(255 * percent);
            EqpdTrail[param1].SetAlpha(alpha);

            char Color[24];
            EqpdTrail[param1].ColorToStr(Color, 24);
            SetCookies(param1, 5, Color);
            CPrintToChat(param1, "%s Sucessfully set your alpha to {greenyellow}%s percent{default}!", Prefix, option);
            UpdateTrail(param1);
            SendTrailAlphaMenu(param1);
        }
        case MenuAction_Cancel:
            BuildTrailSettings(param1);
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int TCPage1_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            switch (param2)
            {
                case 1:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    SendTrailAlphaMenu(param1);
                }
                case 2:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    EqpdTrail[param1].SetRGB(RED);
                    CPrintToChat(param1, "%s Sucessfully set your trail color to {greenyellow}Red!", Prefix);

                    char Color[24];
                    EqpdTrail[param1].ColorToStr(Color, 24);
                    
                    SetCookies(param1, 5, Color);
                    SendTrailColors_Page1(param1);
                    UpdateTrail(param1);
                }
                case 3:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    EqpdTrail[param1].SetRGB(ORANGE);
                    CPrintToChat(param1, "%s Sucessfully set your trail color to {greenyellow}Orange!", Prefix);

                    char Color[24];
                    EqpdTrail[param1].ColorToStr(Color, 24);
                    
                    SetCookies(param1, 5, Color);
                    SendTrailColors_Page1(param1);
                    UpdateTrail(param1);
                }
                case 4:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    EqpdTrail[param1].SetRGB(YELLOW);
                    CPrintToChat(param1, "%s Sucessfully set your trail color to {greenyellow}Yellow!", Prefix);

                    char Color[24];
                    EqpdTrail[param1].ColorToStr(Color, 24);
                    
                    SetCookies(param1, 5, Color);
                    SendTrailColors_Page1(param1);
                    UpdateTrail(param1);
                }
                case 5:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    SendTrailColors_Page2(param1);
                }
                case 6:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    SendPage1(param1);
                }
                case 7:
                {
                    EmitSoundToClient(param1, "buttons/combine_button7.wav");
                    delete menu;
                }
            }
            UpdateTrail(param1);
        }
    }
    return 0;
}

public int TCPage2_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            switch (param2)
            {
                case 1:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    EqpdTrail[param1].SetRGB(YELLOWGREEN);
                    CPrintToChat(param1, "%s Sucessfully set your trail color to {greenyellow}Yellow Green!", Prefix);

                    char Color[24];
                    EqpdTrail[param1].ColorToStr(Color, 24);
                    
                    SetCookies(param1, 5, Color);
                    UpdateTrail(param1);
                    SendTrailColors_Page2(param1);
                }
                case 2:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    EqpdTrail[param1].SetRGB(GREEN);
                    CPrintToChat(param1, "%s Sucessfully set your trail color to {greenyellow}Green!", Prefix);

                    char Color[24];
                    EqpdTrail[param1].ColorToStr(Color, 24);
                    
                    SetCookies(param1, 5, Color);
                    UpdateTrail(param1);
                    SendTrailColors_Page2(param1);
                }
                case 3:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    EqpdTrail[param1].SetRGB(GREENBLUE);
                    CPrintToChat(param1, "%s Sucessfully set your trail color to {greenyellow}Green Blue!", Prefix);

                    char Color[24];
                    EqpdTrail[param1].ColorToStr(Color, 24);
                    
                    SetCookies(param1, 5, Color);
                    UpdateTrail(param1);
                    SendTrailColors_Page2(param1);
                }
                case 4:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    EqpdTrail[param1].SetRGB(CYAN);
                    CPrintToChat(param1, "%s Sucessfully set your trail color to {greenyellow}Cyan!", Prefix);

                    char Color[24];
                    EqpdTrail[param1].ColorToStr(Color, 24);
                    
                    SetCookies(param1, 5, Color);
                    UpdateTrail(param1);
                    SendTrailColors_Page2(param1);
                }
                case 5:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    EqpdTrail[param1].SetRGB(BLUEGREEN);
                    CPrintToChat(param1, "%s Sucessfully set your trail color to {greenyellow}Blue Green!", Prefix);

                    char Color[24];
                    EqpdTrail[param1].ColorToStr(Color, 24);
                    
                    SetCookies(param1, 5, Color);
                    UpdateTrail(param1);
                    SendTrailColors_Page2(param1);
                }
                case 6:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    SendTrailColors_Page1(param1);
                }
                case 7:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    SendTrailColors_Page3(param1);
                }
                case 8:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    SendPage1(param1);
                }
                case 9:
                {
                    EmitSoundToClient(param1, "buttons/combine_button7.wav");
                    delete menu;
                }
            }
            UpdateTrail(param1);
        }
    }
    return 0;
}

public int TCPage3_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            switch (param2)
            {
                case 1:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    EqpdTrail[param1].SetRGB(BLUE);
                    CPrintToChat(param1, "%s Sucessfully set your trail color to {greenyellow}Blue!", Prefix);

                    char Color[24];
                    EqpdTrail[param1].ColorToStr(Color, 24);
                    
                    SetCookies(param1, 5, Color);
                    UpdateTrail(param1);
                    SendTrailColors_Page3(param1);
                }
                case 2:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    EqpdTrail[param1].SetRGB(PURPLE);
                    CPrintToChat(param1, "%s Sucessfully set your trail color to {greenyellow}Purple!", Prefix);

                    char Color[24];
                    EqpdTrail[param1].ColorToStr(Color, 24);
                    
                    SetCookies(param1, 5, Color);
                    UpdateTrail(param1);
                    SendTrailColors_Page3(param1);
                }
                case 3:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    EqpdTrail[param1].SetRGB(PINK);
                    CPrintToChat(param1, "%s Sucessfully set your trail color to {greenyellow}Pink!", Prefix);

                    char Color[24];
                    EqpdTrail[param1].ColorToStr(Color, 24);
                    
                    SetCookies(param1, 5, Color);
                    UpdateTrail(param1);
                    SendTrailColors_Page3(param1);
                }
                case 4:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    EqpdTrail[param1].SetRGB(MAGENTA);
                    CPrintToChat(param1, "%s Sucessfully set your trail color to {greenyellow}Magenta!", Prefix);

                    char Color[24];
                    EqpdTrail[param1].ColorToStr(Color, 24);
                    
                    SetCookies(param1, 5, Color);
                    UpdateTrail(param1);
                    SendTrailColors_Page3(param1);
                }
                case 5:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    EqpdTrail[param1].SetRGB(GREY);
                    CPrintToChat(param1, "%s Sucessfully set your trail color to {greenyellow}Grey!", Prefix);

                    char Color[24];
                    EqpdTrail[param1].ColorToStr(Color, 24);
                    SetCookies(param1, 5, Color);
                    UpdateTrail(param1);
                    SendTrailColors_Page3(param1);
                }
                case 6:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    EqpdTrail[param1].SetRGB(WHITE);
                    CPrintToChat(param1, "%s Sucessfully set your trail color to {greenyellow}White!", Prefix);

                    char Color[24];
                    EqpdTrail[param1].ColorToStr(Color, 24);
                    SetCookies(param1, 5, Color);
                    UpdateTrail(param1);
                    SendTrailColors_Page3(param1);
                }
                case 7:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    SendTrailColors_Page2(param1);
                }
                case 8:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    SendPage1(param1);
                }
                case 9:
                {
                    EmitSoundToClient(param1, "buttons/combine_button7.wav");
                    delete menu;
                }
            }
            UpdateTrail(param1);
        }
    }
    return 0;
}

public int MainPage1_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            switch (param2)
            {
            case 1:
                {
                    char SteamId[64];
                    GetClientAuthId(param1, AuthId_Steam3, SteamId, 64);

                    EmitSoundToClient(param1, "buttons/button14.wav");
                    char sQuery[512];
                    Format(sQuery, 512, "SELECT ItemId, TrailName FROM %sInventories WHERE SteamId=\'%s\' ORDER BY TrailName ASC", StoreSchema, SteamId);
                    SQL_TQuery(DB_sntdb, SQL_FillEquipMenu, sQuery, param1);
                }
                case 2:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    BuildTrailSettings(param1);
                }
                case 3:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    BuildPluginSettings(param1);
                }
                case 4:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    SNT_OpenInventoryMenu(param1);
                }
                case 5:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    SNT_OpenStoreMenu(param1);
                }
                case 6:
                {
                    EmitSoundToClient(param1, "buttons/combine_button7.wav");
                    delete menu;
                }
            }
        }
    }
    return 0;
}

public int TrailSettingsPage_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            switch (param2)
            {
                case 1:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    SendTrailColors_Page1(param1);
                }
                case 2:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    SendWidthMenu(param1);
                }
                case 3:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    (EqpdTrail[param1].Showing) ? KillTrail(param1) : CreateTrail(param1);
                    (EqpdTrail[param1].Showing) ? SetCookies(param1, 0, "false") : SetCookies(param1, 0, "true");
                    BuildPluginSettings(param1);
                }
                case 4:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    SendPage1(param1);
                }
                case 5:
                {
                    EmitSoundToClient(param1, "buttons/combine_button7.wav");
                    delete menu;
                }
            }
        }
    }
    return 0;
}

public int PluginSettingsPage_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            switch (param2)
            {
                case 1:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    EqpdTrail[param1].Showing = !EqpdTrail[param1].Showing;
                    BuildPluginSettings(param1);

                    (EqpdTrail[param1].Showing) ? SetCookies(param1, 0, "true") : SetCookies(param1, 0, "false");
                    if (EqpdTrail[param1].EntityIndex != -1)
                        (EqpdTrail[param1].Showing) ? AcceptEntityInput(EqpdTrail[param1].EntityIndex, "ShowSprite") : AcceptEntityInput(EqpdTrail[param1].EntityIndex, "HideSprite");
                }
                case 2:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    SendPage1(param1);
                }
                case 3:
                {
                    EmitSoundToClient(param1, "buttons/combine_button7.wav");
                    delete menu;
                }
            }
        }
    }
    return 0;
}

public int EquipMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char Option[64];
            GetMenuItem(menu, param2, Option, 64);

            char Previous[64];
            EqpdTrail[param1].GetId(Previous, 64);

            if (StrEqual(Option, Previous))
            {
                char clientName[128];
                GetClientName(param1, clientName, 128);

                char TrailName[64];
                EqpdTrail[param1].GetName(TrailName, 64);
                EqpdTrail[param1].SetId("NONE");
                EqpdTrail[param1].SetName("NONE");

                if (EqpdTrail[param1].EntityIndex != -1)
                {
                    KillTrail(param1);
                    EqpdTrail[param1].Showing = false;
                    CPrintToChat(param1, "%s Sucessfully unequipped {greenyellow}%s {default}from your trail slot!", Prefix, TrailName);
                }
            }
            else
            {
                for (int i = 0; i < sizeof(Trails); i++)
                {
                    char TrailId[64];
                    char TrailName[64];
                    char TrailVMT[256];
                    Trails[i].GetId(TrailId, 64);
                    Trails[i].GetName(TrailName, 64);
                    Trails[i].GetVMT(TrailVMT, 256);

                    if (StrEqual(Option, TrailId))
                    {
                        EqpdTrail[param1].SetId(TrailId);
                        EqpdTrail[param1].SetName(TrailName);
                        EqpdTrail[param1].SetVMT(TrailVMT);
                        CPrintToChat(param1, "%s Sucessfully equipped {greenyellow}%s {default}as your trail!", Prefix, TrailName);
                        
                        SetCookies(param1, 2, TrailId);
                        SetCookies(param1, 3, TrailName);
                        SetCookies(param1, 4, TrailVMT);
                        EqpdTrail[param1].Showing = true;

                        if (EqpdTrail[param1].EntityIndex != -1)
                            UpdateTrail(param1);
                        else
                            CreateTrail(param1);
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

public void SQL_CacheFiles(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        ThrowError("[SNT] DATABASE IS NULL!");
    }

    if (!StrEqual(error, ""))
    {
        ThrowError("[SNT] ERROR IN SHOWING ITEM INFO: %s", error);
    }
    
    int row;
    while (SQL_FetchRow(results))
    {
        char ItemId[64];
        char TrailName[64];
        SQL_FetchString(results, 0, ItemId, 64);
        SQL_FetchString(results, 1, TrailName, 64);
        if (StrContains(ItemId, "trl_") != -1)
        {
            char TrailVMT[PLATFORM_MAX_PATH];
            char TrailVTF[PLATFORM_MAX_PATH];

            SQL_FetchString(results, 2, TrailVMT, PLATFORM_MAX_PATH);
            SQL_FetchString(results, 3, TrailVTF, PLATFORM_MAX_PATH);
            
            Trails[row].TrailIndex = (PrecacheModel(TrailVMT, true));
            Trails[row].SetId(ItemId);
            Trails[row].SetName(TrailName);
            Trails[row].SetVMT(TrailVMT);

            AddFileToDownloadsTable(TrailVMT);
            AddFileToDownloadsTable(TrailVTF);
            row++;
        }
    }
}

public void SQL_FillEquipMenu(Database db, DBResultSet results, const char[] error, any data)
{
    int client = data;

    Menu EquipMenu = new Menu(EquipMenu_Handler, MENU_ACTIONS_DEFAULT);
    EquipMenu.SetTitle("Select a trail!");
    
    while (SQL_FetchRow(results))
    {
        char SQL_ItemId[64];
        char SQL_ItemName[64];

        SQL_FetchString(results, 0, SQL_ItemId, 64);
        SQL_FetchString(results, 1, SQL_ItemName, 64);

        if (StrContains(SQL_ItemId, "trl_") != -1)
            EquipMenu.AddItem(SQL_ItemId, SQL_ItemName);
    }

    EquipMenu.Display(client, 0);
}

public Action USR_OpenTrailMenu(int client, int args)
{
    if (client == 0)
    {
        return Plugin_Handled;
    }

    if (!IsPlayerAlive(client) || TF2_GetClientTeam(client) == TFTeam_Spectator)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred}Dead men equip no trails!", Prefix);
        return Plugin_Handled;
    }

    if (args < 1)
    {
        SendPage1(client);
        return Plugin_Handled;
    }
    else
    {
        char Arg1[12];
        GetCmdArg(1, Arg1, 12);
        if (StrEqual(Arg1, "color"))
        {
            char Arg2[18];
            GetCmdArg(2, Arg2, 18);

            EqpdTrail[client].StrToColor4(Arg2);
            UpdateTrail(client);
            SetClientCookie(client, ck_TrailColor, Arg2);
        }
        else
        {
            EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
            CReplyToCommand(client, "{fullred} If ye want to change yer trail's color, do '/trail color r,g,b,a' or use '/trail' to visit the trail menu!");
        }
    }
    return Plugin_Handled;
}

public Action ADM_RefreshTrails(int client, int args)
{
    if (args > 0)
        return Plugin_Handled;
    
    for (int i = 1; i < MaxClients; i++)
    {

        char entName[32];
        Format(entName, sizeof(entName), "snt_trail_%i", i);

        int trailEnt = FindEntityByTargetName(-1, "snt_trail_%i", "env_spritetrail");

        if (trailEnt != - 1)
            AcceptEntityInput(trailEnt, "Kill");

        if (EqpdTrail[i].Showing)
            CreateTrail(i);
    }

    return Plugin_Handled;
}