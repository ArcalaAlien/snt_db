-- STORE --
-- TABLES --
DROP TABLE IF EXISTS storeinventory;
DROP TABLE IF EXISTS storeplayeritems;
DROP TABLE IF EXISTS storeplayergroups;
DROP TABLE IF EXISTS storeserveritems;
DROP TABLE IF EXISTS storetrails;
DROP TABLE IF EXISTS storesounds;
DROP TABLE IF EXISTS storetags;
DROP TABLE IF EXISTS storecolors;
DROP TABLE IF EXISTS storegroups;
DROP TABLE IF EXISTS storeplayers;

CREATE TABLE storeplayers (
    SteamId     varchar(64),
    PlayerName  varchar(64)     NOT NULL,
    Credits     int             DEFAULT 750,
    PRIMARY KEY (SteamId)
);

CREATE TABLE storegroups (
    GroupNum    int             NOT NULL,
    GroupName   varchar(64)     NOT NULL,
    PRIMARY KEY (GroupNum)
);

CREATE TABLE storecolors(
    ColorId     varchar(64)     NOT NULL,
    ColorName   varchar(64)     NOT NULL,
    ColorType   varchar(12)     NOT NULL    DEFAULT "GREYSCALE",
    PackName    varchar(64)     NOT NULL    DEFAULT "DEFAULT",
    PRIMARY KEY(ColorId)
);

CREATE TABLE storesounds (
    ItemId      varchar(64),
    SoundName   varchar(64)     NOT NULL,
    SoundFile   varchar(260)    NOT NULL,
    Cooldown    float(3)        DEFAULT 2.0 NOT NULL,
    Owner       varchar(64)     DEFAULT "STORE" NOT NULL,
    Price       int             DEFAULT 0,
    PRIMARY KEY (ItemId)
);

CREATE TABLE storetrails (
    ItemId          varchar(64),
    TrailName       varchar(64)         NOT NULL,
    TextureVTF      varchar(260)        NOT NULL,
    TextureVMT      varchar(260)        NOT NULL,
    ModelIndex      int                 DEFAULT -1 NOT NULL,
    Owner           varchar(64)         DEFAULT "STORE" NOT NULL,
    Price           int                 DEFAULT 0,
    PRIMARY KEY (ItemId)
);

CREATE TABLE storeserveritems (
    ItemId      varchar(64),
    ItemName    varchar(64)     NOT NULL,
    ItemDesc    varchar(96)     NOT NULL,
    Owner       varchar(64)     DEFAULT "STORE" NOT NULL,
    Price       int             DEFAULT 0,
    PRIMARY KEY (ItemId)
);

CREATE TABLE storetags (
    ItemId          varchar(64),
    TagName			varchar(64) NOT NULL,
    DisplayName     varchar(64) NOT NULL,
    DisplayColor    varchar(64) NOT NULL,
    Owner           varchar(64) DEFAULT "STORE" NOT NULL,
    Price           int         DEFAULT 0,
    PRIMARY KEY (ItemId)
);

CREATE TABLE storeplayergroups (
    SteamId     varchar(64)     NOT NULL,
    GroupNum     int            NOT NULL,
    PRIMARY KEY (SteamId, GroupNum),
    FOREIGN KEY (SteamId)  REFERENCES storeplayers (SteamId),
    FOREIGN KEY (GroupNum) REFERENCES storegroups (GroupNum)
);

CREATE TABLE storeplayeritems (
    SteamId     varchar(64)     NOT NULL,
    ItemId      varchar(64)     NOT NULL,
    Donator     int             DEFAULT 0,
    PRIMARY KEY (SteamId, ItemId),
    FOREIGN KEY (SteamId) REFERENCES storeplayers (SteamId)
);

-- VIEWS --
DROP VIEW IF EXISTS storeInventories;
DROP VIEW IF EXISTS storeTopItems;
DROP VIEW IF EXISTS storeTopTags;
DROP VIEW IF EXISTS storeTopSounds;
DROP VIEW IF EXISTS storeTopTrails;

CREATE VIEW storeInventories AS
SELECT P.SteamId, PI.ItemId, P.PlayerName, TA.TagName, TA.DisplayName, TA.DisplayColor, S.SoundName, S.SoundFile, S.Cooldown, TR.TrailName, TR.ModelIndex, SI.ItemName, SI.ItemDesc
FROM storeplayers P
    JOIN storeplayeritems PI
        ON P.SteamId = PI.SteamId
            LEFT JOIN storetags TA
                ON PI.ItemId = TA.ItemId
            LEFT JOIN storesounds S
                ON PI.ItemId = S.ItemId
            LEFT JOIN storetrails TR
                ON PI.ItemId = TR.ItemId
            LEFT JOIN storeserveritems SI
                ON PI.ItemId = SI.ItemId;

CREATE VIEW storeTopItems AS
SELECT ItemId, DisplayName, SoundName, TrailName, ItemName, SUM(Buyers) TotalPurchased
FROM ( 
    SELECT PL.ItemId, TA.DisplayName, S.SoundName, TR.TrailName, SI.ItemName, COUNT(DISTINCT PL.SteamId) Buyers
    FROM storeplayeritems PL
        LEFT JOIN storetags TA
            ON PL.ItemId = TA.ItemId
        LEFT JOIN storesounds S
            ON PL.ItemId = S.ItemId
        LEFT JOIN storetrails TR
            ON PL.ItemId = TR.ItemId
        LEFT JOIN storeserveritems SI
            ON PL.ItemId = SI.ItemId
	WHERE TA.Owner='STORE' OR S.Owner='STORE' OR TR.Owner='STORE' OR SI.Owner='STORE'
) AS ItemCount
GROUP BY ItemId, DisplayName, SoundName, TrailName, ItemName;

CREATE VIEW storeTopTags AS
SELECT ItemId, SUM(Buyers) TotalPurchased
FROM ( 
    SELECT PL.ItemId, TA.DisplayName, COUNT(DISTINCT PL.SteamId) Buyers
    FROM storeplayeritems PL
        JOIN storetags TA
            ON PL.ItemId = TA.ItemId
	WHERE TA.Owner='STORE'
) AS TagCount
GROUP BY ItemId, DisplayName;

CREATE VIEW storeTopSounds AS
SELECT ItemId, SoundName, SUM(Buyers) TotalPurchased
FROM ( 
    SELECT PL.ItemId, S.SoundName, COUNT(DISTINCT PL.SteamId) Buyers
    FROM storeplayeritems PL
        JOIN storesounds S
            ON PL.ItemId = S.ItemId
	WHERE S.Owner='STORE'
) AS SoundCount
GROUP BY ItemId, SoundName;

CREATE VIEW storeTopTrails AS
SELECT ItemId, TrailName, SUM(Buyers) TotalPurchased
FROM ( 
    SELECT PL.ItemId, TR.TrailName, COUNT(DISTINCT PL.SteamId) Buyers
    FROM storeplayeritems PL
        JOIN storetrails TR
            ON PL.ItemId = TR.ItemId
	WHERE TR.Owner='STORE'
) AS TrailCount
GROUP BY ItemId, TrailName;

-- TRIGGERS --
DROP TRIGGER IF EXISTS storeGivePlayerDefaults;
DROP TRIGGER IF EXISTS storeGiveItemsForSupports;
DROP TRIGGER IF EXISTS storeGiveItemsForContributors;
DROP TRIGGER IF EXISTS storeGiveItemsForDonators;
DROP TRIGGER IF EXISTS storeRemoveDonatorPerks;
DROP TRIGGER IF EXISTS storeRemovePlayerFromDatabase;

delimiter $$

CREATE TRIGGER storeGivePlayerDefaults AFTER INSERT ON storeplayers FOR EACH ROW
BEGIN 
	INSERT INTO storeplayergroups VALUES (NEW.SteamId, 1);
    INSERT INTO storeplayeritems (SteamId, ItemId) VALUES (NEW.SteamId, "tag_news", 0), (NEW.SteamId, "tag_bgns", 0), (NEW.SteamId, "tag_ints", 0), (NEW.SteamId, "tag_exps", 0), (NEW.SteamId, "tag_msts", 0), (NEW.SteamId, "tag_pirt", 0), (NEW.SteamId, "clr_srcm", 0), (NEW.SteamId, "snd_yarr", 0), (NEW.SteamId, "trl_pflg", 0);
END$$

CREATE TRIGGER storeGiveItemsForSupporters AFTER INSERT ON storeplayergroups FOR EACH ROW
BEGIN
    IF (NEW.GroupNum = 2) THEN
        INSERT INTO storeplayeritems (SteamId, ItemId) VALUES (NEW.SteamId, "tag_erly", 0), (NEW.SteamId, "tag_hist", 0), (NEW.SteamId, "tag_frst", 0), (NEW.SteamId, "srv_rank", 0), (NEW.SteamId, "srv_mspm", 0);
	END IF;
END$$

CREATE TRIGGER storeGiveItemsForContributors AFTER INSERT ON storeplayergroups FOR EACH ROW
BEGIN
    IF (NEW.GroupNum = 3) THEN
			INSERT INTO storeplayeritems (SteamId, ItemId) VALUES (NEW.SteamId, "tag_erly", 0), (NEW.SteamId, "tag_hist", 0), (NEW.SteamId, "tag_frst", 0), (NEW.SteamId, "srv_rank", 0), (NEW.SteamId, "srv_mspm", 0);
	END IF;
END$$

CREATE TRIGGER storeGiveItemsForDonators AFTER INSERT ON storeplayergroups FOR EACH ROW
BEGIN
    IF (NEW.GroupNum = 4) THEN
			INSERT INTO storeplayeritems VALUES (NEW.SteamId, "tag_vip", 1), (NEW.SteamId, "tag_dnte", 1), (NEW.SteamId, "tag_rich", 1), (NEW.SteamId, "srv_mpsm", 1), (NEW.SteamId, "srv_rank", 1), (NEW.SteamId, "srv_cnme", 1), (NEW.SteamId, "srv_ccht", 1);
	END IF;
END$$

CREATE TRIGGER storeGiveServerSoundItems AFTER INSERT ON storeplayeritems FOR EACH ROW
BEGIN
    IF (NEW.ItemId = 'srv_ssnd') THEN
            INSERT INTO storeplayeritems VALUES (NEW.SteamId, "snd_srv_sting", 0), (NEW.SteamId, 'snd_srv_login', 0), (NEW.SteamId, 'snd_mspam_warn1', 0), (NEW.SteamId, 'snd_mspam_warn2', 0);
    END IF;
END$$

CREATE TRIGGER storeRemoveServerSoundItems BEFORE DELETE ON storeplayeritems FOR EACH ROW
BEGIN
    IF (OLD.ItemId = 'srv_ssnd') THEN
            DELETE FROM storeplayeritems WHERE SteamId=OLD.SteamId AND ItemId='snd_srv_sting';
            DELETE FROM storeplayeritems WHERE SteamId=OLD.SteamId and ItemId='snd_srv_login';
    END IF;
END$$

CREATE TRIGGER storeRemoveDonatorPerks BEFORE DELETE ON storeplayergroups FOR EACH ROW
BEGIN
    IF (OLD.GroupNum = 4) THEN
        DELETE FROM storeplayeritems
        WHERE SteamId=OLD.SteamId AND Donator=1;
    END IF;
END$$

CREATE TRIGGER storeRemovePlayerFromDatabase BEFORE DELETE ON storeplayers FOR EACH ROW
BEGIN
    DELETE FROM storeplayeritems WHERE SteamId=OLD.SteamId;
    DELETE FROM storeplayergroups WHERE SteamId=OLD.SteamId;
END$$

delimiter ;