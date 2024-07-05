-- Change surf0 to the name of the server.

-- TABLES --

DROP TABLE IF EXISTS surf0votes;
DROP TABLE IF EXISTS surf0logs;
DROP TABLE IF EXISTS surf0playermaps;
DROP TABLE IF EXISTS surf0maps;
DROP TABLE IF EXISTS surf0players;


CREATE TABLE surf0players (
    SteamId     varchar(64),
    PlayerName  varchar(64)     NOT NULL,
    Points      decimal         DEFAULT 0,
    VotePerms   decimal         DEFAULT 1,
    PRIMARY KEY (SteamId)
);

CREATE TABLE surf0maps (
    MapName     varchar(64),
    EventId     varchar(15)     DEFAULT "evnt_none" NOT NULL,
    Rating1     int             DEFAULT 0,
    Rating2     int             DEFAULT 0,
    Rating3     int             DEFAULT 0,
    Rating4     int             DEFAULT 0,
    Rating5     int             DEFAULT 0,
    PRIMARY KEY (MapName)
);

CREATE TABLE surf0playermaps (
    SteamId     varchar(64),
    MapName     varchar(64)     NOT NULL,
    LastVote    int             DEFAULT 0,
    PRIMARY KEY (SteamId, MapName),
    FOREIGN KEY (SteamId) REFERENCES surf0players (SteamId),
    FOREIGN KEY (MapName) REFERENCES surf0maps (MapName)
);

CREATE TABLE surf0votes (
    DateCalled   varchar(64),
    VoterAuth    varchar(64),
    VoteeAuth    varchar(64),
    VoteType     varchar(12),
    VoterName    varchar(64),
    VoteeName    varchar(64),
    PRIMARY KEY (VoterAuth, DateCalled),
    FOREIGN KEY (VoterAuth) REFERENCES surf0players (SteamId),
    FOREIGN KEY (VoteeAuth) REFERENCES surf0players (SteamId)
);

CREATE TABLE surf0logs (
    DateSent    varchar(64),
    ChatterAuth varchar(64),
    ChatterName varchar(64),
    ChatMessage varchar(512),
    PRIMARY KEY (DateSent, ChatterAuth),
    FOREIGN KEY (ChatterAuth) REFERENCES surf0players(SteamId)
)

-- VIEWS --

CREATE OR REPLACE VIEW surf0MapRatings AS
SELECT VoteCount.MapName, SUM(SubmittedVotes) TotalVotes, CAST(((Rating1+Rating2+Rating3+Rating4+Rating5)/SUM(SubmittedVotes)) AS decimal(10, 2)) Stars
FROM (
    SELECT M.MapName, COUNT(DISTINCT SteamId) SubmittedVotes 
    FROM surf0maps M
        JOIN surf0playermaps PM
            ON M.MapName = PM.MapName
    GROUP BY M.MapName
) AS VoteCount
    JOIN surf0maps M
        ON VoteCount.MapName = M.MapName
GROUP BY VoteCount.MapName;


-- TRIGGERS --

delimiter $$

DROP TRIGGER IF EXISTS surf0CleanUpPlayer$$
DROP TRIGGER IF EXISTS surf0CleanUpMap$$

CREATE TRIGGER surf0CleanUpPlayer BEFORE DELETE ON surf0players FOR EACH ROW
BEGIN
    DELETE FROM surf0playermaps WHERE SteamId = old.SteamId;
END$$

CREATE TRIGGER surf0CleanUpMap BEFORE DELETE ON surf0maps FOR EACH ROW
BEGIN
    DELETE FROM surf0playermaps WHERE MapName = old.MapName;
END$$

delimiter ;