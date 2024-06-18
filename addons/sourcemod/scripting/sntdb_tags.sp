#include <sourcemod>
#include <sdktools>
#include <dbi>
#include <clientprefs>
#include <chat-processor>
#include <morecolors>
#include <sntdb_store>

#define REQUIRED_PLUGIN
#include <sntdb_core>


enum struct TagSettings
{
    bool IsTagDisplayed;
    char TagId[64];
    char TagName[64];
    char TagDisplay[64];
    char TagColor[64];
    int TagPosition;

    void SetShowingTag(bool enabled)
    {
        this.IsTagDisplayed = enabled;
    }

    void SetTagId(char[] tag_id)
    {
        strcopy(this.TagId, 64, tag_id);
    }

    void SetTagName(char[] tag_name)
    {
        strcopy(this.TagName, 64, tag_name);
    }

    void SetTagDisplay(char[] tag_display)
    {
        strcopy(this.TagDisplay, 64, tag_display);
    }

    void SetTagColor(char[] tag_color)
    {
        strcopy(this.TagColor, 64, tag_color);
    }

    void SetTagPos(int pos)
    {
        this.TagPosition = pos;
    } 

    bool GetShowingTag()
    {
        return this.IsTagDisplayed;
    }

    void GetTagId(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TagId);
    }

    void GetTagName(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TagName);
    }

    void GetTagDisplay(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TagDisplay);
    }

    void GetTagColor(char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.TagColor);
    }

    int GetTagPos()
    {
        return this.TagPosition;
    }
}

public Plugin myinfo =
{
    name = "sntdb Tag Module",
    author = "Arcala the Gyiyg",
    description = "(required) SNTDB Tag Module.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

Database DB_sntdb;
char DBConfName[64];
char Prefix[96];
char StoreSchema[64];
char CurrencyName[64];
char CurrencyColor[64];
int credits_given;
float over_mins;

Cookie ck_IsTagDisplayed;
Cookie ck_TagName;
Cookie ck_TagDisplay;
Cookie ck_TagColor;
Cookie ck_TagPosition;

TagSettings PlayerTags[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{

    CreateNative("OpenTagMenu", BuildTagsPage1_Native);
    CreateNative("OpenTagEquip", SendTagEquip_Native);
    RegPluginLibrary("sntdb_tags");

    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadSQLStoreConfigs(DBConfName, 64, Prefix, 96, StoreSchema, 64, "Tags", CurrencyName, 64, CurrencyColor, 64, credits_given, over_mins);

    PrintToServer("[SNT] Connecting to Database");
    char error[255];
    DB_sntdb = SQL_Connect(DBConfName, true, error, sizeof(error));
    if (!StrEqual(error, ""))
    {
        ThrowError("[SNT] ERROR IN STORE PLUGIN START: %s", error);
    }

    ck_IsTagDisplayed = RegClientCookie("is_tag_displayed", "Is the user displaying a tag?", CookieAccess_Protected);
    ck_TagName = RegClientCookie("tag_name", "The name of the tag to display to the user.", CookieAccess_Protected);
    ck_TagDisplay = RegClientCookie("tag_display", "The color of a user's text", CookieAccess_Protected);
    ck_TagColor = RegClientCookie("tag_color", "The color of a user's tag", CookieAccess_Protected);
    ck_TagPosition = RegClientCookie("tag_position", "The position of a user's tag", CookieAccess_Protected);

    RegConsoleCmd("sm_tag", USR_OpenTagMenu, "/tag: Use this to open the tag menu!");
    RegConsoleCmd("sm_tags", USR_OpenTagMenu, "/tags: Use this to open the tag menu!");
}

public void OnClientPutInServer(int client)
{
    GetCookies(client);
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

        GetClientCookie(client, ck_IsTagDisplayed, TagDisplaying, 8);
        GetClientCookie(client, ck_TagName, TagName, 64);
        GetClientCookie(client, ck_TagDisplay, TagChatDisplay, 64);
        GetClientCookie(client, ck_TagColor, TagColor, 64);
        GetClientCookie(client, ck_TagPosition, TagPosition, 4);

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

void SetCookies(int client)
{
    if (AreClientCookiesCached(client))
    {
        if (PlayerTags[client].GetShowingTag())
            SetClientCookie(client, ck_IsTagDisplayed, "true");
        else
            SetClientCookie(client, ck_IsTagDisplayed, "false");
        
        char TagDisplay[64];
        PlayerTags[client].GetTagDisplay(TagDisplay, 64);
        SetClientCookie(client, ck_TagDisplay, TagDisplay);

        char TagColor[64];
        PlayerTags[client].GetTagColor(TagColor, 64);
        SetClientCookie(client, ck_TagColor, TagColor);

        char TagPos[4];
        Format(TagPos, 4, "%i", PlayerTags[client].GetTagPos());
        SetClientCookie(client, ck_TagPosition, TagPos);
    }
}

void BuildTagsPage1(int client)
{
    Panel TagsPage1 = CreatePanel();
    TagsPage1.SetTitle("Tag Menu");
    TagsPage1.DrawItem("Equip a tag!");
    TagsPage1.DrawItem("Tag Settings")
    TagsPage1.DrawText(" ");
    TagsPage1.DrawItem("Yer Treasure");
    TagsPage1.DrawItem("The Tavern");
    TagsPage1.DrawText(" ");
    TagsPage1.DrawItem("Exit");
    TagsPage1.Send(client, TagsPage1_Handler, 0);
}

void BuildSettingsPanel(int client)
{
    Panel SettingsPanel = CreatePanel();
    SettingsPanel.SetTitle("Tag Settings");
    SettingsPanel.DrawText(" ");
    (PlayerTags[client].GetShowingTag()) ? SettingsPanel.DrawText("Current Status: Showing") : SettingsPanel.DrawText("Current Status: Hiding");
    SettingsPanel.DrawItem("Toggle Tag Display");
    SettingsPanel.DrawText(" ");
    switch(PlayerTags[client].GetTagPos())
    {
        case 0:
            SettingsPanel.DrawText("Current Position: Before Name");
        case 1:
            SettingsPanel.DrawText("Current Position: After Name");
    }
    SettingsPanel.DrawItem("Toggle Tag Position");
    SettingsPanel.DrawText(" ");
    SettingsPanel.DrawItem("Tag Menu");
    SettingsPanel.DrawItem("Exit");
    SettingsPanel.Send(client, SettingsPanel_Handler, 0);
}

void BuildTagsPage1_Native(Handle plugin, int params)
{
    int client = GetNativeCell(1);
    char CTagName[64];
    PlayerTags[client].GetTagName(CTagName, 64);

    Panel TagsPage1 = CreatePanel();
    TagsPage1.SetTitle("Tag Menu");
    TagsPage1.DrawItem("Equip a tag!");
    TagsPage1.DrawItem("Tag Settings");
    TagsPage1.DrawText(" ");
    TagsPage1.DrawItem("Yer Treasure");
    TagsPage1.DrawItem("The Tavern");
    TagsPage1.DrawText(" ");
    TagsPage1.DrawItem("Exit", ITEMDRAW_DISABLED);
    TagsPage1.Send(GetNativeCell(1), TagsPage1_Handler, 0);
}

void SendTagEquip_Native(Handle plugin, int params)
{
    char SteamId[64];
    GetClientAuthId(GetNativeCell(1), AuthId_Steam3, SteamId, 64);

    char sQuery[256];
    Format(sQuery, 256, "SELECT ItemId, TagName, DisplayName, DisplayColor FROM %sInventories WHERE SteamId=\'%s\' ORDER BY TagName ASC", StoreSchema, SteamId);
    SQL_TQuery(DB_sntdb, SQL_FillTagList, sQuery, GetNativeCell(1));
}

public int SettingsPanel_Handler(Menu menu, MenuAction action, int param1, int param2)
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
                    PlayerTags[param1].SetShowingTag(!PlayerTags[param1].GetShowingTag());
                    BuildSettingsPanel(param1);
                }
                case 2:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    switch (PlayerTags[param1].GetTagPos())
                    {
                        case 0:
                            PlayerTags[param1].SetTagPos(1);
                        case 1:
                            PlayerTags[param1].SetTagPos(0);
                    }
                    SetCookies(param1);
                    BuildSettingsPanel(param1);
                }
                case 3:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    BuildTagsPage1(param1);
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

public int TagMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char MenuOpt[196];
            GetMenuItem(menu, param2, MenuOpt, 196);

            char SplitOpt[3][64];
            ExplodeString(MenuOpt, ",", SplitOpt, 3, 64);

            char CurrentTag[64];
            PlayerTags[param1].GetTagId(CurrentTag, 64);

            PrintToServer("[SNT] CurrentTag: %s, User Choice: %s", CurrentTag, SplitOpt[0]);

            if (StrEqual(SplitOpt[0], CurrentTag))
            {
                PlayerTags[param1].SetShowingTag(false);
                PlayerTags[param1].SetTagColor("NONE");
                PlayerTags[param1].SetTagDisplay("NONE");
                CPrintToChat(param1, "%s Succesfully unequipped %s%s {default}from your tag slot!", Prefix, SplitOpt[2], SplitOpt[1]);
                SetCookies(param1);
                return 0;
            }
            else
            {
                PlayerTags[param1].SetTagDisplay(SplitOpt[1]);
                PlayerTags[param1].SetTagColor(SplitOpt[2]);
                CPrintToChat(param1, "%s Sucessfully equipped %s%s {default}as your tag!", Prefix, SplitOpt[2], SplitOpt[1]);
                SetCookies(param1);
            }
        }
    }
    return 0;
}

public int TagsPage1_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            EmitSoundToClient(param1, "buttons/button14.wav");

            char SteamId[64];
            GetClientAuthId(param1, AuthId_Steam3, SteamId, 64);

            switch (param2)
            {
                case 1:
                {
                    char sQuery[256];
                    Format(sQuery, 256, "SELECT ItemId, TagName, DisplayName, DisplayColor FROM %sInventories WHERE SteamId=\'%s\' ORDER BY TagName ASC", StoreSchema, SteamId);
                    SQL_TQuery(DB_sntdb, SQL_FillTagList, sQuery, param1);
                }
                case 2:
                    BuildSettingsPanel(param1);
                case 3:
                    OpenInventoryMenu(param1);
                case 4:
                    OpenStoreMenu(param1);
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

public void SQL_FillTagList(Database db, DBResultSet results, const char[] error, any data)
{
    Menu TagMenu = new Menu(TagMenu_Handler, MENU_ACTIONS_DEFAULT);
    TagMenu.SetTitle("Choose a tag:");
    TagMenu.AddItem("BACK", "Back to tag menu");
    while (SQL_FetchRow(results))
    {
        char TagId[64];
        SQL_FetchString(results, 0, TagId, 64);
        if (StrContains(TagId, "tag_") != -1)
        {
            char TagName[64];
            char DisplayName[64];
            char DisplayColor[64];
            char FmtMenuOpt[196];

            SQL_FetchString(results, 1, TagName, 64);
            SQL_FetchString(results, 2, DisplayName, 64);
            SQL_FetchString(results, 3, DisplayColor, 64);

            Format(FmtMenuOpt, 196, "%s,%s,%s", TagId, DisplayName, DisplayColor);

            TagMenu.AddItem(FmtMenuOpt, TagName);
        }
        else
            continue;
    }
    TagMenu.Display(data, 0);
}

public Action USR_OpenTagMenu(int client, int args)
{
    BuildTagsPage1(client);
    return Plugin_Handled;
}