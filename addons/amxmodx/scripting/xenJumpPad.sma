/*
*
*	Xen Jump Pad by RedSMURF
*
*
*	Description:
*
*	Cvars:
*		None
*
*	Commands:
*       say /xenjump                     "Opens the Xen Jump Pad menu."
*       say_team /xenjump                "Opens the Xen Jump Pad menu."
*       xenjump_reload                   "Reloads the configuration file."
*
*	Changelog:
*       v1.0: Initial release.
*       v1.1: Fixed the model, added different sizes, added usage per team
*
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#if !defined MAX_PLAYERS
    #define MAX_PLAYERS 32
#endif

#if !defined MAX_VALUE_LENGTH
    #define MAX_VALUE_LENGTH 64
#endif

#if !defined MAX_RESOURCE_PATH_LENGTH
    #define MAX_RESOURCE_PATH_LENGTH 128
#endif

#if !defined MAX_FILE_CELL_SIZE
    #define MAX_FILE_CELL_SIZE 192
#endif

#if !defined MAX_PLATFORM_PATH_LENGTH
    #define MAX_PLATFORM_PATH_LENGTH 256
#endif

#define MAX_ENT             32
#define ADMIN_ACCESS        ADMIN_RCON
#define PAD_KEY             114477
#define PAD_ARRAY_ITEM      pev_iuser1
#define PAD_SEQ_ACTIVE      0
#define PAD_SEQ_RETURN      1
#define SOUND_NAV           "buttons/blip1.wav"
#define SOUND_REMOVE        "buttons/button10.wav"
#define SOUND_ALERT         "buttons/bell1.wav"

new const PLUGIN_VERSION[]          = "1.0"
new const Float:DELAY_ON_CONNECT    = 1.0
new const Float:DELAY_ON_LOAD       = 1.0
new const ERROR_FILE[]              = "XenJumpPad_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS,
    SECTION_PAD
}

enum
{
    DTYPE_INT,
    DTYPE_INT_RANGE,
    DTYPE_FLOAT,
    DTYPE_FLOAT_RANGE,
    DTYPE_INT_LIST,
    DTYPE_FLOAT_LIST,
    DTYPE_BOOL,
    DTYPE_FLAGS,
    DTYPE_ARRAY_STRING,
    DTYPE_ARRAY_SOUND,
    DTYPE_STRING_MODEL,
    DTYPE_STRING_SOUND,
    DTYPE_STRING_MODEL_ID
}

enum
{
    FLAG_ACTIVE_DELAY       = (1 << 0),
    FLAG_ACTIVE_DURATION    = (1 << 1),
    FLAG_PLAYERS_ONLY       = (1 << 2),

    FLAG_SHOW               = (1 << 3),
    FLAG_GHOST              = (1 << 4),
    FLAG_GROUND             = (1 << 5),
    FLAG_ACTIVE             = (1 << 7),
    FLAG_PENDING            = (1 << 8)
}

enum
{
    ROTATE_MODE_PITCH,
    ROTATE_MODE_YAW,
    ROTATE_MODE_ROLL
}

enum
{
    TEAM_NONE,
    TEAM_T,
    TEAM_CT,
    TEAM_BOTH
}

enum
{
    SIZE_SMALL,
    SIZE_MEDIUM,
    SIZE_LARGE
}

enum
{
    TARGET_GHOST,
    TARGET_SELECT,
    TARGET_HIDE,
    TARGET_CLEAR
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_FLAGS,
    SETTING_DEFAULT_TEAM,
    Float:SETTING_DEFAULT_FRAMERATE,
    Float:SETTING_DEFAULT_SPAWN_CHANCE,
    Float:SETTING_DEFAULT_ACTIVE_DELAY[2],
    Float:SETTING_DEFAULT_ACTIVE_DURATION[2],
    Float:SETTING_DEFAULT_ACTIVE_COOLDOWN[2],
    Float:SETTING_DEFAULT_RADIUS,
    Float:SETTING_DEFAULT_RADIUS_OFFSET,
    Float:SETTING_DEFAULT_STRENGTH[2],
    Float:SETTING_DEFAULT_COOLDOWN[2],
    Float:SETTING_DEFAULT_FRAMERATE,

    SETTING_MODEL_SMALL[MAX_RESOURCE_PATH_LENGTH],
    SETTING_MODEL_MEDIUM[MAX_RESOURCE_PATH_LENGTH],
    SETTING_MODEL_LARGE[MAX_RESOURCE_PATH_LENGTH],
    Float:SETTING_MINS_SMALL[3],
    Float:SETTING_MAXS_SMALL[3],
    Float:SETTING_MINS_MEDIUM[3],
    Float:SETTING_MAXS_MEDIUM[3],
    Float:SETTING_MINS_LARGE[3],
    Float:SETTING_MAXS_LARGE[3],
    Float:SETTING_TRIGGER_RADIUS[3],
    Float:SETTING_TRIGGER_OFFSET[3],
    Array:SETTING_SOUND_JUMP,

    bool:SETTING_PAD_LOAD,
    Float:SETTING_PAD_CHECK,
    Float:SETTING_PAD_TASK,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET[2],
    Float:SETTING_OFFSET_STEP,
    SETTING_GHOST_ALPHA,
    Float:SETTING_ROTATION_STEP
}

enum _:PAD
{
    PAD_ID,
    PAD_ITEM,
    PAD_FLAGS,
    PAD_TEAM,
    PAD_SIZE,
    PAD_NAME[MAX_VALUE_LENGTH],
    PAD_MODEL[MAX_RESOURCE_PATH_LENGTH],

    Float:PAD_ORIGIN[3],
    Float:PAD_ANGLES[3],
    Float:PAD_MINS[3],
    Float:PAD_MAXS[3],
    Float:PAD_DIRECTION[3],

    Float:PAD_SPAWN_CHANCE,
    Float:PAD_ACTIVE_DELAY[2],
    Float:PAD_ACTIVE_DURATION[2],
    Float:PAD_ACTIVE_COOLDOWN[2],
    Float:PAD_TRIGGER_ORIGIN[3],
    Float:PAD_TRIGGER_RADIUS,
    Float:PAD_TRIGGER_OFFSET,
    Float:PAD_STRENGTH[2],
    Float:PAD_COOLDOWN[2],
    Float:PAD_FRAMERATE,

    Float:PAD_NEXT_ENABLE,
    Float:PAD_NEXT_DISABLE
}

enum _:PLAYER_DATA
{
    PDATA_PAD_GHOST,
    PDATA_PAD_MENU,
    bool:PDATA_PAD_ACTION,
    PDATA_ROTATE_MODE,
    PDATA_ROTATE_SIZE,
    Float:PDATA_OFFSET,
    Float:PDATA_NEXT_OFFSET,

    PDATA_MENU_TYPE,
    bool:PDATA_MENU_TRACE
}

enum
{
    SOUND_MENU_NAV,
    SOUND_MENU_REMOVE,
    SOUND_MENU_ALERT,
    SOUND_JUMP
}

enum
{
    MENU_ROOT,
    MENU_CREATE,
    MENU_EDIT,
    MENU_REMOVE,
    MENU_SHOW,
    MENU_STATUS,
    MENU_ROTATE
}

enum
{
    ROOT_CREATE,
    ROOT_EDIT,
    ROOT_REMOVE,
    ROOT_SAVE,

    ROOT_NOCLIP = 5,
    ROOT_GODMODE
}

enum
{
    EDIT_SHOW,
    EDIT_STATUS
}

enum
{
    REMOVE_NEXT,
    REMOVE_BACK,

    REMOVE_CURRENT = 3,
    REMOVE_ALL
}

enum
{
    SHOW_NEXT,
    SHOW_BACK,

    SHOW_CURRENT = 3,
    SHOW_ALL_SHOW,
    SHOW_ALL_HIDE
}

enum
{
    STATUS_NEXT,
    STATUS_BACK,

    STATUS_CURRENT = 3,
    STATUS_ALL_ENABLE,
    STATUS_ALL_DISABLE
}

enum
{
    ROTATE_UP,
    ROTATE_DOWN,

    ROTATE_GROUND = 3,
    ROTATE_MODE,
    ROTATE_SIZE,
    ROTATE_PLACE
}

new Float:g_fDirections[][] =
{
    {-1.0, 0.0, 0.0},
    {1.0, 0.0, 0.0},
    {0.0, -1.0, 0.0},
    {0.0, 1.0, 0.0},
    {0.0, 0.0, -1.0},
    {0.0, 0.0, 1.0}
}

new g_szMenuHandler[][MAX_VALUE_LENGTH] =
{
    "menuHandlerRoot",
    "menuHandlerCreate",
    "menuHandlerEdit",
    "menuHandlerRemove",
    "menuHandlerShow",
    "menuHandlerStatus",
    "menuHandlerRotate"
}

new g_szCN[] = "xen_jumppad"

new Array:g_aPad,
    Array:g_aPadConfig,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    bool:g_bFileWasRead, g_iActivePlayers,
    g_iFwdUpdateClientData, HamHook:g_iFwdSpawn, HamHook:g_iFwdPreThink, HamHook:g_iFwdKilled,
    g_iPad, g_iPadConfig,
    g_iMaxPlayers

new const g_iColorActive[] = { 0, 255, 0 }
new const g_iColorInactive[] = { 255, 0, 0 }
new g_szRotateMode[][] = {"PAD_ROTATE_PITCH", "PAD_ROTATE_YAW", "PAD_ROTATE_ROLL"}
new g_szRotateSize[][] = {"PAD_ROTATE_SMALL", "PAD_ROTATE_MEDIUM", "PAD_ROTATE_LARGE"}

public plugin_init()
{
    register_plugin("Xen Jump Pad", PLUGIN_VERSION, "RedSMURF")
    register_cvar("RedSMURF_XenJumpPad", PLUGIN_VERSION, ADMIN_ACCESS)

    register_clcmd("say /xenjump",         "cmdMenu", ADMIN_RCON, "-- Opens the Xen Jump Pad menu.")
    register_clcmd("say_team /xenjump",    "cmdMenu", ADMIN_RCON, "-- Opens the Xen Jump Pad menu.")
    register_concmd("xenjump_reload",    "cmdReload", ADMIN_RCON, "-- Reloads the configuration file")
    register_dictionary("XenJumpPad.txt")

    g_iFwdUpdateClientData = register_forward(FM_UpdateClientData, "fwdUpdateClientData", 1)
    g_iFwdSpawn = RegisterHam(Ham_Spawn, "info_target", "fwdSpawn", 1)
    g_iFwdPreThink = RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink")
    g_iFwdKilled = RegisterHam(Ham_Killed, "player", "fwdKilled", 1)
    register_logevent("eventRoundStart", 2, "1=Round_Start")
    DisableForward()

    padInit()
    g_iMaxPlayers = get_maxplayers()
}

public plugin_precache()
{
    g_aPad = ArrayCreate(PAD)
    g_aPadConfig = ArrayCreate(PAD)
    g_eSettings[SETTING_SOUND_JUMP] = ArrayCreate(MAX_RESOURCE_PATH_LENGTH)

    ReadFile()
}

public plugin_end()
{
    ArrayDestroy(g_aPad)
    ArrayDestroy(g_aPadConfig)
    ArrayDestroy(g_eSettings[SETTING_SOUND_JUMP])
}

public cmdMenu(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    padSound(id, SOUND_MENU_NAV)
    padMenu(id, MENU_ROOT)

    return PLUGIN_HANDLED
}

public cmdReload(id, iLevel, iCmd)
{
    if ( !cmd_access(id, iLevel, iCmd, 1) )
        return PLUGIN_HANDLED

    ReadFile()
    console_print(id, "The configuration file has been reloaded successfully !")

    return PLUGIN_HANDLED
}

public eventRoundStart()
{
    if ( !g_iPad )
        return PLUGIN_HANDLED

    new ePad[PAD]

    for ( new i = 0; i < g_iPad; i ++ )
    {
        ArrayGetArray(g_aPad, i, ePad)
        if ( !(ePad[PAD_FLAGS] & FLAG_SHOW) )
            continue

        padReset(ePad)
        if ( ePad[PAD_SPAWN_CHANCE] >= random_float(0.0, 1.0) )
        {
            ePad[PAD_FLAGS] |= (FLAG_SHOW | FLAG_ACTIVE)

            padSetDelay(ePad)
            padSetState(ePad)
        }

        ArraySetArray(g_aPad, i, ePad)
    }

    return PLUGIN_HANDLED
}

ReadFile()
{
    if ( g_bFileWasRead )
    {
        for ( new id = 1; id <= g_iMaxPlayers; id ++ )
            if ( is_user_connected(id))
                UpdateData(id)

        ArrayClear(g_eSettings[SETTING_SOUND_JUMP])
        ArrayClear(g_aPadConfig)
        g_iPadConfig = 0
    }

    new g_szFileName[MAX_RESOURCE_PATH_LENGTH]
    get_configsdir(g_szFileName, charsmax(g_szFileName))
    add(g_szFileName, charsmax(g_szFileName), "/XenJumpPad.ini")

    new iFile
    iFile = fopen(g_szFileName, "rt")

    if ( !iFile )
    {
        set_fail_state("An error occured during the opening of the configuration file !")
    }

    new szData[MAX_FILE_CELL_SIZE], szKey[MAX_VALUE_LENGTH], szValue[MAX_VALUE_LENGTH],
        ePad[PAD], iSection = SECTION_NONE, iLine, iPos

    while( !feof(iFile) )
    {
        iLine ++
        fgets(iFile, szData, charsmax(szData))
        trim(szData)

        switch( szData[0] )
        {
            case EOS, ';', '#':
            {
                continue
            }
            case '[':
            {
                if ( szData[strlen(szData) - 1] == ']' )
                {
                    replace(szData, charsmax(szData), "[", "")
                    replace(szData, charsmax(szData), "]", "")
                    trim(szData)

                    if ( equali(szData, "Main Settings") )
                    {
                        iSection = SECTION_MAIN_SETTINGS
                    }
                    else
                    {
                        if ( g_iPadConfig )
                            ArrayPushArray(g_aPadConfig, ePad)

                        copy(ePad[PAD_NAME], charsmax(ePad[PAD_NAME]), szData)
                        ePad[PAD_FLAGS]               = g_eSettings[SETTING_DEFAULT_FLAGS]
                        ePad[PAD_TEAM]                = g_eSettings[SETTING_DEFAULT_TEAM]
                        ePad[PAD_FRAMERATE]           = g_eSettings[SETTING_DEFAULT_FRAMERATE]
                        ePad[PAD_SPAWN_CHANCE]        = g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE]
                        ePad[PAD_ACTIVE_DELAY][0]     = g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][0]
                        ePad[PAD_ACTIVE_DELAY][1]     = g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][1]
                        ePad[PAD_ACTIVE_DURATION][0]  = g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][0]
                        ePad[PAD_ACTIVE_DURATION][1]  = g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][1]
                        ePad[PAD_ACTIVE_COOLDOWN][0]  = g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][0]
                        ePad[PAD_ACTIVE_COOLDOWN][1]  = g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][1]
                        ePad[PAD_STRENGTH][0]         = g_eSettings[SETTING_DEFAULT_STRENGTH][0]
                        ePad[PAD_STRENGTH][1]         = g_eSettings[SETTING_DEFAULT_STRENGTH][1]
                        ePad[PAD_COOLDOWN][0]         = g_eSettings[SETTING_DEFAULT_COOLDOWN][0]
                        ePad[PAD_COOLDOWN][1]         = g_eSettings[SETTING_DEFAULT_COOLDOWN][1]

                        iSection = SECTION_PAD
                        g_iPadConfig ++
                    }
                }
                else
                {
                    LogConfigError(iLine, "Unclosed section name: %s", szData)
                    iSection = SECTION_NONE
                }
            }
            default:
            {
                strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
                iPos = contain(szValue, "#")
                if ( iPos != -1 )
                    szValue[iPos] = EOS

                trim(szKey)
                trim(szValue)

                switch( iSection )
                {
                    case SECTION_NONE:
                    {
                        LogConfigError(iLine, "Data is not in any defined section: %s", szData)
                    }
                    case SECTION_MAIN_SETTINGS:
                    {
                        if ( equali(szKey, "SETTING_DEFAULT_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FLAGS], charsmax(g_eSettings[SETTING_DEFAULT_FLAGS]))
                        else if ( equali(szKey, "SETTING_DEFAULT_TEAM") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_TEAM], charsmax(g_eSettings[SETTING_DEFAULT_TEAM]))
                        else if ( equali(szKey, "SETTING_DEFAULT_FRAMERATE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FRAMERATE], charsmax(g_eSettings[SETTING_DEFAULT_FRAMERATE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_SPAWN_CHANCE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE], charsmax(g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_DELAY") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY], charsmax(g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_DURATION") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION], charsmax(g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION]))
                        else if ( equali(szKey, "SETTING_DEFAULT_ACTIVE_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN], charsmax(g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN]))
                        else if ( equali(szKey, "SETTING_DEFAULT_RADIUS") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_RADIUS], charsmax(g_eSettings[SETTING_DEFAULT_RADIUS]))
                        else if ( equali(szKey, "SETTING_DEFAULT_RADIUS_OFFSET") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_RADIUS_OFFSET], charsmax(g_eSettings[SETTING_DEFAULT_RADIUS_OFFSET]))
                        else if ( equali(szKey, "SETTING_DEFAULT_STRENGTH") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_STRENGTH], charsmax(g_eSettings[SETTING_DEFAULT_STRENGTH]))
                        else if ( equali(szKey, "SETTING_DEFAULT_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_COOLDOWN], charsmax(g_eSettings[SETTING_DEFAULT_COOLDOWN]))
                        else if ( equali(szKey, "SETTING_DEFAULT_FRAMERATE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FRAMERATE], charsmax(g_eSettings[SETTING_DEFAULT_FRAMERATE]))
                        else if ( equali(szKey, "SETTING_MODEL_SMALL") )
                            parseSetting(DTYPE_STRING_MODEL, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_MODEL_SMALL], charsmax(g_eSettings[SETTING_MODEL_SMALL]))
                        else if ( equali(szKey, "SETTING_MODEL_MEDIUM") )
                            parseSetting(DTYPE_STRING_MODEL, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_MODEL_MEDIUM], charsmax(g_eSettings[SETTING_MODEL_MEDIUM]))
                        else if ( equali(szKey, "SETTING_MODEL_LARGE") )
                            parseSetting(DTYPE_STRING_MODEL, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_MODEL_LARGE], charsmax(g_eSettings[SETTING_MODEL_LARGE]))
                        else if ( equali(szKey, "SETTING_MINS_SMALL") )
                            parseSetting(DTYPE_FLOAT_LIST, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_MINS_SMALL], charsmax(g_eSettings[SETTING_MINS_SMALL]))
                        else if ( equali(szKey, "SETTING_MAXS_SMALL") )
                            parseSetting(DTYPE_FLOAT_LIST, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_MAXS_SMALL], charsmax(g_eSettings[SETTING_MAXS_SMALL]))
                        else if ( equali(szKey, "SETTING_MINS_MEDIUM") )
                            parseSetting(DTYPE_FLOAT_LIST, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_MINS_MEDIUM], charsmax(g_eSettings[SETTING_MINS_MEDIUM]))
                        else if ( equali(szKey, "SETTING_MAXS_MEDIUM") )
                            parseSetting(DTYPE_FLOAT_LIST, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_MAXS_MEDIUM], charsmax(g_eSettings[SETTING_MAXS_MEDIUM]))
                        else if ( equali(szKey, "SETTING_MINS_LARGE") )
                            parseSetting(DTYPE_FLOAT_LIST, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_MINS_LARGE], charsmax(g_eSettings[SETTING_MINS_LARGE]))
                        else if ( equali(szKey, "SETTING_MAXS_LARGE") )
                            parseSetting(DTYPE_FLOAT_LIST, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_MAXS_LARGE], charsmax(g_eSettings[SETTING_MAXS_LARGE]))
                        else if ( equali(szKey, "SETTING_TRIGGER_RADIUS") )
                            parseSetting(DTYPE_FLOAT_LIST, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_TRIGGER_RADIUS], charsmax(g_eSettings[SETTING_TRIGGER_RADIUS]))
                        else if ( equali(szKey, "SETTING_TRIGGER_OFFSET") )
                            parseSetting(DTYPE_FLOAT_LIST, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_TRIGGER_OFFSET], charsmax(g_eSettings[SETTING_TRIGGER_OFFSET]))
                        else if ( equali(szKey, "SETTING_SOUND_JUMP"))
                            parseSetting(DTYPE_ARRAY_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_JUMP], charsmax(g_eSettings[SETTING_SOUND_JUMP]))
                        else if ( equali(szKey, "SETTING_PAD_LOAD") )
                            parseSetting(DTYPE_BOOL, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_PAD_LOAD], charsmax(g_eSettings[SETTING_PAD_LOAD]))
                        else if ( equali(szKey, "SETTING_PAD_CHECK") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_PAD_CHECK], charsmax(g_eSettings[SETTING_PAD_CHECK]))
                        else if ( equali(szKey, "SETTING_PAD_TASK") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_PAD_TASK], charsmax(g_eSettings[SETTING_PAD_TASK]))
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_BASE], charsmax(g_eSettings[SETTING_OFFSET_BASE]))
                        else if ( equali(szKey, "SETTING_OFFSET") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET], charsmax(g_eSettings[SETTING_OFFSET]))
                        else if ( equali(szKey, "SETTING_OFFSET_STEP") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_STEP], charsmax(g_eSettings[SETTING_OFFSET_STEP]))
                        else if ( equali(szKey, "SETTING_GHOST_ALPHA") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_GHOST_ALPHA], charsmax(g_eSettings[SETTING_GHOST_ALPHA]))
                        else if ( equali(szKey, "SETTING_ROTATION_STEP") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_ROTATION_STEP], charsmax(g_eSettings[SETTING_ROTATION_STEP]))
                    }
                    case SECTION_PAD:
                    {
                        if ( equali(szKey, "PAD_MODEL") )
                            parseSetting(DTYPE_STRING_MODEL, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_MODEL], charsmax(ePad[PAD_MODEL]))
                        else if ( equali(szKey, "PAD_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_FLAGS], charsmax(ePad[PAD_FLAGS]))
                        else if ( equali(szKey, "PAD_FRAMERATE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_FRAMERATE], charsmax(ePad[PAD_FRAMERATE]))
                        else if ( equali(szKey, "PAD_TEAM") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_TEAM], charsmax(ePad[PAD_TEAM]))
                        else if ( equali(szKey, "PAD_SPAWN_CHANCE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_SPAWN_CHANCE], charsmax(ePad[PAD_SPAWN_CHANCE]))
                        else if ( equali(szKey, "PAD_ACTIVE_DELAY") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_ACTIVE_DELAY], charsmax(ePad[PAD_ACTIVE_DELAY]))
                        else if ( equali(szKey, "PAD_ACTIVE_DURATION") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_ACTIVE_DURATION], charsmax(ePad[PAD_ACTIVE_DURATION]))
                        else if ( equali(szKey, "PAD_ACTIVE_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_ACTIVE_COOLDOWN], charsmax(ePad[PAD_ACTIVE_COOLDOWN]))
                        else if ( equali(szKey, "PAD_TRIGGER_RADIUS") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_TRIGGER_RADIUS], charsmax(ePad[PAD_TRIGGER_RADIUS]))
                        else if ( equali(szKey, "PAD_TRIGGER_OFFSET") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_TRIGGER_OFFSET], charsmax(ePad[PAD_TRIGGER_OFFSET]))
                        else if ( equali(szKey, "PAD_STRENGTH") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_STRENGTH], charsmax(ePad[PAD_STRENGTH]))
                        else if ( equali(szKey, "PAD_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_COOLDOWN], charsmax(ePad[PAD_COOLDOWN]))
                    }
                }
            }
        }
    }

    if ( g_iPadConfig )
        ArrayPushArray(g_aPadConfig, ePad)
    else
        set_fail_state("No Pads were found in the configuration file.")

    g_bFileWasRead = true
    fclose(iFile)
}

public client_authorized(id)
{
    set_task(DELAY_ON_CONNECT, "UpdateData", id)
}

public client_disconnected(id)
{
    DisableAction(id)

    new ePad[PAD], iItem
    if ( g_ePlayerData[id][PDATA_PAD_GHOST]
    && (iItem = padGet(ePad, g_ePlayerData[id][PDATA_PAD_GHOST])) != -1 )
    {
        padKill(ePad[PAD_ID])
        padRemove(iItem)
    }

    g_ePlayerData[id][PDATA_PAD_GHOST]  = 0
    g_ePlayerData[id][PDATA_PAD_ACTION] = false
    g_ePlayerData[id][PDATA_PAD_MENU]   = 0
}

public UpdateData(id)
{
    g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]
}

public padInit()
{
    if ( g_eSettings[SETTING_PAD_LOAD] )
        set_task(DELAY_ON_LOAD, "loadData")
}

public padMenu(id, iType)
{
    if ( !is_user_connected(id) )
        return PLUGIN_HANDLED

    new szData[64], iMenu
    formatex(szData, charsmax(szData), "%L", id, "PAD_MENU_TITLE", PLUGIN_VERSION)
    iMenu = menu_create(szData, g_szMenuHandler[iType])
    switch( iType )
    {
        case MENU_ROOT:   { menuRoot(id, iMenu); }
        case MENU_CREATE: { menuCreate(iMenu);      format(szData, charsmax(szData), "%s^n%L", szData, id, "PAD_ROOT_CREATE"); }
        case MENU_EDIT:   { menuEdit(id, iMenu);    format(szData, charsmax(szData), "%s^n%L", szData, id, "PAD_ROOT_EDIT"); }
        case MENU_REMOVE: { menuRemove(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "PAD_ROOT_REMOVE"); }
        case MENU_SHOW:   { menuShow(id, iMenu);    format(szData, charsmax(szData), "%s^n%L", szData, id, "PAD_ROOT_SHOW"); }
        case MENU_STATUS: { menuStatus(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "PAD_ROOT_STATUS"); }
        case MENU_ROTATE: { menuRotate(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "PAD_ROOT_ROTATE"); }
    }

    if ( menu_pages(iMenu) > 1 )
        format(szData, charsmax(szData), "%s^n%L", szData, id, "PAD_MENU_TITLE_PAGE")

    menu_setprop(iMenu, MPROP_TITLE, szData)
    menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL)
    menu_setprop(iMenu, MPROP_NUMBER_COLOR, "\r")

    menu_display(id, iMenu)
    return PLUGIN_HANDLED
}

stock menuNav(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "PAD_NAV_NEXT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_NAV_BACK")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)
}

public menuRoot(id, iMenu)
{
    new szItem[64]

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_ROOT_CREATE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_ROOT_EDIT")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_ROOT_REMOVE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_ROOT_SAVE")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_ROOT_NOCLIP", id, get_user_noclip(id) ? "PAD_ON" : "PAD_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_ROOT_GODMODE", id, get_user_godmode(id) ? "PAD_ON" : "PAD_OFF")
    menu_additem(iMenu, szItem)
}

public menuHandlerRoot(id, menu, item)
{
    if ( item == MENU_EXIT )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case ROOT_CREATE:
        {
            if ( g_iPad >= MAX_ENT )
            {
                client_print_color(id, id, "%L %L", id, "PAD_CHAT_TAG", id, "PAD_CHAT_LIMIT", MAX_ENT)

                padSound(id, SOUND_MENU_REMOVE)
                padMenu(id, MENU_ROOT)
            }
            else
            {
                padSound(id, SOUND_MENU_NAV)
                padMenu(id, MENU_CREATE)
            }
        }
        case ROOT_EDIT:
        {
            if ( !g_iPad )
            {
                client_print_color(id, id, "%L %L", id, "PAD_CHAT_TAG", id, "PAD_CHAT_NO_PAD")

                padSound(id, SOUND_MENU_REMOVE)
                padMenu(id, MENU_ROOT)
            }
            else
            {
                padSound(id, SOUND_MENU_NAV)
                padMenu(id, MENU_SHOW)
            }
        }
        case ROOT_REMOVE:
        {
            if ( !g_iPad )
            {
                client_print_color(id, id, "%L %L", id, "PAD_CHAT_TAG", id, "PAD_CHAT_NO_PAD")

                padSound(id, SOUND_MENU_REMOVE)
                padMenu(id, MENU_ROOT)
            }
            else
            {
                padSound(id, SOUND_MENU_REMOVE)
                padMenu(id, MENU_REMOVE)
            }
        }
        case ROOT_SAVE:
        {
            saveData(id)
        }
        case ROOT_NOCLIP:
        {
            padNoClip(id)
        }
        case ROOT_GODMODE:
        {
            padGodMode(id)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuCreate(iMenu)
{
    new ePad[PAD], szItem[64]

    for ( new i = 0; i < g_iPadConfig; i ++ )
    {
        ArrayGetArray(g_aPadConfig, i, ePad)

        copy(szItem, charsmax(szItem), ePad[PAD_NAME])
        menu_additem(iMenu, szItem)
    }
}

public menuHandlerCreate(id, menu, item)
{
    if ( !is_user_alive(id) )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }
    else if ( item == MENU_EXIT )
    {
        padSound(id, SOUND_MENU_NAV)
        padMenu(id, MENU_ROOT)

        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    padCreate(id, item)
    padSound(id, SOUND_MENU_NAV)
    padMenu(id, MENU_ROTATE)

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuEdit(id, iMenu)
{
    new szItem[64]
    formatex(szItem, charsmax(szItem), "%L", id, "PAD_EDIT_SHOW")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_EDIT_STATUS")
    menu_additem(iMenu, szItem)
}

public menuHandlerEdit(id, menu, item)
{
    switch( item )
    {
        case EDIT_SHOW:
        {
            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_SHOW)
        }
        case EDIT_STATUS:
        {
            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_STATUS)
        }
        case MENU_EXIT:
        {
            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_ROOT)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRemove(id, iMenu)
{
    new szItem[64], ePad[PAD]

    menuNav(id, iMenu)
    ArrayGetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_REMOVE_CURRENT", ePad[PAD_NAME])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_REMOVE_ALL")
    menu_additem(iMenu, szItem)

    EnableAction(id)
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_REMOVE
    padSelect(ePad, TARGET_SELECT)
    ArraySetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)
}

public menuHandlerRemove(id, menu, item)
{
    new ePad[PAD]
    ArrayGetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
        padSelect(ePad, ePad[PAD_FLAGS] & FLAG_SHOW ? TARGET_CLEAR : TARGET_GHOST)

    switch( item )
    {
        case REMOVE_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_PAD_MENU] >= g_iPad - 1 )
                g_ePlayerData[id][PDATA_PAD_MENU] = 0
            else
                g_ePlayerData[id][PDATA_PAD_MENU] ++

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_REMOVE)
        }
        case REMOVE_BACK:
        {
            if ( g_ePlayerData[id][PDATA_PAD_MENU] <= 0 )
                g_ePlayerData[id][PDATA_PAD_MENU] = g_iPad - 1
            else
                g_ePlayerData[id][PDATA_PAD_MENU] --

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_REMOVE)
        }
        case REMOVE_CURRENT:
        {
            ePad[PAD_FLAGS] &= ~FLAG_ACTIVE
            padSetState(ePad)
            padKill(ePad[PAD_ID])
            padRemove(g_ePlayerData[id][PDATA_PAD_MENU])

            client_print_color(id, id, "%L %L", id, "PAD_CHAT_TAG", id, "PAD_CHAT_REMOVE_CURRENT", ePad[PAD_NAME])
            g_ePlayerData[id][PDATA_PAD_MENU] = 0

            padSound(id, g_iPad > 0 ? SOUND_MENU_REMOVE : SOUND_MENU_NAV)
            padMenu(id, g_iPad > 0 ? MENU_REMOVE : MENU_ROOT)
        }
        case REMOVE_ALL:
        {
            while( g_iPad )
            {
                ArrayGetArray(g_aPad, 0, ePad)
                ePad[PAD_FLAGS] &= ~FLAG_ACTIVE

                padSetState(ePad)
                padKill(ePad[PAD_ID])
                padRemove(0)
            }

            client_print_color(id, id, "%L %L", id, "PAD_CHAT_TAG", id, "PAD_CHAT_REMOVE_ALL")
            g_ePlayerData[id][PDATA_PAD_MENU] = 0

            padSound(id, SOUND_MENU_ALERT)
            padMenu(id, MENU_ROOT)
        }
        case MENU_EXIT:
        {
            if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
            {
                padSound(id, SOUND_MENU_NAV)
                padMenu(id, MENU_ROOT)

                g_ePlayerData[id][PDATA_PAD_MENU] = 0
                DisableAction(id)
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            g_ePlayerData[id][PDATA_PAD_MENU] = 0
            DisableAction(id)
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuShow(id, iMenu)
{
    new szItem[64], ePad[PAD]
    menuNav(id, iMenu)
    ArrayGetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_SHOW_CURRENT",
    ePad[PAD_FLAGS] & FLAG_SHOW ? "\y" : "\r", ePad[PAD_NAME], id, ePad[PAD_FLAGS] & FLAG_SHOW ? "PAD_SHOWN" : "PAD_HIDDEN")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_SHOW_ALL_SHOW")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_SHOW_ALL_HIDE")
    menu_additem(iMenu, szItem)

    EnableAction(id)
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_SHOW
    padSelect(ePad, TARGET_SELECT)
    ArraySetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)
}

public menuHandlerShow(id, menu, item)
{
    new ePad[PAD]
    ArrayGetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
        padSelect(ePad, ePad[PAD_FLAGS] & FLAG_SHOW ? TARGET_CLEAR : TARGET_GHOST)

    switch( item )
    {
        case SHOW_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_PAD_MENU] >= g_iPad - 1 )
                g_ePlayerData[id][PDATA_PAD_MENU] = 0
            else
                g_ePlayerData[id][PDATA_PAD_MENU] ++

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_SHOW)
        }
        case SHOW_BACK:
        {
            if ( g_ePlayerData[id][PDATA_PAD_MENU] <= 0 )
                g_ePlayerData[id][PDATA_PAD_MENU] = g_iPad - 1
            else
                g_ePlayerData[id][PDATA_PAD_MENU] --

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_SHOW)
        }
        case SHOW_CURRENT:
        {
            ePad[PAD_FLAGS] ^= FLAG_SHOW
            padSetState(ePad)

            client_print_color(id, id, "%L %L", id, "PAD_CHAT_TAG", id, "PAD_CHAT_SHOW_CURRENT",
            ePad[PAD_NAME], id, ePad[PAD_FLAGS] & FLAG_SHOW ? "PAD_CHAT_SHOWN" : "PAD_CHAT_HIDDEN")
            ArraySetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_SHOW)
        }
        case SHOW_ALL_SHOW:
        {
            for ( new i = 0; i < g_iPad; i ++ )
            {
                ArrayGetArray(g_aPad, i, ePad)
                ePad[PAD_FLAGS] |= FLAG_SHOW
                padSetState(ePad)

                ArraySetArray(g_aPad, i, ePad)
            }

            client_print_color(id, id, "%L %L", id, "PAD_CHAT_TAG", id, "PAD_CHAT_SHOW_ALL_SHOWN")
            padSound(id, SOUND_MENU_ALERT)
            padMenu(id, MENU_SHOW)
        }
        case SHOW_ALL_HIDE:
        {
            for ( new i = 0; i < g_iPad; i ++ )
            {
                ArrayGetArray(g_aPad, i, ePad)
                ePad[PAD_FLAGS] &= ~FLAG_SHOW
                padSetState(ePad)

                ArraySetArray(g_aPad, i, ePad)
            }

            client_print_color(id, id, "%L %L", id, "PAD_CHAT_TAG", id, "PAD_CHAT_SHOW_ALL_HIDDEN")
            padSound(id, SOUND_MENU_ALERT)
            padMenu(id, MENU_SHOW)
        }
        case MENU_EXIT:
        {
            if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
            {
                padSound(id, SOUND_MENU_NAV)
                padMenu(id, MENU_ROOT)

                g_ePlayerData[id][PDATA_PAD_MENU] = 0
                DisableAction(id)
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            DisableAction(id)
            g_ePlayerData[id][PDATA_PAD_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuStatus(id, iMenu)
{
    new szItem[64], ePad[PAD]
    menuNav(id, iMenu)
    ArrayGetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_STATUS_CURRENT",
    ePad[PAD_FLAGS] & FLAG_ACTIVE ? "\y" : "\r", ePad[PAD_NAME], id, ePad[PAD_FLAGS] & FLAG_ACTIVE ? "PAD_ENABLED" : "PAD_DISABLED")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_STATUS_ALL_ENABLE")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_STATUS_ALL_DISABLE")
    menu_additem(iMenu, szItem)

    EnableAction(id)
    padSelect(ePad, TARGET_SELECT)
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_STATUS
    ArraySetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)
}

public menuHandlerStatus(id, menu, item)
{
    new ePad[PAD]
    ArrayGetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
        padSelect(ePad, ePad[PAD_FLAGS] & FLAG_SHOW ? TARGET_CLEAR : TARGET_GHOST)

    switch( item )
    {
        case STATUS_NEXT:
        {
            if ( g_ePlayerData[id][PDATA_PAD_MENU] >= g_iPad - 1 )
                g_ePlayerData[id][PDATA_PAD_MENU] = 0
            else
                g_ePlayerData[id][PDATA_PAD_MENU] ++

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_STATUS)
        }
        case STATUS_BACK:
        {
            if ( g_ePlayerData[id][PDATA_PAD_MENU] <= 0 )
                g_ePlayerData[id][PDATA_PAD_MENU] = g_iPad - 1
            else
                g_ePlayerData[id][PDATA_PAD_MENU] --

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_STATUS)
        }
        case STATUS_CURRENT:
        {
            ePad[PAD_FLAGS] ^= FLAG_ACTIVE
            padSetState(ePad)

            client_print_color(id, id, "%L %L", id, "PAD_CHAT_TAG", id, "PAD_CHAT_STATUS_CURRENT",
            ePad[PAD_NAME], id, ePad[PAD_FLAGS] & FLAG_ACTIVE ? "PAD_CHAT_ENABLED" : "PAD_CHAT_DISABLED")
            ArraySetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_ENABLE:
        {
            for ( new i = 0; i < g_iPad; i ++ )
            {
                ArrayGetArray(g_aPad, i, ePad)
                ePad[PAD_FLAGS] |= FLAG_ACTIVE
                padSetState(ePad)

                ArraySetArray(g_aPad, i, ePad)
            }

            client_print_color(id, id, "%L %L", id, "PAD_CHAT_TAG", id, "PAD_CHAT_STATUS_ALL_ENABLED")
            padSound(id, SOUND_MENU_ALERT)
            padMenu(id, MENU_STATUS)
        }
        case STATUS_ALL_DISABLE:
        {
            for ( new i = 0; i < g_iPad; i ++ )
            {
                ArrayGetArray(g_aPad, i, ePad)
                ePad[PAD_FLAGS] &= ~FLAG_ACTIVE
                padSetState(ePad)

                ArraySetArray(g_aPad, i, ePad)
            }

            client_print_color(id, id, "%L %L", id, "PAD_CHAT_TAG", id, "PAD_CHAT_STATUS_ALL_DISABLED")
            padSound(id, SOUND_MENU_ALERT)
            padMenu(id, MENU_STATUS)
        }
        case MENU_EXIT:
        {
            if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
            {
                padSound(id, SOUND_MENU_NAV)
                padMenu(id, MENU_ROOT)

                DisableAction(id)
                g_ePlayerData[id][PDATA_PAD_MENU] = 0
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            DisableAction(id)
            g_ePlayerData[id][PDATA_PAD_MENU] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public menuRotate(id, iMenu)
{
    new szItem[64], ePad[PAD]
    if ( padGet(ePad, g_ePlayerData[id][PDATA_PAD_GHOST]) == -1 )
    {
        menu_destroy(iMenu)
        return
    }

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_ROTATE_UP")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_ROTATE_DOWN")
    menu_additem(iMenu, szItem)

    menu_addblank2(iMenu)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_ROTATE_GROUND",
    id, ePad[PAD_FLAGS] & FLAG_GROUND ? "PAD_ON" : "PAD_OFF")
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_ROTATE_MODE", id, g_szRotateMode[g_ePlayerData[id][PDATA_ROTATE_MODE]])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_ROTATE_SIZE", id, g_szRotateSize[g_ePlayerData[id][PDATA_ROTATE_SIZE]])
    menu_additem(iMenu, szItem)

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_ROTATE_PLACE")
    menu_additem(iMenu, szItem)
}

public menuHandlerRotate(id, menu, item)
{
    new ePad[PAD], iItem
    if ( (iItem = padGet(ePad, g_ePlayerData[id][PDATA_PAD_GHOST])) == -1 )
    {
        menu_destroy(menu)
        return PLUGIN_HANDLED
    }

    switch( item )
    {
        case ROTATE_UP:
        {
            pev(ePad[PAD_ID], pev_angles, ePad[PAD_ANGLES])
            ePad[PAD_ANGLES][g_ePlayerData[id][PDATA_ROTATE_MODE]] -= g_eSettings[SETTING_ROTATION_STEP]
            if ( ePad[PAD_ANGLES][g_ePlayerData[id][PDATA_ROTATE_MODE]] < -180.0 ) ePad[PAD_ANGLES][g_ePlayerData[id][PDATA_ROTATE_MODE]] += 360.0

            set_pev(ePad[PAD_ID], pev_angles, ePad[PAD_ANGLES])
            ArraySetArray(g_aPad, iItem, ePad)

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_ROTATE)
        }
        case ROTATE_DOWN:
        {
            pev(ePad[PAD_ID], pev_angles, ePad[PAD_ANGLES])
            ePad[PAD_ANGLES][g_ePlayerData[id][PDATA_ROTATE_MODE]] += g_eSettings[SETTING_ROTATION_STEP]
            if ( ePad[PAD_ANGLES][g_ePlayerData[id][PDATA_ROTATE_MODE]] > 180.0 ) ePad[PAD_ANGLES][g_ePlayerData[id][PDATA_ROTATE_MODE]] -= 360.0

            set_pev(ePad[PAD_ID], pev_angles, ePad[PAD_ANGLES])
            ArraySetArray(g_aPad, iItem, ePad)

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_ROTATE)
        }
        case ROTATE_GROUND:
        {
            ePad[PAD_FLAGS] ^= FLAG_GROUND
            ArraySetArray(g_aPad, iItem, ePad)

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_ROTATE)
        }
        case ROTATE_MODE:
        {
            if ( ++ g_ePlayerData[id][PDATA_ROTATE_MODE] > ROTATE_MODE_ROLL )
                g_ePlayerData[id][PDATA_ROTATE_MODE] = ROTATE_MODE_PITCH

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_ROTATE)
        }
        case ROTATE_SIZE:
        {
            if ( ++ g_ePlayerData[id][PDATA_ROTATE_SIZE] > SIZE_LARGE )
                g_ePlayerData[id][PDATA_ROTATE_SIZE] = SIZE_SMALL

            ePad[PAD_SIZE] = g_ePlayerData[id][PDATA_ROTATE_SIZE]
            switch ( ePad[PAD_SIZE] )
            {
                case SIZE_SMALL:  { engfunc(EngFunc_SetModel, ePad[PAD_ID], g_eSettings[SETTING_MODEL_SMALL]);  ePad[PAD_TRIGGER_RADIUS] = g_eSettings[SETTING_TRIGGER_RADIUS][0];  ePad[PAD_TRIGGER_OFFSET] = g_eSettings[SETTING_TRIGGER_OFFSET][0]; }
                case SIZE_MEDIUM: { engfunc(EngFunc_SetModel, ePad[PAD_ID], g_eSettings[SETTING_MODEL_MEDIUM]); ePad[PAD_TRIGGER_RADIUS] = g_eSettings[SETTING_TRIGGER_RADIUS][1];  ePad[PAD_TRIGGER_OFFSET] = g_eSettings[SETTING_TRIGGER_OFFSET][1]; }
                case SIZE_LARGE:  { engfunc(EngFunc_SetModel, ePad[PAD_ID], g_eSettings[SETTING_MODEL_LARGE]);  ePad[PAD_TRIGGER_RADIUS] = g_eSettings[SETTING_TRIGGER_RADIUS][2];  ePad[PAD_TRIGGER_OFFSET] = g_eSettings[SETTING_TRIGGER_OFFSET][2]; }
            }
            ArraySetArray(g_aPad, iItem, ePad)

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_ROTATE)
        }
        case ROTATE_PLACE:
        {
            padTrace(ePad, id)
            DisableAction(id)
            g_ePlayerData[id][PDATA_PAD_GHOST] = 0

            ePad[PAD_FLAGS] |= (FLAG_SHOW | FLAG_ACTIVE)
            ePad[PAD_FLAGS] &= ~FLAG_GHOST
            ePad[PAD_ANGLES][0] = -ePad[PAD_ANGLES][0]
            padSetSize(ePad)
            padSetDelay(ePad)
            padSetState(ePad)
            ArraySetArray(g_aPad, iItem, ePad)

            client_print_color(id, id, "%L %L", id, "PAD_CHAT_TAG", id, "PAD_CHAT_CREATE_NEW", ePad[PAD_NAME])
            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_ROOT)
        }
        case MENU_EXIT:
        {
            padKill(ePad[PAD_ID])
            padRemove(iItem)
            DisableAction(id)
            g_ePlayerData[id][PDATA_PAD_GHOST] = 0

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_CREATE)
        }
        default:
        {
            padKill(ePad[PAD_ID])
            padRemove(iItem)
            DisableAction(id)
            g_ePlayerData[id][PDATA_PAD_GHOST] = 0
        }
    }

    menu_destroy(menu)
    return PLUGIN_HANDLED
}

public padTask()
{
    new ePad[PAD], bool:bModified, Float:fCurrentTime,
    Float:fVec1[3], Float:fVec2[3],
    bool:bFound, iEnt = -1
    fCurrentTime = get_gametime()

    for ( new i = 0; i < g_iPad; i ++ )
    {
        ArrayGetArray(g_aPad, i, ePad)
        bModified = false
        bFound = false

        if ( ePad[PAD_FLAGS] & FLAG_SHOW )
        {
            if ( ePad[PAD_FLAGS] & FLAG_ACTIVE )
            {
                while( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, ePad[PAD_TRIGGER_ORIGIN], ePad[PAD_TRIGGER_RADIUS])) )
                {
                    if ( !pev_valid(iEnt)
                    || ePad[PAD_ID] == iEnt
                    || pev(iEnt, pev_solid) == SOLID_NOT
                    || pev(iEnt, pev_movetype) == MOVETYPE_NONE
                    || pev(iEnt, pev_movetype) == MOVETYPE_FOLLOW
                    || (ePad[PAD_FLAGS] & FLAG_PLAYERS_ONLY && !is_user_alive(iEnt))
                    || (is_user_alive(iEnt) && !(CsTeams:ePad[PAD_TEAM] & cs_get_user_team(iEnt))) )
                        continue

                    bFound = true
                    pev(iEnt, pev_velocity, fVec1)

                    xs_vec_mul_scalar(ePad[PAD_DIRECTION], random_float(ePad[PAD_STRENGTH][0], ePad[PAD_STRENGTH][1]), fVec2)
                    xs_vec_add(fVec1, fVec2, fVec1)
                    set_pev(iEnt, pev_velocity, fVec1)
                }

                if ( bFound )
                {
                    ePad[PAD_FLAGS] &= ~FLAG_ACTIVE
                    ePad[PAD_NEXT_ENABLE] = fCurrentTime + random_float(ePad[PAD_COOLDOWN][0], ePad[PAD_COOLDOWN][1])
                    padSound(ePad[PAD_ID], SOUND_JUMP, false)
                    padSetSeq(ePad, PAD_SEQ_ACTIVE)

                    bModified = true
                }

                if ( ePad[PAD_NEXT_DISABLE] > 0.0
                && fCurrentTime >= ePad[PAD_NEXT_DISABLE] )
                {
                    ePad[PAD_FLAGS] &= ~FLAG_ACTIVE
                    ePad[PAD_FLAGS] |= FLAG_PENDING
                    ePad[PAD_NEXT_DISABLE] = 0.0
                    ePad[PAD_NEXT_ENABLE] = fCurrentTime + random_float(ePad[PAD_ACTIVE_COOLDOWN][0], ePad[PAD_ACTIVE_COOLDOWN][1])
                    padSetSeq(ePad, PAD_SEQ_ACTIVE)

                    bModified = true
                }
            }
            else
            {
                if ( ePad[PAD_NEXT_ENABLE] > 0.0
                && fCurrentTime >= ePad[PAD_NEXT_ENABLE] )
                {
                    ePad[PAD_FLAGS] |= FLAG_ACTIVE
                    ePad[PAD_FLAGS] &= ~FLAG_PENDING
                    ePad[PAD_NEXT_ENABLE] = 0.0
                    if ( ePad[PAD_FLAGS] & FLAG_ACTIVE_DURATION )
                        ePad[PAD_NEXT_DISABLE] = fCurrentTime + random_float(ePad[PAD_ACTIVE_DURATION][0], ePad[PAD_ACTIVE_DURATION][1])
                    padSetSeq(ePad, PAD_SEQ_RETURN)

                    bModified = true
                }
            }
        }

        if ( bModified )
            ArraySetArray(g_aPad, i, ePad)
    }
}

stock padCreate(id, iItem)
{
    new iEnt = cs_create_entity("info_target")
    if ( !pev_valid(iEnt) )
        return

    new ePad[PAD]
    ArrayGetArray(g_aPadConfig, iItem, ePad)
    ePad[PAD_ID] = iEnt
    ePad[PAD_ITEM] = iItem
    if ( id )
    {
        EnableAction(id)
        g_ePlayerData[id][PDATA_PAD_GHOST] = ePad[PAD_ID]
        g_ePlayerData[id][PDATA_ROTATE_MODE] = ROTATE_MODE_YAW
        g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]

        ePad[PAD_FLAGS] |= FLAG_GHOST
    }

    padSelect(ePad, TARGET_GHOST)
    set_pev(iEnt, pev_classname, g_szCN)
    set_pev(iEnt, pev_impulse, PAD_KEY)
    set_pev(iEnt, PAD_ARRAY_ITEM, g_iPad)

    dllfunc(DLLFunc_Spawn, iEnt)
    set_pev(iEnt, pev_framerate, ePad[PAD_FRAMERATE])

    if ( id )
    {
        switch ( ePad[PAD_SIZE] )
        {
            case SIZE_SMALL:  { engfunc(EngFunc_SetModel, iEnt, g_eSettings[SETTING_MODEL_SMALL]);  ePad[PAD_TRIGGER_RADIUS] = g_eSettings[SETTING_TRIGGER_RADIUS][0];  ePad[PAD_TRIGGER_OFFSET] = g_eSettings[SETTING_TRIGGER_OFFSET][0]; }
            case SIZE_MEDIUM: { engfunc(EngFunc_SetModel, iEnt, g_eSettings[SETTING_MODEL_MEDIUM]); ePad[PAD_TRIGGER_RADIUS] = g_eSettings[SETTING_TRIGGER_RADIUS][1];  ePad[PAD_TRIGGER_OFFSET] = g_eSettings[SETTING_TRIGGER_OFFSET][1]; }
            case SIZE_LARGE:  { engfunc(EngFunc_SetModel, iEnt, g_eSettings[SETTING_MODEL_LARGE]);  ePad[PAD_TRIGGER_RADIUS] = g_eSettings[SETTING_TRIGGER_RADIUS][2];  ePad[PAD_TRIGGER_OFFSET] = g_eSettings[SETTING_TRIGGER_OFFSET][2]; }
        }
    }

    ArrayPushArray(g_aPad, ePad)
    if ( ++ g_iPad == 1 )
        set_task(g_eSettings[SETTING_PAD_TASK], "padTask", PAD_KEY, .flags = "b")
}

public padRemove(iItem)
{
    new ePad[PAD]
    ArrayDeleteItem(g_aPad, iItem)

    if ( -- g_iPad == 0 )
        remove_task(PAD_KEY)

    for ( new i = iItem; i < g_iPad; i ++ )
    {
        ArrayGetArray(g_aPad, i, ePad)
        set_pev(ePad[PAD_ID], PAD_ARRAY_ITEM, i)
    }
}

public saveData(id)
{
    new ePad[PAD],
        szFile[128], iFile,
        szData[64]

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_XenJumpPad.ini", szFile)

    iFile = fopen(szFile, "wt")
    if ( !iFile )
        return PLUGIN_HANDLED

    padTerminate()
    for ( new i = 0; i < g_iPad; i ++ )
    {
        ArrayGetArray(g_aPad, i, ePad)

        formatex(szData, charsmax(szData), "[%d]^n", i)
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "item = %d^n", ePad[PAD_ITEM])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "flags = %d^n", ePad[PAD_FLAGS])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "size = %d^n", ePad[PAD_SIZE])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "origin = %.2f %.2f %.2f^n",
        ePad[PAD_ORIGIN][0], ePad[PAD_ORIGIN][1], ePad[PAD_ORIGIN][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "angles = %.2f %.2f %.2f^n",
        ePad[PAD_ANGLES][0], ePad[PAD_ANGLES][1], ePad[PAD_ANGLES][2])
        fputs(iFile, szData)
    }

    client_print_color(id, id, "%L %L", id, "PAD_CHAT_TAG", id, "PAD_CHAT_SAVE", szFile)
    fclose(iFile)

    padSound(id, SOUND_MENU_NAV)
    padMenu(id, MENU_ROOT)
    return PLUGIN_HANDLED
}

public loadData()
{
    new szFile[128], iFile,
        szData[64], szKey[32], szValue[32],
        Float:fOrigin[3], Float:fAngles[3], iItem, iFlags, iSize, iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_XenJumpPad.ini", szFile)

    iFile = fopen(szFile, "rt")
    if ( !iFile )
        return PLUGIN_HANDLED

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))

        if ( szData[0] == '[' )
        {
            if ( iCount != -1 )
                loadDataPad(iItem, iFlags, iSize, fOrigin, fAngles, iCount)

            iCount ++
        }
        else
        {
            strtok(szData, szKey, charsmax( szKey ), szValue, charsmax( szValue ), '=')
            trim(szKey)
            trim(szValue)

            if ( equal(szKey, "item") )
            {
                iItem = str_to_num(szValue)
            }
            else if ( equal(szKey, "flags") )
            {
                iFlags = str_to_num(szValue)
            }
            else if ( equal(szKey, "size") )
            {
                iSize = str_to_num(szValue)
            }
            else if ( equal(szKey, "origin") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fOrigin[1] = str_to_float(szKey)
                fOrigin[2] = str_to_float(szValue)
            }
            else if ( equal(szKey, "angles") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fAngles[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fAngles[1] = str_to_float(szKey)
                fAngles[2] = str_to_float(szValue)
            }
        }
    }

    if ( iCount != -1 )
        loadDataPad(iItem, iFlags, iSize, fOrigin, fAngles, iCount)

    fclose(iFile)
    return PLUGIN_HANDLED
}

stock loadDataPad(iItem, iFlags, iSize, Float:fOrigin[3], Float:fAngles[3], iCount)
{
    new ePad[PAD]
    padCreate(0, iItem)
    ArrayGetArray(g_aPad, iCount, ePad)

    fAngles[0] = -fAngles[0]
    xs_vec_copy(fOrigin, ePad[PAD_ORIGIN])
    xs_vec_copy(fAngles, ePad[PAD_ANGLES])

    ePad[PAD_FLAGS] = iFlags
    ePad[PAD_SIZE] = iSize
    switch ( ePad[PAD_SIZE] )
    {
        case SIZE_SMALL:  { engfunc(EngFunc_SetModel, ePad[PAD_ID], g_eSettings[SETTING_MODEL_SMALL]);  ePad[PAD_TRIGGER_RADIUS] = g_eSettings[SETTING_TRIGGER_RADIUS][0];  ePad[PAD_TRIGGER_OFFSET] = g_eSettings[SETTING_TRIGGER_OFFSET][0]; }
        case SIZE_MEDIUM: { engfunc(EngFunc_SetModel, ePad[PAD_ID], g_eSettings[SETTING_MODEL_MEDIUM]); ePad[PAD_TRIGGER_RADIUS] = g_eSettings[SETTING_TRIGGER_RADIUS][1];  ePad[PAD_TRIGGER_OFFSET] = g_eSettings[SETTING_TRIGGER_OFFSET][1]; }
        case SIZE_LARGE:  { engfunc(EngFunc_SetModel, ePad[PAD_ID], g_eSettings[SETTING_MODEL_LARGE]);  ePad[PAD_TRIGGER_RADIUS] = g_eSettings[SETTING_TRIGGER_RADIUS][2];  ePad[PAD_TRIGGER_OFFSET] = g_eSettings[SETTING_TRIGGER_OFFSET][2]; }
    }

    padSetBox(ePad)
    padSetSize(ePad)
    padSetDelay(ePad)
    padSetState(ePad)
    ArraySetArray(g_aPad, iCount, ePad)
}

public padNoClip(id)
{
    set_user_noclip(id, !get_user_noclip(id))

    padSound(id, SOUND_MENU_NAV)
    padMenu(id, MENU_ROOT)
}

public padGodMode(id)
{
    set_user_godmode(id, !get_user_godmode(id))

    padSound(id, SOUND_MENU_NAV)
    padMenu(id, MENU_ROOT)
}

public fwdUpdateClientData(id, iSendWeapons, iHandle)
{
    if ( g_ePlayerData[id][PDATA_PAD_GHOST] )
    {
        set_cd(iHandle, CD_WeaponAnim, 0)
        set_cd(iHandle, CD_flNextAttack, get_gametime() + 0.1)
    }

    return FMRES_IGNORED
}

public fwdSpawn(iEnt)
{
    if ( isPad(iEnt) )
    {
        set_pev(iEnt, pev_solid, SOLID_NOT)
        set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
    }

    return HAM_IGNORED
}

public fwdPreThink(id)
{
    if ( !is_user_alive(id) )
        return HAM_IGNORED

    static ePad[PAD], iButton, Float:fCurrentTime
    iButton = pev(id, pev_button)
    fCurrentTime = get_gametime()

    if ( g_ePlayerData[id][PDATA_PAD_GHOST]
    && padGet(ePad, g_ePlayerData[id][PDATA_PAD_GHOST]) != -1 )
    {
        if ( fCurrentTime > g_ePlayerData[id][PDATA_NEXT_OFFSET] )
        {
            if ( iButton & IN_ATTACK )
            {
                g_ePlayerData[id][PDATA_OFFSET]      += g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + 0.1
            }
            else if ( iButton & IN_ATTACK2 )
            {
                g_ePlayerData[id][PDATA_OFFSET]      -= g_eSettings[SETTING_OFFSET_STEP]
                g_ePlayerData[id][PDATA_OFFSET]      = floatclamp(g_ePlayerData[id][PDATA_OFFSET], g_eSettings[SETTING_OFFSET][0], g_eSettings[SETTING_OFFSET][1])
                g_ePlayerData[id][PDATA_NEXT_OFFSET] = fCurrentTime + 0.1
            }
        }

        iButton &= ~(IN_ATTACK | IN_ATTACK2)
        set_pev(id, pev_button, iButton)

        padTrace(ePad, id)
    }
    else if ( g_ePlayerData[id][PDATA_PAD_ACTION] )
    {
        padCheck(id)
    }

    return HAM_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
    DisableAction(id)
    g_ePlayerData[id][PDATA_PAD_ACTION] = false
    g_ePlayerData[id][PDATA_PAD_MENU]   = 0

    if ( g_ePlayerData[id][PDATA_PAD_GHOST] )
    {
        new ePad[PAD], iItem

        if ( (iItem = padGet(ePad, g_ePlayerData[id][PDATA_PAD_GHOST])) != -1 )
        {
            padKill(g_ePlayerData[id][PDATA_PAD_GHOST])
            padRemove(iItem)
        }

        g_ePlayerData[id][PDATA_PAD_GHOST] = 0
    }
}

stock padTrace(ePad[PAD], id)
{
    new Float:fVec1[3]
    pev(id, pev_origin, ePad[PAD_ORIGIN])
    pev(id, pev_v_angle, fVec1)
    engfunc(EngFunc_MakeVectors, fVec1)
    global_get(glb_v_forward, fVec1)

    xs_vec_mul_scalar(fVec1, g_ePlayerData[id][PDATA_OFFSET], fVec1)
    xs_vec_add(fVec1, ePad[PAD_ORIGIN], fVec1)

    engfunc(EngFunc_TraceLine, ePad[PAD_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, id, 0)
    get_tr2(0, TR_vecEndPos, ePad[PAD_ORIGIN])

    padSetBox(ePad)
    padSetOffset(ePad)
    set_pev(ePad[PAD_ID], pev_origin, ePad[PAD_ORIGIN])
}

stock padCheck(id)
{
    new ePad[PAD], Float:fVec1[3], Float:fVec2[3], Float:fVec3[3], Float:fMins[3], Float:fMaxs[3], Float:fNearest[3]
    new iBest, Float:fBestDist, Float:fDot, Float:fDist

    pev(id, pev_origin, fVec1)
    pev(id, pev_view_ofs, fVec2)
    xs_vec_add(fVec1, fVec2, fVec1)

    pev(id, pev_v_angle, fVec2)
    engfunc(EngFunc_MakeVectors, fVec2)
    global_get(glb_v_forward, fVec2)

    iBest = -1
    fBestDist = g_eSettings[SETTING_PAD_CHECK]
    for ( new i = 0; i < g_iPad; i ++ )
    {
        ArrayGetArray(g_aPad, i, ePad)
        xs_vec_sub(ePad[PAD_ORIGIN], fVec1, fVec3)
        fDot = xs_vec_dot(fVec2, fVec3)

        if ( fDot < 0.0 )
            continue

        pev(ePad[PAD_ID], pev_absmin, fMins)
        pev(ePad[PAD_ID], pev_absmax, fMaxs)
        xs_vec_mul_scalar(fVec2, fDot, fVec3)
        xs_vec_add(fVec3, fVec1, fVec3)

        fNearest[0] = floatclamp(fVec3[0], fMins[0], fMaxs[0])
        fNearest[1] = floatclamp(fVec3[1], fMins[1], fMaxs[1])
        fNearest[2] = floatclamp(fVec3[2], fMins[2], fMaxs[2])
        fDist = get_distance_f(fVec3, fNearest)
        if ( fDist < fBestDist )
        {
            fBestDist = fDist
            iBest = i
        }
    }

    if ( iBest != -1
    && g_ePlayerData[id][PDATA_PAD_MENU] != iBest )
    {
        ArrayGetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)
        padSelect(ePad, ePad[PAD_FLAGS] & FLAG_SHOW ? TARGET_CLEAR : TARGET_GHOST)

        g_ePlayerData[id][PDATA_MENU_TRACE] = true
        g_ePlayerData[id][PDATA_PAD_MENU] = iBest
        padMenu(id, g_ePlayerData[id][PDATA_MENU_TYPE])
    }
}

stock padSetBox(ePad[PAD])
{
    new Float:fMins[3], Float:fMaxs[3],
        Float:fForward[3], Float:fRight[3], Float:fUp[3],
        Float:fCorners[8][3]

    ePad[PAD_ANGLES][0] = -ePad[PAD_ANGLES][0]
    engfunc(EngFunc_AngleVectors, ePad[PAD_ANGLES], fForward, fRight, fUp)
    switch( ePad[PAD_SIZE] )
    {
        case SIZE_SMALL:    { xs_vec_copy(g_eSettings[SETTING_MINS_SMALL], fMins);  xs_vec_copy(g_eSettings[SETTING_MAXS_SMALL], fMaxs); }
        case SIZE_MEDIUM:   { xs_vec_copy(g_eSettings[SETTING_MINS_MEDIUM], fMins); xs_vec_copy(g_eSettings[SETTING_MAXS_MEDIUM], fMaxs); }
        case SIZE_LARGE:    { xs_vec_copy(g_eSettings[SETTING_MINS_LARGE], fMins);  xs_vec_copy(g_eSettings[SETTING_MAXS_LARGE], fMaxs); }
    }

    for ( new i = 0; i < 8; i ++ )
    {
        fCorners[i][0] = (i & 1) ? fMaxs[0] : fMins[0]
        fCorners[i][1] = (i & 2) ? fMaxs[1] : fMins[1]
        fCorners[i][2] = (i & 4) ? fMaxs[2] : fMins[2]

        boxRotate(fCorners[i], fForward, fRight, fUp)
    }

    xs_vec_copy(fCorners[0], fMins)
    xs_vec_copy(fCorners[0], fMaxs)
    for ( new i = 1; i < 8; i ++ )
    {
        fMins[0] = floatmin(fMins[0], fCorners[i][0])
        fMins[1] = floatmin(fMins[1], fCorners[i][1])
        fMins[2] = floatmin(fMins[2], fCorners[i][2])

        fMaxs[0] = floatmax(fMaxs[0], fCorners[i][0])
        fMaxs[1] = floatmax(fMaxs[1], fCorners[i][1])
        fMaxs[2] = floatmax(fMaxs[2], fCorners[i][2])
    }

    xs_vec_copy(fMins, ePad[PAD_MINS])
    xs_vec_copy(fMaxs, ePad[PAD_MAXS])
}

stock boxRotate(Float:fLocal[3], Float:fForward[3], Float:fRight[3], Float:fUp[3])
{
    new Float:fOut[3]
    fOut[0] = fLocal[0] * fForward[0] + fLocal[1] * fRight[0] + fLocal[2] * fUp[0]
    fOut[1] = fLocal[0] * fForward[1] + fLocal[1] * fRight[1] + fLocal[2] * fUp[1]
    fOut[2] = fLocal[0] * fForward[2] + fLocal[1] * fRight[2] + fLocal[2] * fUp[2]

    xs_vec_copy(fOut, fLocal)
}

stock padSetOffset(ePad[PAD])
{
    new Float:fGaps[6], Float:fVec1[3],
        Float:fCurrentGap

    fGaps[0] = -ePad[PAD_MINS][0]
    fGaps[1] = ePad[PAD_MAXS][0]
    fGaps[2] = -ePad[PAD_MINS][1]
    fGaps[3] = ePad[PAD_MAXS][1]
    fGaps[4] = -ePad[PAD_MINS][2]
    fGaps[5] = ePad[PAD_MAXS][2]

    if ( ePad[PAD_FLAGS] & FLAG_GROUND )
    {
        xs_vec_sub(ePad[PAD_ORIGIN], Float:{0.0, 0.0, 9999.9}, fVec1)
        engfunc(EngFunc_TraceLine, ePad[PAD_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, ePad[PAD_ID], 0)
        get_tr2(0, TR_vecEndPos, ePad[PAD_ORIGIN])
    }

    for ( new i = 5; i >= 0; i -- )
    {
        xs_vec_mul_scalar(g_fDirections[i], 9999.9, fVec1)
        xs_vec_add(fVec1, ePad[PAD_ORIGIN], fVec1)
        engfunc(EngFunc_TraceLine, ePad[PAD_ORIGIN], fVec1, DONT_IGNORE_MONSTERS, ePad[PAD_ID], 0)
        get_tr2(0, TR_vecEndPos, fVec1)
        fCurrentGap = xs_vec_distance(ePad[PAD_ORIGIN], fVec1)

        if ( fCurrentGap < fGaps[i] )
        {
            get_tr2(0, TR_vecPlaneNormal, fVec1)
            xs_vec_mul_scalar(fVec1, fGaps[i] - fCurrentGap, fVec1)
            xs_vec_add(ePad[PAD_ORIGIN], fVec1, ePad[PAD_ORIGIN])
        }
    }
}

stock padSetSeq(ePad[PAD], iSeq)
{
    set_pev(ePad[PAD_ID], pev_frame, 0)
    set_pev(ePad[PAD_ID], pev_framerate, g_eSettings[SETTING_DEFAULT_FRAMERATE])
    set_pev(ePad[PAD_ID], pev_animtime, get_gametime())
    set_pev(ePad[PAD_ID], pev_sequence, iSeq)
}

stock padSetSize(ePad[PAD])
{
    padSelect(ePad, TARGET_CLEAR)
    engfunc(EngFunc_SetOrigin, ePad[PAD_ID], ePad[PAD_ORIGIN])
    set_pev(ePad[PAD_ID], pev_angles, ePad[PAD_ANGLES])
    set_pev(ePad[PAD_ID], pev_solid, ePad[PAD_FLAGS] & FLAG_SHOW ? SOLID_BBOX : SOLID_NOT)
    set_pev(ePad[PAD_ID], pev_movetype, MOVETYPE_NONE)

    ePad[PAD_ANGLES][0] = -ePad[PAD_ANGLES][0]
    engfunc(EngFunc_SetSize, ePad[PAD_ID], ePad[PAD_MINS], ePad[PAD_MAXS])
    engfunc(EngFunc_AngleVectors, ePad[PAD_ANGLES], NULL_VECTOR, NULL_VECTOR, ePad[PAD_DIRECTION])
    xs_vec_mul_scalar(ePad[PAD_DIRECTION], ePad[PAD_TRIGGER_OFFSET], ePad[PAD_TRIGGER_ORIGIN])
    xs_vec_add(ePad[PAD_TRIGGER_ORIGIN], ePad[PAD_ORIGIN], ePad[PAD_TRIGGER_ORIGIN])
}

stock padSelect(ePad[PAD], iAction)
{
    new iRender, iRenderFx, iRenderColor[3], iRenderAmt

    iRenderFx = kRenderFxNone
    switch ( iAction )
    {
        case TARGET_SELECT:
        {
            if ( ePad[PAD_FLAGS] & FLAG_ACTIVE ) { iRenderColor[0] = g_iColorActive[0];      iRenderColor[1] = g_iColorActive[1];     iRenderColor[2] = g_iColorActive[2]; }
            else                                 { iRenderColor[0] = g_iColorInactive[0];    iRenderColor[1] = g_iColorInactive[1];   iRenderColor[2] = g_iColorInactive[2]; }

            iRender = ePad[PAD_FLAGS] & FLAG_SHOW ? kRenderTransColor : kRenderTransAlpha
            iRenderAmt = ePad[PAD_FLAGS] & FLAG_SHOW ? 16 : 32
            iRenderFx = kRenderFxGlowShell
        }
        case TARGET_GHOST:
        {
            iRender = kRenderTransAlpha
            iRenderAmt = g_eSettings[SETTING_GHOST_ALPHA]
        }
        case TARGET_HIDE:
        {
            iRender = kRenderTransAlpha
            iRenderAmt = 0
        }
        case TARGET_CLEAR:
        {
            iRender = kRenderNormal
            iRenderAmt = 255
        }
    }

    set_ent_rendering(ePad[PAD_ID], iRenderFx, iRenderColor[0], iRenderColor[1], iRenderColor[2], iRender, iRenderAmt)
}

stock padSetDelay(ePad[PAD])
{
    if ( ePad[PAD_FLAGS] & FLAG_ACTIVE )
    {
        new Float:fCurrentTime
        fCurrentTime = get_gametime()

        if ( ePad[PAD_FLAGS] & FLAG_ACTIVE_DELAY )
        {
            ePad[PAD_FLAGS] &= ~FLAG_ACTIVE
            ePad[PAD_NEXT_ENABLE] = fCurrentTime + random_float(ePad[PAD_ACTIVE_DELAY][0], ePad[PAD_ACTIVE_DELAY][1])

            padSetState(ePad)
        }
        else
        {
            if ( ePad[PAD_FLAGS] & FLAG_ACTIVE_DURATION )
                ePad[PAD_NEXT_DISABLE] = fCurrentTime + random_float(ePad[PAD_ACTIVE_DURATION][0], ePad[PAD_ACTIVE_DURATION][1])
        }
    }
}

stock padSetState(ePad[PAD])
{
    if ( ePad[PAD_FLAGS] & FLAG_SHOW )
    {
        set_pev(ePad[PAD_ID], pev_solid, SOLID_BBOX)
        padSetSeq(ePad, ePad[PAD_FLAGS] & FLAG_ACTIVE ? PAD_SEQ_RETURN : PAD_SEQ_ACTIVE)
        padSelect(ePad, TARGET_CLEAR)
    }
    else
    {
        set_pev(ePad[PAD_ID], pev_solid, SOLID_NOT)
        padSetSeq(ePad, PAD_SEQ_ACTIVE)
        padSelect(ePad, TARGET_HIDE)
    }
}

stock padReset(ePad[PAD])
{
    ePad[PAD_FLAGS] &= ~(FLAG_SHOW | FLAG_ACTIVE)
    ePad[PAD_NEXT_ENABLE] = 0.0
    ePad[PAD_NEXT_DISABLE] = 0.0

    padSetState(ePad)
}

stock padTerminate()
{
    new ePad[PAD]
    for ( new i = 0; i < g_iPad; i ++ )
    {
        ArrayGetArray(g_aPad, i, ePad)
        if ( !(ePad[PAD_FLAGS] & FLAG_PENDING) )
            continue

        ePad[PAD_FLAGS] |= FLAG_ACTIVE
        ePad[PAD_FLAGS] &= ~FLAG_PENDING
        ArraySetArray(g_aPad, i, ePad)
    }
}

stock padSound(iEnt, iSound, bool:bPlayer = true)
{
    new szSample[64]
    switch( iSound )
    {
        case SOUND_MENU_NAV:    copy(szSample, charsmax(szSample), SOUND_NAV)
        case SOUND_MENU_REMOVE: copy(szSample, charsmax(szSample), SOUND_REMOVE)
        case SOUND_MENU_ALERT:  copy(szSample, charsmax(szSample), SOUND_ALERT)
        case SOUND_JUMP:        ArrayGetString(g_eSettings[SETTING_SOUND_JUMP], random(ArraySize(g_eSettings[SETTING_SOUND_JUMP])), szSample, charsmax(szSample))
    }

    if ( bPlayer )
        client_cmd(iEnt, "spk %s", szSample)
    else
        engfunc(EngFunc_EmitSound, iEnt, CHAN_ITEM, szSample, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

stock padGet(ePad[PAD], iEnt)
{
    new iItem
    iItem = pev(iEnt, PAD_ARRAY_ITEM)
    if ( iItem < 0 || iItem >= g_iPad )
        return -1

    ArrayGetArray(g_aPad, iItem, ePad)
    return iItem
}

stock bool:isPad(iEnt)
{
    return pev(iEnt, pev_impulse) == PAD_KEY
}

stock padKill(iEnt)
{
    if (pev_valid(iEnt))
        set_pev(iEnt, pev_flags, pev(iEnt, pev_flags) | FL_KILLME)
}

stock parseSetting(iType, szKey[], iKeyLen, szValue[], iValueLen, any:aOutput[], iOutputLength)
{
    switch ( iType )
    {
        case DTYPE_INT:
        {
            aOutput[0] = str_to_num(szValue)
        }
        case DTYPE_INT_RANGE:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            aOutput[0] = str_to_num(szKey)
            aOutput[1] = str_to_num(szValue)
        }
        case DTYPE_FLOAT:
        {
            aOutput[0] = str_to_float(szValue)
        }
        case DTYPE_FLOAT_RANGE:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            aOutput[0] = str_to_float(szKey)
            aOutput[1] = str_to_float(szValue)
        }
        case DTYPE_INT_LIST:
        {
            new szTok[MAX_VALUE_LENGTH], szTmp[MAX_VALUE_LENGTH], iCounter
            copy(szTmp, charsmax(szTmp), szValue)

            strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
            trim(szTok)
            while ( szTok[0] )
            {
                aOutput[iCounter ++] = str_to_num(szTok)

                strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
                trim(szTok)
            }
        }
        case DTYPE_FLOAT_LIST:
        {
            new szTok[MAX_VALUE_LENGTH], szTmp[MAX_VALUE_LENGTH], iCounter
            copy(szTmp, charsmax(szTmp), szValue)

            strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
            trim(szTok)
            while ( szTok[0] )
            {
                aOutput[iCounter ++] = str_to_float(szTok)

                strtok(szTmp, szTok, charsmax(szTok), szTmp, charsmax(szTmp), ' ')
                trim(szTok)
            }
        }
        case DTYPE_BOOL:
        {
            aOutput[0] = bool:str_to_num(szValue)
        }
        case DTYPE_FLAGS:
        {
            aOutput[0] = read_flags(szValue)
        }
        case DTYPE_ARRAY_STRING:
        {
            replace_all(szValue, iValueLen, "^"", " ")
            replace_all(szValue, iValueLen, "^^n", "^n")
            ArrayPushString(aOutput[0], szValue)
        }
        case DTYPE_ARRAY_SOUND:
        {
            ArrayPushString(aOutput[0], szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_MODEL:
        {
            copy(aOutput, iOutputLength, szValue)
            if ( !g_bFileWasRead ) precache_model(szValue)
        }
        case DTYPE_STRING_SOUND:
        {
            copy(aOutput, iOutputLength, szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_MODEL_ID:
        {
            if ( !g_bFileWasRead )
                aOutput[0] = precache_model(szValue)
        }
    }
}

stock EnableAction(id)
{
    if ( !g_ePlayerData[id][PDATA_PAD_ACTION] )
    {
        new ePad[PAD]
        for ( new i = 0; i < g_iPad; i ++ )
        {
            ArrayGetArray(g_aPad, i, ePad)
            if ( ePad[PAD_FLAGS] & FLAG_SHOW )
                continue

            padSelect(ePad, TARGET_GHOST)
        }

        g_ePlayerData[id][PDATA_PAD_ACTION] = true
        if ( ++ g_iActivePlayers == 1 )
            EnableForward()
    }
}

stock DisableAction(id)
{
    if ( g_ePlayerData[id][PDATA_PAD_ACTION] )
    {
        new ePad[PAD]
        for ( new i = 0; i < g_iPad; i ++ )
        {
            ArrayGetArray(g_aPad, i, ePad)
            if ( ePad[PAD_FLAGS] & FLAG_SHOW )
                continue

            padSelect(ePad, TARGET_HIDE)
        }

        g_ePlayerData[id][PDATA_PAD_ACTION] = false
        if ( -- g_iActivePlayers == 0 )
            DisableForward()
    }
}

stock EnableForward()
{
    g_iFwdUpdateClientData = register_forward(FM_UpdateClientData, "fwdUpdateClientData", 1)
    EnableHamForward(g_iFwdSpawn)
    EnableHamForward(g_iFwdPreThink)
    EnableHamForward(g_iFwdKilled)
}

stock DisableForward()
{
    unregister_forward(FM_UpdateClientData, g_iFwdUpdateClientData, 1)
    DisableHamForward(g_iFwdSpawn)
    DisableHamForward(g_iFwdPreThink)
    DisableHamForward(g_iFwdKilled)
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}


