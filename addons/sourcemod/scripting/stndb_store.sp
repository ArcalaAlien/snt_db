#include <sourcemod>
#include <dbi>
#include <files>
#include <keyvalues>
#include <clientprefs>
#include <clients>
#include <convars>
#include <sdktools>
#include <commandfilters>

// third party includes
#include <morecolors>
#include <chat-processor>
#include <sntdb_sound>
#include <sntdb_tags>
#include <sntdb_trails>

#define REQUIRED_PLUGIN
#include <sntdb_core>

public Plugin myinfo =
{
    name = "sntdb Store Module",
    author = "Arcala the Gyiyg",
    description = "(required) SNTDB Store Module.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

enum struct ItemChoice
{
    int ItemType;
    char ItemId[64];
    char ItemName[64];
    char TagColor[64];
    char TagDisplay[64];
    char FilePath[256];
    int TrailIndex;
    char Description[512];
    int Price;
    float LastPosition[3];
    bool preview;

    void SetItemType(int item_type)
    {
        this.ItemType = item_type;
    }

    void SetItemId(char[] item_id)
    {
        strcopy(this.ItemId, 64, item_id);
    }

    void SetItemName(char[] item_name)
    {        
        strcopy(this.ItemName, 64, item_name);
    }

    void SetTagColor(char[] tag_color)
    {
        strcopy(this.TagColor, 64, tag_color);
    }

    void SetTagDisplay(char[] tag_display)
    {
        strcopy(this.TagDisplay, 64, tag_display);
    }

    void SetItemFilepath(char[] file_path)
    {
        strcopy(this.FilePath, 256, file_path);
    }

    void SetItemPrice(int price)
    {
        this.Price = price;
    }

    void SetTrailIndex(int index)
    {
        this.TrailIndex = index;
    }

    void SetDescription(char[] item_description)
    {
        strcopy(this.Description, 512, item_description);
    }

    void SetLastPosition(float last_pos[3])
    {
        this.LastPosition[0] = last_pos[0];
        this.LastPosition[1] = last_pos[1];
        this.LastPosition[2] = last_pos[2];
    }

    void SetPreviewingTrail(bool enabled)
    {
        this.preview = enabled;
    }

    int GetItemType()
    {
        return this.ItemType;
    }

    void GetItemId(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.ItemId);
    }

    void GetItemName(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.ItemName);
    }

    void GetTagColor(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TagColor);
    }

    void GetTagDisplay(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TagDisplay);
    }

    void GetItemFilepath(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.FilePath);
    }

    int GetItemPrice()
    {
        return this.Price;
    }

    int GetTrailIndex()
    {
        return this.TrailIndex;
    }

    void GetDescription(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.Description);
    }

    void GetLastPosition(float last_pos[3])
    {
        last_pos[0] = this.LastPosition[0];
        last_pos[1] = this.LastPosition[1];
        last_pos[2] = this.LastPosition[2];
    }

    bool GetPreviewingTrail()
    {
        return this.preview;
    }

    void Reset()
    {
        this.ItemType = 1;
        strcopy(this.ItemId, 64, "");
        strcopy(this.ItemName, 64, "");
        strcopy(this.TagColor, 64, "");
        strcopy(this.TagDisplay, 64, "");
        strcopy(this.FilePath, 256, "")
        this.TrailIndex = -1;
        strcopy(this.Description, 512, "");
        this.Price = 0;
    }
}


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{

    CreateNative("OpenStoreMenu", BuildPage1Store_Native);
    CreateNative("OpenInventoryMenu", BuildPage1Inventory_Native);
    CreateNative("GetClientNameColor",  SendClientNameColor_Native);
    CreateNative("GetClientChatColor", SendClientChatColor_Native);
    CreateNative("SNT_AddCredits", AddCredits_Native);
    RegPluginLibrary("sntdb_store");

    return APLRes_Success;
}

char DBConfName[64];
char Prefix[96];
char CurrencyName[64];
char CurrencyColor[64];
char StoreSchema[64];
int CFG_CreditsToGive;
float MinsTilCredits;

int RenderFrame[MAXPLAYERS + 1];

Database DB_sntdb;
ConVar isDoubleCredits;
Handle CreditTimer[MAXPLAYERS + 1];

Cookie ck_NameColor;
Cookie ck_ChatColor;
Cookie ck_IsTagDisplayed;
Cookie ck_TagName;
Cookie ck_TagDisplay;
Cookie ck_TagColor;
Cookie ck_TagPosition;

SNT_ClientInfo Player[MAXPLAYERS + 1];
ItemChoice TempChoice[MAXPLAYERS + 1];
TagSettings PlayerTags[MAXPLAYERS + 1];
TrailInfo Trails[128];

public void OnPluginStart()
{
    LoadSQLStoreConfigs(DBConfName, 64, Prefix, 96, StoreSchema, 64, "Main", CurrencyName, 64, CurrencyColor, 64, CFG_CreditsToGive, MinsTilCredits);
    LoadTranslations("common.phrases");

    PrintToServer("[SNT] Connecting to Database");
    char error[255];
    DB_sntdb = SQL_Connect(DBConfName, true, error, sizeof(error));
    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN STORE PLUGIN START: %s", error);
    }

    // credit settings
    isDoubleCredits = CreateConVar("snt_doublecredits", "0", "Enables double credits on the server!", 0, true, 0.0, true, 1.0);

    ck_NameColor = RegClientCookie("name_color", "The color of a user's name", CookieAccess_Protected);
    ck_ChatColor = RegClientCookie("chat_color", "The color of a user's text", CookieAccess_Protected);
    ck_IsTagDisplayed = RegClientCookie("is_tag_displayed", "Is the user displaying a tag?", CookieAccess_Protected);
    ck_TagName = RegClientCookie("tag_name", "The name of the tag to display to the user.", CookieAccess_Protected);
    ck_TagDisplay = RegClientCookie("tag_display", "The color of a user's text", CookieAccess_Protected);
    ck_TagColor = RegClientCookie("tag_color", "The color of a user's tag", CookieAccess_Protected);
    ck_TagPosition = RegClientCookie("tag_position", "The position of a user's tag", CookieAccess_Protected);

    // user commands
    RegConsoleCmd("sm_store", USR_OpenStore, "Use this to open the store menu!");
    RegConsoleCmd("sm_shop", USR_OpenStore, "Use this to open the store menu!");
    RegConsoleCmd("sm_tavern", USR_OpenStore, "Use this to open the store menu!")
    RegConsoleCmd("sm_inventory", USR_OpenInv, "Use this to open the inventory menu!");
    RegConsoleCmd("sm_inv", USR_OpenInv, "Use this to open the inventory menu!");
    RegConsoleCmd("sm_treasure", USR_OpenInv, "Use this to open the inventory menu!")
    RegConsoleCmd("sm_color", USR_OpenColorMenu, "Use this to preview all of the different colors we have!");
    RegConsoleCmd("sm_colors", USR_OpenColorMenu, "Use this to preview all of the different colors we have!");
    RegConsoleCmd("sm_equip", USR_OpenEquipCatMenu, "Use this to quickly access all equip menus!");
    // admin commands
    RegAdminCmd("sm_reloadstore_cfg", ADM_ReloadCfgs, ADMFLAG_ROOT, "/reloadstore_cfg Use this to reload the main config for the store");
    RegAdminCmd("sm_addcredits", ADM_AddCredits, ADMFLAG_UNBAN, "/addcredits <player> <amount> Use this to give credits to a player.");
    RegAdminCmd("sm_rmvcredits", ADM_RmvCredits, ADMFLAG_UNBAN, "/rmvcredits <player> <amount> Use this to take away credits from a player.");
}

public void OnClientPostAdminCheck(int client)
{
    if (ValidateClient(client))
    {
        if (AreClientCookiesCached(client))
        {
            GetCookies(client);
        }

        char SteamId[64];
        GetClientAuthId(client, AuthId_Steam3, SteamId, 64);

        char PlayerName[128];
        char PlayerNameEsc[257];
        GetClientName(client, PlayerName, 128);
        SQL_EscapeString(DB_sntdb, PlayerName, PlayerNameEsc, 257);

        char uQuery[512];
        Format(uQuery, 512, "INSERT INTO %splayers (SteamId, PlayerName) VALUES (\'%s\', \'%s\') ON DUPLICATE KEY UPDATE PlayerName=\'%s\'", StoreSchema, SteamId, PlayerNameEsc, PlayerNameEsc);
        SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);

        DataPack Client_Info = CreateDataPack();
        Client_Info.WriteCell(client);
        Client_Info.WriteString(SteamId);

        char sQuery[512];
        Format(sQuery, sizeof(sQuery), "SELECT SteamId, Credits FROM %splayers WHERE SteamId=\'%s\'", StoreSchema, SteamId);
        SQL_TQuery(DB_sntdb, SQL_GetPlayerInfo, sQuery, Client_Info);

        char sQuery2[512];
        Format(sQuery2, 512, "SELECT ItemId FROM %sInventories WHERE SteamId=\'%s\'", StoreSchema, SteamId);
        SQL_TQuery(DB_sntdb, SQL_CheckForColorItems, sQuery2, client);

        CreditTimer[client] = CreateTimer((MinsTilCredits*60.0), Timer_AddCredits, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        
    }
}

public void OnClientDisconnect(int client)
{
    if (SNT_IsValidClient(client))
    {
        TempChoice[client].Reset();
        Player[client].Reset();
        if (CreditTimer[client] != INVALID_HANDLE)
            CloseHandle(CreditTimer[client]);
    }
}

public void OnMapStart()
{
    char sQuerySounds[128];
    Format(sQuerySounds, 128, "SELECT ItemId, SoundFile FROM %ssounds", StoreSchema);
    SQL_TQuery(DB_sntdb, SQL_CacheFiles, sQuerySounds);

    char sQueryTrails[130];
    Format(sQueryTrails, 130, "SELECT ItemId, TrailName, TextureVMT, TextureVTF FROM %strails", StoreSchema);
    SQL_TQuery(DB_sntdb, SQL_CacheFiles, sQueryTrails);

    PrecacheSound("mvm/mvm_money_pickup.wav", true);
}

bool ValidateClient(int client)
{
    if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
        return true;
    else
        return false;
}

void GetCookies(int client)
{
    if (AreClientCookiesCached(client))
    {
        char TagDisplaying[8];
        char TagName[64];
        char TagChatDisplay[64];
        char TagColor[64];
        char TagPosition[4];
        char CurrNameColor[64];
        char CurrChatColor[64];

        GetClientCookie(client, ck_IsTagDisplayed, TagDisplaying, 8);
        GetClientCookie(client, ck_TagName, TagName, 64);
        GetClientCookie(client, ck_TagDisplay, TagChatDisplay, 64);
        GetClientCookie(client, ck_TagColor, TagColor, 64);
        GetClientCookie(client, ck_TagPosition, TagPosition, 4);
        GetClientCookie(client, ck_NameColor, CurrNameColor, 64);
        GetClientCookie(client, ck_ChatColor, CurrChatColor, 64);

        if (CurrNameColor[0] == '\0')
        {
            SetClientCookie(client, ck_NameColor, "{teamcolor}");
            Player[client].SetNameColor("{teamcolor}");
        }
        else
        {
            Player[client].SetNameColor(CurrNameColor);
        }

        if (CurrChatColor[0] == '\0')
        {
            SetClientCookie(client, ck_ChatColor, "{default}");
            Player[client].SetTextColor("{default}");
        }
        else
        {
            Player[client].SetTextColor(CurrChatColor);
        }

        if (TagDisplaying[0] == '\0')
        {
            PlayerTags[client].SetShowingTag(false);
            SetClientCookie(client, ck_IsTagDisplayed, "false");
        }
        else
            PlayerTags[client].SetShowingTag(true);

        if (TagName[0] == '\0')
        {
            PlayerTags[client].SetTagName("NONE");
            SetClientCookie(client, ck_TagName, "NONE");
        }
        else
            PlayerTags[client].SetTagName(TagName);

        if (TagChatDisplay[0] == '\0')
        {
            PlayerTags[client].SetTagDisplay("NONE");
            SetClientCookie(client, ck_TagDisplay, "NONE");
        }
        else
            PlayerTags[client].SetTagDisplay(TagChatDisplay);

        if (TagColor[0] == '\0')
        {
            PlayerTags[client].SetTagColor("NONE");
            SetClientCookie(client, ck_TagColor, "NONE");
        }
        else
            PlayerTags[client].SetTagColor(TagColor);

        if (TagPosition[0] == '\0')
        {
            PlayerTags[client].SetTagPos(0);
            SetClientCookie(client, ck_IsTagDisplayed, "0");
        }
        else
            PlayerTags[client].SetTagPos(StringToInt(TagPosition));
    }
}

void SetCookies(int client, int slot)
{
    if (AreClientCookiesCached(client))
    {
        switch (slot)
        {
            case 0:
            {
                char CurrNameColor[64];
                Player[client].GetNameColor(CurrNameColor, 64);
                SetClientCookie(client, ck_NameColor, CurrNameColor);
            }
            case 1:
            {
                char CurrChatColor[64];
                Player[client].GetTextColor(CurrChatColor, 64);
                SetClientCookie(client, ck_ChatColor, CurrChatColor);
            }
        }
    }
}

void BuildPage1Store(int client)
{
    int credits;
    credits = Player[client].GetCredits();

    char playername[MAX_NAME_LENGTH];
    GetClientName(client, playername, MAX_NAME_LENGTH);

    char title[256];
    Format(title, 256, "Ahoy %s!", playername);

    char current_creds[64];
    Format(current_creds, 64, "Ye have %i %s in yer coffers.", credits, CurrencyName);

    Panel StoreMainPanel;
    StoreMainPanel = CreatePanel();
    StoreMainPanel.SetTitle(title);
    StoreMainPanel.DrawText(" ");
    StoreMainPanel.DrawText(current_creds);
    StoreMainPanel.DrawItem("View yer treasure!");
    StoreMainPanel.DrawText(" ");
    StoreMainPanel.DrawItem("Purchase Tags");
    StoreMainPanel.DrawItem("Purchase Sounds");
    StoreMainPanel.DrawItem("Purchase Trails");
    StoreMainPanel.DrawItem("Purchase Server Items");
    StoreMainPanel.DrawItem("Color Previewer");
    // StoreMainPanel.DrawItem("Top 10s!");
    StoreMainPanel.DrawText(" ");
    StoreMainPanel.DrawItem("Exit");
    StoreMainPanel.Send(client, Store_Page1Handler, 10);
}

public void BuildPage1Store_Native(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    int credits;
    credits = Player[client].GetCredits();

    char playername[MAX_NAME_LENGTH];
    GetClientName(client, playername, MAX_NAME_LENGTH);

    char title[256];
    Format(title, 256, "Ahoy %s!", playername);

    char current_creds[64];
    Format(current_creds, 64, "Ye have %i %s in yer coffers.", credits, CurrencyName);

    Panel StoreMainPanel;
    StoreMainPanel = CreatePanel();
    StoreMainPanel.SetTitle(title);
    StoreMainPanel.DrawText(" ");
    StoreMainPanel.DrawText(current_creds);
    StoreMainPanel.DrawItem("View yer treasure!");
    StoreMainPanel.DrawText(" ");
    StoreMainPanel.DrawItem("Purchase Tags");
    StoreMainPanel.DrawItem("Purchase Sounds");
    StoreMainPanel.DrawItem("Purchase Trails");
    StoreMainPanel.DrawItem("Purchase Server Items");
    StoreMainPanel.DrawItem("Color Previewer");
    // StoreMainPanel.DrawItem("Top 10s!");
    StoreMainPanel.DrawText(" ");
    StoreMainPanel.DrawItem("Exit");
    StoreMainPanel.Send(client, Store_Page1Handler, 10);
}

void BuildPage1Inventory(int client)
{
    int credits;
    credits = Player[client].GetCredits();

    char playername[MAX_NAME_LENGTH];
    GetClientName(client, playername, MAX_NAME_LENGTH);

    char title[256];
    Format(title, 256, "%s's Treasure", playername);

    char current_creds[64];
    Format(current_creds, 64, "Ye have %i %s in yer coffers", credits, CurrencyName);

    Panel InvMainPanel;
    InvMainPanel = CreatePanel();
    InvMainPanel.SetTitle(title);
    InvMainPanel.DrawText(" ");
    InvMainPanel.DrawText(current_creds);
    InvMainPanel.DrawText(" ");
    InvMainPanel.DrawItem("Yer Tags");
    InvMainPanel.DrawItem("Yer Sounds");
    InvMainPanel.DrawItem("Yer Trails");
    InvMainPanel.DrawItem("Yer Server Items");
    InvMainPanel.DrawText(" ");
    InvMainPanel.DrawItem("The Tavern");
    InvMainPanel.DrawItem("Exit");
    InvMainPanel.Send(client, Inv_Page1Handler, 10);
}

public void BuildPage1Inventory_Native(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);

    int credits;
    credits = Player[client].GetCredits();

    char playername[MAX_NAME_LENGTH];
    GetClientName(client, playername, MAX_NAME_LENGTH);

    char title[256];
    Format(title, 256, "%s's Treasure", playername);

    char current_creds[64];
    Format(current_creds, 64, "Ye have %i %s in yer coffers", credits, CurrencyName);

    Panel InvMainPanel;
    InvMainPanel = CreatePanel();
    InvMainPanel.SetTitle(title);
    InvMainPanel.DrawText(" ");
    InvMainPanel.DrawText(current_creds);
    InvMainPanel.DrawText(" ");
    InvMainPanel.DrawItem("Yer Tags");
    InvMainPanel.DrawItem("Yer Sounds");
    InvMainPanel.DrawItem("Yer Trails");
    InvMainPanel.DrawItem("Yer Server Items");
    InvMainPanel.DrawText(" ");
    InvMainPanel.DrawItem("The Tavern");
    InvMainPanel.DrawItem("Exit");
    InvMainPanel.Send(client, Inv_Page1Handler, 10);
}

public void SendClientNameColor_Native(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char nameColor[64];
    Player[client].GetNameColor(nameColor, 64);

    SetNativeString(2, nameColor, GetNativeCell(3));
}

public void SendClientChatColor_Native(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char chatColor[64];
    Player[client].GetTextColor(chatColor, 64);
    
    SetNativeString(2, chatColor, GetNativeCell(3));
}

public void AddCredits_Native(Handle plugin, int numParams)
{
    int client = GetNativeCell(1);
    char sSteamId[64];
    if (GetClientAuthId(client, AuthId_Steam3, sSteamId, sizeof(sSteamId)))
    {
        char sQuery[512];
        int iCurCredits = Player[client].GetCredits();
        int iPayout = GetNativeCell(2);

        iCurCredits = (iCurCredits + iPayout);
        Player[client].SetCredits(iCurCredits);
        Format(sQuery, sizeof(sQuery), "UPDATE %splayers "
                                    ..."SET Credits=\"%i\" "
                                    ..."WHERE SteamId=\"%s\";", StoreSchema, iCurCredits, sSteamId);
        
        SQL_TQuery(DB_sntdb, SQL_ErrorHandler, sQuery);
    }
    else
        LogError("** AddCredits_Native ** Could not get client AuthId");
}

// void BuildTop10sPage(int client)
// {
//     Menu Top10Cats = new Menu(Top10Categories_Handler, MENU_ACTIONS_DEFAULT);
//     Top10Cats.SetTitle("Choose a category:");
//     Top10Cats.AddItem("1", "Top 10 All Items Bought");
//     Top10Cats.AddItem("2", "Top 10 Tags Bought");
//     Top10Cats.AddItem("3", "Top 10 Sounds Bought");
//     Top10Cats.AddItem("4", "Top 10 Trails Bought");
//     Top10Cats.AddItem("5", "Top 10 Server Items Bought");
//     Top10Cats.Display(client, 0);
// }

public int Store_Page1Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            EmitSoundToClient(param1, "buttons/button14.wav");
            char sQuery[512];

            DataPack Client_Info;
            Client_Info = CreateDataPack();
            Client_Info.WriteCell(param1);

            switch (param2)
            {
                case 1:
                    BuildPage1Inventory(param1);
                case 2:
                {
                    Format(sQuery, 512, "SELECT Price, ItemId, TagName FROM %stags WHERE Owner=\'STORE\' AND LEFT(ItemId, 4)=\'tag_\' ORDER BY Price, TagName ASC", StoreSchema);
                    Client_Info.WriteCell(1);
                }
                case 3:
                {
                    Format(sQuery, 512, "SELECT Price, ItemId, SoundName FROM %ssounds WHERE Owner=\'STORE\' AND LEFT(ItemId, 4)=\'snd_\' ORDER BY Price, SoundName ASC", StoreSchema);
                    Client_Info.WriteCell(2);
                }
                case 4:
                {
                    Format(sQuery, 512, "SELECT Price, ItemId, TrailName FROM %strails WHERE Owner=\'STORE\' AND LEFT(ItemId, 4)=\'trl_\' ORDER BY Price, TrailName ASC", StoreSchema);
                    Client_Info.WriteCell(3);
                }
                case 5:
                {
                    Format(sQuery, 512, "SELECT Price, ItemId, ItemName, ItemDesc FROM %sserveritems WHERE Owner=\'STORE\' AND LEFT(ItemId, 4)=\'srv_\' ORDER BY Price, ItemName ASC", StoreSchema);
                    Client_Info.WriteCell(4);
                }
                case 6:
                    Color_SendPage1(param1);
                // case 7:
                //     BuildTop10sPage(param1);
                case 7:
                {
                    EmitSoundToClient(param1, "buttons/combine_button7.wav");
                    delete menu;
                }
            }
            SQL_TQuery(DB_sntdb, SQL_FillItemMenu, sQuery, Client_Info);
        }
        case MenuAction_Cancel:
        {
            EmitSoundToClient(param1, "buttons/combine_button7.wav");
            CloseHandle(menu);
        }
    }
    return 0;
}

public int Inv_Page1Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            EmitSoundToClient(param1, "buttons/button14.wav");
            char sQuery[512];
            char SteamId[64];
            GetClientAuthId(param1, AuthId_Steam3, SteamId, 64);

            DataPack Client_Info = CreateDataPack();
            Client_Info.WriteCell(param1);

            switch (param2)
            {
                case 1:
                {
                    Format(sQuery, 512, "SELECT ItemId, TagName FROM %sInventories WHERE SteamId=\'%s\' AND LEFT(ItemId, 4)=\'tag_\' ORDER BY TagName ASC", StoreSchema, SteamId);
                    Client_Info.WriteCell(1);
                    SQL_TQuery(DB_sntdb, SQL_FillInvMenu, sQuery, Client_Info);
                }
                case 2:
                {
                    Format(sQuery, 512, "SELECT ItemId, SoundName FROM %sInventories WHERE SteamId=\'%s\' AND LEFT(ItemId, 4)=\'snd_\' ORDER BY SoundName ASC", StoreSchema, SteamId);
                    Client_Info.WriteCell(2);
                    SQL_TQuery(DB_sntdb, SQL_FillInvMenu, sQuery, Client_Info);
                }
                case 3:
                {
                    Format(sQuery, 512, "SELECT ItemId, TrailName FROM %sInventories WHERE SteamId=\'%s\' AND LEFT(ItemId, 4)=\'trl_\' ORDER BY TrailName ASC", StoreSchema, SteamId);
                    Client_Info.WriteCell(3);
                    SQL_TQuery(DB_sntdb, SQL_FillInvMenu, sQuery, Client_Info);
                }
                case 4:
                {
                    Format(sQuery, 512, "SELECT ItemId, ItemName, ItemDesc FROM %sInventories WHERE SteamId=\'%s\' AND LEFT(ItemId, 4)=\'srv_\' ORDER BY ItemName ASC", StoreSchema, SteamId);
                    Client_Info.WriteCell(4);
                    SQL_TQuery(DB_sntdb, SQL_FillInvMenu, sQuery, Client_Info);
                }
                case 5:
                {
                    BuildPage1Store(param1);
                }
                case 6:
                {
                    EmitSoundToClient(param1, "buttons/combine_button7.wav");
                    delete menu;
                }
            }
        }
        case MenuAction_End:
        {
            EmitSoundToClient(param1, "buttons/combine_button7.wav");
            delete menu;
        }
    }
    return 0;
}

public int ItemInfo_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char ChosenOption[64];
            GetMenuItem(menu, param2, ChosenOption, 64);

            char sQuery[512];
            switch(TempChoice[param1].GetItemType())
            {
                case 1:
                {   
                    Format(sQuery, 512, "SELECT ItemId, TagName, Price, DisplayColor, DisplayName FROM %stags WHERE Owner=\'STORE\' AND LEFT(ItemId, 4)=\'tag_\' ORDER BY Price ASC", StoreSchema);
                    TempChoice[param1].SetItemId(ChosenOption);
                    TempChoice[param1].SetItemType(1);
                }
                case 2:
                {
                    Format(sQuery, 512, "SELECT ItemId, SoundName, Price, SoundFile, Cooldown FROM %ssounds WHERE Owner=\'STORE\' AND LEFT(ItemId, 4)=\'snd_\' ORDER BY Price ASC", StoreSchema);
                    TempChoice[param1].SetItemId(ChosenOption);
                    TempChoice[param1].SetItemType(2);
                }
                case 3:
                {
                    Format(sQuery, 512, "SELECT ItemId, TrailName, Price FROM %strails WHERE Owner=\'STORE\' AND LEFT(ItemId, 4)=\'trl_\' ORDER BY Price ASC", StoreSchema);
                    TempChoice[param1].SetItemId(ChosenOption);
                    TempChoice[param1].SetItemType(3);
                }
                case 4:
                {
                    Format(sQuery, 512, "SELECT ItemId, ItemName, Price, ItemDesc FROM %sserveritems WHERE Owner=\'STORE\' AND LEFT(ItemId, 4)=\'srv_\' ORDER BY Price ASC", StoreSchema);
                    TempChoice[param1].SetItemId(ChosenOption);
                    TempChoice[param1].SetItemType(4);
                }
            }
            DataPack Option_Info;
            Option_Info = CreateDataPack();
            Option_Info.WriteCell(param1);
            Option_Info.WriteString(ChosenOption);

            SQL_TQuery(DB_sntdb, SQL_ShowItemInfo, sQuery, Option_Info);
        }
    }
    return 0;
}

public int InvItems_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char ChosenOption[64];
            GetMenuItem(menu, param2, ChosenOption, 64);
            char SteamId[64];
            GetClientAuthId(param1, AuthId_Steam3, SteamId, 64);

            char sQuery[512];
            if (StrEqual(ChosenOption, "X"))
            {
                BuildPage1Store(param1);
                return 0;
            }
            switch(TempChoice[param1].GetItemType())
            {
                case 1:
                {   
                    Format(sQuery, 512, "SELECT ItemId, TagName, DisplayColor, DisplayName FROM %sInventories WHERE SteamId=\'%s\' AND LEFT(ItemId, 4)=\'tag_\'", StoreSchema, SteamId);
                    TempChoice[param1].SetItemId(ChosenOption);
                    TempChoice[param1].SetItemType(1);
                }
                case 2:
                {
                    Format(sQuery, 512, "SELECT ItemId, SoundName, SoundFile, Cooldown FROM %sInventories WHERE SteamId=\'%s\' AND LEFT(ItemId, 4)=\'snd_\'", StoreSchema, SteamId);
                    TempChoice[param1].SetItemId(ChosenOption);
                    TempChoice[param1].SetItemType(2);
                }
                case 3:
                {
                    Format(sQuery, 512, "SELECT ItemId, TrailName FROM %sInventories WHERE SteamId=\'%s\' AND LEFT(ItemId, 4)=\'trl_\'", StoreSchema, SteamId);
                    TempChoice[param1].SetItemId(ChosenOption);
                    TempChoice[param1].SetItemType(3);
                }
                case 4:
                {
                    Format(sQuery, 512, "SELECT ItemId, ItemName, ItemDesc FROM %sInventories WHERE SteamId=\'%s\' AND LEFT(ItemId, 4)=\'srv_\'", StoreSchema, SteamId);
                    TempChoice[param1].SetItemId(ChosenOption);
                    TempChoice[param1].SetItemType(4);
                }
            }
            DataPack Option_Info;
            Option_Info = CreateDataPack();
            Option_Info.WriteCell(param1);
            Option_Info.WriteString(ChosenOption);

            SQL_TQuery(DB_sntdb, SQL_ShowItemInfo_Inv, sQuery, Option_Info);
        }
        case MenuAction_Cancel:
        {
            BuildPage1Inventory(param1);
        }
    }
    return 0;
}

public int InfoPanel_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    int ItemType;
    ItemType = TempChoice[param1].GetItemType();

    switch (action)
    {
        case MenuAction_Select:
        {
            EmitSoundToClient(param1, "buttons/button14.wav");
            char sQuery[512];
            switch (ItemType)
            {
                case 1:
                {
                    char TagId[64];
                    char TagName[64];
                    char TagColor[64];
                    char PlayerName[128];
                    char NameColor[64];
                    char TextColor[64];

                    Player[param1].GetName(PlayerName, 128);
                    Player[param1].GetNameColor(NameColor, 64);
                    Player[param1].GetTextColor(TextColor, 64);
                    TempChoice[param1].GetItemId(TagId, 64);
                    TempChoice[param1].GetTagDisplay(TagName, 64);
                    TempChoice[param1].GetTagColor(TagColor, 64);
                    

                    switch (param2)
                    {
                        case 1:
                        {
                            CPrintToChatEx(param1, param1, "%s%s %s%s: %sPreviewing tag in chat.", TagColor, TagName, NameColor, PlayerName, TextColor);
                            menu.DisplayAt(param1, GetMenuSelectionPosition(), 0);
                        }
                        case 2:
                        {
                            DataPack Item_Info;
                            Item_Info = CreateDataPack();
                            Item_Info.WriteCell(param1);
                            Item_Info.WriteString(TagId);
                            
                            Format(sQuery, 512, "SELECT ItemId, TagName, Price FROM %stags", StoreSchema);
                            SQL_TQuery(DB_sntdb, SQL_BuyItem, sQuery, Item_Info)
                        }
                        case 3:
                        {
                            DataPack Category_Info;
                            Category_Info = CreateDataPack();
                            Category_Info.WriteCell(param1);
                            Category_Info.WriteCell(1);

                            Format(sQuery, 512, "SELECT Price, ItemId, TagName FROM %stags WHERE Owner=\'STORE\' ORDER BY Price, TagName ASC", StoreSchema);
                            SQL_TQuery(DB_sntdb, SQL_FillItemMenu, sQuery, Category_Info);
                        }
                        case 4:
                        {
                            BuildPage1Store(param1);
                        }
                    }
                    TempChoice[param1].Reset();
                }
                case 2:
                {
                    char SoundId[64];
                    char SoundName[64];
                    char SoundFile[64];

                    TempChoice[param1].GetItemId(SoundId, 64);
                    TempChoice[param1].GetItemName(SoundName, 64);
                    TempChoice[param1].GetItemFilepath(SoundFile, 64);

                    switch (param2)
                    {
                        case 1:
                        {

                            EmitSoundToClient(param1, SoundFile);
                            CPrintToChat(param1, "%s Previewing sound: {greenyellow}%s", Prefix, SoundName);
                            menu.DisplayAt(param1, GetMenuSelectionPosition(), 0);
                        }
                        case 2:
                        {
                            DataPack Item_Info;
                            Item_Info = CreateDataPack();
                            Item_Info.WriteCell(param1);
                            Item_Info.WriteString(SoundId);
                            
                            TempChoice[param1].SetItemType(2);

                            Format(sQuery, 512, "SELECT ItemId, SoundName, Price FROM %ssounds", StoreSchema);
                            SQL_TQuery(DB_sntdb, SQL_BuyItem, sQuery, Item_Info)
                        }
                        case 3:
                        {
                            DataPack Category_Info;
                            Category_Info = CreateDataPack();
                            Category_Info.WriteCell(param1);
                            Category_Info.WriteCell(2);

                            Format(sQuery, 512, "SELECT Price, ItemId, SoundName, Cooldown FROM %ssounds WHERE Owner=\'STORE\' ORDER BY Price, SoundName ASC", StoreSchema);
                            SQL_TQuery(DB_sntdb, SQL_FillItemMenu, sQuery, Category_Info);
                        }
                        case 4:
                        {
                            BuildPage1Store(param1);
                        }
                    }
                    TempChoice[param1].Reset();
                }
                case 3:
                {
                    char TrailId[64];
                    char TrailName[64];

                    TempChoice[param1].GetItemId(TrailId, 64);
                    TempChoice[param1].GetItemName(TrailName, 64);
                    switch (param2)
                    {
                        case 1:
                        {
                            DataPack Item_Info;
                            Item_Info = CreateDataPack();
                            Item_Info.WriteCell(param1);
                            Item_Info.WriteString(TrailId);
                            
                            TempChoice[param1].SetItemType(3);

                            Format(sQuery, 512, "SELECT ItemId, TrailName, Price FROM %strails", StoreSchema);
                            SQL_TQuery(DB_sntdb, SQL_BuyItem, sQuery, Item_Info)
                        }
                        case 2:
                        {
                            DataPack Category_Info;
                            Category_Info = CreateDataPack();
                            Category_Info.WriteCell(param1);
                            Category_Info.WriteCell(3);

                            Format(sQuery, 512, "SELECT Price, ItemId, TrailName FROM %strails WHERE Owner=\'STORE\' ORDER BY Price, TrailName ASC", StoreSchema);
                            SQL_TQuery(DB_sntdb, SQL_FillItemMenu, sQuery, Category_Info);
                        }
                        case 3:
                        {
                            BuildPage1Store(param1);
                        }
                    }
                }
                case 4:
                {
                    char ItemId[64];
                    TempChoice[param1].GetItemId(ItemId, 64);
                    switch (param2)
                    {
                        case 1:
                        {
                            if (StrEqual(ItemId, "srv_clr_rblx") || StrEqual(ItemId, "srv_clr_vvvv"))
                            {
                                if(!Player[param1].GetOwnsNameColor() || !Player[param1].GetOwnsChatColor())
                                {
                                    EmitSoundToClient(param1, "snt_sounds/ypp_sting.mp3");
                                    CPrintToChat(param1, "{fullred}Ye have ta buy chat or name colors from the tavern first!\n{default}Use {greenyellow}/tavern {default}to see their wares!", Prefix);
                                    return 0;
                                }
                            }
                            DataPack Item_Info;
                            Item_Info = CreateDataPack();
                            Item_Info.WriteCell(param1);
                            Item_Info.WriteString(ItemId);
                            
                            TempChoice[param1].SetItemType(4);

                            Format(sQuery, 512, "SELECT ItemId, ItemName, Price, ItemDesc FROM %sserveritems", StoreSchema);
                            SQL_TQuery(DB_sntdb, SQL_BuyItem, sQuery, Item_Info)
                        }
                        case 2:
                        {
                            DataPack Category_Info;
                            Category_Info = CreateDataPack();
                            Category_Info.WriteCell(param1);
                            Category_Info.WriteCell(1);

                            Format(sQuery, 512, "SELECT Price, ItemId, ItemName, ItemDesc FROM %sserveritems WHERE Owner=\'STORE\' ORDER BY Price, ItemName ASC", StoreSchema);
                            SQL_TQuery(DB_sntdb, SQL_FillItemMenu, sQuery, Category_Info);
                        }
                        case 3:
                        {
                            BuildPage1Store(param1);
                            TempChoice[param1].Reset();
                        }
                    }   
                }
                default:
                {
                    CPrintToChat(param1, "%s {rblxbrightblue}Coming Soon!", Prefix);
                    TempChoice[param1].Reset();
                }
            }
        }
        case MenuAction_End:
        {            
            EmitSoundToClient(param1, "buttons/combine_button7.wav");
            delete menu;
        }
    }
    return 0;
}

public int InvInfoPanel_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    int ItemType;
    ItemType = TempChoice[param1].GetItemType();
    switch (action)
    {
        case MenuAction_Select:
        {
            EmitSoundToClient(param1, "buttons/button14.wav");
            switch (ItemType)
            {
                case 1:
                {
                    switch (param2)
                    {
                        case 1:
                        {
                            char TagColor[64];
                            char TagName[64];
                            char TagId[64];
                            char PlayerName[128];
                            char NameColor[64]
                            char TextColor[64];

                            TempChoice[param1].GetTagColor(TagColor, 64);
                            TempChoice[param1].GetTagDisplay(TagName, 64);
                            TempChoice[param1].GetItemId(TagId, 64);
                            Player[param1].GetName(PlayerName, 128);
                            Player[param1].GetNameColor(NameColor, 64);
                            Player[param1].GetTextColor(TextColor, 64);

                            CPrintToChatEx(param1, param1, "%s%s %s%s: %sPreviewing tag in chat.", TagColor, TagName, NameColor, PlayerName, TextColor);
                            menu.DisplayAt(param1, GetMenuSelectionPosition(), 0);
                        }
                        case 2:
                            OpenTagMenu(param1);
                        case 3:
                            BuildPage1Inventory(param1);
                        case 4:
                            BuildPage1Store(param1);
                    }
                    TempChoice[param1].Reset();
                }
                case 2:
                {
                    switch (param2)
                    {
                        case 1:
                        {
                            char SoundId[64];
                            char SoundName[64];
                            char SoundFile[64];

                            TempChoice[param1].GetItemId(SoundId, 64);
                            TempChoice[param1].GetItemName(SoundName, 64);
                            TempChoice[param1].GetItemFilepath(SoundFile, 64);
                            
                            EmitSoundToClient(param1, SoundFile);
                            CPrintToChat(param1, "%s Previewing sound: {greenyellow}%s", Prefix, SoundName);
                            menu.DisplayAt(param1, GetMenuSelectionPosition(), 0);
                        }
                        case 2:
                            OpenSoundMenu(param1);
                        case 3:
                            BuildPage1Inventory(param1);
                        case 4:
                            BuildPage1Store(param1);
                    }
                    TempChoice[param1].Reset();
                }
                case 3:
                {
                    switch (param2)
                    {
                        case 1:
                            OpenTrailMenu(param1);
                        case 2:
                            BuildPage1Inventory(param1);
                        case 3:
                            BuildPage1Store(param1);
                    }
                }
                case 4:
                {
                    char ItemId[64];
                    TempChoice[param1].GetItemId(ItemId, 64);
                    switch (param2)
                    {
                        case 1:
                            BuildPage1Inventory(param1);
                        case 2:
                            BuildPage1Store(param1);
                    }   
                }
                default:
                {
                    CPrintToChat(param1, "%s {rblxbrightblue}Coming Soon!", Prefix);
                    TempChoice[param1].Reset();
                }
            }
        }
        case MenuAction_End:
        {
            
            EmitSoundToClient(param1, "buttons/combine_button7.wav");
            delete menu;
        }
    }
    return 0;
}

public int AddCredit_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char PickedOption[196];
            GetMenuItem(menu, param2, PickedOption, 64);

            char SplitOption[4][196];
            ExplodeString(PickedOption, ",", SplitOption, 4, 196);

            int PickedClient = StringToInt(SplitOption[0]);
            int CreditsToAdd = StringToInt(SplitOption[3]);

            Player[PickedClient].AddCredits(CreditsToAdd);

            char uQuery[512];
            Format(uQuery, 512, "UPDATE %splayers SET Credits=%i WHERE SteamId=\'%s\'", StoreSchema, Player[PickedClient].GetCredits(), SplitOption[1]);
            SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);
            CPrintToChat(param1, "%s Gave %s%i %s to %s!", Prefix, CurrencyColor, CreditsToAdd, CurrencyName, SplitOption[1]);
        }
    }
    return 0;
}

public int RemoveCredit_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char PickedOption[196];
            GetMenuItem(menu, param2, PickedOption, 64);

            char SplitOption[4][196];
            ExplodeString(PickedOption, ",", SplitOption, 4, 196);

            int PickedClient = StringToInt(SplitOption[0]);
            int CreditsToRmv = StringToInt(SplitOption[3]);

            Player[PickedClient].RemoveCredits(CreditsToRmv);

            char uQuery[512];
            Format(uQuery, 512, "UPDATE %splayers SET Credits=%i WHERE SteamId=\'%s\'", StoreSchema, Player[PickedClient].GetCredits(), SplitOption[1]);
            SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);
            CPrintToChat(param1, "%s Took away %s%i %s from %s!", Prefix, CurrencyColor, CreditsToRmv, CurrencyName, SplitOption[1]);
        }
    }
    return 0;
}


public int ECatMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
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
                    OpenTagEquip(param1);
                }
                case 2:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    OpenSoundEquip(param1);
                }
                case 3:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    OpenTrailEquip(param1);
                }
                case 4:
                {
                    if (Player[param1].OwnsNameColor)
                    {
                        EmitSoundToClient(param1, "buttons/button14.wav");
                        Menu ColorMenuPage2 = new Menu(ColorPage2_Handler, MENU_ACTIONS_DEFAULT);
                        ColorMenuPage2.SetTitle("Pick a pack!");
                        ColorMenuPage2.AddItem("BACK,-1", "Main Menu");
                        ColorMenuPage2.AddItem("ENAME,0", "SourceMod Colors");
                        ColorMenuPage2.AddItem("ENAME,1", "Roblox Colors");
                        ColorMenuPage2.Display(param1, MENU_TIME_FOREVER);
                    }
                    else
                    {
                        EmitSoundToClient(param1, "snt_sounds/ypp_sting.mp3");
                        CPrintToChat(param1, "{fullred}Ye have ta buy name colors from the tavern first!\n{default}Use {greenyellow}/tavern {default}to see their wares!", Prefix);
                        return 0;
                    }
                }
                case 5:
                {
                    if (Player[param1].OwnsTextColor)
                    {
                        EmitSoundToClient(param1, "buttons/button14.wav");
                        Menu ColorMenuPage2 = new Menu(ColorPage2_Handler, MENU_ACTIONS_DEFAULT);
                        ColorMenuPage2.SetTitle("Pick a pack!");
                        ColorMenuPage2.AddItem("BACK,-1", "Main Menu");
                        ColorMenuPage2.AddItem("ETEXT,0", "SourceMod Colors");
                        ColorMenuPage2.AddItem("ETEXT,1", "Roblox Colors");
                        ColorMenuPage2.Display(param1, MENU_TIME_FOREVER);
                    }
                    else
                    {
                        EmitSoundToClient(param1, "snt_sounds/ypp_sting.mp3");
                        CPrintToChat(param1, "{fullred}Ye have ta buy chat colors from the tavern first!\n{default}Use {greenyellow}/tavern {default}to see their wares!", Prefix);
                        return 0;
                    }
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

public Action Timer_AddCredits(Handle timer, any client)
{
    char SteamId[64];
    Player[client].GetAuthId(SteamId, 64);
    int DoubleCreditsEnabled = GetConVarInt(isDoubleCredits);
    int CreditsGiven;

    switch (DoubleCreditsEnabled)
    {
        case 0:
        {
            CreditsGiven += CFG_CreditsToGive;
            if (GetClientCount() <= 12)
            {
                CreditsGiven += (CFG_CreditsToGive/2);
                CPrintToChat(client, "%s %s%i %s {default}have been put in yer coffers!\n{greenyellow}Thanks fer recruitin' more crewmates!", Prefix, CurrencyColor, CreditsGiven, CurrencyName);
            }
            else
            {
                CPrintToChat(client, "%s %s%i %s {default}have been put in yer coffers!", Prefix, CurrencyColor, CreditsGiven, CurrencyName);
            }
        }
        case 1:
        {
            CreditsGiven += (CFG_CreditsToGive*2);
            if (GetClientCount() <= 12)
            {
                CreditsGiven += (CFG_CreditsToGive/2);
                CPrintToChat(client, "%s %s%i %s {default}have been put in yer coffers!\n{greenyellow}Thanks fer recruitin' more crewmates!", Prefix, CurrencyColor, CreditsGiven, CurrencyName);
            }
            else
            {
                CPrintToChat(client, "%s %s%i %s {default}have been put in yer coffers!", Prefix, CurrencyColor, CreditsGiven, CurrencyName);
            }
        }
    }

    Player[client].AddCredits(CreditsGiven);
    
    char uQuery[512];
    Format(uQuery, 512, "UPDATE %splayers SET Credits=\'%i\' WHERE SteamId=\'%s\'", StoreSchema, Player[client].GetCredits(), SteamId);
    SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);
    return Plugin_Continue;
}

public Action Timer_StopPreview(Handle timer, any data)
{
    TempChoice[data].SetTrailIndex(-1);
    TempChoice[data].SetPreviewingTrail(false);
    return Plugin_Continue;
}

public void SQL_ErrorHandler(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] ERROR! DATABASE IS NULL!");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] SQL_ErrorHandler: %s", error);
    }
}

public void SQL_GetPlayerInfo(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] DATABASE IS NULL!");
        return;
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN SQL_GetPlayerInfo: %s", error);
        return;
    }

    int client;
    int uid;
    char SteamId[64];
    char playername[128];
    char playernameEsc[257];

    ResetPack(data);
    client = ReadPackCell(data);
    ReadPackString(data, SteamId, 64);

    uid = GetClientUserId(client);
    GetClientName(client, playername, 128);
    SQL_EscapeString(DB_sntdb, playername, playernameEsc, 257);

    while (SQL_FetchRow(results))
    {
        char SQL_SteamId[64];
        SQL_FetchString(results, 0, SQL_SteamId, 64);

        if (StrEqual(SQL_SteamId, SteamId))
        {
            int credits;
            credits = SQL_FetchInt(results, 1);

            Player[client].SetPlayerName(playername);
            Player[client].SetClientId(client);
            Player[client].SetAuthId(SteamId);
            Player[client].SetUserId(uid);
            Player[client].SetCredits(credits);
        }
        else
        {
            Player[client].SetPlayerName(playername);
            Player[client].SetClientId(client);
            Player[client].SetAuthId(SteamId);
            Player[client].SetUserId(uid);
            Player[client].SetCredits(750);
        }
    }
}


public void SQL_CheckForColorItems(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] DATABASE IS NULL!");
        return;
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN SQL_CheckForColorItems: %s", error);
        return;
    }

    while (SQL_FetchRow(results))
    {
        char SQL_ItemId[64];
        SQL_FetchString(results, 0, SQL_ItemId, 64);

        if (StrEqual(SQL_ItemId, "srv_cnme"))
            Player[data].SetOwnsColoredName(true);

        if (StrEqual(SQL_ItemId, "srv_ccht"))
            Player[data].SetOwnsColoredChat(true);

        if (StrEqual(SQL_ItemId, "srv_clr_rblx"))
            Player[data].SetOwnsRblxColors(true);

        if (StrEqual(SQL_ItemId, "srv_clr_vvvv"))
            Player[data].SetOwnsVVVColors(true);
    }
}

public void SQL_CacheFiles(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] DATABASE IS NULL!");
        return;
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN SQL_CacheFiles: %s", error);
        return;
    }

    int row;
    char ItemId[64];
    char TrailName[64];
    char OutFile[8];
    while (SQL_FetchRow(results))
    {
        SQL_FetchString(results, 0, ItemId, 64);
        if (StrContains(ItemId, "snd_") != -1)
        {
            char FileName[PLATFORM_MAX_PATH];

            SQL_FetchString(results, 0, ItemId, 64);
            SQL_FetchString(results, 1, FileName, PLATFORM_MAX_PATH);

            PrecacheSound(FileName, true);

            Format(FileName, 256, "sound/%s", FileName);
            AddFileToDownloadsTable(FileName);
            Format(OutFile, 8, "sounds");
            row++
        }
        if (StrContains(ItemId, "trl_") != -1)
        {
            char TrailVMT[PLATFORM_MAX_PATH];
            char TrailVTF[PLATFORM_MAX_PATH];
            SQL_FetchString(results, 1, TrailName, 64);
            SQL_FetchString(results, 2, TrailVMT, PLATFORM_MAX_PATH);
            SQL_FetchString(results, 3, TrailVTF, PLATFORM_MAX_PATH);

            Trails[row].TrailIndex = (PrecacheModel(TrailVMT, true));
            Trails[row].SetId(ItemId);
            Trails[row].SetName(TrailName);

            AddFileToDownloadsTable(TrailVMT);
            AddFileToDownloadsTable(TrailVTF);
            Format(OutFile, 8, "trails");
            row++;
        }
    }
    PrintToServer("[SNT] %i %s precached.", row, OutFile);
}

public void SQL_ShowItemInfo(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] DATABASE IS NULL!");
        return;
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN SQL_ShowItemInfo: %s", error);
        return;
    }

    int client;
    char ItemToShow[64];
    
    ResetPack(data);
    client = ReadPackCell(data);
    ReadPackString(data, ItemToShow, 64);

    Panel InfoPanel = CreatePanel()
    while (SQL_FetchRow(results))
    {
        char SQL_ItemId[64];
        char SQL_ItemName[64];
        int  SQL_Price;
        SQL_FetchString(results, 0, SQL_ItemId, 64);
        SQL_FetchString(results, 1, SQL_ItemName, 64);
        SQL_Price = SQL_FetchInt(results, 2);

        if (StrEqual(SQL_ItemId, ItemToShow))
        {
            if (StrContains(ItemToShow, "tag_") != -1)
            {
                char SQL_TagColor[64];
                char SQL_DisplayName[64];
                SQL_FetchString(results, 3, SQL_TagColor, 64);
                SQL_FetchString(results, 4, SQL_DisplayName, 64);

                TempChoice[client].SetItemId(SQL_ItemId);
                TempChoice[client].SetItemName(SQL_ItemName);
                TempChoice[client].SetTagColor(SQL_TagColor);
                TempChoice[client].SetTagDisplay(SQL_DisplayName);
                TempChoice[client].SetItemPrice(SQL_Price);

                char Line3[64];
                Format(SQL_ItemName, 64, "Tag Name: %s", SQL_ItemName);
                Format(SQL_TagColor, 64, "Tag Color: %s", SQL_TagColor);
                Format(Line3, 64, "Price: %i %s", SQL_Price, CurrencyName);
                InfoPanel.SetTitle("Viewing Tag Info:");
                InfoPanel.DrawText(SQL_ItemName);
                InfoPanel.DrawText(SQL_TagColor);
                InfoPanel.DrawText(Line3);
                InfoPanel.DrawText(" ");
                InfoPanel.DrawItem("Preview Tag");
                InfoPanel.DrawItem("Purchase Tag");
                InfoPanel.DrawText(" ");
                InfoPanel.DrawItem("Tag List");
                InfoPanel.DrawItem("Main Menu");
            }
            else if (StrContains(ItemToShow, "snd_") != -1)
            {
                char SQL_FileName[64];
                SQL_FetchString(results, 3, SQL_FileName, 64);

                TempChoice[client].SetItemId(SQL_ItemId);
                TempChoice[client].SetItemName(SQL_ItemName);
                TempChoice[client].SetItemFilepath(SQL_FileName);
                TempChoice[client].SetItemPrice(SQL_Price);

                char Line2[64];
                char Line3[64];
                Format(SQL_ItemName, 64, "Sound Name: %s", SQL_ItemName);
                Format(Line2, 64, "Price: %i %s", SQL_Price, CurrencyName);
                Format(Line3, 64, "Cooldown: %.1f sec(s)", SQL_FetchFloat(results, 4));
                InfoPanel.SetTitle("Viewing Sound Info:");
                InfoPanel.DrawText(SQL_ItemName);
                InfoPanel.DrawText(Line2);
                InfoPanel.DrawText(Line3);
                InfoPanel.DrawText(" ");
                InfoPanel.DrawItem("Preview Sound");
                InfoPanel.DrawItem("Purchase Sound");
                InfoPanel.DrawText(" ");
                InfoPanel.DrawItem("Sound List");
                InfoPanel.DrawItem("Main Menu");
            }
            else if (StrContains(ItemToShow, "trl_") != -1)
            {
                TempChoice[client].SetItemId(SQL_ItemId);
                TempChoice[client].SetItemName(SQL_ItemName);
                TempChoice[client].Price = SQL_Price;

                char Line2[64];
                Format(SQL_ItemName, 64, "Trail Name: %s", SQL_ItemName);
                Format(Line2, 64, "Price: %i %s", SQL_Price, CurrencyName);
                
                InfoPanel.SetTitle("Viewing Trail Info:");
                InfoPanel.DrawText(SQL_ItemName);
                InfoPanel.DrawText(Line2);
                InfoPanel.DrawText(" ");
                InfoPanel.DrawItem("Purchase Trail");
                InfoPanel.DrawText(" ");
                InfoPanel.DrawItem("Trail List");
                InfoPanel.DrawItem("Main Menu");
            }
            else if (StrContains(ItemToShow, "srv_") != -1)
            {
                char SQL_ShortDesc[512];
                SQL_FetchString(results, 3, SQL_ShortDesc, 512);

                TempChoice[client].SetItemId(SQL_ItemId);
                TempChoice[client].SetItemName(SQL_ItemName);
                TempChoice[client].SetDescription(SQL_ShortDesc);
                TempChoice[client].SetItemPrice(SQL_Price);

                char Line2[64];
                Format(SQL_ItemName, 64, "Name: %s", SQL_ItemName);
                Format(Line2, 64, "Price: %i %s", SQL_Price, CurrencyName);
                InfoPanel.SetTitle("Viewing Server Item:");
                InfoPanel.DrawText(SQL_ItemName);
                InfoPanel.DrawText(Line2);
                InfoPanel.DrawText(" ");
                InfoPanel.DrawText(SQL_ShortDesc)
                InfoPanel.DrawText(" ");
                InfoPanel.DrawItem("Purchase Item");
                InfoPanel.DrawText(" ");
                InfoPanel.DrawItem("Item List");
                InfoPanel.DrawItem("Main Menu");
            }
            InfoPanel.Send(client, InfoPanel_Handler, MENU_TIME_FOREVER);
            break;
        }
    }
}

public void SQL_ShowItemInfo_Inv(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] DATABASE IS NULL!");
        return;
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN SQL_ShowItemInfo_Inv: %s", error);
        return;
    }

    int client;
    char ItemToShow[64];
    
    ResetPack(data);
    client = ReadPackCell(data);
    ReadPackString(data, ItemToShow, 64);

    Panel InfoPanel = CreatePanel();

    while (SQL_FetchRow(results))
    {
        char SQL_ItemId[64];
        char SQL_ItemName[64];
        SQL_FetchString(results, 0, SQL_ItemId, 64);
        SQL_FetchString(results, 1, SQL_ItemName, 64);

        if (StrEqual(SQL_ItemId, ItemToShow))
        {
            if (StrContains(ItemToShow, "tag_") != -1)
            {
                char SQL_TagColor[64];
                char SQL_DisplayName[64];
                SQL_FetchString(results, 2, SQL_TagColor, 64);
                SQL_FetchString(results, 3, SQL_DisplayName, 64);

                TempChoice[client].SetItemId(SQL_ItemId);
                TempChoice[client].SetItemName(SQL_ItemName);
                TempChoice[client].SetTagColor(SQL_TagColor);
                TempChoice[client].SetTagDisplay(SQL_DisplayName);

                Format(SQL_ItemName, 64, "Tag Name: %s", SQL_ItemName);
                Format(SQL_TagColor, 64, "Tag Color: %s", SQL_TagColor);
                InfoPanel.SetTitle("Viewing Tag Info:");
                InfoPanel.DrawText(SQL_ItemName);
                InfoPanel.DrawText(SQL_TagColor);
                InfoPanel.DrawText(" ");
                InfoPanel.DrawItem("Preview Tag");
                InfoPanel.DrawItem("Tag Menu");
                InfoPanel.DrawText(" ");
                InfoPanel.DrawItem("Yer Treasure");
                InfoPanel.DrawItem("Main Menu");
            }
            else if (StrContains(ItemToShow, "snd_") != -1)
            {
                char SQL_FileName[256];
                SQL_FetchString(results, 2, SQL_FileName, 256);

                TempChoice[client].SetItemId(SQL_ItemId);
                TempChoice[client].SetItemName(SQL_ItemName);
                TempChoice[client].SetItemFilepath(SQL_FileName);

                char Line2[64];
                Format(SQL_ItemName, 64, "Sound Name: %s", SQL_ItemName);
                Format(Line2, 64, "Cooldown: %.1f sec(s)", SQL_FetchFloat(results, 3));
                InfoPanel.SetTitle("Viewing Sound Info:");
                InfoPanel.DrawText(SQL_ItemName);
                InfoPanel.DrawText(Line2);
                InfoPanel.DrawText(" ");
                InfoPanel.DrawItem("Preview Sound");
                InfoPanel.DrawItem("Sound Menu");
                InfoPanel.DrawText(" ");
                InfoPanel.DrawItem("Yer Treasure");
                InfoPanel.DrawItem("Main Menu");
            }
            else if (StrContains(ItemToShow, "trl_") != -1)
            {
                TempChoice[client].TrailIndex = SQL_FetchInt(results, 2);
                TempChoice[client].SetItemId(SQL_ItemId);
                TempChoice[client].SetItemName(SQL_ItemName);

                Format(SQL_ItemName, 64, "Trail Name: %s", SQL_ItemName);

                InfoPanel.SetTitle("Viewing Trail Info:");
                InfoPanel.DrawText(SQL_ItemName);
                InfoPanel.DrawText(" ");
                InfoPanel.DrawItem("Trail Menu");
                InfoPanel.DrawText(" ");
                InfoPanel.DrawItem("Yer Treasure");
                InfoPanel.DrawItem("Main Menu");
            }
            else if (StrContains(ItemToShow, "srv_") != -1)
            {
                char SQL_ShortDesc[512];
                SQL_FetchString(results, 2, SQL_ShortDesc, 512);

                TempChoice[client].SetItemId(SQL_ItemId);
                TempChoice[client].SetItemName(SQL_ItemName);
                TempChoice[client].SetDescription(SQL_ShortDesc);

                Format(SQL_ItemName, 64, "Name: %s", SQL_ItemName);
                InfoPanel.SetTitle("Viewing Server Item:");
                InfoPanel.DrawText(SQL_ItemName);
                InfoPanel.DrawText(" ");
                InfoPanel.DrawText(SQL_ShortDesc)
                InfoPanel.DrawText(" ");
                InfoPanel.DrawItem("Yer Treasure");
                InfoPanel.DrawItem("Main Menu");
            }
            InfoPanel.Send(client, InvInfoPanel_Handler, MENU_TIME_FOREVER);
            break;
        }
    }
}

public void SQL_BuyItem(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] DATABASE IS NULL!");
        return;
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN SQL_BuyItem: %s", error);
        return;
    }
    int client;
    char ItemToBuy[64];
    
    ResetPack(data);
    client = ReadPackCell(data);
    ReadPackString(data, ItemToBuy, 64);

    while (SQL_FetchRow(results))
    {
        char SQL_ItemID[64];
        char SQL_ItemName[64];
        int SQL_Price;
        if (!SQL_IsFieldNull(results, 0) && !SQL_IsFieldNull(results, 1) && !SQL_IsFieldNull(results, 2))
        {
            SQL_FetchString(results, 0, SQL_ItemID, 64);
            SQL_FetchString(results, 1, SQL_ItemName, 64);
            SQL_Price = SQL_FetchInt(results, 2);
            if (StrEqual(ItemToBuy, SQL_ItemID))
            {
                char SteamId[64];
                Player[client].GetAuthId(SteamId, 64);
                if (SQL_Price > Player[client].GetCredits())
                {
                    EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
                    CPrintToChat(client, "{fullred}Sorry matey! Ye don't have enough dubloons fer that!");
                    break;
                }
                else
                {
                    DataPack ItemInfo = CreateDataPack();
                    ItemInfo.WriteCell(client);
                    ItemInfo.WriteString(SQL_ItemID);
                    ItemInfo.WriteString(SQL_ItemName);
                    ItemInfo.WriteCell(SQL_Price);

                    char sQuery[512];
                    Format(sQuery, 512, "SELECT ItemId FROM %sInventories WHERE SteamId=\'%s\'", StoreSchema, SteamId);
                    SQL_TQuery(DB_sntdb, SQL_IsItemAlreadyOwned, sQuery, ItemInfo);
                    
                    break;
                }
            }
        }
    }
    CloseHandle(data);
}

public void SQL_IsItemAlreadyOwned(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] DATABASE IS NULL!");
        return;
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN SQL_IsItemAlreadyOwned: %s", error);
        return;
    }


    char ItemId[64];
    char ItemName[64];
    char SteamId[64];
    int client;
    int Price

    ResetPack(data)
    client = ReadPackCell(data);
    ReadPackString(data, ItemId, 64);
    ReadPackString(data, ItemName, 64);
    Price = ReadPackCell(data);
    GetClientAuthId(client, AuthId_Steam3, SteamId, 64);

    while (SQL_FetchRow(results))
    {
        char SQL_ItemId[64];
        SQL_FetchString(results, 0, SQL_ItemId, 64);

        if (StrEqual(SQL_ItemId, ItemId))
        {
            EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
            CPrintToChat(client, "{fullred}Ye already own that item! Check yer {greenyellow}/treasure {fullred}for more info!");
            break;
        }
        
        if (!StrEqual(SQL_ItemId, ItemId) && !SQL_MoreRows(results))
        {
            Player[client].RemoveCredits(Price);

            int ClientCreds = Player[client].GetCredits();                

            char iQuery[512];
            char uQuery[512];
            Format(iQuery, 512, "INSERT INTO %splayeritems (SteamId, ItemId) VALUES (\'%s\', \'%s\')", StoreSchema, SteamId, ItemId);
            Format(uQuery, 512, "UPDATE %splayers SET Credits=%i WHERE SteamId=\'%s\'", StoreSchema, ClientCreds, SteamId);

            SQL_TQuery(DB_sntdb, SQL_ErrorHandler, iQuery);
            SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);

            CPrintToChat(client, "%s Ye bought {greenyellow}%s{default}!\nYer coffers now have %s%i %s{default} in 'em.\nUse {greenyellow}/treasure{default} to view yer new booty!", Prefix, ItemName, CurrencyColor, ClientCreds, CurrencyName);
        }
    }
}

public void SQL_FillItemMenu(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] DATABASE IS NULL!");
        return;
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN SQL_FillItemMenu: %s", error);
        return;
    }

    int client;
    int module;
    ResetPack(data);
    client = ReadPackCell(data);
    module = ReadPackCell(data);
    Menu ItemMenu = new Menu(ItemInfo_Handler, MENU_ACTIONS_DEFAULT);
    switch (module)
    {
        case 1:
        {        
            ItemMenu.SetTitle("Purchase a tag?");
            TempChoice[client].SetItemType(1);
        }
        case 2:
        {
            ItemMenu.SetTitle("Purchase a sound?");
            TempChoice[client].SetItemType(2);
        }
        case 3:
        {
            ItemMenu.SetTitle("Purchase a trail?");
            TempChoice[client].SetItemType(3);
        }
        case 4:
        {
            ItemMenu.SetTitle("Purchase a server item?");
            TempChoice[client].SetItemType(4);
        }
    }

    while (SQL_FetchRow(results))
    {
        if (!SQL_IsFieldNull(results, 0) && !SQL_IsFieldNull(results, 1) && !SQL_IsFieldNull(results, 2))
        {
            char ItemId[64];
            char ItemName[64];

            SQL_FetchString(results, 1, ItemId, 64);
            SQL_FetchString(results, 2, ItemName, 64);

            AddMenuItem(ItemMenu, ItemId, ItemName);
        }
    }
    ItemMenu.Display(client, MENU_TIME_FOREVER);
}

public void SQL_FillInvMenu(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] DATABASE IS NULL!");
        return;
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN SQL_FillInvMenu: %s", error);
        return;
    }

    int client;
    int module;

    ResetPack(data);
    client = ReadPackCell(data);
    module = ReadPackCell(data);

    Menu InvMenu = new Menu(InvItems_Handler, MENU_ACTIONS_DEFAULT);
    InvMenu.ExitBackButton = true;
    switch (module)
    {
        case 1:
        {
            InvMenu.SetTitle("Here be yer tags:");
            TempChoice[client].SetItemType(1);
        }
        case 2:
        {
            InvMenu.SetTitle("Here be yer sounds:");
            TempChoice[client].SetItemType(2);
        }
        case 3:
        {
            InvMenu.SetTitle("Here be yer trails:");
            TempChoice[client].SetItemType(3);
        }
        case 4:
        {
            InvMenu.SetTitle("Here be yer server items:");
            TempChoice[client].SetItemType(4);
        }
    }
    if (SQL_GetRowCount(results) <= 0)
    {
        switch (module)
        {
            case 1:
                InvMenu.SetTitle("Ye have no tags!");
            case 2:
                InvMenu.SetTitle("Ye have no sounds!");
            case 3:
                InvMenu.SetTitle("Ye have no trails!");
            case 4:
                InvMenu.SetTitle("Ye have no server items!");
        }
        InvMenu.AddItem("X", "Select this to sail to the /tavern!");
    }
    else
    {
        while (SQL_FetchRow(results))
        {
            if (!SQL_IsFieldNull(results, 0) && !SQL_IsFieldNull(results, 1))
            {
                char ItemId[64];
                char ItemName[64];

                SQL_FetchString(results, 0, ItemId, 64);
                SQL_FetchString(results, 1, ItemName, 64);

                InvMenu.AddItem(ItemId, ItemName);
            }
        }
    }

    InvMenu.Display(client, MENU_TIME_FOREVER);
}


public Action USR_OpenStore(int client, int args)
{
    BuildPage1Store(client);
    return Plugin_Handled;
}

public Action USR_OpenInv(int client, int args)
{
    BuildPage1Inventory(client);
    return Plugin_Handled;
}
 
public Action ADM_AddCredits (int client, int args)
{
    if (args < 2)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {yellow}Usage: {greenyellow}/addcredits <playername> <amount>{default} Add %s%s {default}to a specific player in the server.", Prefix, CurrencyColor, CurrencyName);
        return Plugin_Handled;
    }

    char PlayerName[128];
    char CredAmountStr[12];
    int CreditsToAdd;
    GetCmdArg(1, PlayerName, 128);
    GetCmdArg(2, CredAmountStr, 12);
    CreditsToAdd = StringToInt(CredAmountStr);

    if (CreditsToAdd < 0)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s If you want to remove %s%s {default}from a player, use {greenyellow}/rmvcredits <playername> <amount>{default}!", Prefix, CurrencyColor, CurrencyName);
        return Plugin_Handled;
    }

    int Targets[5];
    char target_name[128];
    bool IsML;
    if (ProcessTargetString(PlayerName, client, Targets, 5, COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_BOTS, target_name, 128, IsML) == COMMAND_TARGET_AMBIGUOUS)
    {
        Menu TargetMenu = new Menu(AddCredit_Handler, MENU_ACTIONS_DEFAULT);

        for (int i = 0; i <= 4; i++)
        {
            char ret_name[128];
            char ret_auth[64];
            Player[Targets[i]].GetName(ret_name, 128);
            Player[Targets[i]].GetAuthId(ret_auth, 64);

            char info[196];
            Format(info, 196, "%i,%s,%s,%i", Targets[i], ret_auth, ret_name, CreditsToAdd);
            TargetMenu.AddItem(info, ret_name);
        }

        TargetMenu.Display(client, 30);
        return Plugin_Handled;
    }
    else
    {
        char ret_name[128];
        char ret_auth[64];
        Player[Targets[0]].GetName(ret_name, 128);
        Player[Targets[0]].GetAuthId(ret_auth, 64);
        Player[Targets[0]].AddCredits(CreditsToAdd);

        char uQuery[512];
        Format(uQuery, 512, "UPDATE %splayers SET Credits=%i WHERE SteamId=\'%s\'", StoreSchema, Player[Targets[0]].GetCredits(), ret_auth);
        SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);
        
        CPrintToChat(client, "%s Gave %s%i %s {default}to {greenyellow}%s{default}!", Prefix, CurrencyColor, CreditsToAdd, CurrencyName, ret_name);
        EmitGameSoundToClient(Targets[0], "mvm/mvm_money_pickup.wav");
        CPrintToChat(Targets[0], "%s An admin has given %s%i %s {default}to you.", Prefix, CurrencyColor, CreditsToAdd, CurrencyName);
        return Plugin_Handled;
    }
}

public Action ADM_RmvCredits (int client, int args)
{
    if (args < 2)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {yellow}Usage: {greenyellow}/rmvcredits <playername> <amount>{default} %s%s {default}to a specific player in the server.", Prefix, CurrencyColor, CurrencyName);
        return Plugin_Handled;
    }

    char PlayerName[128];
    char CredAmountStr[12];
    int CreditsToRmv;
    GetCmdArg(1, PlayerName, 128);
    GetCmdArg(2, CredAmountStr, 12);
    CreditsToRmv = StringToInt(CredAmountStr);

    if (CreditsToRmv < 0)
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s If you want to give %s%s {default}to a player, use {greenyellow}/addcredits <playername> <amount>{default}!", Prefix, CurrencyColor, CurrencyName);
        return Plugin_Handled;
    }

    int Targets[5];
    char target_name[128];
    bool IsML;
    if (ProcessTargetString(PlayerName, client, Targets, 5, COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_BOTS, target_name, 128, IsML) == COMMAND_TARGET_AMBIGUOUS)
    {
        Menu TargetMenu = new Menu(RemoveCredit_Handler, MENU_ACTIONS_DEFAULT);

        for (int i = 0; i <= 4; i++)
        {
            char ret_name[128];
            char ret_auth[64];
            Player[Targets[i]].GetName(ret_name, 128);
            Player[Targets[i]].GetAuthId(ret_auth, 64);

            char info[196];
            Format(info, 196, "%i,%s,%s,%i", Targets[i], ret_auth, ret_name, CreditsToRmv);
            TargetMenu.AddItem(info, ret_name);
        }

        TargetMenu.Display(client, 30);
        return Plugin_Handled;
    }
    else
    {
        char ret_name[128];
        char ret_auth[64];
        Player[Targets[0]].GetName(ret_name, 128);
        Player[Targets[0]].GetAuthId(ret_auth, 64);
        Player[Targets[0]].RemoveCredits(CreditsToRmv);

        char uQuery[512];
        Format(uQuery, 512, "UPDATE %splayers SET Credits=%i WHERE SteamId=\'%s\'", StoreSchema, Player[Targets[0]].GetCredits(), ret_auth);
        SQL_TQuery(DB_sntdb, SQL_ErrorHandler, uQuery);
        
        CPrintToChat(client, "%s Took away %s%i %s from {greenyellow}%s{default}!", Prefix, CurrencyColor, CreditsToRmv, CurrencyName, ret_name);
        CPrintToChat(Targets[0], "%s An admin has taken away %s%i %s {default}from you.", Prefix, CurrencyColor, CreditsToRmv, CurrencyName);
        return Plugin_Handled;
    }
}

public Action ADM_ReloadCfgs (int client, int args)
{
    LoadSQLStoreConfigs(DBConfName, 64, Prefix, 96, StoreSchema, 64, "Main", CurrencyName, 64, CurrencyColor, 64, CFG_CreditsToGive, MinsTilCredits);

    DB_sntdb.Close();

    char error[255];
    DB_sntdb = SQL_Connect(DBConfName, true, error, sizeof(error));
    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN STORE PLUGIN START: %s", error);
    }
    return Plugin_Handled;
}

public Action ADM_StartTable(int client, int args)
{
    char SteamId[64];
    GetClientAuthId(client, AuthId_Steam3, SteamId, 64);

    char ClientName[128];
    char ClientNameEsc[257];

    GetClientName(client, ClientName, 128);
    SQL_EscapeString(DB_sntdb, ClientName, ClientNameEsc, 257);

    char iQuery[512];
    Format(iQuery, sizeof(iQuery), "INSERT INTO %splayers (SteamId, PlayerName) VALUES (\'%s\', \'%s\')", StoreSchema, SteamId, ClientNameEsc);

    Player[client].SetPlayerName(ClientName);
    Player[client].SetClientId(client);
    Player[client].SetAuthId(SteamId);
    Player[client].SetUserId(GetClientUserId(client));
    Player[client].SetCredits(750);
    Player[client].SetNameColor("{teamcolor}");
    Player[client].SetTextColor("{default}");

    SQL_TQuery(DB_sntdb, SQL_ErrorHandler, iQuery);
    CPrintToChat(client, "%s Started store players table.", Prefix);
    return Plugin_Handled;
}

public Action USR_OpenEquipCatMenu(int client, int args)
{
    char SteamId[64];
    GetClientAuthId(client, AuthId_Steam3, SteamId, 64);

    char sQuery[512];
    Format(sQuery, 512, "SELECT ItemId FROM %sInventories WHERE SteamId=\'%s\'", StoreSchema, SteamId);
    SQL_TQuery(DB_sntdb, SQL_CheckForColorItems, sQuery, client);

    Panel ECatMenu = CreatePanel();
    ECatMenu.SetTitle("Select a category!");
    ECatMenu.DrawItem("Tag");
    ECatMenu.DrawItem("Sound");
    ECatMenu.DrawItem("Trail");
    ECatMenu.DrawItem("Name Color");
    ECatMenu.DrawItem("Chat Color");
    ECatMenu.DrawText(" ");
    ECatMenu.DrawItem("Exit");
    ECatMenu.Send(client, ECatMenu_Handler, 0);
    return Plugin_Handled;
}

// Color Menu //

void Color_SendPage1(int client)
{
    Menu ColorMenuPage1 = new Menu(ColorPage1_Handler, MENU_ACTIONS_DEFAULT);
    ColorMenuPage1.SetTitle("Color Menu");
    ColorMenuPage1.AddItem("ENAME", "Equip Name Color");
    ColorMenuPage1.AddItem("ETEXT", "Equip Chat Color");
    ColorMenuPage1.AddItem(" ", " ", ITEMDRAW_SPACER);
    ColorMenuPage1.AddItem("NAME", "Preview Name Color");
    ColorMenuPage1.AddItem("TEXT", "Preview Chat Color");
    ColorMenuPage1.Display(client, 0);
}

void BuildColorPage3(int client, char[] preview_type, int pack)
{
    char opt1[48] = "GREYSCALE";
    char opt2[48] = "RED";
    char opt3[48] = "ORANGE";
    char opt4[48] = "YELLOW";
    char opt5[48] = "GREEN";
    char opt6[48] = "BLUE";
    char opt7[48] = "PURPLE";
    char opt8[48] = "PINK";
    char opt9[48] = "BROWN";

    switch (pack)
    {
        case 0:
        {
            Format(opt1, 48, "%s,0,%s", preview_type, opt1);
            Format(opt2, 48, "%s,0,%s", preview_type, opt2);
            Format(opt3, 48, "%s,0,%s", preview_type, opt3);
            Format(opt4, 48, "%s,0,%s", preview_type, opt4);
            Format(opt5, 48, "%s,0,%s", preview_type, opt5);
            Format(opt6, 48, "%s,0,%s", preview_type, opt6);
            Format(opt7, 48, "%s,0,%s", preview_type, opt7);
            Format(opt8, 48, "%s,0,%s", preview_type, opt8);
            Format(opt9, 48, "%s,0,%s", preview_type, opt9);
        }
        case 1:
        {
            Format(opt1, 48, "%s,1,%s", preview_type, opt1);
            Format(opt2, 48, "%s,1,%s", preview_type, opt2);
            Format(opt3, 48, "%s,1,%s", preview_type, opt3);
            Format(opt4, 48, "%s,1,%s", preview_type, opt4);
            Format(opt5, 48, "%s,1,%s", preview_type, opt5);
            Format(opt6, 48, "%s,1,%s", preview_type, opt6);
            Format(opt7, 48, "%s,1,%s", preview_type, opt7);
            Format(opt8, 48, "%s,1,%s", preview_type, opt8);
            Format(opt9, 48, "%s,1,%s", preview_type, opt9);
        }
        case 2:
        {
            Format(opt1, 48, "%s,2,%s", preview_type, opt1);
            Format(opt2, 48, "%s,2,%s", preview_type, opt2);
            Format(opt3, 48, "%s,2,%s", preview_type, opt3);
            Format(opt4, 48, "%s,2,%s", preview_type, opt4);
            Format(opt5, 48, "%s,2,%s", preview_type, opt5);
            Format(opt6, 48, "%s,2,%s", preview_type, opt6);
            Format(opt7, 48, "%s,2,%s", preview_type, opt7);
            Format(opt8, 48, "%s,2,%s", preview_type, opt8);
            Format(opt9, 48, "%s,2,%s", preview_type, opt9);
        }
    }
    Menu ColorMenuPage3 = new Menu(ColorPage3_Handler, MENU_ACTIONS_DEFAULT);
    ColorMenuPage3.SetTitle("Pick a color category!");

    char BackOption[64];
    Format(BackOption, 64, "%s,%i,BACK", preview_type, pack);
    
    ColorMenuPage3.AddItem(BackOption, "Back to packs");
    ColorMenuPage3.AddItem(opt2, "Reds");
    ColorMenuPage3.AddItem(opt3, "Oranges");
    ColorMenuPage3.AddItem(opt4, "Yellows");
    ColorMenuPage3.AddItem(opt5, "Greens");
    ColorMenuPage3.AddItem(opt6, "Blues");
    ColorMenuPage3.AddItem(opt7, "Purples");
    ColorMenuPage3.AddItem(opt8, "Pinks");
    ColorMenuPage3.AddItem(opt9, "Browns");
    ColorMenuPage3.AddItem(opt1, "Greyscales");
    ColorMenuPage3.Display(client, 0);
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
    GetCookies(author);

    char NameColor[64];
    char ChatColor[64];

    Player[author].GetNameColor(NameColor, 64);
    Player[author].GetTextColor(ChatColor, 64);

    Format(name, MAXLENGTH_NAME, "%s%s", NameColor, name);
    CReplaceColorCodes(name, author);

    char TagDisplay[64];
    char TagColor[64];
    PlayerTags[author].GetTagDisplay(TagDisplay, 64);
    PlayerTags[author].GetTagColor(TagColor, 64);

    if (GetPlayerTagBool(author))
    {
        if (!StrEqual(TagDisplay, "NONE") && !StrEqual(TagColor, "NONE"))
        {
            switch (PlayerTags[author].GetTagPos())
            {
                case 0:
                    Format(name, MAXLENGTH_NAME, "%s%s %s", TagColor, TagDisplay, name);
                case 1:
                    Format(name, MAXLENGTH_NAME, "%s %s%s", name, TagColor, TagDisplay);
            }
            CReplaceColorCodes(name, author);
        }
    }

    Format(message, MAXLENGTH_MESSAGE, "%s%s", ChatColor, message);
    CReplaceColorCodes(message, author);
    
    return Plugin_Changed;
}

public int ColorPage1_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char Option[6];
            GetMenuItem(menu, param2, Option, 6);

            Menu ColorMenuPage2 = new Menu(ColorPage2_Handler, MENU_ACTIONS_DEFAULT);
            ColorMenuPage2.SetTitle("Pick a pack!");

            if (StrEqual(Option, "NAME"))
            {
                ColorMenuPage2.AddItem("BACK,-1", "Main Menu");
                ColorMenuPage2.AddItem("NAME,0", "SourceMod Colors");
                ColorMenuPage2.AddItem("NAME,1", "Roblox Colors");
                //ColorMenuPage2.AddItem("NAME,2", "VVVVVV Colors");
            }
            else if (StrEqual(Option, "TEXT"))
            {
                ColorMenuPage2.AddItem("BACK,-1", "Main Menu");
                ColorMenuPage2.AddItem("TEXT,0", "SourceMod Colors");
                ColorMenuPage2.AddItem("TEXT,1", "Roblox Colors");
                //ColorMenuPage2.AddItem("TEXT,2", "VVVVVV Colors");
            }
            else if (StrEqual(Option, "ENAME"))
            {
                ColorMenuPage2.AddItem("BACK,-1", "Main Menu");
                ColorMenuPage2.AddItem("ENAME,0", "SourceMod Colors");
                ColorMenuPage2.AddItem("ENAME,1", "Roblox Colors");
            }
            else if (StrEqual(Option, "ETEXT"))
            {
                ColorMenuPage2.AddItem("BACK,-1", "Main Menu");
                ColorMenuPage2.AddItem("ETEXT,0", "SourceMod Colors");
                ColorMenuPage2.AddItem("ETEXT,1", "Roblox Colors");
            }

            ColorMenuPage2.Display(param1, MENU_TIME_FOREVER);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int ColorPage2_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char Option[24];
            GetMenuItem(menu, param2, Option, 24);

            char SplitOption[2][24];
            ExplodeString(Option, ",", SplitOption, 2, 24);
            if (StrEqual(SplitOption[0], "BACK"))
            {
                Color_SendPage1(param1);
                return 0;
            }
            if (StrEqual(SplitOption[0], "NAME"))
            {
                switch (StringToInt(SplitOption[1]))
                {
                    case 0:
                    {
                        BuildColorPage3(param1, "NAME", 0);
                    }
                    case 1:
                    {
                        BuildColorPage3(param1, "NAME", 1);
                    }
                    case 2:
                    {
                        BuildColorPage3(param1, "NAME", 2);
                    }
                }
            }
            else if (StrEqual(SplitOption[0], "TEXT"))
            {
                switch (StringToInt(SplitOption[1]))
                {
                    case 0:
                    {
                        BuildColorPage3(param1, "TEXT", 0);
                    }
                    case 1:
                    {
                        BuildColorPage3(param1, "TEXT", 1);
                    }
                    case 2:
                    {
                        BuildColorPage3(param1, "TEXT", 2);
                    }
                }
            }
            else if (StrEqual(SplitOption[0], "ENAME"))
            {
                if (!Player[param1].GetOwnsNameColor())
                {
                    EmitSoundToClient(param1, "snt_sounds/ypp_sting.mp3");
                    CPrintToChat(param1, "{fullred}Ye have ta buy name colors from the tavern first!\n{default}Use {greenyellow}/tavern {default}to see their wares!", Prefix);
                    return 0;
                }
                switch (StringToInt(SplitOption[1]))
                {
                    case 0:
                    {
                        BuildColorPage3(param1, "ENAME", 0);
                    }
                    case 1:
                    {
                        if (!Player[param1].GetOwnsRblxColors())
                        {
                            EmitSoundToClient(param1, "snt_sounds/ypp_sting.mp3");
                            CPrintToChat(param1, "{fullred}Ye have ta buy roblox colors from the tavern first!\n{default}Use {greenyellow}/tavern {default}to see their wares!", Prefix);
                            return 0;
                        }
                        BuildColorPage3(param1, "ENAME", 1);
                    }
                    case 2:
                    {
                        BuildColorPage3(param1, "ENAME", 2);
                    }
                }
            }
            else if (StrEqual(SplitOption[0], "ETEXT"))
            {
                if (!Player[param1].GetOwnsChatColor())
                {
                    EmitSoundToClient(param1, "snt_sounds/ypp_sting.mp3");
                    CPrintToChat(param1, "{fullred}Ye have ta buy chat colors from the tavern first!\n{default}Use {greenyellow}/tavern {default}to see their wares!", Prefix);
                    return 0;
                }
                switch (StringToInt(SplitOption[1]))
                {
                    case 0:
                    {
                        BuildColorPage3(param1, "ETEXT", 0);
                    }
                    case 1:
                    {
                        if (!Player[param1].GetOwnsRblxColors())
                        {
                            EmitSoundToClient(param1, "snt_sounds/ypp_sting.mp3");
                            CPrintToChat(param1, "{fullred}Ye have ta buy roblox colors from the tavern first!\n{default}Use {greenyellow}/tavern {default}to see their wares!", Prefix);
                            return 0;
                        }
                        BuildColorPage3(param1, "ETEXT", 1);
                    }
                    case 2:
                    {
                        BuildColorPage3(param1, "ETEXT", 2);
                    }
                }
            }
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int ColorPage3_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    char Option[128];
    GetMenuItem(menu, param2, Option, 128);

    char SplitOption[3][48];
    ExplodeString(Option, ",", SplitOption, 3, 48);

    int pack = StringToInt(SplitOption[1]);

    char sQuery[196];
    switch (action)
    {
        case MenuAction_Select:
        {
            if (StrEqual(SplitOption[2], "BACK"))
            {
                Menu ColorMenuPage2 = new Menu(ColorPage2_Handler, MENU_ACTIONS_DEFAULT);
                ColorMenuPage2.SetTitle("Pick a pack!");

                if (StrEqual(SplitOption[0], "NAME"))
                {
                    ColorMenuPage2.AddItem("BACK,-1", "Main Menu");
                    ColorMenuPage2.AddItem("NAME,0", "SourceMod Colors");
                    ColorMenuPage2.AddItem("NAME,1", "Roblox Colors");
                    //ColorMenuPage2.AddItem("NAME,2", "VVVVVV Colors");
                }
                else if (StrEqual(SplitOption[0], "TEXT"))
                {
                    ColorMenuPage2.AddItem("BACK,-1", "Main Menu")
                    ColorMenuPage2.AddItem("TEXT,0", "SourceMod Colors");
                    ColorMenuPage2.AddItem("TEXT,1", "Roblox Colors");
                    //ColorMenuPage2.AddItem("TEXT,2", "VVVVVV Colors");
                }
                else if (StrEqual(SplitOption[0], "ENAME"))
                {
                    ColorMenuPage2.AddItem("BACK,-1", "Main Menu")
                    ColorMenuPage2.AddItem("ENAME,0", "SourceMod Colors");
                    ColorMenuPage2.AddItem("ENAME,1", "Roblox Colors");
                    //ColorMenuPage2.AddItem("TEXT,2", "VVVVVV Colors");
                }
                else if (StrEqual(SplitOption[0], "ETEXT"))
                {
                    ColorMenuPage2.AddItem("BACK,-1", "Main Menu")
                    ColorMenuPage2.AddItem("ETEXT,0", "SourceMod Colors");
                    ColorMenuPage2.AddItem("ETEXT,1", "Roblox Colors");
                    //ColorMenuPage2.AddItem("TEXT,2", "VVVVVV Colors");
                }
                ColorMenuPage2.Display(param1, MENU_TIME_FOREVER);
                return 0;
            }
            switch(pack)
            {
                case 0:
                {
                    Format(sQuery, 196, "SELECT * FROM %scolors WHERE PackName=\'DEFAULT\' AND ColorType=\'%s\' ORDER BY ColorName ASC", StoreSchema, SplitOption[2]);
                }
                case 1:
                {
                    Format(sQuery, 196, "SELECT * FROM %scolors WHERE PackName=\'ROBLOX\' AND ColorType=\'%s\' ORDER BY ColorName ASC", StoreSchema, SplitOption[2]);
                }
                case 2:
                {
                    Format(sQuery, 196, "SELECT * FROM %scolors WHERE PackName=\'VVVVVV\' AND ColorType=\'%s\' ORDER BY ColorName ASC", StoreSchema, SplitOption[2]);
                }
            }
            DataPack Color_Info = CreateDataPack();
            Color_Info.WriteCell(param1);
            Color_Info.WriteString(SplitOption[0]);
            Color_Info.WriteCell(pack);

            SQL_TQuery(DB_sntdb, SQL_FillColorMenu, sQuery, Color_Info);
        }
        case MenuAction_End:
            delete menu;
    }
    return 0;
}

public int ColorPreviewer_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char Option[128];
            GetMenuItem(menu, param2, Option, 128);
            char SplitOption[5][48];
            ExplodeString(Option, ",", SplitOption, 5, 48);

            int pack = StringToInt(SplitOption[4]);

            char CurrentNameColor[64];
            char CurrentChatColor[64];
            char PlayerName[64];
            Player[param1].GetName(PlayerName, 64);
            Player[param1].GetNameColor(CurrentNameColor, 64);
            Player[param1].GetTextColor(CurrentChatColor, 64);

            if (StrEqual(SplitOption[0], "BACK"))
            {
                BuildColorPage3(param1, SplitOption[1], StringToInt(SplitOption[2]));
                return 0;
            }

            if (StrEqual(SplitOption[0], "NAME"))
            {
                switch(pack)
                {
                    case 0:
                    {
                        CPrintToChatEx(param1, param1, "(SourceMod, %s)\n%s%s: %sThe quick brown fox jumped over the lazy dog.", SplitOption[2], SplitOption[1], PlayerName, CurrentChatColor);
                        menu.DisplayAt(param1, GetMenuSelectionPosition(), 0);
                    }
                    case 1:
                    {
                        CPrintToChatEx(param1, param1, "(Roblox, %s)\n%s%s: %sThe quick brown fox jumped over the lazy dog.", SplitOption[2], SplitOption[1], PlayerName, CurrentChatColor);
                        menu.DisplayAt(param1, GetMenuSelectionPosition(), 0);
                    }
                    case 2:
                    {
                        CPrintToChatEx(param1, param1, "(VVVVVV, %s)\n%s%s: %sThe quick brown fox jumped over the lazy dog.", SplitOption[2], SplitOption[1], PlayerName, CurrentChatColor);
                        menu.DisplayAt(param1, GetMenuSelectionPosition(), 0);
                    }
                }
            }
            else if (StrEqual(SplitOption[0], "TEXT"))
            {
                switch(pack)
                {
                    case 0:
                    {
                        CPrintToChatEx(param1, param1, "(SourceMod, %s)\n%s%s: %sThe quick brown fox jumped over the lazy dog.", SplitOption[2], CurrentNameColor, PlayerName, SplitOption[1]);
                        menu.DisplayAt(param1, GetMenuSelectionPosition(), 0);
                    }
                    case 1:
                    {
                        CPrintToChatEx(param1, param1, "(Roblox, %s)\n%s%s: %sThe quick brown fox jumped over the lazy dog.", SplitOption[2], CurrentNameColor, PlayerName, SplitOption[1]);
                        menu.DisplayAt(param1, GetMenuSelectionPosition(), 0);
                    }
                    case 2:
                    {
                        menu.DisplayAt(param1, GetMenuSelectionPosition(), 0);
                        CPrintToChatEx(param1, param1, "(VVVVVV, %s)\n%s%s: %sThe quick brown fox jumped over the lazy dog.", SplitOption[2], CurrentNameColor, PlayerName, SplitOption[1]);
                    }
                }
            }
            else if (StrEqual(SplitOption[0], "ENAME"))
            {
                char OldNameColor[64];
                Player[param1].GetNameColor(OldNameColor, 64);

                if (StrEqual(OldNameColor, SplitOption[1]))
                {
                    Player[param1].SetNameColor("{teamcolor}");
                    CPrintToChat(param1, "%s Unequipped %s%s {default}from your name color.", Prefix, SplitOption[1], SplitOption[2]);
                    SetClientCookie(param1, ck_NameColor, "{teamcolor}");
                    ChatProcessor_SetNameColor(param1, "{teamcolor}");
                }
                else
                {
                    Player[param1].SetNameColor(SplitOption[1]);
                    CPrintToChat(param1, "%s Equipped %s%s {default}as your name color!", Prefix, SplitOption[1], SplitOption[2]);
                    SetClientCookie(param1, ck_NameColor, SplitOption[1]);
                    ChatProcessor_SetNameColor(param1, SplitOption[1]);
                }
                SetCookies(param1, 0);
            }
            else if (StrEqual(SplitOption[0], "ETEXT"))
            {
                char OldChatColor[64];
                Player[param1].GetTextColor(OldChatColor, 64);

                if (StrEqual(OldChatColor, SplitOption[1]))
                {
                    Player[param1].SetTextColor("{default}");
                    CPrintToChat(param1, "%s Unequipped %s%s {default}from your chat color.", Prefix, SplitOption[1], SplitOption[2]);
                    SetClientCookie(param1, ck_ChatColor, "{default}")
                    ChatProcessor_SetChatColor(param1, "{default}");
                }
                else
                {
                    Player[param1].SetTextColor(SplitOption[1]);
                    CPrintToChat(param1, "%s Equipped %s%s {default}as your chat color!", Prefix, SplitOption[1], SplitOption[2]);
                    SetClientCookie(param1, ck_ChatColor, SplitOption[1]);
                    ChatProcessor_SetChatColor(param1, SplitOption[1]);
                }
                SetCookies(param1, 1);
            }
        }
    }
    return 0;
}

public void SQL_FillColorMenu(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] DATABASE IS NULL!");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN PREVIEWING COLOR: %s", error);
    }
    ResetPack(data);
    int client = ReadPackCell(data);
    char PreviewType[6];
    ReadPackString(data, PreviewType, 6);
    int pack = ReadPackCell(data);
    CloseHandle(data);

    Menu ColorMenuPreviewer = new Menu(ColorPreviewer_Handler, MENU_ACTIONS_DEFAULT);
    ColorMenuPreviewer.SetTitle("Pick a color!");

    char BackOption[64];
    Format(BackOption, 64, "BACK,%s,%i", PreviewType, pack);
    ColorMenuPreviewer.AddItem(BackOption, "Back to Colors");

    while (SQL_FetchRow(results))
    {
        char ColorId[64];
        char ColorName[64];
        char ColorType[12];
        char MenuOption[128];
        SQL_FetchString(results, 0, ColorId, 64);
        SQL_FetchString(results, 1, ColorName, 64);
        SQL_FetchString(results, 2, ColorType, 12);
        Format(MenuOption, 128, "%s,{%s},%s,%s,%i", PreviewType, ColorId, ColorName, ColorType, pack);
        ColorMenuPreviewer.AddItem(MenuOption, ColorName);
    }

    ColorMenuPreviewer.Display(client, 0);
}

public Action USR_OpenColorMenu (int client, int args)
{
    if (client == 0)
    {
        return Plugin_Handled;
    }
    
    char SteamId[64];
    GetClientAuthId(client, AuthId_Steam3, SteamId, 64);

    char sQuery[512];
    Format(sQuery, 512, "SELECT ItemId FROM %sInventories WHERE SteamId=\'%s\'", StoreSchema, SteamId);
    SQL_TQuery(DB_sntdb, SQL_CheckForColorItems, sQuery, client);

    Color_SendPage1(client);
    return Plugin_Handled;
}