/* AntiRush custom entity 
by Outerbeast
*/
#include "cubemath/trigger_once_mp"
#include "cubemath/trigger_multiple_mp"
#include "cubemath/func_wall_custom"

class anti_rush : ScriptBaseEntity
{
    private EHandle hAntiRushBarrier, hAntiRushIcon, hAntiRushLock;

    private string strIconName              = "sprites/antirush/percent.spr";
    private string strSoundName             = "buttons/bell1.wav";
    private string strPercentTriggerType    = "trigger_once_mp";
    private string strMasterName, strKillTarget;

    private Vector vZoneCornerMin, vZoneCornerMax, vBlockerCornerMin, vBlockerCornerMax;

    private float flPercentRequired, flTargetDelay, flTriggerWait;
    private float flFadeTime = 5.0f;

    private uint8 iVpType = 0;

    bool KeyValue(const string& in szKey, const string& in szValue)
    {
        if( szKey == "icon" ) 
        {
            strIconName = szValue;
            return true;
        }
        else if( szKey == "sound" ) 
        {
            strSoundName = szValue;
            return true;
        }
        else if( szKey == "icon_drawtype" ) 
        {
            iVpType = atoi( szValue );
            return true;
        }
        else if( szKey == "master" ) 
        {
            strMasterName = szValue;
            return true;
        }
        else if( szKey == "killtarget" ) 
        {
            strKillTarget = szValue;
            return true;
        }
        else if( szKey == "zonecornermin" ) 
        {
            g_Utility.StringToVector( vZoneCornerMin, szValue );
            return true;
        }
        else if( szKey == "zonecornermax" ) 
        {
            g_Utility.StringToVector( vZoneCornerMax, szValue );
            return true;
        }
        else if( szKey == "blockercornermin" ) 
        {
            g_Utility.StringToVector( vBlockerCornerMin, szValue );
            return true;
        }
        else if( szKey == "blockercornermax" ) 
        {
            g_Utility.StringToVector( vBlockerCornerMax, szValue );
            return true;
        }
        else if( szKey == "percentage" ) 
        {
            flPercentRequired = atof( szValue );
            return true;
        }
        else if( szKey == "wait" )
        {
            flTriggerWait = atof( szValue );
            return true;
        }
        else if( szKey == "delay" )
        {
            flTargetDelay = atof( szValue );
            return true;
        }
        else if( szKey == "fadetime" ) 
        {
            flFadeTime = atof( szValue );
            return true;
        }
        else
            return BaseClass.KeyValue( szKey, szValue );
    }
	
    void Precache()
    {
        g_Game.PrecacheModel( "" + strIconName );
        g_Game.PrecacheGeneric( "" + strIconName );

        g_SoundSystem.PrecacheSound( "" + strSoundName );
    }

    void Spawn()
    {
        self.Precache();
        self.pev.movetype 	= MOVETYPE_NONE;
        self.pev.solid 		= SOLID_NOT;
        g_EntityFuncs.SetOrigin( self, self.pev.origin );
        // Configuring the settings for each antirush component
        if( self.GetTargetname() == "" )
            self.pev.targetname = "" + self.GetClassname() + "_ent" + self.entindex();

        if( flTriggerWait > 0.0f )
            strPercentTriggerType = "trigger_multiple_mp";
        else
            strPercentTriggerType = "trigger_once_mp";

        if( flPercentRequired > 0.01f )
        {   
            if( vZoneCornerMin != g_vecZero && vZoneCornerMax != g_vecZero )
            {
                if( vZoneCornerMin != vZoneCornerMax )
                    CreatePercentPlayerTrigger();
            }
        }

        if( vBlockerCornerMin != g_vecZero && vBlockerCornerMax != g_vecZero ) 
        {
            if( vBlockerCornerMin != vBlockerCornerMax )
                CreateBarrier();
        }

        if( self.pev.scale <= 0 )
            self.pev.scale = 0.15;
        
        CreateIcon();

        if( self.pev.target != "" || self.pev.target != self.GetTargetname() )
            CreateLock();
    }
    // Auxilliary entities required for antirush logic
    void CreatePercentPlayerTrigger()
    {
        dictionary trgr;
        trgr ["minhullsize"]        = "" + vZoneCornerMin.ToString();
        trgr ["maxhullsize"]        = "" + vZoneCornerMax.ToString();
        trgr ["m_flPercentage"]     = "" + flPercentRequired/100; // trigger_once/multiple_mp (annoyingly) wants a decimal fraction, not a whole number for the percentage >:c
        trgr ["target"]             = "" + self.GetTargetname();
        if( strMasterName != "" || strMasterName != "" + self.GetTargetname() ) trgr ["master"] = "" + strMasterName;
        if( strPercentTriggerType == "trigger_multiple_mp" ) trgr ["m_flDelay"] = "" + flTriggerWait;
        CBaseEntity@ pPercentPlayerTrigger = g_EntityFuncs.CreateEntity( "" + strPercentTriggerType, trgr, true );
    }

    void CreateBarrier()
    {
        dictionary wall =
        {
            { "minhullsize", "" + vBlockerCornerMin.ToString() },
            { "maxhullsize", "" + vBlockerCornerMax.ToString() }
        };
        hAntiRushBarrier = EHandle( g_EntityFuncs.CreateEntity( "func_wall_custom", wall, true ) );
    }

    void CreateIcon()
    {
        CSprite@ pAntiRushIcon = g_EntityFuncs.CreateSprite( strIconName, self.GetOrigin(), false, 0.0f );
        g_EntityFuncs.DispatchKeyValue( pAntiRushIcon.edict(), "vp_type", iVpType );
        pAntiRushIcon.SetScale( self.pev.scale );
        pAntiRushIcon.pev.angles        = self.pev.angles;
        pAntiRushIcon.pev.nextthink     = 0.0f;
        pAntiRushIcon.pev.frame         = flPercentRequired;
        pAntiRushIcon.pev.rendermode    = self.pev.rendermode == 0 ? 2 : self.pev.rendermode; // Using the enums here instead thows exception: "Can't implicitly convert from 'int' to 'RenderModes'" - wtf?
        pAntiRushIcon.pev.rendercolor   = self.pev.rendercolor == g_vecZero ? Vector( 255, 0, 0 ) : self.pev.rendercolor;
        pAntiRushIcon.pev.renderamt     = self.pev.renderamt == 0 ? 255.0f : self.pev.renderamt;
        hAntiRushIcon = pAntiRushIcon;
    }

    void CreateLock()
    {
        dictionary ms = { { "targetname", "" + self.pev.target } };
        hAntiRushLock = EHandle( g_EntityFuncs.CreateEntity( "multisource", ms, true ) );
    }
    // Main triggering business
    void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float value)
    {
        if( hAntiRushIcon )
        {
            g_SoundSystem.EmitSound( hAntiRushIcon.GetEntity().edict(), CHAN_ITEM, "" + strSoundName, 0.5f, ATTN_NORM );
            hAntiRushIcon.GetEntity().pev.rendercolor = Vector( 0, 255, 0 );

            if( flPercentRequired > 0.0f )
                hAntiRushIcon.GetEntity().pev.frame = 100.0f;

            if( flFadeTime > 0 )
                g_Scheduler.SetTimeout( this, "RemoveIcon", flFadeTime );
        }

        if( hAntiRushBarrier )
            g_EntityFuncs.Remove( hAntiRushBarrier.GetEntity() );

        g_Scheduler.SetTimeout( this, "TargetFuncs", flTargetDelay );
    }

    void TargetFuncs()
    {
        self.SUB_UseTargets( @self, USE_TOGGLE, 0 );
        // Why is there no m_sKillTarget property for CBaseEntity???
        CBaseEntity@ pKillTargetEnt;
        if( strKillTarget != "" || strKillTarget != self.GetTargetname() )
        {
            while( ( @pKillTargetEnt = g_EntityFuncs.FindEntityByTargetname( pKillTargetEnt, "" + strKillTarget ) ) !is null )
                g_EntityFuncs.Remove( pKillTargetEnt );
        }
    }

    void RemoveIcon()
    {
        if( hAntiRushIcon )
            g_EntityFuncs.Remove( hAntiRushIcon.GetEntity() );
    }

    void UpdateOnRemove()
    {
        RemoveIcon();

        if( hAntiRushBarrier )
            g_EntityFuncs.Remove( hAntiRushBarrier.GetEntity() );

        if( hAntiRushLock )
            g_EntityFuncs.Remove( hAntiRushLock.GetEntity() );
    }
}

void RegisterAntiRushEntity()
{
    g_CustomEntityFuncs.RegisterCustomEntity( "anti_rush", "anti_rush" );
    g_CustomEntityFuncs.RegisterCustomEntity( "trigger_once_mp", "trigger_once_mp" );
    g_CustomEntityFuncs.RegisterCustomEntity( "trigger_multiple_mp", "trigger_multiple_mp" );
    g_CustomEntityFuncs.RegisterCustomEntity( "func_wall_custom", "func_wall_custom" );
}
/* Special Thanks to:-
- CubeMath - trigger_once/multiple and func_wall_custom entity scripts
- I_Ka - icon sprites
*/