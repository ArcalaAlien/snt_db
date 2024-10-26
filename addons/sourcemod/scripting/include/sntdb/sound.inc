#if defined _sntdb_sound_included_
    #endinput
#endif
#define _sntdb_sound_included_

public SharedPlugin __pl_sntdbsound = 
{
    name = "sntdb_sound",
    file = "sntdb/sntdb_sound.smx",
    #if defined REQUIRE_PLUGIN
        required = 1,
    #else
        required = 0,
    #endif
};

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

/**
 * 
 * Opens the sound menu for a client
 *
 * @param client    Client index
 */
native void SNT_OpenSoundMenu(int client);

/**
 * Open the sound equip menu for a client
 * 
 * @param client      Client Index
 */
native void SNT_OpenSoundEquip(int client);