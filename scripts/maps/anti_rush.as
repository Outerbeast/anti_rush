/* anti_rush Entity Version 1.1
by Outerbeast
Custom entity for creating percentage player condition requirements for level progression
For install and usage instructions, see anti_rush.fgd
*/
namespace ANTI_RUSH
{

enum antirush_modes
{
    DEFAULT = 0,    // Let the map control AntiRush mode
    FORCE_ON,       // Have AntiRush enabled for all (supported) levels
    FORCE_OFF,      // Force AntiRush disabled for all (supported) levels
    SOLO          // Disable AntiRush in single player
};

enum antirush_flags
{
    SF_START_OFF        = 1 << 0,
    SF_NO_MS            = 1 << 1,
    SF_NO_SOUND         = 1 << 2,
    SF_NO_ICON          = 1 << 3,
    SF_REMEMBER_PLAYER  = 1 << 4
};

array<EHandle> H_AR_ENTITIES;

const uint OverrideSetting = DEFAULT; // Override the map setting for AntiRush. See "antirush_modes" enum for possible options
string RemoveEntities;

bool IsActive()
{
    return g_CustomEntityFuncs.IsCustomEntity( "anti_rush" );
}

bool EntityRegister(bool blEnable = true, uint iAntiRushMode = OverrideSetting)
{
    if( IsActive() && iAntiRushMode != FORCE_OFF )
        return true;
    
    switch( iAntiRushMode )
    {
        case FORCE_ON:
            g_CustomEntityFuncs.RegisterCustomEntity( "ANTI_RUSH::anti_rush", "anti_rush" );
            break;

        case FORCE_OFF:
        {
            if( g_CustomEntityFuncs.IsCustomEntity( "anti_rush" ) )
                g_CustomEntityFuncs.UnRegisterCustomEntity( "anti_rush" );

            break;
        }
            
        case SOLO:
        {
            if( g_Engine.maxClients > 2 && blEnable )
                g_CustomEntityFuncs.RegisterCustomEntity( "ANTI_RUSH::anti_rush", "anti_rush" );

            break;
        }

        default:
        {
            if( blEnable )
                g_CustomEntityFuncs.RegisterCustomEntity( "ANTI_RUSH::anti_rush", "anti_rush" );
        }
    }

    if( !IsActive() && RemoveEntities != "" )
        g_Scheduler.SetTimeout( "AREntityRemove", 0.1f, RemoveEntities );
    else
        ARLoadEnts( "" );

    return g_CustomEntityFuncs.IsCustomEntity( "anti_rush" );
}
// Use preconfigured antirush entities
bool ARLoadEnts(string strCustomFile)
{
    if( !IsActive() )
        return false;
    
    const string strAntiRushFile = strCustomFile == "" ? "store/antirush/" + string( g_Engine.mapname ) + ".antirush" : strCustomFile;
    // This check is not critical. Only doing this so to avoid "file doesn't exist" warnings filling the logs.
    if( g_FileSystem.OpenFile( "scripts/maps/" + strAntiRushFile, OpenFile::READ ) is null )
        return false;

    return g_EntityLoader.LoadFromFile( strAntiRushFile );
}
// Routine for cleaning up antirush remnant entities when disabled - call in MapStart(). Wildcards supported
void AREntityRemove(string strAntiRushRemoveList)
{
    if( IsActive() || strAntiRushRemoveList == "" )
        return;

    const array<string> STR_ANTIRUSH_REMOVE_LST = strAntiRushRemoveList.Split( ";" );

    if( STR_ANTIRUSH_REMOVE_LST.length() < 1 )
        return;

    for( uint i = 0; i < STR_ANTIRUSH_REMOVE_LST.length(); i++ )
    {
        if( STR_ANTIRUSH_REMOVE_LST[i] == "" )
            continue;

        CBaseEntity@ pEntity;

        while( ( @pEntity = g_EntityFuncs.FindEntityByTargetname( pEntity, STR_ANTIRUSH_REMOVE_LST[i] ) ) !is null )
            g_EntityFuncs.Remove( pEntity );

        while( ( @pEntity = g_EntityFuncs.FindEntityByString( pEntity, "target", STR_ANTIRUSH_REMOVE_LST[i] ) ) !is null )
            g_EntityFuncs.Remove( pEntity );

        while( ( @pEntity = g_EntityFuncs.FindEntityByString( pEntity, "model", STR_ANTIRUSH_REMOVE_LST[i] ) ) !is null )
            g_EntityFuncs.Remove( pEntity );
    }
}

final class anti_rush : ScriptBaseEntity // Need a ScriptBaseToggleEntity baseclass please.
{
    private EHandle hAntiRushIcon, hAntiRushLock;
    private array<EHandle> H_ANTIRUSH_BORDER_BEAMS;
    
    private CSprite@ pAntiRushIcon
    {
        get { return hAntiRushIcon ? cast<CSprite@>( hAntiRushIcon.GetEntity() ) : null; }
        set { hAntiRushIcon = EHandle( @value ); }
    }

    private CScheduledFunction@ fnTriggerBlocked, fnKillTarget, fnIconFade, fnBorderFade;

    private string strAntiRushIcon, strMaster, strKillTarget, strLockEnts, strBorderBeamPoints;
    private Vector vecZoneCornerMin, vecZoneCornerMax, vecBlockerCornerMin, vecBlockerCornerMax;
    private float
        flTargetDelay,
        flFadeTime = 5.0f,
        flZoneRadius = 512.0f;
    private uint8 iVpType;
    private bool blInitialised, blAntiRushBarrier;

    bool KeyValue(const string& in szKey, const string& in szValue)
    {
        if( szKey == "icon" )
            strAntiRushIcon = szValue;
        else if( szKey == "icon_drawtype" )
            iVpType = atoui( szValue );
        else if( szKey == "master" )// This should be a standard CBaseEntity property!!
            strMaster = szValue;
        else if( szKey == "killtarget" )// This should be a standard CBaseEntity property!!!
            strKillTarget = szValue;
        else if( szKey == "lock" )
            strLockEnts = szValue;
        else if( szKey == "zoneradius" )
            flZoneRadius = Math.clamp( 16.0f, 2048.0f, atof( szValue ) );
        else if( szKey == "zonecornermin" )
            g_Utility.StringToVector( vecZoneCornerMin, szValue );
        else if( szKey == "zonecornermax" )
            g_Utility.StringToVector( vecZoneCornerMax, szValue );
        else if( szKey == "blockercornermin" )
            g_Utility.StringToVector( vecBlockerCornerMin, szValue );
        else if( szKey == "blockercornermax" )
            g_Utility.StringToVector( vecBlockerCornerMax, szValue );
        else if( szKey == "borderbeampoints" )
            strBorderBeamPoints = szValue;
        else if( szKey == "percentage" )
            self.pev.frame = atof( szValue ) < 0.0f ? 0.0f : atof( szValue );
        else if( szKey == "delay" )// This should be a standard CBaseEntity property!!!
            flTargetDelay = atof( szValue ) < 0.0f ? 0.0f : atof( szValue );
        else if( szKey == "fadetime" )
            flFadeTime = atof( szValue ) < 0.0f ? 0.0f : atof( szValue );
        else
            return BaseClass.KeyValue( szKey, szValue );
            
        return true;
    }
	
    void Precache()
    {
        if( strAntiRushIcon == "" )
            strAntiRushIcon = "sprites/antirush/percent.spr";

        if( self.pev.noise == "" )
            self.pev.noise = "buttons/bell1.wav";
    
        g_Game.PrecacheModel( strAntiRushIcon );
        g_Game.PrecacheGeneric( strAntiRushIcon );

        g_Game.PrecacheModel( "sprites/laserbeam.spr" );

        g_SoundSystem.PrecacheSound( self.pev.noise );
        g_Game.PrecacheGeneric( "sound/" + self.pev.noise );

        BaseClass.Precache();
    }

    void Spawn()
    {
        self.Precache();
        self.pev.movetype   = MOVETYPE_NONE;
        self.pev.solid      = SOLID_NOT;
        self.pev.effects    |= EF_NODRAW;
        g_EntityFuncs.SetOrigin( self, self.pev.origin );

        BaseClass.Spawn();
    }

    void PostSpawn()
    {   
        if( !self.pev.SpawnFlagBitSet( SF_START_OFF ) )
            blInitialised = Initialise();
        // If set, entity will trigger "netname" when it spawns
        if( self.pev.netname != "" && self.pev.netname != self.GetTargetname() )
            g_EntityFuncs.FireTargets( "" + self.pev.netname, self, self, USE_TOGGLE, 0.0f, 0.5f );

        H_AR_ENTITIES.insertLast( self );
    }
    // Configuring the settings for each antirush component
    bool Initialise()
    {
        if( !self.pev.SpawnFlagBitSet( SF_NO_ICON ) )
            CreateIcon();

        if( vecBlockerCornerMin != g_vecZero && 
            vecBlockerCornerMax != g_vecZero && 
            vecBlockerCornerMin != vecBlockerCornerMax )
            blAntiRushBarrier = CreateBarrier();

        if( self.pev.target != "" || strLockEnts != "" )
        {
            hAntiRushLock = CreateLock();

            if( hAntiRushLock )
                @hAntiRushLock.GetEntity().pev.owner = self.edict();
        }

        if( strBorderBeamPoints != "" )
            H_ANTIRUSH_BORDER_BEAMS = DrawBorder();

        self.pev.spawnflags &= ~SF_START_OFF;
        self.pev.nextthink = self.pev.frame >= 0.01f ? g_Engine.time + 5.0f : 0.0f;
        
        return( pAntiRushIcon !is null || 
                hAntiRushLock.IsValid() ||
                blAntiRushBarrier ||
                self.pev.nextthink > g_Engine.time );
    }
    // Auxilliary entities required for antirush logic
    bool CreateIcon()
    {
        @pAntiRushIcon = g_EntityFuncs.CreateSprite( strAntiRushIcon, self.pev.origin, false, 0.0f );
        g_EntityFuncs.DispatchKeyValue( pAntiRushIcon.edict(), "vp_type", iVpType );
        pAntiRushIcon.SetScale( self.pev.scale <= 0.0f ? 0.15f : self.pev.scale );
        pAntiRushIcon.pev.nextthink     = 0.0f;
        pAntiRushIcon.pev.angles        = self.pev.angles;
        pAntiRushIcon.pev.frame         = self.pev.frame;
        pAntiRushIcon.pev.rendermode    = self.pev.rendermode == kRenderFxNone ? int( kRenderTransTexture ) : self.pev.rendermode; // Using the enums here instead thows exception: "Can't implicitly convert from 'int' to 'RenderModes'" - wtf?
        pAntiRushIcon.pev.renderamt     = self.pev.renderamt == 0.0f ? 255.0f : self.pev.renderamt;
        pAntiRushIcon.pev.rendercolor   = self.pev.rendercolor == g_vecZero ? Vector( 255, 0, 0 ) : self.pev.rendercolor;
        @pAntiRushIcon.pev.owner        = self.edict();

        return pAntiRushIcon !is null;
    }

    EHandle CreateLock()
    {
        if( ( strMaster != "" && self.pev.target == strMaster ) || 
            ( self.GetTargetname() != "" && self.pev.target == self.GetTargetname() ) ||
            ( self.pev.SpawnFlagBitSet( SF_NO_MS ) && strLockEnts == "" ) )
            return EHandle();
            
        if( strLockEnts != "" )
        {
            if( self.pev.target == "" )
                self.pev.target = "" + self.GetClassname() + "_ent_ID" + self.edict().serialnumber;

            const array<string> STR_LOCK_ENTS = strLockEnts.Split( ";" );

            for( uint i = 0; i < STR_LOCK_ENTS.length(); i++ )
            {
                if( STR_LOCK_ENTS[i] == "" )
                    continue;

                CBaseToggle@ pBrushEntity;
                // There might be more than one brush entity using the same model
                while( ( @pBrushEntity = cast<CBaseToggle@>( g_EntityFuncs.FindEntityByString( pBrushEntity, "model", STR_LOCK_ENTS[i] ) ) ) !is null )
                {
                    if( pBrushEntity is null || !pBrushEntity.IsBSPModel() || pBrushEntity.m_sMaster != "" )
                        continue;

                    pBrushEntity.m_sMaster = self.pev.target;
                }
            }
        }

        return g_EntityFuncs.CreateEntity( "multisource", {{ "targetname", "" + self.pev.target }} );
    }

    bool CreateBarrier()
    {
        self.pev.mins = vecBlockerCornerMin - self.pev.origin;
        self.pev.maxs = vecBlockerCornerMax - self.pev.origin;
        self.pev.solid = SOLID_BBOX;

        g_EntityFuncs.SetOrigin( self, self.pev.origin );
        g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );

        return self.pev.solid == SOLID_BBOX;
    }

    array<EHandle>@ DrawBorder()
    {
        array<EHandle> H_BEAMS_OUT;
        const array<string> STR_BEAM_POINTS = strBorderBeamPoints.Split( ";" );
        // No such thing as a 2-sided shape.
        if( STR_BEAM_POINTS.length() < 3 )
            return array<EHandle>();

        Vector vecStartPos, vecEndPos;

        for( uint i = 0; i < STR_BEAM_POINTS.length(); i++ )
        {
            if( STR_BEAM_POINTS[i] == "" )
                continue;

            g_Utility.StringToVector( vecStartPos, STR_BEAM_POINTS[i] );
            g_Utility.StringToVector( vecEndPos, i == STR_BEAM_POINTS.length() - 1 ? STR_BEAM_POINTS[0] : STR_BEAM_POINTS[i + 1] );

            if( vecStartPos == vecEndPos )
                continue;

            CBeam@ pBorderBeam = g_EntityFuncs.CreateBeam( "sprites/laserbeam.spr", 7 );
            pBorderBeam.SetFlags( BEAM_POINTS );
            pBorderBeam.SetStartPos( vecStartPos );
            pBorderBeam.SetEndPos( vecEndPos );
            pBorderBeam.SetBrightness( 128 );
            pBorderBeam.SetScrollRate( 100 );
            pBorderBeam.pev.rendercolor = self.pev.rendercolor == g_vecZero ? Vector( 255, 0, 0 ) : self.pev.rendercolor;
            @pBorderBeam.pev.owner = self.edict();

            H_BEAMS_OUT.insertLast( EHandle( pBorderBeam ) );
        }

        return @H_BEAMS_OUT;
    }
    // Calculate percentage of players in the zone
    void Think()
    {
        if( self.pev.frame <= 0.0f )
            return;
        // Why is there no m_sMaster property for CBaseEntity???
        if( !g_EntityFuncs.IsMasterTriggered( strMaster, null ) )
        {
            self.pev.nextthink = g_Engine.time + 0.5f;
            return;
        }
        
        uint 
            iPlayersAlive = 0,
            iPlayersInZone = 0;

        for( int iPlayer = 1; iPlayer <= g_Engine.maxClients; iPlayer++ )
        {
            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayer );
            
            if( pPlayer is null || !pPlayer.IsConnected() || !pPlayer.IsAlive() )
            {
                self.pev.iuser1 &= ~( 1 << ( iPlayer & 31 ) );
                continue;
            }
            
            iPlayersAlive++;

            const bool blPlayerInZone = vecZoneCornerMin != g_vecZero && vecZoneCornerMax != g_vecZero && vecZoneCornerMin != vecZoneCornerMax ?
                                        ( pPlayer.pev.origin.x >= vecZoneCornerMin.x && pPlayer.pev.origin.x <= vecZoneCornerMax.x ) &&
                                        ( pPlayer.pev.origin.y >= vecZoneCornerMin.y && pPlayer.pev.origin.y <= vecZoneCornerMax.y ) &&
                                        ( pPlayer.pev.origin.z >= vecZoneCornerMin.z && pPlayer.pev.origin.z <= vecZoneCornerMax.z ) :
                                        ( self.pev.origin - pPlayer.pev.origin ).Length() <= flZoneRadius && self.FVisibleFromPos( pPlayer.pev.origin, self.pev.origin );

            if( blPlayerInZone )
            {
                @fnTriggerBlocked = self.pev.message != "" && self.pev.message != self.GetTargetname() && self.pev.iuser1 & 1 << ( iPlayer & 31 ) == 0 ? 
                                    g_Scheduler.SetTimeout( this, "TriggerBlocked", 0.0f, EHandle( pPlayer ) ) : null;

                self.pev.iuser1 |= 1 << ( iPlayer & 31 );
                iPlayersInZone++;
            }
            else if( self.pev.iuser1 & 1 << ( iPlayer & 31 ) != 0 && self.pev.SpawnFlagBitSet( SF_REMEMBER_PLAYER ) )
                iPlayersInZone++;
        }
        
        if( iPlayersAlive >= 1 )
        {
            const float
                flCurrentPercent = float( iPlayersInZone ) / float( iPlayersAlive ) + 0.00001f,
                flRequiredPercent = self.pev.frame / 100.0f;

            if( flCurrentPercent >= flRequiredPercent )
            {
                g_Scheduler.RemoveTimer( fnTriggerBlocked );
                self.Use( self, self, USE_ON );
                self.pev.nextthink = 0.0f;// We are done here, stop thinking
                return;
            }
        }

        self.pev.nextthink = g_Engine.time + 0.5f;
    }

    void TriggerBlocked(EHandle hActivator)
    {
        g_EntityFuncs.FireTargets( self.pev.message, hActivator ? hActivator.GetEntity() : null, self, USE_ON, 0.0f, 0.0f );
    }
    // Main triggering business
    void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float value)
    {
        if( !blInitialised )
        {
            blInitialised = Initialise();
            return;
        }
        
        if( !self.pev.SpawnFlagBitSet( SF_NO_SOUND ) )
            g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, self.pev.noise, 0.5f, ATTN_NORM );

        if( pAntiRushIcon !is null )
        {
            pAntiRushIcon.SetColor( 0, 255, 0 );
            // !-BUG-!: CSprite method "float Frames() const" doesn't work. This is the current workaround.
            const int iAntiRushIconFrames = Math.max( 0, g_EngineFuncs.ModelFrames( g_EngineFuncs.ModelIndex( pAntiRushIcon.pev.model ) ) - 1 );
            // Change the icon to display 100% when applicable
            if( self.pev.frame > 0.0f && iAntiRushIconFrames >= 100 )
                pAntiRushIcon.pev.frame = 100.0f;

            if( flFadeTime > 0 )
                @fnIconFade = g_Scheduler.SetTimeout( this, "RemoveIcon", flFadeTime );
        }

        if( blAntiRushBarrier )
        {
            self.pev.solid = SOLID_NOT;
            blAntiRushBarrier = self.pev.solid == SOLID_BBOX;
        }

        if( H_ANTIRUSH_BORDER_BEAMS.length() > 1 )
        {
            for( uint i = 0; i < H_ANTIRUSH_BORDER_BEAMS.length(); i++ )
            {
                if( !H_ANTIRUSH_BORDER_BEAMS[i] )
                    continue;

                H_ANTIRUSH_BORDER_BEAMS[i].GetEntity().pev.rendercolor = Vector( 0, 255, 0 );
            }

            if( flFadeTime > 0 )
                @fnBorderFade = g_Scheduler.SetTimeout( this, "RemoveBorder", flFadeTime + 5.0f );
        }

        if( self.pev.target != "" && self.pev.target != self.GetTargetname() )
            g_EntityFuncs.FireTargets( string( self.pev.target ), pActivator, pCaller, USE_TOGGLE, 0.0f, flTargetDelay );

        if( strKillTarget != "" && strKillTarget != self.GetTargetname() )
            KillTarget( strKillTarget, flTargetDelay );
    }

    void KillTarget(string strTargetname, float flDelay)
    {
        if( strTargetname == "" )
            return;

        if( flDelay > 0.0f )
        {
            @fnKillTarget = g_Scheduler.SetTimeout( this, "KillTarget", flDelay, strTargetname, 0.0f );
            return;
        }
        
        do( g_EntityFuncs.Remove( g_EntityFuncs.FindEntityByTargetname( null, strTargetname ) ) );
        while( g_EntityFuncs.FindEntityByTargetname( null, strTargetname ) !is null );
    }

    void RemoveIcon()
    {
        if( pAntiRushIcon !is null )
            g_EntityFuncs.Remove( pAntiRushIcon );

        if( fnIconFade !is null )
            g_Scheduler.RemoveTimer( fnIconFade );
    }

    void RemoveBorder()
    {
        for( uint i = 0; i < H_ANTIRUSH_BORDER_BEAMS.length(); i++ )
        {
            if( !H_ANTIRUSH_BORDER_BEAMS[i] )
                continue;

            g_EntityFuncs.Remove( H_ANTIRUSH_BORDER_BEAMS[i].GetEntity() );
        }

        if( fnBorderFade !is null )
            g_Scheduler.RemoveTimer( fnBorderFade );
    }

    void UpdateOnRemove()
    {
        RemoveIcon();
        RemoveBorder();

        if( hAntiRushLock )
            g_EntityFuncs.Remove( hAntiRushLock.GetEntity() );

        if( fnKillTarget !is null )
            g_Scheduler.RemoveTimer( fnKillTarget );

        if( fnTriggerBlocked !is null )
            g_Scheduler.RemoveTimer( fnTriggerBlocked );

        BaseClass.UpdateOnRemove();
    }
};

}
/* Special Thanks to:-
- CubeMath - building concept and basis for AntiRush logic
- I_Ka - icon sprites
- H2 - programming support
*/
