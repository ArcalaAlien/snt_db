#define ICON_ON     "materials/icons/snt_mspam_on.vmt"
#define ICON_PAUSE  "materials/icons/snt_mspam_pause.vmt"
#define ICON_OFF    "materials/icons/snt_mspam_off.vmt"

enum struct SNT_Icon
{
    int index;
    bool isSpamming;

    // Create entity for client.
    int createSprite(int client)
    {
        if (SNT_IsValidClient(client))
        {
            // Get player origin for the sprite.
            float spriteOrigin[3];
            GetClientAbsOrigin(client, spriteOrigin);

            // Add 96hu to origin to raise the sprite above the player
            spriteOrigin[2] += 96.0;

            if (this.index == -1)
            {
                int entity = CreateEntityByName("env_sprite");
                switch (entity)
                {
                    case -1:
                    {
                        PrintToServer("[SNT] Unable to create env_sprite entity.");
                        return -1;
                    }

                    default:
                    {
                        // Set sprite name to mspam_<clientname>
                        char spriteName[144];
                        Format(spriteName, sizeof(spriteName), "mspam_%i", client);
                        if (!DispatchKeyValue(entity, "targetname", spriteName))
                            PrintToServer("[SNT] MICSPAM: Unable to set sprite name");

                        // Set sprite vmt to the off icon
                        if (!DispatchKeyValue(entity, "model", ICON_OFF))
                            PrintToServer("[SNT] MICSPAM: Unable to set env_sprite material to ICON_OFF");

                        // Set the scale of the sprite.
                        if (!DispatchKeyValueFloat(entity, "scale", 0.25))
                            PrintToServer("[SNT] MICSPAM: Unable to set env_sprite scale.");

                        // Set render mode to color
                        if (!DispatchKeyValueInt(entity, "rendermode", 5))
                            // PrintToServer("[SNT] MICSPAM: Unable to set env_sprite rendermode.");

                        if (DispatchSpawn(entity))
                        {
                            // Teleport entity to where it should be
                            TeleportEntity(entity, spriteOrigin);

                            // Parent it to the client.
                            SetVariantString("!activator");
                            AcceptEntityInput(entity, "SetParent", client);
                            CreateTimer(1.0, Timer_ShowSprite, entity);

                            // return the entity index.
                            //PrintToServer("[SNT] MICSPAM: Dispatching entity (%i)", entity);
                            return this.index;
                        }
                        else
                            PrintToServer("[SNT] MICSPAM: Unable to dispatch env_sprite");
                    }
                }
            }
            else
            {
                this.killSprite(client);
                this.createSprite(client);
            }
        }
        return -1;
    }

    bool killSprite(int client)
    {
        // Is client valid?
        if (SNT_IsValidClient(client))
            // Is the sprite valid?
            if (this.index != -1 && IsValidEdict(this.index))
            {
                // Kill the sprite.
                AcceptEntityInput(this.index, "Kill");
                return true;
            }
        
        // Not able to kill sprite.
        return false;
    }

    bool updateSprite(int client, int mode = 0)
    {
        if (SNT_IsValidClient(client))
            if (this.index != -1 && IsValidEdict(this.index))
            {
                if (this.isSpamming)
                {
                    switch (mode)
                    {
                        case 0:
                        {
                            AcceptEntityInput(this.index, "HideSprite");
                            DispatchKeyValue(this.index, "model", ICON_PAUSE);
                            CreateTimer(0.5, Timer_ShowSprite, this.index);
                        }
                        case 1:
                        {
                            AcceptEntityInput(this.index, "HideSprite");
                            DispatchKeyValue(this.index, "model", ICON_ON);
                            CreateTimer(0.5, Timer_ShowSprite, this.index);
                        }
                    }
                }
                else
                {
                    AcceptEntityInput(this.index, "HideSprite");
                    DispatchKeyValue(this.index, "model", ICON_OFF);
                    CreateTimer(0.5, Timer_ShowSprite, this.index);
                }
                return true;
            }
        return false;
    }

    void reset()
    {
        this.index = -1;
        this.isSpamming = false;
    }
}

public Action Timer_ShowSprite (Handle timer, any data)
{
    if (IsValidEdict(data))
        AcceptEntityInput(data, "ShowSprite");

    return Plugin_Handled;
}