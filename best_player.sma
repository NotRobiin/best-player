#include <amxmodx>
#include <colorchat>
#include <csx>

#define AUTHOR "Wicked - amxx.pl/user/60210-wicked/"

#pragma semicolon 1

#define ForPlayers(%1) for(new %1 = 1; %1 <= 32; %1++)
#define ForRange(%1,%2,%3) for(new %1 = %2; %1 <= %3; %1++)
#define ForArray(%1,%2) for(new %1 = 0; %1 < sizeof %2; %1++)

enum _:StatsEnumerator
{
    bool:stats_planted,
    bool:stats_defused
};

enum _:CsxStatsEnumerator
{
    csx_kills = 0,
    csx_headshots = 2,
    csx_shots_fired = 4,
    csx_shots_hit = 5,
    csx_damage = 6
};

enum (+= 1)
{
    message_type = 0,

    show_bomb,
    show_acc,

    hud_color_r,
    hud_color_g,
    hud_color_b,

    hud_pos_x,
    hud_pos_y,

    hud_hold
};

/*
    These go respectively:
        Name
        Default value
        Minimum value (Empty if not specified)
        Maximum value (Empty if not specified)
*/
new const CvarsData[][][] =
{
    { "mvp_info_type", "1", "0", "1" },

    { "mvp_show_bomb", "1", "0", "1" },
    { "mvp_show_acc", "1", "0", "1" },

    { "mvp_hud_r", "150", "0", "255" },
    { "mvp_hud_g", "150", "0", "255" },
    { "mvp_hud_b", "150", "0", "255" },

    { "mvp_hud_x", "0.0", "-1.0", "1.0" },
    { "mvp_hud_y", "0.5", "-1.0", "1.0" },

    { "mvp_hud_hold", "6.0", "0.1", "" }
};

new const ChatPrefix[] = "^x01[^x04MVP^x01]";
new const HudPrefix[] = "[MVP]";

new cvars[sizeof(CvarsData)],
    user_stats[33][StatsEnumerator];

public plugin_init()
{
    register_plugin("Round MVP", "v0.1", AUTHOR);

    register_logevent("RoundEnded", 2, "1=Round_End");

    register_cvars();
}

public RoundEnded()
{
    static player;
    
    player = get_round_mvp();

    // Invalid player id or player not connected.
    if(!is_user_connected(player))
    {
        reset_stats();

        return;
    }
    
    format_and_display_mvp(player);

    reset_stats();
}

/*
    [ Functions ]
*/
register_cvars()
{
    // Create cvars based on AMXX version.
    ForArray(i, CvarsData)
    {
        #if AMXX_VERSION_NUM > 183

        static bool:has_min,
            Float:min_value,
            bool:has_max,
            Float:max_value;

        has_min = bool:strlen(CvarsData[i][2]);
        has_max = bool:strlen(CvarsData[i][3]);

        min_value = has_min ? str_to_float(CvarsData[i][2]) : 0.0;
        max_value = has_max ? str_to_float(CvarsData[i][3]) : 0.0;

        cvars[i] = create_cvar(CvarsData[i][0], CvarsData[i][1], _, _, has_min, min_value, has_max, max_value);

        #else

        cvars[i] = register_cvar(CvarsData[i][0], CvarsData[i][1]);
        
        #endif
    }
}

// Outputs message of MVP.
// Does not check if given argument 'mvp' is valid.
format_and_display_mvp(mvp)
{
    static message[2 << 7],
        round_stats[8],
        blank[8],
        mvp_kills,
        mvp_headshots,
        mvp_accuracy,
        mvp_bomb;

    message = "";
    mvp_kills = round_stats[csx_kills];
    mvp_headshots = round_stats[csx_headshots];
    mvp_accuracy = 0;
    mvp_bomb = 0;

    get_user_rstats(mvp, round_stats, blank);

    // Bomb
    if(get_pcvar_num(cvars[show_bomb]))
    {
        if(user_stats[mvp][stats_defused])
        {
            mvp_bomb = 1;
        }
        else if(user_stats[mvp][stats_planted])
        {
            mvp_bomb = 2;
        }
    }

    // Accuracy
    if(get_pcvar_num(cvars[show_acc]))
    {
        mvp_accuracy = floatround(get_accuracy(round_stats[csx_shots_fired], round_stats[csx_shots_hit]));
    }

    // Do not print anything if the mvp
    // player did not kill anyone.
    if(!mvp_kills)
    {
        return;
    }

    switch(get_pcvar_num(cvars[message_type]))
    {
        // Colorchat
        case 0:
        {
            #if AMXX_VERSION_NUM > 183
            
            ColorChat(0, NORMAL, "%s^x01 Najlepszy gracz rundy:^x04 %n^x01.", ChatPrefix, mvp);

            #else

            new name[33];

            get_user_name(mvp, name, charsmax(name));

            ColorChat(0, NORMAL, "%s^x01 MVP:^x04 %s^x01.", ChatPrefix, name);

            #endif

            formatex(message, charsmax(message), "%s^x01 Fragow:^x04 %i^x01 HSow:^x04 %i^x01", ChatPrefix, mvp_kills, mvp_headshots);
            
            if(mvp_accuracy)
            {
                format(message, charsmax(message), "%s Celnosc:^x04 %i%%^x01", message, mvp_accuracy);
            }

            if(mvp_bomb)
            {
                format(message, charsmax(message), "%s Bomba:^x04 %s^x01", message, mvp_bomb == 1 ? "Rozbrojona" : "Podlozona");
            }

            ColorChat(0, NORMAL, message);
        }

        // Hud
        case 1:
        {
            static player_name[33],
                accuracy_message[33],
                bomb_message[33];
            
            accuracy_message = "";
            bomb_message = "";

            get_user_name(mvp, player_name, charsmax(player_name));

            // Add accuracy if enabled so.
            if(get_pcvar_num(cvars[show_acc]) && mvp_accuracy)
            {
                formatex(accuracy_message, charsmax(accuracy_message), "Celnosc: %i^%^n", mvp_accuracy);
            }

            // Add bomb if enabled so.
            if(get_pcvar_num(cvars[show_bomb]))
            {
                switch(mvp_bomb)
                {
                    case 1: formatex(bomb_message, charsmax(bomb_message), "Bomba: Rozbrojona^n");
                    case 2: formatex(bomb_message, charsmax(bomb_message), "Bomba: Podlozona^n");
                }
            }

            // Format entire message.
            formatex(message, charsmax(message),
                "%s^n\
                Gracz: %s^n\
                Fragow: %i^n\
                HSow: %i^n\
                %s\
                %s\
                %s",
                HudPrefix,
                player_name,
                mvp_kills,
                mvp_headshots,
                accuracy_message,
                bomb_message,
                HudPrefix);

            // Prepare hud.
            set_hudmessage(
                get_pcvar_num(cvars[hud_color_r]),
                get_pcvar_num(cvars[hud_color_g]),
                get_pcvar_num(cvars[hud_color_b]),
                get_pcvar_float(cvars[hud_pos_x]),
                get_pcvar_float(cvars[hud_pos_y]),
                0,
                0.1,
                get_pcvar_float(cvars[hud_hold]),
                0.1,
                0.2);
            show_hudmessage(0, message);
        }
    }
}

// Resets custom stats back to default value.
reset_stats()
{
    ForPlayers(i)
    {
        if(!is_user_connected(i))
        {
            continue;
        }
        
        ForRange(s, 0, StatsEnumerator - 1)
        {
            user_stats[i][s] = 0;
        }
    }
}

// Returns id of best player based on
// Kills, headshots and accuracy.
// Returns 0 if noone is present.
get_round_mvp()
{
    // Defines for easier static-arrays indexing.
    #define PLAYER 0
    #define BEST 1

    static best,
        best_stats[8],
        player_stats[8],
        blank[8],
        Float:accuracy[2];
    
    best = 0;

    ForPlayers(i)
    {
        if(!is_user_connected(i) || is_user_hltv(i))
        {
            continue;
        }

        // Best player not yet chosen, don't bother
        // checking the stats.
        if(!is_user_connected(best))
        {
            best = i;

            continue;
        }

        // Get both players stats.
        get_user_rstats(best, best_stats, blank);
        get_user_rstats(i, player_stats, blank);

        // Calculate accuracy.
        accuracy[PLAYER] = get_accuracy(player_stats[csx_shots_fired], player_stats[csx_shots_hit]);
        accuracy[BEST] = get_accuracy(best_stats[csx_shots_fired], best_stats[csx_shots_hit]);

        // Check kills.
        if(player_stats[csx_kills] < best_stats[csx_kills])
        {
            continue;
        }

        // Check who got more headshots, if they
        // both had the same amount of kills.
        if(player_stats[csx_kills] == best_stats[csx_kills] && player_stats[csx_headshots] < best_stats[csx_headshots])
        {
            continue;
        }

        // Check which one had better accuracy, if they
        // both had the same amount of headshots.
        if(player_stats[csx_headshots] == best_stats[csx_headshots] && accuracy[PLAYER] < accuracy[BEST])
        {
            continue;
        }

        // Assign new best player.
        best = i;
    }

    return best;
}

// Returns accuracy in float.
Float:get_accuracy(shots_fired, shots_hit)
{
    if(!shots_fired || !shots_hit)
    {
        return 0.0;
    }

    return (100.0 * shots_hit / shots_fired);
}