CREATE TABLE webLogins (
    uid int NOT NULL AUTO_INCREMENT,
    username varchar(64) NOT NULL,
    password varchar(512) NOT NULL,
    PRIMARY KEY(uid)
) DEFAULT CHARSET=utf8;