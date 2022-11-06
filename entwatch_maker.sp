#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>

public Plugin myinfo =
{
    name = "EntWatch Config Maker",
    author = "tilgep",
    description = "Makes a basic EntWatch config for the current map.",
    version = "1.2",
    url = "https://github.com/tilgep/EntWatch-Maker"
};

enum Mode
{
    GFL = 0,
    DarkerZ,
    Mapea,
}

#define MODE_INFO "0-none, 1-spam, 2-cd, 3-uses, 4-use w/ cd, 5-cd after uses, 6-counter stop@min, 7-counter stop@max"
#define DEFAULT_DIR_PERMS FPERM_O_READ|FPERM_O_EXEC|FPERM_G_READ|FPERM_G_EXEC|FPERM_U_READ|FPERM_U_WRITE|FPERM_U_EXEC
Mode mode;
char path[PLATFORM_MAX_PATH];
char g_currentmap[128];

ArrayList weps;
ArrayList buts;
ArrayList filt;

ConVar dire;
ConVar style;

public void OnPluginStart()
{
    weps = CreateArray();
    buts = CreateArray();
    filt = CreateArray();
    dire = CreateConVar("ewmaker_path", "addons/sourcemod/configs/entwatch_maker", "Path to store generated configs in. Relative to csgo/", _, true, 0.0, true, 1.0);
    dire.AddChangeHook(Cvar_Changed);

    style = CreateConVar("ewmaker_style", "1", "Options to include (0=GFL style, 1=DarkerZ Style, 2=Mapea MapTrack style)", _, true, 0.0, true, 2.0);
    style.AddChangeHook(Cvar_Changed);

    RegConsoleCmd("sm_ewmake", Command_Make);
    AutoExecConfig();
}

public void Cvar_Changed(ConVar cvar, const char[] oldVal, const char[] newVal)
{
    if(cvar == dire)
    {
        dire.GetString(path, PLATFORM_MAX_PATH);
        if(!DirExists(path)) 
        {
            if(!CreateDirectory(path, DEFAULT_DIR_PERMS))
            {
                LogError("Failed to create directory %s", path);
            }
            else
            {
                LogMessage("Created directory %s", path);
            }
        }
        Format(path, PLATFORM_MAX_PATH, "%s/%s.cfg", path, g_currentmap);
    }
    else if(cvar == style)
    {
        mode = view_as<Mode>(style.IntValue);
    }
}

public void OnMapInit(const char[] mapName)
{
    mode = view_as<Mode>(style.IntValue);
    dire.GetString(path, PLATFORM_MAX_PATH);
    if(!DirExists(path)) 
    {
        if(!CreateDirectory(path, DEFAULT_DIR_PERMS))
        {
            LogError("Failed to create directory %s", path);
        }
        else
        {
            LogMessage("Created directory %s", path);
        }
    }
    Format(path, PLATFORM_MAX_PATH, "%s/%s.cfg", path, mapName);
    strcopy(g_currentmap, sizeof(g_currentmap), mapName);
}

public Action Command_Make(int client, int args)
{
    switch(LoadConfig())
    {
        case 0: ReplyToCommand(client, "Failed to create config file %s", path);
        case 1: ReplyToCommand(client, "No items found in the map!");
        case 2: ReplyToCommand(client, "Config created at %s", path);
    }
    return Plugin_Handled;
}

/**
 * Creates the basic entwatch config for the current map
 * 
 * @return     0 = file failed to open
 *             1 = No items found
 *             2 = Items found and config made
 */
public int LoadConfig()
{
    weps.Clear();
    buts.Clear();
    filt.Clear();
    File file = OpenFile(path, "w");
    if(file==null)
    {
        LogError("Failed to create file %s", path);
        return 0;
    }

    EntityLumpEntry ent;
    char class[64];
    char paren[64];
    char hammer[16];

    // Find entities we might be interested in
    for(int i = 0; i < EntityLump.Length(); i++)
    {
        ent = EntityLump.Get(i);
        int cl = ent.GetNextKey("classname", class, 64);
        if(cl == -1) continue;
        
        ent.GetNextKey("hammerid", hammer, sizeof(hammer));
        if(strncmp(class, "weapon_", 7) == 0)
        {
            if(!StrEqual(hammer, "")) weps.Push(i);
        }
        else if(strncmp(class, "func_button", 11) == 0)
        {
            int parent = ent.GetNextKey("parentname", paren, 64);
            if(parent != -1 && !StrEqual(paren, "")) buts.Push(i);
        }
        else if(strncmp(class, "filter_activator_name", 21) == 0)
        {
            filt.Push(i);
        }
        
        delete ent;
    }

    if(weps.Length == 0)
    {
        delete file;
        return 1;
    }

    if(mode == Mapea)
    {
        file.WriteLine("\"%s\"\n{", g_currentmap);
    }
    else
    {
        file.WriteLine("\"entities\"\n{", g_currentmap);
    }

    char key[64];
    char val[128];
    char targe[64];
    char bhammer[16];
    char filter[64];
    char filterid[16];
    char output[5][32];
    bool knife;
    bool gameui;

    EntityLumpEntry button;
    int index = 0;
    // Go through weapons
    for(int i = 0; i < weps.Length; i++)
    {
        targe[0] = '\0';
        hammer[0] = '\0';
        bhammer[0] = '\0';
        filter[0] = '\0';
        filterid[0] = '\0';
        knife = false;
        gameui = false;
        ent = EntityLump.Get(weps.Get(i));
        bool mapweapon = false;

        //Store properties we might want
        for(int w = 0; w < ent.Length; w++)
        {
            ent.Get(w, key, 64, val, 128);
            if(StrEqual(key, "classname")) knife = StrEqual(val, "weapon_knife");
            else if(StrEqual(key, "targetname"))strcopy(targe, sizeof(targe), val);
            else if(StrEqual(key, "hammerid"))
            {
                strcopy(hammer, sizeof(hammer), val);
                mapweapon = true;
            }
            else if(StrEqual(key, "OnPlayerPickup", false))
            {
                ExplodeString(val, "", output, 5, 32, true);
                if(StrEqual(output[1], "Activate")) gameui = true;
            }
        }

        if(!mapweapon) 
        {
            delete ent;
            continue;
        }

        for(int b = gameui ? buts.Length : 0; b < buts.Length; b++)
        {
            button = EntityLump.Get(buts.Get(b));
            button.GetNextKey("parentname", paren, 64);
            if(StrEqual(paren, targe))
            {
                button.GetNextKey("hammerid", bhammer, sizeof(bhammer));
                button.GetNextKey("filtername", filter, sizeof(filter));
                int fi = button.GetNextKey("OnPressed", val, sizeof(val));
                while(fi != -1)
                {
                    ExplodeString(val, "", output, 5, 32, true);
                    if(StrEqual(output[1], "TestActivator")) break;
                    fi = button.GetNextKey("OnPressed", val, sizeof(val), fi);
                }

                if(fi != -1)
                {
                    EntityLumpEntry filterr;
                    char ftargetname[64];
                    for(int f = 0; f < filt.Length; f++)
                    {
                        filterr = EntityLump.Get(filt.Get(f));
                        filterr.GetNextKey("targetname", ftargetname, sizeof(ftargetname));
                        if(!StrEqual(ftargetname, output[0])) continue;

                        filterr.GetNextKey("filtername", filter, sizeof(filter));
                        filterr.GetNextKey("hammerid", filterid, sizeof(filterid));
                        break;
                    }
                    delete filterr;
                }

                delete button;
                break;
            }
            delete button;
        }

        file.WriteLine("\t\"%d\"", index);
        file.WriteLine("\t{");

        switch(mode)
        {
            case GFL:
            {
                file.WriteLine("\t\t\"name\"            \"%s\" //currently weapon targetname (change me)", targe);
                file.WriteLine("\t\t\"shortname\"       \"%s\" //currently weapon targetname (change me)", targe);
                file.WriteLine("\t\t\"color\"           \"{default}\" // Change me");
                file.WriteLine("\t\t");
                file.WriteLine("\t\t\"buttonclass\"     \"%s\"", gameui ? "game_ui" : "func_button");
                file.WriteLine("\t\t");
                file.WriteLine("\t\t\"filtername\"      \"%s\"", filter);
                file.WriteLine("\t\t\"blockpickup\"     \"false\"");
                file.WriteLine("\t\t\"allowtransfer\"   \"%s\"", knife ? "false" : "true");
                file.WriteLine("\t\t\"forcedrop\"       \"%s\"", knife ? "false" : "true");
                file.WriteLine("\t\t\"chat\"            \"true\"");
                file.WriteLine("\t\t\"hud\"             \"true\"");
                file.WriteLine("\t\t\"hammerid\"        \"%s\"", hammer);
                file.WriteLine("\t\t");
                file.WriteLine("\t\t// [EntWatchMaker] Settings below may need changing.");
                file.WriteLine("\t\t\"mode\"            \"0\" // %s", MODE_INFO);
                file.WriteLine("\t\t");
                file.WriteLine("\t\t\"cooldown\"        \"0\" //mode = 2/4/5");
                file.WriteLine("\t\t\"maxuses\"         \"0\" //mode = 3/4/5");
                file.WriteLine("\t\t\"mathid\"          \"0\" //mode 6/7");
                file.WriteLine("\t\t");
                file.WriteLine("\t\t//\"buttonid\"        \"%s\" //hammerid of a detected button", bhammer);
                file.WriteLine("\t\t\"trigger\"         \"0\"");
                file.WriteLine("\t\t\"physbox\"         \"false\"");
                file.WriteLine("\t\t\"maxamount\"       \"1\"");
            }
            case DarkerZ:
            {
                file.WriteLine("\t\t\"name\"            \"%s\" //currently weapon targetname (change me)", targe);
                file.WriteLine("\t\t\"shortname\"       \"%s\" //currently weapon targetname (change me)", targe);
                file.WriteLine("\t\t\"color\"           \"{default}\" // Change me");
                file.WriteLine("\t\t");
                file.WriteLine("\t\t\"buttonclass\"     \"%s\"", gameui ? "game_ui" : "func_button");
                file.WriteLine("\t\t\"buttonclass2\"    \"\"");
                file.WriteLine("\t\t");
                file.WriteLine("\t\t\"filtername\"      \"%s\"", filter);
                file.WriteLine("\t\t\"blockpickup\"     \"false\"");
                file.WriteLine("\t\t\"allowtransfer\"   \"%s\"", knife ? "false" : "true");
                file.WriteLine("\t\t\"forcedrop\"       \"%s\"", knife ? "false" : "true");
                file.WriteLine("\t\t");
                file.WriteLine("\t\t\"chat\"            \"true\"");
                file.WriteLine("\t\t\"chat_uses\"       \"true\"");
                file.WriteLine("\t\t\"hud\"             \"true\"");
                file.WriteLine("\t\t\"hammerid\"        \"%s\"", hammer);
                file.WriteLine("\t\t");
                file.WriteLine("\t\t// [EntWatchMaker] Settings below may need changing.");
                file.WriteLine("\t\t\"mode\"            \"0\" // %s", MODE_INFO);
                file.WriteLine("\t\t\"mode2\"           \"0\"");
                file.WriteLine("\t\t");
                file.WriteLine("\t\t\"cooldown\"        \"0\" //mode = 2/4/5");
                file.WriteLine("\t\t\"cooldown2\"       \"0\" //mode2 = 2/4/5");
                file.WriteLine("\t\t\"maxuses\"         \"0\" //mode = 3/4/5");
                file.WriteLine("\t\t\"maxuses2\"        \"0\" //mode2 = 3/4/5");
                file.WriteLine("\t\t\"energyid\"        \"0\" //mode = 6/7");
                file.WriteLine("\t\t\"energyid2\"       \"0\" //mode2 = 6/7");
                file.WriteLine("\t\t");
                file.WriteLine("\t\t//\"buttonid\"        \"%s\" //hammerid of a detected button", bhammer);
                file.WriteLine("\t\t//\"buttonid2\"       \"\"");
                file.WriteLine("\t\t\"trigger\"         \"0\"");
                file.WriteLine("\t\t\"physbox\"         \"false\"");
                file.WriteLine("\t\t");
                file.WriteLine("\t\t\"pt_spawner\"      \"\"");
                file.WriteLine("\t\t\"use_priority\"    \"true\"");
            }
            case Mapea:
            {
                file.WriteLine("\t\t\"hammerid\"        \"%s\"", hammer);
                file.WriteLine("\t\t\"name\"            \"%s\" //currently weapon targetname (change me)", targe);
                file.WriteLine("\t\t\"shortname\"       \"%s\" //currently weapon targetname (change me)", targe);
                file.WriteLine("\t\t\"color\"           \"{WHITE}\" // Change me");
                file.WriteLine("\t\t\"glowcolor\"       \"255 255 255 255\" // Change me");
                file.WriteLine("\t\t\"maxamount\"       \"\"");
                file.WriteLine("\t\t");
                file.WriteLine("\t\t\"buttonclass\"     \"%s\"", gameui ? "game_ui" : "func_button");
                file.WriteLine("\t\t\"filterid\"        \"%s\"", filterid);
                file.WriteLine("\t\t\"passive\"         \"\"");
                file.WriteLine("\t\t\"blockpickup\"     \"\"");
                file.WriteLine("\t\t\"forcedrop\"       \"true\"");
                file.WriteLine("\t\t\"maxuses\"         \"-1\"");
                file.WriteLine("\t\t\"cooldown\"        \"\"");
                file.WriteLine("\t\t\"ignoredactions\"  \"\"");
                file.WriteLine("\t\t");
                file.WriteLine("\t\t\"chat\"            \"true\"");
                file.WriteLine("\t\t\"hud\"             \"true\"");
            }
        }
        
        file.WriteLine("\t}");
        index++;
    }
    file.WriteLine("}");
    delete ent;
    delete file;
    return 2;
}