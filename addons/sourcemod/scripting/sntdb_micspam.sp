public Plugin myinfo =
{
    name = "SNT Micspam Module",
    author = "Arcala the Gyiyg",
    description = "Handles the micspam queue and timers",
    version = "1.0.0",
    url = "https://github.com/ArcalaAlien/snt_db"
};

/*
Potential Micspam module?
    Players buy micspam ability from store
    While players have micspam ability equipped
        Player's voicechat gets muted
        Add player to bottom of micspam queue
        Move player through queue as other players spam / leave / unequip
        Player uses /start command to start spamming
        30 seconds to start or else player gets bumped to back of queue
        Player gets unmuted and has a 10 minute timer to play music.
        Players can end at any time by using /end
            Admins can end anyone's spam by using /end <name>
        Once player is done spamming mute them again, bump up queue. 

        CLOSING TIMERS DOES NOT FIRE THEM!!!!
*/

ArrayList MicspamQueue;


