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
#define PAD_KEY             114477
#define PAD_ARRAY_ITEM      pev_iuser1
#define TARGET_OFFSET_UP    25.0

#define PAD_SEQ_ACTIVE      0
#define PAD_SEQ_RETURN      1

new const PLUGIN_VERSION[]          = "1.0"
new const Float:DELAY_ON_CONNECT    = 1.0
new const ERROR_FILE[]              = "XenJumpPad_ERRORS.log"

enum
{
    SECTION_NONE,
    SECTION_MAIN_SETTINGS,
    SECTION_PAD
}

enum
{
    DTYPE_FLOAT,
    DTYPE_FLOAT_RANGE,
    DTYPE_INT,
    DTYPE_INT_RANGE,
    DTYPE_BOOL,
    DTYPE_FLAGS,
    DTYPE_VECTOR,
    DTYPE_VECTOR_FLOAT,
    DTYPE_ARRAY,
    DTYPE_ARRAY_SOUND,
    DTYPE_STRING_MODEL,
    DTYPE_STRING_SOUND,
    DTYPE_STRING_SPRITE
}

enum
{
    FLAG_ACTIVE_DELAY       = (1 << 0),
    FLAG_ACTIVE_DURATION    = (1 << 1),

    FLAG_SHOW               = (1 << 2),
    FLAG_GHOST              = (1 << 3),
    FLAG_GROUND             = (1 << 4),
    FLAG_SELECT             = (1 << 5),
    FLAG_ACTIVE             = (1 << 6)
}

enum _:MAIN_SETTINGS
{
    SETTING_DEFAULT_MODEL[MAX_RESOURCE_PATH_LENGTH],
    SETTING_DEFAULT_FLAGS,
    SETTING_DEFAULT_FRAMERATE,
    Float:SETTING_DEFAULT_FRAMERATE,
    Float:SETTING_DEFAULT_SPAWN_CHANCE,
    Float:SETTING_DEFAULT_ACTIVE_DELAY[2],
    Float:SETTING_DEFAULT_ACTIVE_DURATION[2],
    Float:SETTING_DEFAULT_ACTIVE_COOLDOWN[2],

    Float:SETTING_PAD_MINS[3],
    Float:SETTING_PAD_MAXS[3],
    Float:SETTING_DEFAULT_RADIUS,
    Float:SETTING_DEFAULT_STRENGTH[2],
    Float:SETTING_DEFAULT_COOLDOWN[2],

    bool:SETTING_PAD_LOAD,
    Float:SETTING_PAD_RANGE,
    Float:SETTING_PAD_CHECK,
    Float:SETTING_OFFSET_BASE,
    Float:SETTING_OFFSET[2],
    Float:SETTING_OFFSET_STEP,
    SETTING_GHOST_ALPHA,

    SETTING_SOUND_MENU_NAV[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_MENU_REMOVE[MAX_RESOURCE_PATH_LENGTH],
    SETTING_SOUND_MENU_ALERT[MAX_RESOURCE_PATH_LENGTH],
    Array:SETTING_SOUND_JUMP,

    SETTING_COLOR_ACTIVE[3],
    SETTING_COLOR_INACTIVE[3]
}

enum _:PAD
{
    PAD_ID,
    PAD_ITEM,
    PAD_FLAGS,
    PAD_NAME[MAX_VALUE_LENGTH],
    PAD_MODEL[MAX_RESOURCE_PATH_LENGTH],

    Float:PAD_ORIGIN[3],
    Float:PAD_ANGLES[3],
    Float:PAD_MINS[3],
    Float:PAD_MAXS[3],

    Float:PAD_RADIUS,
    Float:PAD_STRENGTH[2],
    Float:PAD_COOLDOWN[2],

    Float:PAD_SPAWN_CHANCE,
    Float:PAD_ACTIVE_DELAY[2],
    Float:PAD_ACTIVE_DURATION[2],
    Float:PAD_ACTIVE_COOLDOWN[2],

    Float:PAD_NEXT_ENABLE,
    Float:PAD_NEXT_DISABLE
}

enum _:PLAYER_DATA
{
    PDATA_PAD_GHOST,
    PDATA_PAD_MENU,
    bool:PDATA_PAD_ACTION,
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
    MENU_SHOW,
    MENU_REMOVE,
    MENU_ROTATE
}

enum
{
    ROOT_CREATE,
    ROOT_SHOW,
    ROOT_REMOVE,
    ROOT_SAVE,

    ROOT_NOCLIP = 5,
    ROOT_GODMODE
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
    REMOVE_NEXT,
    REMOVE_BACK,

    REMOVE_CURRENT = 3,
    REMOVE_ALL
}

enum
{
    ROTATE_UP,
    ROTATE_DOWN,

    ROTATE_GROUND = 3,
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
    "menuHandlerShow",
    "menuHandlerRemove",
    "menuHandlerRotate"
}

new g_szCN[] = "xenjumppad"

new Array:g_aPad,
    Array:g_aPadConfig,
    g_eSettings[MAIN_SETTINGS],
    g_ePlayerData[MAX_PLAYERS + 1][PLAYER_DATA],
    bool:g_bFileWasRead = false,
    g_iPad, g_iPadConfig,
    g_iMaxPlayers

public plugin_init()
{
    register_plugin("Xen Jump Pad", PLUGIN_VERSION, "RedSMURF")

    register_clcmd("say /xenjump",         "cmdMenu", ADMIN_RCON)
    register_clcmd("say_team /xenjump",    "cmdMenu", ADMIN_RCON)
    register_concmd("xenjump_reload",      "cmdReload", ADMIN_RCON, "-- Reloads the configuration file")

    register_dictionary("XenJumpPad.txt")

    register_forward(FM_UpdateClientData, "fwdUpdateClientData", 1)
    register_forward(FM_AddToFullPack, "fwdAddToFullPack", 1)
    RegisterHam(Ham_Spawn, "info_target", "fwdSpawn", 1)
    RegisterHam(Ham_Player_PreThink, "player", "fwdPreThink")
    RegisterHam(Ham_Killed, "player", "fwdKilled", 1)

    register_logevent("eventRoundStart", 2, "1=Round_Start")
    set_task(0.1, "padTask", .flags = "b")

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

public client_command(id)
{
    if ( !g_ePlayerData[id][PDATA_PAD_GHOST] )
        return PLUGIN_CONTINUE

    new szCmd[16]
    read_argv(0, szCmd, charsmax(szCmd))

    if ( contain(szCmd, "weapon_") != -1
    || equal(szCmd, "invnext")
    || equal(szCmd, "invprev")
    || equal(szCmd, "lastinv") )
        return PLUGIN_HANDLED

    return PLUGIN_CONTINUE
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
            set_pev(ePad[PAD_ID], pev_solid, SOLID_BBOX)

            padSetAnim(ePad)
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
                        copy(ePad[PAD_MODEL], charsmax(ePad[PAD_MODEL]), g_eSettings[SETTING_DEFAULT_MODEL])
                        xs_vec_copy(g_eSettings[SETTING_PAD_MINS], ePad[PAD_MINS])
                        xs_vec_copy(g_eSettings[SETTING_PAD_MAXS], ePad[PAD_MAXS])
                        ePad[PAD_FLAGS]               = g_eSettings[SETTING_DEFAULT_FLAGS]
                        ePad[PAD_SPAWN_CHANCE]        = g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE]
                        ePad[PAD_ACTIVE_DELAY][0]     = g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][0]
                        ePad[PAD_ACTIVE_DELAY][1]     = g_eSettings[SETTING_DEFAULT_ACTIVE_DELAY][1]
                        ePad[PAD_ACTIVE_DURATION][0]  = g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][0]
                        ePad[PAD_ACTIVE_DURATION][1]  = g_eSettings[SETTING_DEFAULT_ACTIVE_DURATION][1]
                        ePad[PAD_ACTIVE_COOLDOWN][0]  = g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][0]
                        ePad[PAD_ACTIVE_COOLDOWN][1]  = g_eSettings[SETTING_DEFAULT_ACTIVE_COOLDOWN][1]
                        ePad[PAD_RADIUS]              = g_eSettings[SETTING_DEFAULT_RADIUS]
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
                        if ( equali(szKey, "SETTING_DEFAULT_MODEL") )
                            parseSetting(DTYPE_STRING_MODEL, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_MODEL], charsmax(g_eSettings[SETTING_DEFAULT_MODEL]))
                        else if ( equali(szKey, "SETTING_DEFAULT_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_FLAGS], charsmax(g_eSettings[SETTING_DEFAULT_FLAGS]))
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
                        else if ( equali(szKey, "SETTING_DEFAULT_STRENGTH") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_STRENGTH], charsmax(g_eSettings[SETTING_DEFAULT_STRENGTH]))
                        else if ( equali(szKey, "SETTING_DEFAULT_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_DEFAULT_COOLDOWN], charsmax(g_eSettings[SETTING_DEFAULT_COOLDOWN]))
                        else if ( equali(szKey, "SETTING_PAD_MINS") )
                            parseSetting(DTYPE_VECTOR_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_PAD_MINS], charsmax(g_eSettings[SETTING_PAD_MINS]))
                        else if ( equali(szKey, "SETTING_PAD_MAXS") )
                            parseSetting(DTYPE_VECTOR_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_PAD_MAXS], charsmax(g_eSettings[SETTING_PAD_MAXS]))
                        else if ( equali(szKey, "SETTING_PAD_LOAD") )
                            parseSetting(DTYPE_BOOL, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_PAD_LOAD], charsmax(g_eSettings[SETTING_PAD_LOAD]))
                        else if ( equali(szKey, "SETTING_PAD_CHECK") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_PAD_CHECK], charsmax(g_eSettings[SETTING_PAD_CHECK]))
                        else if ( equali(szKey, "SETTING_OFFSET_BASE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_BASE], charsmax(g_eSettings[SETTING_OFFSET_BASE]))
                        else if ( equali(szKey, "SETTING_OFFSET") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET], charsmax(g_eSettings[SETTING_OFFSET]))
                        else if ( equali(szKey, "SETTING_OFFSET_STEP") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_OFFSET_STEP], charsmax(g_eSettings[SETTING_OFFSET_STEP]))
                        else if ( equali(szKey, "SETTING_GHOST_ALPHA") )
                            parseSetting(DTYPE_INT, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_GHOST_ALPHA], charsmax(g_eSettings[SETTING_GHOST_ALPHA]))
                        else if ( equali(szKey, "SETTING_SOUND_MENU_NAV") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_MENU_NAV], charsmax(g_eSettings[SETTING_SOUND_MENU_NAV]))
                        else if ( equali(szKey, "SETTING_SOUND_MENU_REMOVE") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_MENU_REMOVE], charsmax(g_eSettings[SETTING_SOUND_MENU_REMOVE]))
                        else if ( equali(szKey, "SETTING_SOUND_MENU_ALERT") )
                            parseSetting(DTYPE_STRING_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_MENU_ALERT], charsmax(g_eSettings[SETTING_SOUND_MENU_ALERT]))
                        else if ( equali(szKey, "SETTING_SOUND_JUMP") )
                            parseSetting(DTYPE_ARRAY_SOUND, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_SOUND_JUMP], charsmax(g_eSettings[SETTING_SOUND_JUMP]))
                        else if ( equali(szKey, "SETTING_COLOR_ACTIVE") )
                            parseSetting(DTYPE_VECTOR, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_COLOR_ACTIVE], charsmax(g_eSettings[SETTING_COLOR_ACTIVE]))
                        else if ( equali(szKey, "SETTING_COLOR_INACTIVE") )
                            parseSetting(DTYPE_VECTOR, szKey, charsmax(szKey), szValue, charsmax(szValue), g_eSettings[SETTING_COLOR_INACTIVE], charsmax(g_eSettings[SETTING_COLOR_INACTIVE]))
                    }
                    case SECTION_PAD:
                    {
                        if ( equali(szKey, "PAD_MODEL") )
                            parseSetting(DTYPE_STRING_MODEL, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_MODEL], charsmax(ePad[PAD_MODEL]), g_eSettings[SETTING_DEFAULT_MODEL])
                        else if ( equali(szKey, "PAD_FLAGS") )
                            parseSetting(DTYPE_FLAGS, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_FLAGS], charsmax(ePad[PAD_FLAGS]), g_eSettings[SETTING_DEFAULT_FLAGS])
                        else if ( equali(szKey, "PAD_SPAWN_CHANCE") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_SPAWN_CHANCE], charsmax(ePad[PAD_SPAWN_CHANCE]), g_eSettings[SETTING_DEFAULT_SPAWN_CHANCE])
                        else if ( equali(szKey, "PAD_ACTIVE_DELAY") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_ACTIVE_DELAY], charsmax(ePad[PAD_ACTIVE_DELAY]))
                        else if ( equali(szKey, "PAD_ACTIVE_DURATION") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_ACTIVE_DURATION], charsmax(ePad[PAD_ACTIVE_DURATION]))
                        else if ( equali(szKey, "PAD_ACTIVE_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_ACTIVE_COOLDOWN], charsmax(ePad[PAD_ACTIVE_COOLDOWN]))
                        else if ( equali(szKey, "PAD_RADIUS") )
                            parseSetting(DTYPE_FLOAT, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_RADIUS], charsmax(ePad[PAD_RADIUS]), g_eSettings[SETTING_DEFAULT_RADIUS])
                        else if ( equali(szKey, "PAD_STRENGTH") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_STRENGTH], charsmax(ePad[PAD_STRENGTH]), g_eSettings[SETTING_DEFAULT_STRENGTH])
                        else if ( equali(szKey, "PAD_COOLDOWN") )
                            parseSetting(DTYPE_FLOAT_RANGE, szKey, charsmax(szKey), szValue, charsmax(szValue), ePad[PAD_COOLDOWN], charsmax(ePad[PAD_COOLDOWN]), g_eSettings[SETTING_DEFAULT_COOLDOWN])
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
        loadData()
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
        case MENU_SHOW:   { menuShow(id, iMenu);    format(szData, charsmax(szData), "%s^n%L", szData, id, "PAD_ROOT_SHOW"); }
        case MENU_REMOVE: { menuRemove(id, iMenu);  format(szData, charsmax(szData), "%s^n%L", szData, id, "PAD_ROOT_REMOVE"); }
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

    formatex(szItem, charsmax(szItem), "%L", id, "PAD_ROOT_SHOW")
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
            }
            else
            {
                padSound(id, SOUND_MENU_NAV)
                padMenu(id, MENU_CREATE)
            }
        }
        case ROOT_SHOW:
        {
            if ( !g_iPad )
            {
                client_print_color(id, id, "%L %L", id, "PAD_CHAT_TAG", id, "PAD_CHAT_NO_PAD")
                padSound(id, SOUND_MENU_REMOVE)
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
    }

    padCreate(id, item)
    padSound(id, SOUND_MENU_NAV)
    padMenu(id, MENU_ROTATE)

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

    g_ePlayerData[id][PDATA_PAD_ACTION] = true
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_SHOW
    ePad[PAD_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)
}

public menuHandlerShow(id, menu, item)
{
    new ePad[PAD]
    ArrayGetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
    {
        ePad[PAD_FLAGS] &= ~FLAG_SELECT
        ArraySetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)
    }

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

            if ( ePad[PAD_FLAGS] & FLAG_SHOW )
            {
                ePad[PAD_FLAGS] |= FLAG_ACTIVE
                padSetSeq(ePad, PAD_SEQ_RETURN)
                set_pev(ePad[PAD_ID], pev_solid, SOLID_BBOX)
            }
            else
            {
                ePad[PAD_FLAGS] &= ~FLAG_ACTIVE
                padSetSeq(ePad, PAD_SEQ_ACTIVE)
                set_pev(ePad[PAD_ID], pev_solid, SOLID_NOT)
            }

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
                ePad[PAD_FLAGS] |= FLAG_ACTIVE
                padSetSeq(ePad, PAD_SEQ_RETURN)
                set_pev(ePad[PAD_ID], pev_solid, SOLID_BBOX)

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
                ePad[PAD_FLAGS] &= ~FLAG_ACTIVE
                padSetSeq(ePad, PAD_SEQ_ACTIVE)
                set_pev(ePad[PAD_ID], pev_solid, SOLID_NOT)

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
                g_ePlayerData[id][PDATA_PAD_ACTION] = false
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            g_ePlayerData[id][PDATA_PAD_ACTION] = false
            g_ePlayerData[id][PDATA_PAD_MENU] = 0
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

    g_ePlayerData[id][PDATA_PAD_ACTION] = true
    g_ePlayerData[id][PDATA_MENU_TYPE] = MENU_REMOVE
    ePad[PAD_FLAGS] |= FLAG_SELECT
    ArraySetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)
}

public menuHandlerRemove(id, menu, item)
{
    new ePad[PAD]
    ArrayGetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)
    if ( !g_ePlayerData[id][PDATA_MENU_TRACE] )
    {
        ePad[PAD_FLAGS] &= ~FLAG_SELECT
        ArraySetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)
    }

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
                g_ePlayerData[id][PDATA_PAD_ACTION] = false
            }

            g_ePlayerData[id][PDATA_MENU_TRACE] = false
        }
        default:
        {
            g_ePlayerData[id][PDATA_PAD_MENU] = 0
            g_ePlayerData[id][PDATA_PAD_ACTION] = false
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
            ePad[PAD_ANGLES][1] -= 22.5
            if ( ePad[PAD_ANGLES][1] < -180.0 ) ePad[PAD_ANGLES][1] += 360.0

            set_pev(ePad[PAD_ID], pev_angles, ePad[PAD_ANGLES])
            ArraySetArray(g_aPad, iItem, ePad)

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_ROTATE)
        }
        case ROTATE_DOWN:
        {
            pev(ePad[PAD_ID], pev_angles, ePad[PAD_ANGLES])
            ePad[PAD_ANGLES][1] += 22.5
            if ( ePad[PAD_ANGLES][1] > 180.0 ) ePad[PAD_ANGLES][1] -= 360.0

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
        case ROTATE_PLACE:
        {
            padTrace(ePad, id)
            g_ePlayerData[id][PDATA_PAD_GHOST] = 0
            g_ePlayerData[id][PDATA_PAD_ACTION] = false

            ePad[PAD_ANGLES][0] = -ePad[PAD_ANGLES][0]
            ePad[PAD_FLAGS] |= (FLAG_SHOW | FLAG_ACTIVE)
            ePad[PAD_FLAGS] &= ~FLAG_GHOST

            padSetAnim(ePad)
            padSetSolid(ePad)
            ArraySetArray(g_aPad, iItem, ePad)

            client_print_color(id, id, "%L %L", id, "PAD_CHAT_TAG", id, "PAD_CHAT_CREATE_NEW", ePad[PAD_NAME])
            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_ROOT)
        }
        case MENU_EXIT:
        {
            padKill(ePad[PAD_ID])
            padRemove(iItem)
            g_ePlayerData[id][PDATA_PAD_GHOST] = 0
            g_ePlayerData[id][PDATA_PAD_ACTION] = false

            padSound(id, SOUND_MENU_NAV)
            padMenu(id, MENU_CREATE)
        }
        default:
        {
            padKill(ePad[PAD_ID])
            padRemove(iItem)

            g_ePlayerData[id][PDATA_PAD_GHOST] = 0
            g_ePlayerData[id][PDATA_PAD_ACTION] = false
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
    for ( new id = 1; id <= g_iMaxPlayers; id ++ )
    {
        if ( !is_user_alive(id) )
            continue

        if ( !g_ePlayerData[id][PDATA_PAD_GHOST] )
        {
            if ( g_ePlayerData[id][PDATA_PAD_ACTION] )
                padCheck(id)
        }
        else if ( padGet(ePad, g_ePlayerData[id][PDATA_PAD_GHOST]) != -1 )
        {
            padTrace(ePad, id)
        }
    }

    for ( new i = 0; i < g_iPad; i ++ )
    {
        ArrayGetArray(g_aPad, i, ePad)
        bModified = false
        bFound = false

        if ( ePad[PAD_FLAGS] & FLAG_SHOW )
        {
            if ( ePad[PAD_FLAGS] & FLAG_ACTIVE )
            {
                xs_vec_copy(ePad[PAD_ORIGIN], fVec1)
                fVec1[2] += TARGET_OFFSET_UP
                while( (iEnt = engfunc(EngFunc_FindEntityInSphere, iEnt, fVec1, ePad[PAD_RADIUS])) )
                {
                    if ( !pev_valid(iEnt)
                    || ePad[PAD_ID] == iEnt
                    || pev(iEnt, pev_solid) == SOLID_NOT
                    || pev(iEnt, pev_movetype) == MOVETYPE_NONE
                    || pev(iEnt, pev_movetype) == MOVETYPE_FOLLOW )
                        continue

                    bFound = true
                    pev(iEnt, pev_velocity, fVec2)
                    fVec2[2] = random_float(ePad[PAD_STRENGTH][0], ePad[PAD_STRENGTH][1])
                    set_pev(iEnt, pev_velocity, fVec2)
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
    new iEnt
    iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
    if ( !pev_valid(iEnt) )
        return

    new ePad[PAD]
    ArrayGetArray(g_aPadConfig, iItem, ePad)
    ePad[PAD_ID] = iEnt
    ePad[PAD_ITEM] = iItem
    if ( id )
    {
        g_ePlayerData[id][PDATA_PAD_GHOST] = ePad[PAD_ID]
        g_ePlayerData[id][PDATA_PAD_ACTION] = true
        g_ePlayerData[id][PDATA_OFFSET] = g_eSettings[SETTING_OFFSET_BASE]

        ePad[PAD_FLAGS] |= FLAG_GHOST
    }

    set_pev(iEnt, PAD_ARRAY_ITEM, g_iPad)
    set_pev(iEnt, pev_impulse, PAD_KEY)
    set_pev(iEnt, pev_classname, g_szCN)
    engfunc(EngFunc_SetModel, iEnt, g_eSettings[SETTING_DEFAULT_MODEL])

    ArrayPushArray(g_aPad, ePad)
    g_iPad ++

    dllfunc(DLLFunc_Spawn, iEnt)
}

public padRemove(iItem)
{
    new ePad[PAD]
    ArrayDeleteItem(g_aPad, iItem)
    g_iPad --

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

    for ( new i = 0; i < g_iPad; i ++ )
    {
        ArrayGetArray(g_aPad, i, ePad)

        formatex(szData, charsmax(szData), "[%d]^n", i)
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "item = %d^n", ePad[PAD_ITEM])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "origin = %.2f %.2f %.2f^n",
        ePad[PAD_ORIGIN][0], ePad[PAD_ORIGIN][1], ePad[PAD_ORIGIN][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "angles = %.2f %.2f %.2f^n",
        ePad[PAD_ANGLES][0], ePad[PAD_ANGLES][1], ePad[PAD_ANGLES][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "mins = %.2f %.2f %.2f^n",
        ePad[PAD_MINS][0], ePad[PAD_MINS][1], ePad[PAD_MINS][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "maxs = %.2f %.2f %.2f^n",
        ePad[PAD_MAXS][0], ePad[PAD_MAXS][1], ePad[PAD_MAXS][2])
        fputs(iFile, szData)

        formatex(szData, charsmax(szData), "angles = %.2f %.2f %.2f^n",
        ePad[PAD_ANGLES][0], ePad[PAD_ANGLES][1], ePad[PAD_ANGLES][2])
        fputs(iFile, szData)

        ePad[PAD_FLAGS] &= ~(FLAG_GHOST | FLAG_SELECT)
        formatex(szData, charsmax(szData), "flags = %d^n", ePad[PAD_FLAGS])
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
        Float:fOrigin[3], Float:fAngles[3], iItem, iFlags, iCount = -1

    get_mapname(szFile, charsmax(szFile))
    format(szFile, charsmax(szFile), "maps/%s_XenJumpPad.ini", szFile)

    iFile = fopen(szFile, "rt")
    if ( !iFile )
    {
        console_print(0, "%L %L", 0, "PAD_CHAT_TAG", 0, "PAD_CHAT_NO_DATA")
        return PLUGIN_HANDLED
    }

    while( !feof(iFile) )
    {
        fgets(iFile, szData, charsmax(szData))

        if ( szData[0] == '[' )
        {
            if ( iCount != -1 )
                loadDataPad(fOrigin, fAngles, iFlags, iItem, iCount)

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
            else if ( equal(szKey, "angles") )
            {
                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fAngles[0] = str_to_float(szKey)

                strtok(szValue, szKey, charsmax(szKey), szValue, charsmax(szValue), ' ')
                fAngles[1] = str_to_float(szKey)
                fAngles[2] = str_to_float(szValue)
            }
            else if ( equal(szKey, "flags") )
            {
                iFlags = str_to_num(szValue)
            }
        }
    }

    if ( iCount != -1 )
        loadDataPad(fOrigin, fAngles, iFlags, iItem, iCount)

    fclose(iFile)
    return PLUGIN_HANDLED
}

stock loadDataPad(Float:fOrigin[3], Float:fAngles[3], iFlags, iItem, iCount)
{
    new ePad[PAD]
    padCreate(0, iItem)
    ArrayGetArray(g_aPad, iCount, ePad)

    xs_vec_copy(fOrigin, ePad[PAD_ORIGIN])
    xs_vec_copy(fAngles, ePad[PAD_ANGLES])
    set_pev(ePad[PAD_ID], pev_origin, fOrigin)
    set_pev(ePad[PAD_ID], pev_angles, fAngles)

    ePad[PAD_FLAGS] = iFlags
    padSetSeq(ePad, PAD_SEQ_ACTIVE)
    padSetAnim(ePad)
    padSetSolid(ePad, ePad[PAD_FLAGS] & FLAG_SHOW ? true : false)

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

public fwdAddToFullPack(es, e, iEnt, iHost, iHostFlags, iPlayer, pSet)
{
    if ( !pev_valid(iEnt)
    || !isPad(iEnt)
    || !get_orig_retval() )
        return FMRES_IGNORED

    new ePad[PAD]
    if ( padGet(ePad, iEnt) == -1 )
        return FMRES_IGNORED

    new bool:bHidden
    bHidden = !(ePad[PAD_FLAGS] & FLAG_SHOW)

    if ( !g_ePlayerData[iHost][PDATA_PAD_ACTION] )
    {
        if ( bHidden )
            set_es(es, ES_Effects, EF_NODRAW)
    }
    else if ( ePad[PAD_FLAGS] & FLAG_SELECT )
    {
        if ( ePad[PAD_FLAGS] & FLAG_ACTIVE )    set_es(es, ES_RenderColor, g_eSettings[SETTING_COLOR_ACTIVE])
        else                                    set_es(es, ES_RenderColor, g_eSettings[SETTING_COLOR_INACTIVE])

        set_es(es, ES_RenderAmt, 32)
        set_es(es, ES_RenderFx, kRenderFxGlowShell)

        if ( bHidden )
            set_es(es, ES_RenderMode, kRenderTransAlpha)
    }
    else if ( ePad[PAD_FLAGS] & FLAG_GHOST || bHidden )
    {
        set_es(es, ES_RenderMode, kRenderTransAlpha)
        set_es(es, ES_RenderAmt, g_eSettings[SETTING_GHOST_ALPHA])
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

    static iButton, Float:fCurrentTime
    iButton = pev(id, pev_button)
    fCurrentTime = get_gametime()

    if ( g_ePlayerData[id][PDATA_PAD_GHOST] )
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
    }

    return HAM_IGNORED
}

public fwdKilled(id, iAttacker, bGib)
{
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
        ePad[PAD_FLAGS] &= ~FLAG_SELECT
        ArraySetArray(g_aPad, g_ePlayerData[id][PDATA_PAD_MENU], ePad)

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
    xs_vec_copy(ePad[PAD_MINS], fMins)
    xs_vec_copy(ePad[PAD_MAXS], fMaxs)

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

stock padSetSolid(ePad[PAD], bool:bSolid = true)
{
    set_pev(ePad[PAD_ID], pev_solid, bSolid ? SOLID_BBOX : SOLID_NOT)
    set_pev(ePad[PAD_ID], pev_movetype, MOVETYPE_NONE)

    engfunc(EngFunc_SetSize, ePad[PAD_ID], ePad[PAD_MINS], ePad[PAD_MAXS])
    set_rendering(ePad[PAD_ID], kRenderFxNone, 255, 255, 255, kRenderNormal, 255)
}

stock padSetAnim(ePad[PAD])
{
    if ( ePad[PAD_FLAGS] & FLAG_ACTIVE )
    {
        if ( ePad[PAD_FLAGS] & FLAG_ACTIVE_DELAY )
        {
            ePad[PAD_FLAGS] &= ~FLAG_ACTIVE
            ePad[PAD_NEXT_ENABLE] = get_gametime() + random_float(ePad[PAD_ACTIVE_DELAY][0], ePad[PAD_ACTIVE_DELAY][1])
        }
        else
        {
            padSetSeq(ePad, PAD_SEQ_RETURN)

            if ( ePad[PAD_FLAGS] & FLAG_ACTIVE_DURATION )
                ePad[PAD_NEXT_DISABLE] = get_gametime() + random_float(ePad[PAD_ACTIVE_DURATION][0], ePad[PAD_ACTIVE_DURATION][1])
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

stock padReset(ePad[PAD])
{
    set_pev(ePad[PAD_ID], pev_solid, SOLID_NOT)
    ePad[PAD_FLAGS] &= ~(FLAG_SHOW | FLAG_ACTIVE)
    ePad[PAD_NEXT_ENABLE] = 0.0
    ePad[PAD_NEXT_DISABLE] = 0.0

    padSetSeq(ePad, PAD_SEQ_ACTIVE)
}

stock padSound(iEnt, iSound, bool:bPlayer = true)
{
    new szSample[64]
    switch( iSound )
    {
        case SOUND_MENU_NAV:    copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_NAV])
        case SOUND_MENU_REMOVE: copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_REMOVE])
        case SOUND_MENU_ALERT:  copy(szSample, charsmax(szSample), g_eSettings[SETTING_SOUND_MENU_ALERT])
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

stock parseSetting(iType, szKey[], iKeyLen, szValue[], iValueLen, any:output[], iOutputLen, const any:fallback[] = {0.0, 0.0})
{
    switch ( iType )
    {
        case DTYPE_FLOAT_RANGE:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[0] = str_to_float(szKey)
            output[1] = str_to_float(szValue)

            if ( output[0] < 0.0 ) output[0] = fallback[0]
            if ( output[1] < 0.0 ) output[1] = fallback[1]
        }
        case DTYPE_FLOAT:
        {
            output[0] = str_to_float(szValue)
            if ( output[0] < 0.0 ) output[0] = fallback[0]
        }
        case DTYPE_INT_RANGE:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[0] = str_to_num(szKey)
            output[1] = str_to_num(szValue)

            if ( output[0] < 0 ) output[0] = fallback[0]
            if ( output[1] < 0 ) output[1] = fallback[1]
        }
        case DTYPE_INT:
        {
            output[0] = str_to_num(szValue)
            if ( output[0] < 0 ) output[0] = fallback[0]
        }
        case DTYPE_BOOL:
        {
            output[0] = bool:str_to_num(szValue)
        }
        case DTYPE_FLAGS:
        {
            output[0] = read_flags(szValue)
        }
        case DTYPE_VECTOR:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[0] = str_to_num(szKey)

            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[1] = str_to_num(szKey)
            output[2] = str_to_num(szValue)
        }
        case DTYPE_VECTOR_FLOAT:
        {
            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[0] = str_to_float(szKey)

            strtok(szValue, szKey, iKeyLen, szValue, iValueLen, ' ')
            output[1] = str_to_float(szKey)
            output[2] = str_to_float(szValue)
        }
        case DTYPE_ARRAY:
        {
            replace_all(szValue, iValueLen, "^"", " ")
            replace_all(szValue, iValueLen, "^^n", "^n")
            ArrayPushString(output[0], szValue)
        }
        case DTYPE_ARRAY_SOUND:
        {
            ArrayPushString(output[0], szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_MODEL:
        {
            copy(output, iOutputLen, szValue)
            if ( !g_bFileWasRead ) precache_model(szValue)
        }
        case DTYPE_STRING_SOUND:
        {
            copy(output, iOutputLen, szValue)
            if ( !g_bFileWasRead ) precache_sound(szValue)
        }
        case DTYPE_STRING_SPRITE:
        {
            if ( !g_bFileWasRead )
                output[0] = precache_model(szValue)
        }
    }
}

stock LogConfigError(const iLine, const szText[], any:...)
{
    new szError[MAX_PLATFORM_PATH_LENGTH]
    vformat(szError, charsmax(szError), szText, 3)

    log_to_file(ERROR_FILE, "^nLine %d: %s", iLine, szError)
}


