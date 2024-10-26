// Settings
enum struct PSettings
{
    // Colors for displaying ranks before client names. Places NONE - 3rd, plus default color.
    char pl0clr[32];
    char pl1clr[32];
    char pl2clr[32];
    char pl3clr[32];
    char pldclr[32];

    // Red and blu team's colors. Used to color names in chat.
    char rtmclr[32];
    char btmclr[32];

    // How many points per kill, assist, and assist if you're med.
    float pntkill;
    float pntasst;
    float pntasstmed;

    // How many credits per kill, assist, and assist if you're med.
    int credKill;
    int credAssist;
    int credAssistMed;

    void GetPlaceColor(int place = 0, char[] buffer, int maxlen)
    {
        switch (place)
        {
            case 0:
                strcopy(buffer, maxlen, this.pl0clr);
            case 1:
                strcopy(buffer, maxlen, this.pl1clr);
            case 2:
                strcopy(buffer, maxlen, this.pl2clr);
            case 3:
                strcopy(buffer, maxlen, this.pl3clr);
            default:
                strcopy(buffer, maxlen, this.pldclr);
        }
    }

    void GetTeamColor(int team, char[] buffer, int maxlen)
    {
        switch (team)
        {
            case 2:
                strcopy(buffer, maxlen, this.rtmclr);
            case 3:
                strcopy(buffer, maxlen, this.btmclr);
        }
    }

    float GetKillPts()
    {
        return this.pntkill;
    }

    float GetAsstPts()
    {
        return this.pntasst;
    }

    float GetAsstPtsMed()
    {
        return this.pntasstmed;
    }

    int GetKillCredits()
    {
        return this.credKill;
    }

    int GetAssistCredits()
    {
        return this.credAssist;
    }

    int GetAssistMedCredits()
    {
        return this.credAssistMed;
    }

    void SetPlaceColor(int place, char[] color)
    {
        switch (place)
        {
            case 0:
                strcopy(this.pl0clr, 32, color);
            case 1:
                strcopy(this.pl1clr, 32, color);
            case 2:
                strcopy(this.pl2clr, 32, color);
            case 3:
                strcopy(this.pl3clr, 32, color);
            default:
                strcopy(this.pldclr, 32, color);
        }
    }

    void SetTeamColor(int team, char[] color)
    {
        switch (team)
        {
            case 2:
                strcopy(this.rtmclr, 32, color);
            case 3:
                strcopy(this.btmclr, 32, color);
        }
    }

    void SetKillPts(float points)
    {
        this.pntkill = points;
    }

    void SetAsstPts(float points)
    {
        this.pntasst = points;
    }

    void SetAsstPtsMed(float points)
    {
        this.pntasstmed = points;
    }

    void SetKillCredits(int credits)
    {
        this.credKill = credits;
    }

    void SetAssistCredits(int credits)
    {
        this.credAssist = credits;
    }

    void SetAssistMedCredits(int credits)
    {
        this.credAssistMed = credits;
    }
}

enum struct KSSettings
{

    // Level 1 - 4 Display. EG: 'Player is %s' where %s is l1-4
    char l1[32];
    char l2[32];
    char l3[32];
    char l4[32];

    // The color to display %s above in
    char l1c[32];
    char l2c[32];
    char l3c[32];
    char l4c[32];

    // The amount of kills to get to each level.
    int l1k;
    int l2k;
    int l3k;
    int l4k;

    // Each level's point modifier.
    float l1m;
    float l2m;
    float l3m;
    float l4m;

    int cMultiL1;
    int cMultiL2;
    int cMultiL3;
    int cMultiL4;

    void GetLevelDisplay(int level, char[] buffer, int maxlen)
    {
        switch (level)
        {
            case 1:
                strcopy(buffer, maxlen, this.l1);
            case 2:
                strcopy(buffer, maxlen, this.l2);
            case 3:
                strcopy(buffer, maxlen, this.l3);
            case 4:
                strcopy(buffer, maxlen, this.l4);
        }
    }

    void GetLevelColor(int level, char[] buffer, int maxlen)
    {
        switch (level)
        {
            case 1:
                strcopy(buffer, maxlen, this.l1c);
            case 2:
                strcopy(buffer, maxlen, this.l2c);
            case 3:
                strcopy(buffer, maxlen, this.l3c);
            case 4:
                strcopy(buffer, maxlen, this.l4c);
        }
    }

    int GetKillsForLevel(int level)
    {
        switch (level)
        {
            case 1:
                return this.l1k;
            case 2:
                return this.l2k;
            case 3:
                return this.l3k;
            case 4:
                return this.l4k;
            default:
                return this.l1k;
        }
    }

    float GetMultiplier(int level)
    {
        switch (level)
        {
            case 1:
                return this.l1m;
            case 2:
                return this.l2m;
            case 3:
                return this.l3m;
            case 4:
                return this.l4m;
            default:
                return this.l1m;
        }
    }

    int GetCreditMulti(int level)
    {
        switch (level)
        {
            case 1:
                return this.cMultiL1;
            case 2:
                return this.cMultiL2;
            case 3:
                return this.cMultiL3;
            case 4:
                return this.cMultiL4;
            default:
                return this.cMultiL1;
        }
    }

    void SetLevelDisplay(int level, char[] display)
    {
        switch (level)
        {
            case 1:
                strcopy(this.l1, 32, display);
            case 2:
                strcopy(this.l2, 32, display);
            case 3:
                strcopy(this.l3, 32, display);
            case 4:
                strcopy(this.l4, 32, display);
            default:
                strcopy(this.l1, 32, display);
        }
    }

    void SetLevelColor(int level, char[] color)
    {
        switch (level)
        {
            case 1:
                strcopy(this.l1c, 32, color);
            case 2:
                strcopy(this.l2c, 32, color);
            case 3:
                strcopy(this.l3c, 32, color);
            case 4:
                strcopy(this.l4c, 32, color);
            default:
                strcopy(this.l1c, 32, color);
        }
    }

    void SetKillsForLevel(int level, int amt)
    {
        switch (level)
        {
            case 1:
                this.l1k = amt;
            case 2:
                this.l2k = amt;
            case 3:
                this.l3k = amt;
            case 4:
                this.l4k = amt;
            default:
                this.l1k = amt;
        }
    }

    void SetMultiplier(int level, float multi)
    {
        switch (level)
        {
            case 1:
                this.l1m = multi;
            case 2:
                this.l2m = multi;
            case 3:
                this.l3m = multi;
            case 4:
                this.l4m = multi;
            default:
                this.l1m = multi;
        }
    }

    void SetCreditMulti(int level, int multi)
    {
        switch (level)
        {
            case 1:
                this.cMultiL1 = multi;
            case 2:
                this.cMultiL2 = multi;
            case 3:
                this.cMultiL3 = multi;
            case 4:
                this.cMultiL4 = multi;
            default:
                this.cMultiL1 = 1;
        }
    }
}

/**
 *  Add a specified amount of points to a client.
 * 
 *  @param client   Client to add points too
 *  @param points   Amount of points to add
 */
native void SNT_AddPoints(int client, float points);