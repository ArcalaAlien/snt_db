#include <sourcemod>
#include <sdktools>
#include <dbi>
#include <clientprefs>
#include <files>
#include <keyvalues>

#include <morecolors>
#include <sntdb_store>

#define REQUIRE_PLUGIN 
#include <sntdb_core>

// 12 Modes
#define RED {255, 0, 0}
#define ORANGE {255, 180, 0}
#define YELLOW {255, 255, 0}
#define YELLOWGREEN {180, 255, 0}
#define GREEN {0, 255, 0}
#define GREENBLUE {0, 255, 180}
#define CYAN {0, 255, 255}
#define BLUEGREEN {0, 180, 255}
#define BLUE {0, 0, 255}
#define PURPLE {180, 0, 255}
#define PINK {255, 0, 255}
#define MAGENTA {255, 0, 180}
#define WHITE {255, 255, 255}
#define GREY {180, 180, 180}

public Plugin myinfo =
{
    name = "sntdb Sound Module",
    author = "Arcala the Gyiyg",
    description = "(required) SNTDB Sound Module.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

enum struct TrailInfo
{
    int TrailIndex;
    char TrailId[64];
    char TrailName[64];
    char TrailVMT[256];

    void SetId(char[] new_id)
    {
        strcopy(this.TrailId, 64, new_id);
    }

    void SetName(char[] new_name)
    {
        strcopy(this.TrailName, 64, new_name);
    }

    void SetVMT(char[] vmt)
    {
        strcopy(this.TrailVMT, 256, vmt);
    }

    void GetId(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TrailId);
    }

    void GetName(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TrailName);
    }

    void GetVMT(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TrailVMT);
    }
}

enum struct PlayerTrail
{
    bool Showing;
    int EntityIndex;
    char TrailId[64];
    char TrailName[64];
    char TrailVMT[256];
    int TrailIndex;
    int Color[4];
    int Frame;
    float LastPos[3];
    float Width;

    void SetId(char[] trail_id)
    {
        strcopy(this.TrailId, 64, trail_id);
    }

    void SetName(char[] trail_name)
    {
        strcopy(this.TrailName, 64, trail_name);
    }

    void SetVMT(char[] vmt)
    {
        strcopy(this.TrailVMT, 256, vmt);
    }

    void SetRGB(int new_color[3])
    {
        this.Color[0] = new_color[0];
        this.Color[1] = new_color[1];
        this.Color[2] = new_color[2];
    }

    void SetRGBA(int new_color[4])
    {
        this.Color[0] = new_color[0];
        this.Color[1] = new_color[1];
        this.Color[2] = new_color[2];
        this.Color[3] = new_color[3];
    }

    void StrToColor4(char[] clr_str)
    {
        char RGBA[4][4];
        ExplodeString(clr_str, ",", RGBA, 4, 4);

        int R = StringToInt(RGBA[0]);
        int G = StringToInt(RGBA[1]);
        int B = StringToInt(RGBA[2]);
        int A = StringToInt(RGBA[3]);

        if (R > 255)
            R = 255;
        else if (G > 255)
            G = 255;
        else if (B > 255)
            B = 255;
        else if (A > 255)
            A = 255;
        else if (R < 0)
            R = 0;
        else if (G < 0)
            G = 0;
        else if (B < 0)
            B = 0;
        else if (A < 0)
            A = 0;

        this.Color[0] = R;
        this.Color[1] = G;
        this.Color[2] = B;
        this.Color[3] = A;
    }

    void SetAlpha(int alpha=130)
    {
        this.Color[3] = alpha;
    }

    void SetLastPos(float pos[3])
    {
        this.LastPos[0] = pos[0];
        this.LastPos[1] = pos[1];
        this.LastPos[2] = pos[2];
    }

    void GetId(char[] buffer, int maxlen=64)
    {
        strcopy(buffer, maxlen, this.TrailId);
    }

    void GetName(char[] buffer, int maxlen=64)
    {
        strcopy(buffer, maxlen, this.TrailName);
    }

    void GetVMT(char[] buffer, int maxlen=256)
    {
        strcopy(buffer, maxlen, this.TrailVMT);
    }


    void GetRGB(int color_buffer[3])
    {
        color_buffer[0] = this.Color[0];
        color_buffer[1] = this.Color[1];
        color_buffer[2] = this.Color[2];
    }

    void GetRGBA(int color_buffer[4])
    {
        color_buffer[0] = this.Color[0];
        color_buffer[1] = this.Color[1];
        color_buffer[2] = this.Color[2];
        color_buffer[3] = this.Color[3];
    }

    int GetAlpha()
    {
        return this.Color[3];
    }

    void ColorToStr(char[] buffer, int maxlen=24)
    {
        Format(buffer, maxlen, "%i,%i,%i,%i", this.Color[0], this.Color[1], this.Color[2], this.Color[3]);
    }

    void GetLastPos(float pos[3])
    {
        pos[0] = this.LastPos[0];
        pos[1] = this.LastPos[1];
        pos[2] = this.LastPos[2];
    }

    void Reset()
    {
        this.Showing = false;
        this.EntityIndex = -1;
        strcopy(this.TrailId, 64, "NONE");
        strcopy(this.TrailName, 64, "NONE");
        strcopy(this.TrailVMT, 256, "");
        this.TrailIndex = -1;
        this.Color = {255, 255, 255, 255};
        this.LastPos = {0.0, 0.0, 0.0};
        this.Width = 8.0;
    }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    CreateNative("OpenTrailMenu", SendPage1_Native);
    CreateNative("OpenTrailEquip", SendEquipMenu_Native);
    RegPluginLibrary("sntdb_trails");

    return APLRes_Success;
}

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
TrailInfo Trails[32];

public void OnPluginStart()
{
    LoadSQLStoreConfigs(DBConfName, 64, Prefix, 96, StoreSchema, 64, "Trails", CurrencyName, 64, CurrencyColor, 64, credits_given, over_mins);

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

    RegConsoleCmd("sm_trails", USR_OpenTrailMenu, "Use this to open the trail menu!");
    RegConsoleCmd("sm_trail", USR_OpenTrailMenu, "Use this to open the trail menu!");
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
    if (EqpdTrail[client].EntityIndex != -1)
        KillTrail(client);
    EqpdTrail[client].Reset();
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    // if user is showing their trail, enable it again.
    int uid = GetEventInt(event, "userid");
    int client = GetClientOfUserId(uid);
    if (EqpdTrail[client].EntityIndex != -1)
        UpdateTrail(client);
    else
        CreateTrail(client);
    CreateTimer(0.1, Timer_ShowSprite, client);
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    // Disable trail when player dies
    int uid = GetEventInt(event, "userid");
    int client = GetClientOfUserId(uid);
    KillTrail(client);
}

void CreateTrail(int client)
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
    EqpdTrail[client].EntityIndex = ent_trail;

    DispatchKeyValueFloat(ent_trail, "lifetime", 1.5);
    DispatchKeyValueFloat(ent_trail, "startwidth", EqpdTrail[client].Width);
    DispatchKeyValueFloat(ent_trail, "endwidth", EqpdTrail[client].Width);
    DispatchKeyValue(ent_trail, "spritename",TrailVMT);
    DispatchKeyValue(ent_trail, "rendercolor", RGBStr);
    DispatchKeyValue(ent_trail, "framerate", "30");
    DispatchKeyValue(ent_trail, "animate", "true");
    DispatchKeyValueInt(ent_trail, "renderamt", Alpha);
    DispatchKeyValueInt(ent_trail, "rendermode", 5);

    char trail_name[16];
    Format(trail_name, 16, "trail_%i", client);
    DispatchKeyValue(ent_trail, "targetname", trail_name);

    if (!DispatchSpawn(ent_trail))
    {
        PrintToServer("[SNT] Unable to spawn trail for some reason!");
    }

    TeleportEntity(ent_trail, PlayerOrigin, NULL_VECTOR);

    SetVariantString("!activator");
    AcceptEntityInput(ent_trail, "SetParent", client);

    SetEntPropFloat(ent_trail, Prop_Send, "m_flTextureRes", 0.05);
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
    AcceptEntityInput(EqpdTrail[client].EntityIndex, "ShowSprite");
    return Plugin_Continue;
}

void KillTrail(int client)
{
    if (EqpdTrail[client].EntityIndex != -1)
    {
        AcceptEntityInput(EqpdTrail[client].EntityIndex, "Kill");
        EqpdTrail[client].EntityIndex = -1;
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
    Panel Page1Panel = CreatePanel();
    Page1Panel.SetTitle("Trail Menu");

    char TrailName[96];
    EqpdTrail[GetNativeCell(1)].GetName(TrailName, 96);
    Format(TrailName, 96, "Equipped: %s", TrailName);

    Page1Panel.DrawItem("Equip a trail!");
    Page1Panel.DrawText(" ");
    Page1Panel.DrawItem("Trail Settings");
    Page1Panel.DrawItem("Plugin Settings");
    Page1Panel.DrawText(" ");
    Page1Panel.DrawItem("Yer Treasure");
    Page1Panel.DrawItem("The Tavern");
    Page1Panel.DrawItem("Exit");
    Page1Panel.Send(GetNativeCell(1), MainPage1_Handler, 0);
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
                    OpenInventoryMenu(param1);
                }
                case 5:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    OpenStoreMenu(param1);
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
                    SendPage1(param1);
                }
                case 4:
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
                char TrailName[64];
                EqpdTrail[param1].GetName(TrailName, 64);
                
                EqpdTrail[param1].SetId("NONE");
                EqpdTrail[param1].SetName("NONE");
                EqpdTrail[param1].TrailIndex = -1;
                EqpdTrail[param1].Frame = 0;

                AcceptEntityInput(EqpdTrail[param1].EntityIndex, "HideSprite");

                CPrintToChat(param1, "%s Sucessfully unequipped {greenyellow}%s {default}from your trail slot!", Prefix, TrailName);
                return 0;
            }

            for (int i = 0; i <= sizeof(Trails); i++)
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
                    EqpdTrail[param1].TrailIndex = Trails[i].TrailIndex;
                    CPrintToChat(param1, "%s Sucessfully equipped {greenyellow}%s {default}as your trail!", Prefix, TrailName);
                    
                    SetCookies(param1, 2, TrailId);
                    SetCookies(param1, 3, TrailName);
                    SetCookies(param1, 4, TrailVMT);
                    UpdateTrail(param1);
                }
            }
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
        }
        else
        {
            EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
            CReplyToCommand(client, "{fullred} If ye want to change yer trail's color, do '/trail color r,g,b,a' or use '/trail' to visit the trail menu!");
        }
    }
    return Plugin_Handled;
}