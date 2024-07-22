#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <dbi>
#include <files>
#include <keyvalues>
#include <morecolors>
#include <chat-processor>
#include <sntdb_store>

#define REQUIRED_PLUGIN 
#include <sntdb_core>


public Plugin myinfo =
{
    name = "sntdb Sound Module",
    author = "Arcala the Gyiyg",
    description = "(required) SNTDB Sound Module.",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

/*
CP_OnPlayerChat:
    if player's message contains any sound name play the sound to all cleints
    as long as the client has chat sounds enabled.
*/

enum struct SoundSlots
{
    char Slot1Id[64];
    char Slot1Name[64];
    char Slot1File[256];
    float Slot1Cooldown;

    char Slot2Id[64];
    char Slot2Name[64];
    char Slot2File[256];
    float Slot2Cooldown;

    char Slot3Id[64];
    char Slot3Name[64];
    char Slot3File[256];
    float Slot3Cooldown;

    char SlotConId[64];
    char SlotConName[64];
    char SlotConFile[256];

    char SlotDisconId[64];
    char SlotDisconName[64];
    char SlotDisconFile[256];

    char SlotDeathId[64];
    char SlotDeathName[64];
    char SlotDeathFile[256];

    char PreviousMessage[512];

    bool OwnsConnectItem;
    bool OwnsDeathItem;
    bool OwnsSpectatorItem;
    bool ConnectSoundsEnabled;

    void SetSlotId(int slot, const char[] sound_id)
    {
        switch (slot)
        {
            case 0:
                strcopy(this.Slot1Id, 64, sound_id);
            case 1:
                strcopy(this.Slot2Id, 64, sound_id);
            case 2:
                strcopy(this.Slot3Id, 64, sound_id);
            case 3:
                strcopy(this.SlotConId, 64, sound_id);
            case 4:
                strcopy(this.SlotDisconId, 64, sound_id);
            case 5:
                strcopy(this.SlotDeathId, 64, sound_id);
        }
    }

    void SetSlotName(int slot, const char[] sound_name)
    {
        switch (slot)
        {
            case 0:
                strcopy(this.Slot1Name, 64, sound_name);
            case 1:
                strcopy(this.Slot2Name, 64, sound_name);
            case 2:
                strcopy(this.Slot3Name, 64, sound_name);
            case 3:
                strcopy(this.SlotConName, 64, sound_name);
            case 4:
                strcopy(this.SlotDisconName, 64, sound_name);
            case 5:
                strcopy(this.SlotDeathName, 64, sound_name);
        }
    }

    void SetSlotFile(int slot, const char[] sound_file)
    {
        switch (slot)
        {
            case 0:
                strcopy(this.Slot1File, 64, sound_file);
            case 1:
                strcopy(this.Slot2File, 64, sound_file);
            case 2:
                strcopy(this.Slot3File, 64, sound_file);
            case 3:
                strcopy(this.SlotConFile, 64, sound_file);
            case 4:
                strcopy(this.SlotDisconFile, 64, sound_file);
            case 5:
                strcopy(this.SlotDeathFile, 64, sound_file);
        }
    }

    void SetSlotCooldown(int slot, float time)
    {
        switch (slot)
        {
            case 0:
                this.Slot1Cooldown = time;
            case 1:
                this.Slot2Cooldown = time;
            case 2:
                this.Slot3Cooldown = time;
            default:
                PrintToServer("[SNT] ERROR: No Slot for cooldown");
        }
    }

    void SetOwnsItem(int item, bool owns)
    {
        switch (item)
        {
            case 0:
                this.OwnsConnectItem = owns;
            case 1:
                this.OwnsDeathItem = owns;
            case 2:
                this.OwnsSpectatorItem = owns;
        }
    }

    void SetConnectEnabled(bool enabled)
    {
        this.ConnectSoundsEnabled = enabled;
    }

    void SetPreviousMessage(char[] previous_message)
    {
        strcopy(this.PreviousMessage, 512, previous_message);
    }

    void GetSlotId(int slot, char[] sound_id, int maxlen)
    {
        switch (slot)
        {
            case 0:
                strcopy(sound_id, maxlen, this.Slot1Id);
            case 1:
                strcopy(sound_id, maxlen, this.Slot2Id);
            case 2:
                strcopy(sound_id, maxlen, this.Slot3Id);
            case 3:
                strcopy(sound_id, maxlen, this.SlotConId);
            case 4:
                strcopy(sound_id, maxlen, this.SlotDisconId);
            case 5:
                strcopy(sound_id, maxlen, this.SlotDeathId);
        }
    }

    void GetSlotName(int slot, char[] sound_name, int maxlen)
    {
        switch (slot)
        {
            case 0:
                strcopy(sound_name, maxlen, this.Slot1Name);
            case 1:
                strcopy(sound_name, maxlen, this.Slot2Name);
            case 2:
                strcopy(sound_name, maxlen, this.Slot3Name);
            case 3:
                strcopy(sound_name, maxlen, this.SlotConName);
            case 4:
                strcopy(sound_name, maxlen, this.SlotDisconName);
            case 5:
                strcopy(sound_name, maxlen, this.SlotDeathName);
        }
    }

    void GetSlotFile(int slot, char[] sound_file, int maxlen)
    {
        switch (slot)
        {
            case 0:
                strcopy(sound_file, maxlen, this.Slot1File);
            case 1:
                strcopy(sound_file, maxlen, this.Slot2File);
            case 2:
                strcopy(sound_file, maxlen, this.Slot3File);
            case 3:
                strcopy(sound_file, maxlen, this.SlotConFile);
            case 4:
                strcopy(sound_file, maxlen, this.SlotDisconFile);
            case 5:
                strcopy(sound_file, maxlen, this.SlotDeathFile);
        }
    }

    float GetSlotCooldown(int slot)
    {
        switch (slot)
        {
            case 0:
                return this.Slot1Cooldown;
            case 1:
                return this.Slot1Cooldown;
            case 2:
                return this.Slot1Cooldown;
        }
        return 2.0;
    }

    void GetPrevMessage (char[] buffer, int maxlen)
    {
        strcopy(buffer, maxlen, this.PreviousMessage);
    }

    bool GetOwnsItem(int item)
    {
        switch (item)
        {
            case 0:
                return this.OwnsConnectItem;
            case 1:
                return this.OwnsDeathItem;
            case 2:
                return this.OwnsSpectatorItem;
        }
        return false;
    }

    bool GetIsConnEnabled()
    {
        return this.ConnectSoundsEnabled;
    }

    void Reset()
    {
        strcopy(this.Slot1Id, 64, "");
        strcopy(this.Slot2Id, 64, "");
        strcopy(this.Slot3Id, 64, "");
        strcopy(this.SlotConId, 64, "");
        strcopy(this.SlotDisconId, 64, "");
        strcopy(this.Slot1Name, 64, "");
        strcopy(this.Slot2Name, 64, "");
        strcopy(this.Slot3Name, 64, "");
        strcopy(this.SlotConName, 64, "");
        strcopy(this.SlotDisconName, 64, "");
        strcopy(this.Slot1File, 64, "");
        strcopy(this.Slot2File, 64, "");
        strcopy(this.Slot3File, 64, "");
        strcopy(this.SlotConFile, 64, "");
        strcopy(this.SlotDisconFile, 64, "");
        strcopy(this.PreviousMessage, 512, "");
        this.Slot1Cooldown = 2.0;
        this.Slot2Cooldown = 2.0;
        this.Slot3Cooldown = 2.0;
        this.OwnsConnectItem = false;
        this.ConnectSoundsEnabled = true;
    }
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{

    CreateNative("OpenSoundMenu", BuildSoundPanel_Native);
    CreateNative("OpenSoundEquip", SendEquipMenu_Native);
    RegPluginLibrary("sntdb_sound");

    return APLRes_Success;
}

SNT_ClientInfo Player[MAXPLAYERS + 1];
SoundSlots PlayerSounds[MAXPLAYERS + 1];
bool IsChtCooldown[MAXPLAYERS + 1];
bool IsSlt1Cooldown[MAXPLAYERS + 1];
bool IsSlt2Cooldown[MAXPLAYERS + 1];
bool IsSlt3Cooldown[MAXPLAYERS + 1];

char DBConfName[64];
char Prefix[96];
char StoreSchema[64];
char CurrencyName[64];
char CurrencyColor[64];
int credits_to_give;
float over_time;
Database DB_sntdb;

// Cookies! Yum!
Cookie ck_Slot1Id;
Cookie ck_Slot1Name;
Cookie ck_Slot1File;
Cookie ck_Slot1Cooldown;

Cookie ck_Slot2Id;
Cookie ck_Slot2Name;
Cookie ck_Slot2File;
Cookie ck_Slot2Cooldown;

Cookie ck_Slot3Id;
Cookie ck_Slot3Name;
Cookie ck_Slot3File;
Cookie ck_Slot3Cooldown;

Cookie ck_CSoundId;
Cookie ck_CSoundName;
Cookie ck_CSoundFile;

Cookie ck_DSoundId;
Cookie ck_DSoundName;
Cookie ck_DSoundFile;

Cookie ck_DeathSoundId;
Cookie ck_DeathSoundName;
Cookie ck_DeathSoundFile;

Cookie ck_ConnectionSoundsEnabled;

public void OnPluginStart()
{
    LoadSQLStoreConfigs(DBConfName, 64, Prefix, 96, StoreSchema, 64, "Sounds", CurrencyName, 64, CurrencyColor, 64, credits_to_give, over_time);

    PrintToServer("[SNT] Connecting to Database");
    char error[255];
    DB_sntdb = SQL_Connect(DBConfName, true, error, sizeof(error));
    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR IN STORE PLUGIN START: %s", error);
    }

    HookEvent("player_death", OnPlayerDeath);

    ck_Slot1Id = RegClientCookie("slot1_id", "SOUND SLOT 1 ID", CookieAccess_Protected);
    ck_Slot1Name = RegClientCookie("slot1_name", "SOUND SLOT 1 NAME", CookieAccess_Protected);
    ck_Slot1File = RegClientCookie("slot1_file", "SOUND SLOT 1 FILEPATH", CookieAccess_Protected);
    ck_Slot1Cooldown = RegClientCookie("slot1_cooldown", "SOUND SLOT 1 COOLDOWN", CookieAccess_Protected);

    ck_Slot2Id = RegClientCookie("slot2_id", "SOUND SLOT 2 ID", CookieAccess_Protected);
    ck_Slot2Name = RegClientCookie("slot2_name", "SOUND SLOT 2 NAME", CookieAccess_Protected);
    ck_Slot2File = RegClientCookie("slot2_file", "SOUND SLOT 2 FILEPATH", CookieAccess_Protected);
    ck_Slot2Cooldown = RegClientCookie("slot2_cooldown", "SOUND SLOT 2 COOLDOWN", CookieAccess_Protected);

    ck_Slot3Id = RegClientCookie("slot3_id", "SOUND SLOT 3 ID", CookieAccess_Protected);
    ck_Slot3Name = RegClientCookie("slot3_name", "SOUND SLOT 3 NAME", CookieAccess_Protected);
    ck_Slot3File = RegClientCookie("slot3_file", "SOUND SLOT 3 FILEPATH", CookieAccess_Protected);
    ck_Slot3Cooldown = RegClientCookie("slot3_cooldown", "SOUND SLOT 3 COOLDOWN", CookieAccess_Protected);
    
    ck_CSoundId = RegClientCookie("con_sound_id", "The equipped sound id for when the user connects to the server.", CookieAccess_Protected);
    ck_CSoundName = RegClientCookie("con_sound_name", "The equipped sound name for when the user connects to the server.", CookieAccess_Protected);
    ck_CSoundFile = RegClientCookie("con_sound_file", "The sound file of the sound the user has equipped.", CookieAccess_Protected);
    
    ck_DSoundId = RegClientCookie("dis_sound_id", "The equipped sound for when the user disconnects.", CookieAccess_Protected);
    ck_DSoundName = RegClientCookie("dis_sound_name", "The equipped sound name for when the user disconencts from the server.", CookieAccess_Protected);
    ck_DSoundFile = RegClientCookie("dis_sound_file", "The sound file of the sound the user has equipped.", CookieAccess_Protected);

    ck_DeathSoundId = RegClientCookie("death_sound_id", "The equipped sound for when the user disconnects.", CookieAccess_Protected);
    ck_DeathSoundName = RegClientCookie("death_sound_name", "The equipped sound name for when the user disconencts from the server.", CookieAccess_Protected);
    ck_DeathSoundFile = RegClientCookie("death_sound_file", "The sound file of the sound the user has equipped.", CookieAccess_Protected);

    ck_ConnectionSoundsEnabled = RegClientCookie("connection_sounds", "Does the user have connection sounds enabled?", CookieAccess_Protected);

    RegConsoleCmd("sm_sounds", USR_OpenSoundSettings, "Usage: Use this to open the sound menu to adjust various settings!");
    RegConsoleCmd("sm_sound", USR_OpenSoundSettings, "Usage: Use this to open the sound menu to adjust various settings!");
    RegConsoleCmd("sm_playslot1", USR_PlaySlot1, "Usage: Bind this to a key to play a sound!");
    RegConsoleCmd("sm_playslot2", USR_PlaySlot2, "Usage: Bind this to a key to play a sound!");
    RegConsoleCmd("sm_playslot3", USR_PlaySlot3, "Usage: Bind this to a key to play a sound!");
    RegAdminCmd("sm_give_csnd", ADM_GiveItem, ADMFLAG_ROOT, "Give all players in the server connection sounds.");
}

public void OnClientPutInServer(int client)
{
    Player[client].SetClientId(client);
    Player[client].SetUserId(GetClientUserId(client));

    char SteamId[64];
    char PlayerName[128];

    GetClientAuthId(client, AuthId_Steam3, SteamId, 64);
    GetClientName(client, PlayerName, 128);

    char sQuery[512];
    Format(sQuery, 512, "SELECT ItemId FROM %sInventories WHERE SteamId=\'%s\'", StoreSchema, SteamId);
    SQL_TQuery(DB_sntdb, SQL_CheckForSoundItems, sQuery, client);

    Player[client].SetAuthId(SteamId);
    Player[client].SetPlayerName(PlayerName);

    char Name_Test[128];
    Player[client].GetName(Name_Test, 128);

    for (int i = 0; i < 7; i++)
    {
        GetSlotCookies(client, i);
    }

    char ConnectSound[256];
    PlayerSounds[client].GetSlotFile(3, ConnectSound, 256);

    if (PlayerSounds[client].GetOwnsItem(0))
    {
        for (int i = 1; i <= GetClientCount(); i++)
        {
            if (i != client && !IsFakeClient(i))
            {
                if ((PlayerSounds[i].GetIsConnEnabled() == true) && !StrEqual(ConnectSound, "NONE"))
                {
                    EmitSoundToClient(i, ConnectSound);
                    CPrintToChat(i, "%s {orange}%s {default}entered the server!", Prefix, PlayerName);
                }
            }
        }
    }
}

public void OnClientDisconnect(int client)
{
    if (IsValidClient(client))
    {
        char DisconnectSound[256];
        PlayerSounds[client].GetSlotFile(4, DisconnectSound, 256);

        char PlayerName[128];
        GetClientName(client, PlayerName, 128);

        if (PlayerSounds[client].GetOwnsItem(0))
        {
            for (int i = 1; i <= GetClientCount(); i++)
            {
                if (i != client && !IsFakeClient(i))
                {
                    if ((PlayerSounds[i].GetIsConnEnabled() == true) && !StrEqual(DisconnectSound, "NONE"))
                    {
                        EmitSoundToClient(i, DisconnectSound);
                        CPrintToChat(i, "%s {orange}%s {default}left the server!", Prefix, PlayerName);
                    }
                }
            }
        }
        Player[client].Reset();
        PlayerSounds[client].Reset();
    }
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int userid = GetEventInt(event, "userid");
    int client = GetClientOfUserId(userid);

    if (PlayerSounds[client].GetOwnsItem(1))
    {
        float player_pos[3];
        GetClientAbsOrigin(client, player_pos);

        char DeathSoundFile[256];
        PlayerSounds[client].GetSlotFile(5, DeathSoundFile, 256);

        EmitAmbientSound(DeathSoundFile, player_pos, client);
    }
}

void BuildSoundPanel(int client)
{
    Panel SoundPanel = CreatePanel();
    SoundPanel.SetTitle("Sound Menu");
    SoundPanel.DrawItem("Equip A Sound!");
    SoundPanel.DrawItem("Sound Settings!");
    SoundPanel.DrawText(" ");
    SoundPanel.DrawItem("Yer Treasure");
    SoundPanel.DrawItem("Sail to the Tavern");
    SoundPanel.DrawText(" ");
    SoundPanel.DrawItem("Exit");
    SoundPanel.Send(client, SoundPanel_Handler, 30);
}

void BuildSoundPanel_Native(Handle plugin, int numParams)
{
    Panel SoundPanel = CreatePanel();
    SoundPanel.SetTitle("Sound Menu");
    SoundPanel.DrawItem("Equip A Sound!");
    SoundPanel.DrawItem("Sound Settings!");
    SoundPanel.DrawText(" ");
    SoundPanel.DrawItem("Yer Treasure");
    SoundPanel.DrawItem("Sail to the Tavern");
    SoundPanel.DrawText(" ");
    SoundPanel.DrawItem("Exit");
    SoundPanel.Send(GetNativeCell(1), SoundPanel_Handler, 30);
}

void SendEquipMenu_Native(Handle plugin, int numParams)
{
    Panel EquipCategory = CreatePanel();
    EquipCategory.SetTitle("Choose a sound category:");
    EquipCategory.DrawItem("Soundboard Slots");
    EquipCategory.DrawItem("Server Sound Slots");
    EquipCategory.DrawText(" ");
    EquipCategory.DrawItem("Sound Menu");
    EquipCategory.DrawItem("Exit");
    EquipCategory.Send(GetNativeCell(1), ECategoryPanel_Handler, MENU_TIME_FOREVER);
}

void BuildSettingsPanel(int client)
{
    Panel SettingsCategory = CreatePanel();
    SettingsCategory.SetTitle("Choose a setting:");
    (PlayerSounds[client].GetIsConnEnabled()) ? SettingsCategory.DrawText("Current: Enabled") : SettingsCategory.DrawText("Current: Disabled");
    SettingsCategory.DrawItem("Toggle Connect Sounds");
    SettingsCategory.DrawText(" ");
    SettingsCategory.DrawItem("Sound Menu");
    SettingsCategory.DrawItem("Exit"); 
    SettingsCategory.Send(client, SettingPanel_Handler, MENU_TIME_FOREVER);
}

void GetSlotCookies(int client, int slot)
{
    if (AreClientCookiesCached(client))
    {
        char cookieSID[64];
        char cookieSN[64];
        char cookieSF[256];
        char cookieCStr[8];

        switch(slot)
        {
            // Soundboard Slot 1
            case 0:
            {
                GetClientCookie(client, ck_Slot1Id, cookieSID, 64);
                GetClientCookie(client, ck_Slot1Name, cookieSN, 64);
                GetClientCookie(client, ck_Slot1File, cookieSF, 256);
                GetClientCookie(client, ck_Slot1Cooldown, cookieCStr, 8);

                if (StrEqual(cookieSID, ""))
                {
                    SetClientCookie(client, ck_Slot1Id, "NONE");
                    PlayerSounds[client].SetSlotId(0, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotId(0, cookieSID);

                if (StrEqual(cookieSN, ""))
                {
                    SetClientCookie(client, ck_Slot1Name, "NONE");
                    PlayerSounds[client].SetSlotName(0, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotName(0, cookieSN);

                if (StrEqual(cookieSF, ""))
                {
                    SetClientCookie(client, ck_Slot1File, "NONE");
                    PlayerSounds[client].SetSlotFile(0, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotFile(0, cookieSF);

                if (StrEqual(cookieCStr, ""))
                {
                    SetClientCookie(client, ck_Slot1Cooldown, "2.0");
                    PlayerSounds[client].SetSlotCooldown(0, 2.0);
                }
                else
                {
                    float cookieCld = StringToFloat(cookieCStr);
                    PlayerSounds[client].SetSlotCooldown(0, cookieCld);
                }
            }
            // Soundboard Slot 2
            case 1:
            {
                GetClientCookie(client, ck_Slot2Id, cookieSID, 64);
                GetClientCookie(client, ck_Slot2Name, cookieSN, 64);
                GetClientCookie(client, ck_Slot2File, cookieSF, 256);
                GetClientCookie(client, ck_Slot2Cooldown, cookieCStr, 8);

                if (StrEqual(cookieSID, ""))
                {
                    SetClientCookie(client, ck_Slot2Id, "NONE");
                    PlayerSounds[client].SetSlotId(1, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotId(1, cookieSID);

                if (StrEqual(cookieSN, ""))
                {
                    SetClientCookie(client, ck_Slot2Name, "NONE");
                    PlayerSounds[client].SetSlotName(1, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotName(1, cookieSN);

                if (StrEqual(cookieSF, ""))
                {
                    SetClientCookie(client, ck_Slot2File, "NONE");
                    PlayerSounds[client].SetSlotFile(1, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotFile(1, cookieSF);

                if (StrEqual(cookieCStr, ""))
                {
                    SetClientCookie(client, ck_Slot2Cooldown, "2.0");
                    PlayerSounds[client].SetSlotCooldown(1, 2.0);
                }
                else
                {
                    float cookieCld = StringToFloat(cookieCStr);
                    PlayerSounds[client].SetSlotCooldown(1, cookieCld);
                }
            }
            // Soundboard Slot 3
            case 2:
            {
                GetClientCookie(client, ck_Slot3Id, cookieSID, 64);
                GetClientCookie(client, ck_Slot3Name, cookieSN, 64);
                GetClientCookie(client, ck_Slot3File, cookieSF, 256);
                GetClientCookie(client, ck_Slot3Cooldown, cookieCStr, 8);

                if (StrEqual(cookieSID, ""))
                {
                    SetClientCookie(client, ck_Slot3Id, "NONE");
                    PlayerSounds[client].SetSlotId(2, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotId(2, cookieSID);

                if (StrEqual(cookieSN, ""))
                {
                    SetClientCookie(client, ck_Slot3Name, "NONE");
                    PlayerSounds[client].SetSlotName(2, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotName(2, cookieSN);

                if (StrEqual(cookieSF, ""))
                {
                    SetClientCookie(client, ck_Slot3File, "NONE");
                    PlayerSounds[client].SetSlotFile(2, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotFile(2, cookieSF);

                if (StrEqual(cookieCStr, ""))
                {
                    SetClientCookie(client, ck_Slot3Cooldown, "2.0");
                    PlayerSounds[client].SetSlotCooldown(2, 2.0);
                }
                else
                {
                    float cookieCld = StringToFloat(cookieCStr);
                    PlayerSounds[client].SetSlotCooldown(2, cookieCld);
                }
            }
            // Soundboard Connection Slot
            case 3:
            {
                GetClientCookie(client, ck_CSoundId, cookieSID, 64);
                GetClientCookie(client, ck_CSoundName, cookieSN, 64);
                GetClientCookie(client, ck_CSoundFile, cookieSF, 256);

                if (StrEqual(cookieSID, ""))
                {
                    SetClientCookie(client, ck_CSoundId, "NONE");
                    PlayerSounds[client].SetSlotId(3, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotId(3, cookieSID);

                if (StrEqual(cookieSN, ""))
                {
                    SetClientCookie(client, ck_CSoundName, "NONE");
                    PlayerSounds[client].SetSlotName(3, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotName(3, cookieSN);

                if (StrEqual(cookieSF, ""))
                {
                    SetClientCookie(client, ck_CSoundFile, "NONE");
                    PlayerSounds[client].SetSlotFile(3, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotFile(3, cookieSF);
            }
            // Soundboard Disconnect Slot
            case 4:
            {
                GetClientCookie(client, ck_DSoundId, cookieSID, 64);
                GetClientCookie(client, ck_DSoundName, cookieSN, 64);
                GetClientCookie(client, ck_DSoundFile, cookieSF, 256);

                if (StrEqual(cookieSID, ""))
                {
                    SetClientCookie(client, ck_DSoundId, "NONE");
                    PlayerSounds[client].SetSlotId(4, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotId(4, cookieSID);

                if (StrEqual(cookieSN, ""))
                {
                    SetClientCookie(client, ck_DSoundName, "NONE");
                    PlayerSounds[client].SetSlotName(4, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotName(4, cookieSN);

                if (StrEqual(cookieSF, ""))
                {
                    SetClientCookie(client, ck_DSoundFile, "NONE");
                    PlayerSounds[client].SetSlotFile(4, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotFile(4, cookieSF);
            }

            // Sound Death Slot
            case 5:
            {
                GetClientCookie(client, ck_DeathSoundId, cookieSID, 64);
                GetClientCookie(client, ck_DeathSoundName, cookieSN, 64);
                GetClientCookie(client, ck_DeathSoundFile, cookieSF, 256);

                if (StrEqual(cookieSID, ""))
                {
                    SetClientCookie(client, ck_DeathSoundId, "NONE");
                    PlayerSounds[client].SetSlotId(5, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotId(5, cookieSID);

                if (StrEqual(cookieSN, ""))
                {
                    SetClientCookie(client, ck_DeathSoundName, "NONE");
                    PlayerSounds[client].SetSlotName(5, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotName(5, cookieSN);

                if (StrEqual(cookieSF, ""))
                {
                    SetClientCookie(client, ck_DeathSoundFile, "NONE");
                    PlayerSounds[client].SetSlotFile(5, "NONE");
                }
                else
                    PlayerSounds[client].SetSlotFile(5, cookieSF);
            }

            // Connect sounds enabled
            case 7:
            {
                char SoundsEnabled[8];
                GetClientCookie(client, ck_ConnectionSoundsEnabled, SoundsEnabled, 8);

                if (StrEqual(SoundsEnabled, ""))
                {
                    SetClientCookie(client, ck_ConnectionSoundsEnabled, "true");
                    PlayerSounds[client].SetConnectEnabled(true);
                }
                else
                {
                    if (StrEqual(SoundsEnabled, "true"))
                        PlayerSounds[client].SetConnectEnabled(true);
                    else
                        PlayerSounds[client].SetConnectEnabled(false);
                }
            }
        }
    }
}

void SetSlotCookies(int client, int slot)
{
    if (AreClientCookiesCached(client))
    {
        char cookieSID[64];
        char cookieSN[64];
        char cookieSF[256];
        switch(slot)
        {
            // Soundboard Slot 1
            case 0:
            {
                PlayerSounds[client].GetSlotId(0, cookieSID, 64);
                PlayerSounds[client].GetSlotName(0, cookieSN, 64);
                PlayerSounds[client].GetSlotFile(0, cookieSF, 256);
                float cookieCld = PlayerSounds[client].GetSlotCooldown(0);
                char cookieCStr[8];
                FloatToString(cookieCld, cookieCStr, 8);

                SetClientCookie(client, ck_Slot1Id, cookieSID);
                SetClientCookie(client, ck_Slot1Name, cookieSN);
                SetClientCookie(client, ck_Slot1File, cookieSF);
                SetClientCookie(client, ck_Slot1Cooldown, cookieCStr);

            }
            // Soundboard Slot 2
            case 1:
            {
                PlayerSounds[client].GetSlotId(1, cookieSID, 64);
                PlayerSounds[client].GetSlotName(1, cookieSN, 64);
                PlayerSounds[client].GetSlotFile(1, cookieSF, 256);
                float cookieCld = PlayerSounds[client].GetSlotCooldown(1);
                char cookieCStr[8];
                FloatToString(cookieCld, cookieCStr, 8);

                SetClientCookie(client, ck_Slot2Id, cookieSID);
                SetClientCookie(client, ck_Slot2Name, cookieSN);
                SetClientCookie(client, ck_Slot2File, cookieSF);
                SetClientCookie(client, ck_Slot2Cooldown, cookieCStr);
            }
            // Soundboard Slot 3
            case 2:
            {
                PlayerSounds[client].GetSlotId(2, cookieSID, 64);
                PlayerSounds[client].GetSlotName(2, cookieSN, 64);
                PlayerSounds[client].GetSlotFile(2, cookieSF, 256);
                float cookieCld = PlayerSounds[client].GetSlotCooldown(2);
                char cookieCStr[8];
                FloatToString(cookieCld, cookieCStr, 8);

                SetClientCookie(client, ck_Slot3Id, cookieSID);
                SetClientCookie(client, ck_Slot3Name, cookieSN);
                SetClientCookie(client, ck_Slot3File, cookieSF);
                SetClientCookie(client, ck_Slot3Cooldown, cookieCStr);
            }
            // Soundboard Connection Slot
            case 3:
            {
                PlayerSounds[client].GetSlotId(3, cookieSID, 64);
                PlayerSounds[client].GetSlotName(3, cookieSN, 64);
                PlayerSounds[client].GetSlotFile(3, cookieSF, 256);

                SetClientCookie(client, ck_CSoundId, cookieSID);
                SetClientCookie(client, ck_CSoundName, cookieSN);
                SetClientCookie(client, ck_CSoundFile, cookieSF);
            }
            // Soundboard Disconnect Slot
            case 4:
            {
                PlayerSounds[client].GetSlotId(4, cookieSID, 64);
                PlayerSounds[client].GetSlotName(4, cookieSN, 64);
                PlayerSounds[client].GetSlotFile(4, cookieSF, 256);

                SetClientCookie(client, ck_DSoundId, cookieSID);
                SetClientCookie(client, ck_DSoundName, cookieSN);
                SetClientCookie(client, ck_DSoundFile, cookieSF);
            }
            // Soundboard Death Slot
            case 5:
            {
                PlayerSounds[client].GetSlotId(5, cookieSID, 64);
                PlayerSounds[client].GetSlotName(5, cookieSN, 64);
                PlayerSounds[client].GetSlotFile(5, cookieSF, 256);

                SetClientCookie(client, ck_DeathSoundId, cookieSID);
                SetClientCookie(client, ck_DeathSoundName, cookieSN);
                SetClientCookie(client, ck_DeathSoundFile, cookieSF);
            }
            // Is Connect sounds enabled?
            case 7:
            {
                (PlayerSounds[client].GetIsConnEnabled()) ? SetClientCookie(client, ck_ConnectionSoundsEnabled, "true") : SetClientCookie(client, ck_ConnectionSoundsEnabled, "false");
            }
        }
    }
}

public int SoundPanel_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char SteamId[64];
            GetClientAuthId(param1, AuthId_Steam3, SteamId, 64);

            char sQuery[512];
            Format(sQuery, 512, "SELECT ItemId FROM %sInventories WHERE SteamId=\'%s\'", StoreSchema, SteamId);
            SQL_TQuery(DB_sntdb, SQL_CheckForSoundItems, sQuery, param1);

            EmitSoundToClient(param1, "buttons/button14.wav");
            switch (param2)
            {
                case 1:
                {
                    Panel EquipCategory = CreatePanel();
                    EquipCategory.SetTitle("Choose a sound category:");
                    EquipCategory.DrawItem("Soundboard Slots");
                    EquipCategory.DrawItem("Server Sound Slots");
                    EquipCategory.DrawText(" ");
                    EquipCategory.DrawItem("Sound Menu");
                    EquipCategory.DrawItem("Exit");
                    EquipCategory.Send(param1, ECategoryPanel_Handler, MENU_TIME_FOREVER);
                }
                case 2:
                {
                    BuildSettingsPanel(param1);
                }
                case 3:
                {
                    OpenInventoryMenu(param1);
                }
                case 4:
                {
                    OpenStoreMenu(param1);
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

public int SoundboardSlot_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            DataPack Info_Choice = CreateDataPack();
            Info_Choice.WriteCell(param1);

            switch (param2)
            {
                case 1:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    Info_Choice.WriteCell(0);
                }
                case 2:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    Info_Choice.WriteCell(1);
                }
                case 3:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    Info_Choice.WriteCell(2);
                }
                case 4:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    Info_Choice.Close()
                    BuildSoundPanel(param1);
                    return 0;
                }
                case 5:
                {
                    EmitSoundToClient(param1, "buttons/combine_button7.wav");
                    Info_Choice.Close();
                    delete menu;
                    return 0;
                }
            }
            char SteamId[64];
            GetClientAuthId(param1, AuthId_Steam3, SteamId, 64);

            char sQuery[512];
            Format(sQuery, 512, "SELECT SteamId, ItemId, SoundName FROM %sInventories WHERE SUBSTR(ItemId, 1, 4)=\'snd_\' AND SteamId=\'%s\' ORDER BY SoundName ASC", StoreSchema, SteamId);
            SQL_TQuery(DB_sntdb, SQL_GetPlayerSounds, sQuery, Info_Choice);
        }
    }
    return 0;
}

public int ServerSoundSlot_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            DataPack Info_Choice = CreateDataPack();
            Info_Choice.WriteCell(param1);

            switch (param2)
            {
                case 1:
                {
                    if (!PlayerSounds[param1].GetOwnsItem(0))
                    {
                        EmitSoundToClient(param1, "snt_sounds/ypp_sting.mp3");
                        CPrintToChat(param1, "{fullred}Ye have ta buy this from the tavern first!\n{default}Use {greenyellow}/tavern {default}to see their wares!");
                        menu.DisplayAt(param1, GetMenuSelectionPosition(), 0);
                        return 0;
                    }
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    Info_Choice.WriteCell(3);
                }
                case 2:
                {
                    if (!PlayerSounds[param1].GetOwnsItem(0))
                    {
                        EmitSoundToClient(param1, "snt_sounds/ypp_sting.mp3");
                        CPrintToChat(param1, "{fullred}Ye have ta buy this from the tavern first!\n{default}Use {greenyellow}/tavern {default}to see their wares!");
                        menu.DisplayAt(param1, GetMenuSelectionPosition(), 0);
                        return 0;
                    }
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    Info_Choice.WriteCell(4);
                }
                case 3:
                {
                    if (!PlayerSounds[param1].GetOwnsItem(1))
                    {
                        EmitSoundToClient(param1, "snt_sounds/ypp_sting.mp3");
                        CPrintToChat(param1, "{fullred}Ye have ta buy this from the tavern first!\n{default}Use {greenyellow}/tavern {default}to see their wares!");
                        menu.DisplayAt(param1, GetMenuSelectionPosition(), 0);
                        return 0;
                    }
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    Info_Choice.WriteCell(5);
                }
                case 4:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    Info_Choice.Close()
                    BuildSoundPanel(param1);
                    return 0;
                }
                case 5:
                {
                    EmitSoundToClient(param1, "buttons/combine_button7.wav");
                    Info_Choice.Close();
                    delete menu;
                    return 0;
                }
            }
            char SteamId[64];
            GetClientAuthId(param1, AuthId_Steam3, SteamId, 64);

            char sQuery[512];
            Format(sQuery, 512, "SELECT SteamId, ItemId, SoundName FROM %sInventories WHERE SUBSTR(ItemId, 1, 4)=\'snd_\' AND SteamId=\'%s\' ORDER BY SoundName ASC", StoreSchema, SteamId);
            SQL_TQuery(DB_sntdb, SQL_GetPlayerSounds, sQuery, Info_Choice);
        }
    }
    return 0;
}

public int SettingPanel_Handler(Menu menu, MenuAction action, int param1, int param2)
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
                    if (PlayerSounds[param1].GetIsConnEnabled())
                    {
                        PlayerSounds[param1].SetConnectEnabled(false);
                        BuildSettingsPanel(param1);
                        SetSlotCookies(param1, 7);
                    }
                    else
                    {
                        PlayerSounds[param1].SetConnectEnabled(true);
                        BuildSettingsPanel(param1);
                        SetSlotCookies(param1, 7);
                    }
                }
                case 2:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    BuildSoundPanel(param1);
                    return 0;
                }
                case 3:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    return 0;
                }
            }
        }
    }
    return 0;
}

public int ECategoryPanel_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char SteamId[64];
            GetClientAuthId(param1, AuthId_Steam3, SteamId, 64);

            DataPack Info_Choice = CreateDataPack();
            Info_Choice.WriteCell(param1);
            switch (param2)
            {
                case 1:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    char Slot1Current[64];
                    char Slot2Current[64];
                    char Slot3Current[64];
                    PlayerSounds[param1].GetSlotName(0, Slot1Current, 64);
                    PlayerSounds[param1].GetSlotName(1, Slot2Current, 64);
                    PlayerSounds[param1].GetSlotName(2, Slot3Current, 64);
                    Format(Slot1Current, 64, "Current: %s", Slot1Current);
                    Format(Slot2Current, 64, "Current: %s", Slot2Current);
                    Format(Slot3Current, 64, "Current: %s", Slot3Current);

                    Panel SoundboardPanel = CreatePanel();
                    SoundboardPanel.SetTitle("Choose a slot:");
                    SoundboardPanel.DrawText(Slot1Current);
                    SoundboardPanel.DrawItem("Equip Slot 1");
                    SoundboardPanel.DrawText(" ");
                    SoundboardPanel.DrawText(Slot2Current);
                    SoundboardPanel.DrawItem("Equip Slot 2");
                    SoundboardPanel.DrawText(" ");
                    SoundboardPanel.DrawText(Slot3Current);
                    SoundboardPanel.DrawItem("Equip Slot 3");
                    SoundboardPanel.DrawText(" ");
                    SoundboardPanel.DrawItem("Sound Menu");
                    SoundboardPanel.DrawItem("Exit");
                    SoundboardPanel.Send(param1, SoundboardSlot_Handler, MENU_TIME_FOREVER);
                }
                case 2:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");

                    char CurrConnectSound[64];
                    char CurrDisconnectSound[64];
                    char CurrDeathSound[64];
                    PlayerSounds[param1].GetSlotName(3, CurrConnectSound, 64);
                    PlayerSounds[param1].GetSlotName(4, CurrDisconnectSound, 64);
                    PlayerSounds[param1].GetSlotName(5, CurrDeathSound, 64);
                    Format(CurrConnectSound, 64, "Current: %s", CurrConnectSound);
                    Format(CurrDisconnectSound, 64, "Current: %s", CurrDisconnectSound);
                    Format(CurrDeathSound, 64, "Current: %s", CurrDeathSound);

                    Panel ServerSoundPanel = CreatePanel();
                    ServerSoundPanel.SetTitle("Choose a slot:");
                    ServerSoundPanel.DrawText(CurrConnectSound);
                    ServerSoundPanel.DrawItem("Connect Sound");
                    ServerSoundPanel.DrawText(" ");
                    ServerSoundPanel.DrawText(CurrDisconnectSound);
                    ServerSoundPanel.DrawItem("Disconnect Sound");
                    ServerSoundPanel.DrawText(" ");
                    ServerSoundPanel.DrawText(CurrDeathSound);
                    ServerSoundPanel.DrawItem("Death Sound");
                    ServerSoundPanel.DrawText(" ");
                    ServerSoundPanel.DrawItem("Sound Menu");
                    ServerSoundPanel.DrawItem("Exit");
                    ServerSoundPanel.Send(param1, ServerSoundSlot_Handler, MENU_TIME_FOREVER);
                }
                case 3:
                {
                    EmitSoundToClient(param1, "buttons/button14.wav");
                    Info_Choice.Close()
                    BuildSoundPanel(param1);
                    return 0;
                }
                case 4:
                {
                    EmitSoundToClient(param1, "buttons/combine_button7.wav");
                    Info_Choice.Close();
                    delete menu;
                    return 0;
                }
            }

            char sQuery[512];
            Format(sQuery, 512, "SELECT SteamId, ItemId, SoundName FROM %sInventories WHERE SUBSTR(ItemId, 1, 4)=\'snd_\' AND SteamId=\'%s\' ORDER BY SoundName ASC", StoreSchema, SteamId);
            SQL_TQuery(DB_sntdb, SQL_GetPlayerSounds, sQuery, Info_Choice);
        }
    }
    return 0;
}

public int EquipMenu_Handler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char ChosenItem[64];
            GetMenuItem(menu, param2, ChosenItem, 64);

            char ItemSplit[2][64];
            ExplodeString(ChosenItem, ",", ItemSplit, 2, 64);
            int mode = StringToInt(ItemSplit[0]);

            DataPack Choice_Info = CreateDataPack();
            Choice_Info.WriteCell(param1);
            Choice_Info.WriteCell(mode);
            Choice_Info.WriteString(ItemSplit[1]);

            char sQuery[512];
            Format(sQuery, 512, "SELECT ItemId, SoundName, SoundFile, Cooldown FROM %ssounds", StoreSchema);
            SQL_TQuery(DB_sntdb, SQL_EquipSound, sQuery, Choice_Info);
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
        PrintToServer("[SNT] ERROR IN QUERY: %s", error);
    }
    
    CloseHandle(data);
}

public void SQL_GetPlayerSounds(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] Sounds: ERROR! DATABASE IS NULL");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] Sounds: ERROR: %s", error);
    }

    ResetPack(data);
    int client = ReadPackCell(data);
    int mode = ReadPackCell(data);

    char SteamId[64];
    Player[client].GetAuthId(SteamId, 64);

    Menu EquipMenu = new Menu(EquipMenu_Handler, MENU_ACTIONS_DEFAULT);
    EquipMenu.SetTitle("Choose a sound to equip!");

    while (SQL_FetchRow(results))
    {
        
        if (SQL_GetRowCount(results) < 1)
        {
            EquipMenu.AddItem("8,X", "Ye don't have any sounds to equip!", ITEMDRAW_DISABLED);
            EquipMenu.AddItem("8,STORE", "Ye can choose this, or type /tavern, to sail to the tavern!");
            EquipMenu.Display(client, 0);
            break;
        }
        else
        {
            char SQL_SteamId[64];
            SQL_FetchString(results, 0, SQL_SteamId, 64);

            char SQL_ItemId[64];
            char SQL_SoundName[64];
            SQL_FetchString(results, 1, SQL_ItemId, 64);
            SQL_FetchString(results, 2, SQL_SoundName, 64);
            switch(mode)
            {
                case 0:
                    Format(SQL_ItemId, 64, "0,%s", SQL_ItemId);
                case 1:
                    Format(SQL_ItemId, 64, "1,%s", SQL_ItemId);
                case 2:
                    Format(SQL_ItemId, 64, "2,%s", SQL_ItemId);
                case 3:
                    Format(SQL_ItemId, 64, "3,%s", SQL_ItemId);
                case 4:
                    Format(SQL_ItemId, 64, "4,%s", SQL_ItemId);
                case 5:
                    Format(SQL_ItemId, 64, "5,%s", SQL_ItemId);
            }
            EquipMenu.AddItem(SQL_ItemId, SQL_SoundName);
        }
    }

    EquipMenu.Display(client, 0);
    CloseHandle(data);
}

public void SQL_CheckForSoundItems(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] ERROR! DATABASE IS NULL!");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] ERROR CHECKING FOR CONNECTION SOUND: %s", error);
    }

    while (SQL_FetchRow(results))
    {
        char SQL_Item[64];
        SQL_FetchString(results, 0, SQL_Item, 64);

        if (StrEqual(SQL_Item, "srv_csnd"))
        {
            PlayerSounds[data].SetOwnsItem(0, true);
        }

        if (StrEqual(SQL_Item, "srv_dsnd"))
        {
            PlayerSounds[data].SetOwnsItem(1, true);
        }

        if (StrEqual(SQL_Item, "srv_spcs"))
        {
            PlayerSounds[data].SetOwnsItem(2, true);
        }
    }
}

public void SQL_EquipSound(Database db, DBResultSet results, const char[] error, any data)
{
    if (db == null)
    {
        PrintToServer("[SNT] Sounds: ERROR! DATABASE IS NULL");
    }

    if (!StrEqual(error, ""))
    {
        PrintToServer("[SNT] Sounds: ERROR: %s", error);
    }

    ResetPack(data);
    char SoundId[64];
    char SteamId[64];
    int client = ReadPackCell(data);
    int mode = ReadPackCell(data);
    GetClientAuthId(client, AuthId_Steam3, SteamId, 64);
    ReadPackString(data, SoundId, 64);
    CloseHandle(data);

    while (SQL_FetchRow(results))
    {
        char SQL_SoundId[64];
        char SQL_SoundName[64];
        char SQL_SoundFile[256];

        SQL_FetchString(results, 0, SQL_SoundId, 64);
        SQL_FetchString(results, 1, SQL_SoundName, 64);
        SQL_FetchString(results, 2, SQL_SoundFile, 256);

        if (StrEqual(SQL_SoundId, SoundId))
        {
            switch(mode)
            {
                case 0:
                {
                    char CurrentSlotChoice[64];
                    PlayerSounds[client].GetSlotId(0, CurrentSlotChoice, 64);

                    if (StrEqual(CurrentSlotChoice, SoundId))
                    {
                        PlayerSounds[client].SetSlotId(0, "NONE");
                        PlayerSounds[client].SetSlotName(0, "NONE");
                        PlayerSounds[client].SetSlotFile(0,"NONE");
                        PlayerSounds[client].SetSlotCooldown(0, 2.0);

                        CPrintToChat(client, "%s Sucessfully unequipped {greenyellow}%s {default}from your slot 1 sound!", Prefix, SQL_SoundName);
                    }
                    else
                    {
                        PlayerSounds[client].SetSlotId(0, SQL_SoundId);
                        PlayerSounds[client].SetSlotName(0, SQL_SoundName);
                        PlayerSounds[client].SetSlotFile(0, SQL_SoundFile);
                        PlayerSounds[client].SetSlotCooldown(0, SQL_FetchFloat(results, 3));

                        CPrintToChat(client, "%s Sucessfully equipped {greenyellow}%s {default}as your slot 1 sound!", Prefix, SQL_SoundName);
                    }
                    SetSlotCookies(client, 0);
                }
                case 1:
                {
                    char CurrentSlotChoice[64];
                    PlayerSounds[client].GetSlotId(1, CurrentSlotChoice, 64);

                    if (StrEqual(CurrentSlotChoice, SoundId))
                    {
                        PlayerSounds[client].SetSlotId(1, "NONE");
                        PlayerSounds[client].SetSlotName(1, "NONE");
                        PlayerSounds[client].SetSlotFile(1,"NONE");
                        PlayerSounds[client].SetSlotCooldown(1, 2.0);

                        CPrintToChat(client, "%s Sucessfully unequipped {greenyellow}%s {default}from your slot 2 sound!", Prefix, SQL_SoundName);
                    }
                    else
                    {
                        PlayerSounds[client].SetSlotId(1, SQL_SoundId);
                        PlayerSounds[client].SetSlotName(1, SQL_SoundName);
                        PlayerSounds[client].SetSlotFile(1, SQL_SoundFile);
                        PlayerSounds[client].SetSlotCooldown(1, SQL_FetchFloat(results, 3));

                        CPrintToChat(client, "%s Sucessfully equipped {greenyellow}%s {default}as your slot 2 sound!", Prefix, SQL_SoundName);
                    }
                    SetSlotCookies(client, 1);
                }
                case 2:
                {
                    char CurrentSlotChoice[64];
                    PlayerSounds[client].GetSlotId(2, CurrentSlotChoice, 64);

                    if (StrEqual(CurrentSlotChoice, SoundId))
                    {
                        PlayerSounds[client].SetSlotId(2, "NONE");
                        PlayerSounds[client].SetSlotName(2, "NONE");
                        PlayerSounds[client].SetSlotFile(2,"NONE");
                        PlayerSounds[client].SetSlotCooldown(2, 2.0);

                        CPrintToChat(client, "%s Sucessfully unequipped {greenyellow}%s {default}from your slot 3 sound!", Prefix, SQL_SoundName);
                    }
                    else
                    {
                        PlayerSounds[client].SetSlotId(2, SQL_SoundId);
                        PlayerSounds[client].SetSlotName(2, SQL_SoundName);
                        PlayerSounds[client].SetSlotFile(2, SQL_SoundFile);
                        PlayerSounds[client].SetSlotCooldown(2, SQL_FetchFloat(results, 3));

                        CPrintToChat(client, "%s Sucessfully equipped {greenyellow}%s {default}as your slot 3 sound!", Prefix, SQL_SoundName);
                    }
                    SetSlotCookies(client, 2);
                }
                case 3:
                {
                    char CurrentSlotChoice[64];
                    PlayerSounds[client].GetSlotId(3, CurrentSlotChoice, 64);

                    if (StrEqual(CurrentSlotChoice, SoundId))
                    {
                        PlayerSounds[client].SetSlotId(3, "NONE");
                        PlayerSounds[client].SetSlotName(3, "NONE");
                        PlayerSounds[client].SetSlotFile(3,"NONE");

                        CPrintToChat(client, "%s Sucessfully unequipped {greenyellow}%s {default}from your connect sound!", Prefix, SQL_SoundName);
                    }
                    else
                    {
                        PlayerSounds[client].SetSlotId(3, SQL_SoundId);
                        PlayerSounds[client].SetSlotName(3, SQL_SoundName);
                        PlayerSounds[client].SetSlotFile(3, SQL_SoundFile);

                        CPrintToChat(client, "%s Sucessfully equipped {greenyellow}%s {default}as your connect sound!", Prefix, SQL_SoundName);
                    }
                    SetSlotCookies(client, 3);
                }
                case 4:
                {
                    char CurrentSlotChoice[64];
                    PlayerSounds[client].GetSlotId(4, CurrentSlotChoice, 64);

                    if (StrEqual(CurrentSlotChoice, SoundId))
                    {
                        PlayerSounds[client].SetSlotId(4, "NONE");
                        PlayerSounds[client].SetSlotName(4, "NONE");
                        PlayerSounds[client].SetSlotFile(4,"NONE");

                        CPrintToChat(client, "%s Sucessfully unequipped {greenyellow}%s {default}from your disconnect sound!", Prefix, SQL_SoundName);
                    }
                    else
                    {
                        PlayerSounds[client].SetSlotId(4, SQL_SoundId);
                        PlayerSounds[client].SetSlotName(4, SQL_SoundName);
                        PlayerSounds[client].SetSlotFile(4, SQL_SoundFile);

                        CPrintToChat(client, "%s Sucessfully equipped {greenyellow}%s {default}as your disconnect sound!", Prefix, SQL_SoundName);
                    }
                    SetSlotCookies(client, 4);
                }
                case 5:
                {
                    char CurrentSlotChoice[64];
                    PlayerSounds[client].GetSlotId(5, CurrentSlotChoice, 64);

                    SQL_FetchString(results, 1, SQL_SoundName, 64);

                    if (StrEqual(CurrentSlotChoice, SoundId))
                    {
                        PlayerSounds[client].SetSlotId(5, "NONE");
                        PlayerSounds[client].SetSlotName(5, "NONE");
                        PlayerSounds[client].SetSlotFile(5,"NONE");

                        CPrintToChat(client, "%s Sucessfully unequipped {greenyellow}%s {default}from your death sound!", Prefix, SQL_SoundName);
                    }
                    else
                    {

                        char temp[64];
                        strcopy(temp, 64, SQL_SoundName);
                        PlayerSounds[client].SetSlotId(5, SQL_SoundId);
                        PlayerSounds[client].SetSlotName(5, SQL_SoundName);
                        PlayerSounds[client].SetSlotFile(5, SQL_SoundFile);

                        CPrintToChat(client, "%s Sucessfully equipped {greenyellow}%s {default}as your death sound!", Prefix, SQL_SoundName);
                    }
                    SetSlotCookies(client, 5);
                }
            }
            break;
        }
    }
}

public Action Timer_Cooldown(Handle timer, DataPack data)
{
    data.Reset()
    int client = data.ReadCell();
    int slot = data.ReadCell();

    switch (slot)
    {
        case 0:
            IsSlt1Cooldown[client] = false;
        case 1:
            IsSlt2Cooldown[client] = false;
        case 2:
            IsSlt3Cooldown[client] = false;
        case 3:
            IsChtCooldown[client] = false;
    }
    return Plugin_Continue;
}

public Action USR_PlaySlot1(int client, int args)
{
    if (GetClientTeam(client) == 1 && !PlayerSounds[client].GetOwnsItem(2))
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred} Ye can only play sounds while in spectator if ye get that from the {greenyellow}/tavern{default}!", Prefix);
        return Plugin_Handled;
    }

    if (IsSlt1Cooldown[client])
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred} Yer sound is on cooldown!", Prefix);
        return Plugin_Handled;
    }

    char SoundId[64];
    char SoundFile[256];
    float player_pos[3];

    GetClientAbsOrigin(client, player_pos);
    PlayerSounds[client].GetSlotFile(0, SoundFile, 256);
    PlayerSounds[client].GetSlotId(0, SoundId, 64);

    if (StrEqual(SoundId, "NONE"))
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred} Ye don't have a sound in slot 1 equipped! View yer {greenyellow}/treasure {fullred} or use {greenyellow}/sound {fullred}to view the sound menu!", Prefix);
    }
    else
    {
        IsSlt1Cooldown[client] = true;
        EmitAmbientSound(SoundFile, player_pos, client);
        float Cooldown;

        if (GetClientTeam(client) == 1)
        {
            Cooldown = 3.0;
        }
        else
        {
            Cooldown = PlayerSounds[client].GetSlotCooldown(0);
        }

        DataPack Timer_Info = CreateDataPack();
        CreateDataTimer(Cooldown, Timer_Cooldown, Timer_Info, TIMER_DATA_HNDL_CLOSE);
        Timer_Info.WriteCell(client);
        Timer_Info.WriteCell(0);
    }
    return Plugin_Handled;
}

public Action USR_PlaySlot2(int client, int args)
{
    if (GetClientTeam(client) == 1 && !PlayerSounds[client].GetOwnsItem(2))
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred} Ye can only play sounds while in spectator if ye get that from the {greenyellow}/tavern{default}!", Prefix);
        return Plugin_Handled;
    }

    if (IsSlt2Cooldown[client])
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred} Yer sound is on cooldown!", Prefix);
        return Plugin_Handled;
    }

    char SoundId[64];
    char SoundFile[256];
    float player_pos[3];

    GetClientAbsOrigin(client, player_pos);
    PlayerSounds[client].GetSlotFile(1, SoundFile, 256);
    PlayerSounds[client].GetSlotId(1, SoundId, 64);

    if (StrEqual(SoundId, "NONE"))
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred} Ye don't have a sound in slot 2 equipped! View yer {greenyellow}/treasure {fullred} or use {greenyellow}/sound {fullred}to view the sound menu!", Prefix);
    }
    else
    {
        IsSlt2Cooldown[client] = true;
        EmitAmbientSound(SoundFile, player_pos, client);
        float Cooldown;

        if (GetClientTeam(client) == 1)
        {
            Cooldown = 3.0;
        }
        else
        {
            Cooldown = PlayerSounds[client].GetSlotCooldown(1);
        }

        DataPack Timer_Info = CreateDataPack();
        CreateDataTimer(Cooldown, Timer_Cooldown, Timer_Info, TIMER_DATA_HNDL_CLOSE);
        Timer_Info.WriteCell(client);
        Timer_Info.WriteCell(1);
    }
    return Plugin_Handled;
}

public Action USR_PlaySlot3(int client, int args)
{
    if (GetClientTeam(client) == 1 && !PlayerSounds[client].GetOwnsItem(2))
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred} Ye can only play sounds while in spectator if ye get that from the {greenyellow}/tavern{default}!", Prefix);
        return Plugin_Handled;
    }

    if (IsSlt3Cooldown[client])
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred} Yer sound is on cooldown!", Prefix);
        return Plugin_Handled;
    }

    char SoundId[64];
    char SoundFile[256];
    float player_pos[3];

    GetClientAbsOrigin(client, player_pos);
    PlayerSounds[client].GetSlotFile(2, SoundFile, 256);
    PlayerSounds[client].GetSlotId(2, SoundId, 64);

    if (StrEqual(SoundId, "NONE"))
    {
        EmitSoundToClient(client, "snt_sounds/ypp_sting.mp3");
        CPrintToChat(client, "%s {fullred} Ye don't have a sound in slot 3 equipped! View yer {greenyellow}/treasure {fullred} or use {greenyellow}/sound {fullred}to view the sound menu!", Prefix);
    }
    else
    {
        IsSlt3Cooldown[client] = true;
        EmitAmbientSound(SoundFile, player_pos, client);
        float Cooldown;

        if (GetClientTeam(client) == 1)
        {
            Cooldown = 3.0;
        }
        else
        {
            Cooldown = PlayerSounds[client].GetSlotCooldown(2);
        }

        DataPack Timer_Info = CreateDataPack();
        CreateDataTimer(Cooldown, Timer_Cooldown, Timer_Info, TIMER_DATA_HNDL_CLOSE);
        Timer_Info.WriteCell(client);
        Timer_Info.WriteCell(2);
    }
    return Plugin_Handled;
}

public Action USR_OpenSoundSettings(int client, int args)
{
    BuildSoundPanel(client);
    return Plugin_Handled;
}

public Action ADM_GiveItem(int client, int args)
{
    for (int i = 1; i <= GetClientCount(); i++)
    {
        char SteamId[64];
        GetClientAuthId(i, AuthId_Steam3, SteamId, sizeof(SteamId));

        char iQuery[512];
        Format(iQuery, sizeof(iQuery), "INSERT INTO %splayeritems (SteamId, ItemId) VALUES (\'%s\', 'srv_csnd')", StoreSchema, SteamId);
        SQL_TQuery(DB_sntdb, SQL_ErrorHandler, iQuery);
    }
    return Plugin_Handled;
}