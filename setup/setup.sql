-- Create Tables --

CREATE TABLE snt_players (
    SteamId     varchar(64),
    PlayerName  varchar(64)     NOT NULL,
    Points      int             DEFAULT 0,
    Credits     int             DEFAULT 250,
    PRIMARY KEY (SteamId)
);

CREATE TABLE snt_groups (
    GroupNum    int             NOT NULL,
    GroupName   varchar(64)     NOT NULL,
    PRIMARY KEY (GroupNum)
);

CREATE TABLE snt_tags (
    TagId           varchar(15),
    DisplayName     varchar(64) NOT NULL,
    DisplayColor    varchar(64) NOT NULL,
    Owner           varchar(64) DEFAULT "STORE" NOT NULL,
    Price           int         DEFAULT 0,
    PRIMARY KEY (TagId)
);

CREATE TABLE snt_sounds (
    SoundId     varchar(15),
    SoundName   varchar(64)     NOT NULL,
    SoundFile   varchar(260)    NOT NULL,
    Owner       varchar(64)     DEFAULT "STORE" NOT NULL,
    Price       int             DEFAULT 0,
    PRIMARY KEY (SoundId)
);

CREATE TABLE snt_trails (
    TrailId     varchar(15),
    TrailName   varchar(64)     NOT NULL,
    TextureFile varchar(260)    NOT NULL,
    Owner       varchar(64)     DEFAULT "STORE" NOT NULL,
    Price       int             DEFAULT 0,
    PRIMARY KEY (TrailId)
);

CREATE TABLE snt_serveritems (
    ItemId      varchar(15),
    ItemName    varchar(64)     NOT NULL,
    Price       int             DEFAULT 0,
    PRIMARY KEY (ItemId)
)

CREATE TABLE snt_maps (
    MapName     varchar(64),
    EventId     varchar(15)     DEFAULT "evnt_none" NOT NULL,
    Rating1     int             DEFAULT 0,
    Rating2     int             DEFAULT 0,
    Rating3     int             DEFAULT 0,
    Rating4     int             DEFAULT 0,
    Rating5     int             DEFAULT 0,
    PRIMARY KEY (MapName)
);

CREATE TABLE snt_playergroups (
    SteamId     varchar(64)     NOT NULL,
    GroupNum     int             NOT NULL,
    PRIMARY KEY (SteamId),
    FOREIGN KEY (SteamId)  REFERENCES snt_players (SteamId),
    FOREIGN KEY (GroupNum) REFERENCES snt_groups (GroupNum)
);

CREATE TABLE snt_playermaps (
    SteamId     varchar(64),
    MapName     varchar(64)     NOT NULL,
    LastVote    int             DEFAULT 0,
    PRIMARY KEY (SteamId),
    FOREIGN KEY (SteamId) REFERENCES snt_players (SteamId),
    FOREIGN KEY (MapName) REFERENCES snt_maps (MapName)
);

CREATE TABLE snt_playerinventory (
    SteamId     varchar(64)     NOT NULL,
    ItemId      varchar(64)     NOT NULL,
    PRIMARY KEY (SteamId),
    FOREIGN KEY (SteamId) REFERENCES snt_players (SteamId)
);

-- Create Views --

CREATE VIEW Top10Maps AS
SELECT VoteCount.MapName, SUM(SubmittedVotes) TotalVotes, CAST(((Rating1+Rating2+Rating3+Rating4+Rating5)/SubmittedVotes) AS decimal(2, 2)) Stars
FROM (
    SELECT MapName, COUNT(DISTINCT SteamId) SubmittedVotes 
    FROM snt_maps M
        JOIN snt_playermaps PM
            ON M.MapName = PM.MapName
    GROUP BY MapName
) AS VoteCount
    JOIN snt_maps M
        ON VoteCount.MapName = M.MapName
GROUP BY MapName
ORDER BY Stars ASC
LIMIT 10;

CREATE VIEW Bottom10Maps AS
SELECT VoteCount.MapName, SUM(SubmittedVotes) TotalVotes, CAST(((Rating1+Rating2+Rating3+Rating4+Rating5)/SubmittedVotes) AS decimal(2, 2)) Stars
FROM (
    SELECT MapName, COUNT(SteamId) SubmittedVotes 
    FROM snt_maps M
        JOIN snt_playermaps PM
            ON M.MapName = PM.MapName
    GROUP BY MapName
) AS VoteCount
    JOIN snt_maps M
        ON VoteCount.MapName = M.MapName
GROUP BY MapName
ORDER BY Stars DESC
LIMIT 10;

CREATE VIEW MapRatingInfo AS
SELECT VoteCount.MapName, SUM(SubmittedVotes) TotalVotes, CAST(((Rating1+Rating2+Rating3+Rating4+Rating5)/SubmittedVotes) AS decimal(2, 2)) Stars
FROM (
    SELECT MapName, COUNT(DISTINCT SteamId) SubmittedVotes 
    FROM snt_maps M
        JOIN snt_playermaps PM
            ON M.MapName = PM.MapName
    GROUP BY MapName
) AS VoteCount
    JOIN snt_maps M
        ON VoteCount.MapName = M.MapName
GROUP BY MapName
ORDER BY MapName;

CREATE VIEW Top10Items AS
SELECT ItemId, DisplayName, SoundName, TrailName, SUM(Buyers)
FROM ( 
    SELECT ItemId, DisplayName, SoundName, TrailName, COUNT(DISTINCT SteamId) Buyers
		FROM snt_playerinventory PL
			JOIN snt_tags TA
				ON PL.ItemId = TA.TagId
			JOIN snt_sounds S
				ON PL.ItemId = S.SoundId
			JOIN snt_trails TR
				ON PL.ItemId = TR.TrailId
	WHERE Owner='STORE'
)
GROUP BY ItemId, DisplayName, SoundName, TrailName
LIMIT 10;

CREATE VIEW Top10Tags AS
SELECT ItemId, DisplayName, SoundName, TrailName, SUM(Buyers)
FROM ( 
    SELECT ItemId, DisplayName, SoundName, TrailName, COUNT(DISTINCT SteamId) Buyers
		FROM snt_playerinventory PL
			JOIN snt_tags TA
				ON PL.ItemId = TA.TagId
	WHERE Owner='STORE'
)
GROUP BY ItemId, DisplayName, SoundName, TrailName
ORDER BY Buyers DESC
LIMIT 10;

CREATE VIEW Top10Sounds AS
SELECT ItemId, DisplayName, SoundName, TrailName, SUM(Buyers)
FROM ( 
    SELECT ItemId, DisplayName, SoundName, TrailName, COUNT(DISTINCT SteamId) Buyers
		FROM snt_playerinventory PL
			JOIN snt_sounds S
				ON PL.ItemId = S.SoundId
	WHERE Owner='STORE'
)
GROUP BY ItemId, DisplayName, SoundName, TrailName
ORDER BY Buyers DESC
LIMIT 10;

CREATE VIEW Top10Trails AS
SELECT ItemId, DisplayName, SoundName, TrailName, SUM(Buyers)
FROM ( 
    SELECT ItemId, DisplayName, SoundName, TrailName, COUNT(DISTINCT SteamId) Buyers
		FROM snt_playerinventory PL
			JOIN snt_trails TR
				ON PL.ItemId = TR.TrailId
	WHERE Owner='STORE'
)
GROUP BY ItemId, DisplayName, SoundName, TrailName
ORDER BY Buyers DESC
LIMIT 10;

-- Insert Values --

INSERT INTO snt_groups
VALUES
(1, "REGULAR"),
(2, "SUPPORTER"),
(3, "CONTRIBUTOR"),
(4, "DONATOR");

INSERT INTO snt_sounds (SoundId, SoundName, SoundFile, Price)
VALUES
("snd_bruh",    "Bruh",             "snt_sounds/bruh.mp3",              500),
("snd_crow",    "Crow",             "snt_sounds/crow.mp3",              250),
("snd_door",    "Open Door",        "snt_sounds/open_door.mp3",         1000),
("snd_gate",    "Open the Gates",   "snt_sounds/open_the_gates.mp3",    1000),
("snd_augh",    "Augh",             "snt_sounds/augh.mp3",              1000),
("snd_tada",    "Tada!!",           "snt_sounds/tada.mp3",              250),
("snd_fish",    "FISH",             "snt_sounds/fish.mp3",              500);

INSERT INTO snt_trails (TrailId, TrailName, TextureFile, Price)
VALUES
("trl_beam",     "Regular Beam",    "snt_trails/trail_01.vtf",     500),
("trl_weed",     "Weed Leaves",     "snt_trails/trail_02.vtf",     1000),
("trl_star",     "Stars",           "snt_trails/trail_03.vtf",     500),
("trl_dick",     "Dicks",           "snt_trails/trail_04.vtf",     1500),
("trl_psyc",     "Psychedelic",     "snt_trails/trail_05.vtf",     2000);

INSERT INTO snt_tags (TagId, DisplayName, DisplayColor, Price)
VALUES
("tag_frnd",    "[Friendly]",      "{community}",          750),
("tag_tryh",    "[Tryhard]",       "{goldenrod}",          750),
("tag_dj",      "[DJ]",            "{cornflowerblue}",     750),
("tag_weeb",    "[Weeb]",          "{lightsalmon}",       5000),
("tag_fury",    "[Furry]",         "{orchid}",            5000),
("tag_femb",    "[Femboy]",        "{deeppink}",          2500),
("tag_greg",    "[Greg]",          "{peru}",               750),
("tag_poli",    "[Politician]",    "{navy}",              7500),
("tag_frek",    "[Freak]",         "{indigo}",            1000),
("tag_chnk",    "[Chonker]",       "{lightsteelblue}",     750),
("tag_degn",    "[Degenerate]",    "{maroon}",            2500),
("tag_asin",    "[Assassin]",      "{darkslategray}",     1000),
("tag_god",     "[God]",           "{yellow}",            5000),
("tag_gdss",    "[Goddess]",       "{immortal}",          5000),
("tag_lord",    "[Lord]",          "{midnightblue}",      2500),
("tag_lady",    "[Lady]",          "{hotpink}",           2500),
("tag_sexy",    "[Sexy]",          "{fuschia}",           5000),
("tag_chkn",    "[Chicken]",       "{sienna}",             750),
("tag_alin",    "[Alien]",         "{lime}",               750),
("tag_stnr",    "[Stoner]",        "{forestgreen}",       2500),
("tag_alco",    "[Alcoholic]",     "{mediumpurple}",      2500),
("tag_hipp",    "[Hippie]",        "{lightpink}",         1000),
("tag_drug",    "[Druggie]",       "{palegoldenrod}",     2500),
("tag_mech",    "[Mechanic]",      "{steelblue}",          750),
("tag_goon",    "[Gooner]",        "{ghostwhite}",       10000),
("tag_snt",     "[SurfNTurf]",     "{mistyrose}",        10000);

INSERT INTO snt_tags (TagId, DisplayName, DisplayColor, Owner)
VALUES
("tag_awd_og",      "[OG]",                 "{collectors}",         "[U:1:129770678]"),
("tag_awd_fat",     "[Fattest Surfer]",     "{turquoise}",          "[U:1:105279633]"),
("tag_awd_twp",     "[twerp]",              "{darkorange}",         "[U:1:387291587]"),
("tag_news",    	"[New Surfer]",    		"{white}",              "REGULAR"),
("tag_bgns",    	"[Bgn Surfer]",    		"{lightgray}",          "REGULAR"),
("tag_ints",    	"[Int Surfer]",    		"{gray}",               "REGULAR"),
("tag_exps",    	"[Exp Surfer]",    		"{dimgray}",            "REGULAR"),
("tag_msts",    	"[Mst Surfer]",    		"{black}",              "REGULAR"),
("tag_erly",        "[Early Supporter]",    "{gold}",               "SUPPORTER"),
("tag_hist",        "[Historic]",           "{vintage}",            "SUPPORTER"),
("tag_frst",        "[First Day]",          "{silver}",             "SUPPORTER"),
("tag_cont",        "[Contributor]",        "{darkslateblue}",      "CONTRIBUTOR"),
("tag_desg",        "[Designer]",           "{lavenderblush}",      "CONTRIBUTOR"),
("tag_mapr",        "[Mapper]",             "{aquamarine}",         "CONTRIBUTOR"),
("tag_hlpr",        "[Helper]",             "{mediumaquamarine}",   "CONTRIBUTOR"),
("tag_vip",         "[VIP]",                "{darkviolet}",         "DONATOR"),
("tag_dnte",        "[Donator]",            "{immortal}",           "DONATOR"),
("tag_rich",        "[Rich]",               "{forestgreen}",        "DONATOR");

INSERT INTO snt_sounds (SoundId, SoundName, SoundFile, Owner)
VALUES
("snd_myst",    "Mystery",  "snt_sounds/eb_mystery.mp3",    "[U:1:115545346]");

-- Create Triggers --

delimiter $$

CREATE TRIGGER Give_Player_Defaults AFTER INSERT ON snt_players FOR EACH ROW
BEGIN 
	INSERT INTO snt_playergroup VALUES (NEW.SteamId, 1);
	INSERT INTO snt_playerinventory
	VALUES
	(NEW.SteamId, "tag_news"),
	(NEW.SteamId, "tag_bngs"),
	(NEW.SteamId, "tag_ints"),
	(NEW.SteamId, "tag_exps"),
	(NEW.SteamId, "tag_msts");
END$$

CREATE TRIGGER Give_Items_For_Group AFTER INSERT ON snt_playergroups FOR EACH ROW
BEGIN
	CASE NEW.GroupNum
		WHEN NEW.GroupNum = 2 THEN
			INSERT INTO snt_playerinventory
			VALUES
			(NEW.SteamId, "tag_erly"),
			(NEW.SteamId, "tag_hist"),
			(NEW.SteamId, "tag_frst");
		WHEN NEW.GroupNum = 3 THEN
			INSERT INTO snt_playerinventory
			VALUES
			(NEW.SteamId, "tag_cont"),
			(NEW.SteamId, "tag_desg"),
			(NEW.SteamId, "tag_mapr"),
			(NEW.SteamId, "tag_hlpr");
		WHEN NEW.GroupNum = 4 THEN
			INSERT INTO snt_playerinventory
			VALUES
			(new.SteamId, "tag_vip"),
			(new.SteamId, "tag_dnte"),
			(new.SteamId, "tag_rich");
	END CASE;
END$$

delimiter ;