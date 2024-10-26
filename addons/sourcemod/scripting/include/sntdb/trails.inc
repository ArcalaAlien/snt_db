#if defined _sntdb_trails_included_
    #endinput
#endif
#define _sntdb_trails_included_

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

public SharedPlugin __pl_sntdbtrails = 
{
    name = "sntdb_trails",
    file = "sntdb/sntdb_trails.smx",
    #if defined REQUIRE_PLUGIN
        required = 1,
    #else
        required = 0,
    #endif
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

/**
 * Opens the trail menu for a client.
 * 
 * @param client    Client Index
 */
native void SNT_OpenTrailMenu(int client);

/**
 * Open's the equip menu for a client.
 *
 * @param client    Client Index
 */
native void SNT_OpenTrailEquip(int client);

/**
 * Sends if a player is displaying their tag
 * 
 * @param client    Client index
 * 
 * @return bool
 */
native bool SNT_SendPlayerTagBool(int client);


