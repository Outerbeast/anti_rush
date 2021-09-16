/* anti_rush Entity Version 1.0
by Outerbeast
Custom entity for percentage player condition requirements for level progression
For install and usage instructions, see anti_rush.fgd
*/
namespace ANTI_RUSH
{

enum antirush_modes
{
    DEFAULT = 0,    // Let the map control AntiRush mode
    FORCE_ON,       // Have AntiRush enabled for all (supported) levels
    FORCE_OFF,      // Force AntiRush disabled for all (supported) levels
    SOLO,           // Disable AntiRush in single player
};

const uint OverrideSetting  = FORCE_ON; // Override the map setting for AntiRush. See "antirush_modes" enum for possible options

enum antirush_flags
{
    START_OFF   = 1 << 0,
    NO_MS       = 1 << 1,
    NO_SOUND    = 1 << 2,
    NO_ICON     = 1 << 3
};

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

            break;
        }
    }

    if( !IsActive() && RemoveEntities != "" )
        g_Scheduler.SetTimeout( "AREntityRemove", 0.1f, RemoveEntities );
    else
        ARLoadEnts( "" );

    return g_CustomEntityFuncs.IsCustomEntity( "anti_rush" );
}
// Use preconfigured antirush entities
void ARLoadEnts(string strCustomFile)
{
    if( !IsActive() )
        return;
    
    const string strAntiRushFile = strCustomFile == "" ? "store/antirush/" + string( g_Engine.mapname ) + ".antirush" : strCustomFile;
    // This check is not critical. Only doing this so to avoid "file doesn't exist" warnings filling the logs.
    if( g_FileSystem.OpenFile( "scripts/maps/" + strAntiRushFile, OpenFile::READ ) is null )
        return;

    g_EntityLoader.LoadFromFile( strAntiRushFile );
    g_EngineFuncs.ServerPrint( "anti_rush: Loaded antirush config- " + "scripts/maps/" + strAntiRushFile + "\n" );
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

class anti_rush : ScriptBaseEntity // Need a ScriptBaseToggleEntity baseclass please.
{
    private EHandle hAntiRushIcon, hAntiRushLock;
    private array<EHandle> H_ANTIRUSH_BORDER_BEAMS;

    private string strIcon = "sprites/antirush/percent.spr", strSound = "buttons/bell1.wav";
    private string strMaster, strKillTarget, strLockEnts, strBorderBeamPoints;

    private Vector vecZoneCornerMin, vecZoneCornerMax, vecBlockerCornerMin, vecBlockerCornerMax;

    private float flTargetDelay, flFadeTime = 5.0f, flZoneRadius = 512.0f;

    private uint8 iVpType = 0;

    private bool blInitialised, blAntiRushBarrier;

    bool KeyValue(const string& in szKey, const string& in szValue)
    {
        if( szKey == "icon" )
            strIcon = szValue;
        else if( szKey == "sound" )
            strSound = szValue;
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
        g_Game.PrecacheModel( strIcon );
        g_Game.PrecacheGeneric( strIcon );

        g_Game.PrecacheModel( "sprites/laserbeam.spr" );
        g_Game.PrecacheGeneric( "sprites/laserbeam.spr" );

        g_SoundSystem.PrecacheSound( strSound );
        g_Game.PrecacheGeneric( strSound );

        BaseClass.Precache();
    }

    void Spawn()
    {
        self.Precache();
        self.pev.movetype   = MOVETYPE_NONE;
        self.pev.solid      = SOLID_NOT;
        self.pev.effects    |= EF_NODRAW;
        g_EntityFuncs.SetOrigin( self, self.pev.origin );

        if( !self.pev.SpawnFlagBitSet( START_OFF ) )
            blInitialised = Initialise();

        BaseClass.Spawn();
    }
    // Configuring the settings for each antirush component
    bool Initialise()
    {
        if( !self.pev.SpawnFlagBitSet( NO_ICON ) )
            hAntiRushIcon = CreateIcon();

        if( vecBlockerCornerMin != g_vecZero && 
            vecBlockerCornerMax != g_vecZero && 
            vecBlockerCornerMin != vecBlockerCornerMax )
            blAntiRushBarrier = CreateBarrier();

        if( self.pev.target != "" || strLockEnts != "" )
            hAntiRushLock = CreateLock();

        if( strBorderBeamPoints != "" )
            DrawBorder();

        self.pev.nextthink = self.pev.frame >= 0.01f ? g_Engine.time + 5.0f : 0.0f;
        // If set, entity will trigger "netname" when it spawns
        if( self.pev.netname != "" && self.pev.netname != self.GetTargetname() )
            g_EntityFuncs.FireTargets( "" + self.pev.netname, self, self, USE_TOGGLE, 0.0f, 0.5f );

        self.pev.spawnflags &= ~START_OFF;
        
        return( hAntiRushIcon.IsValid() || 
                hAntiRushLock.IsValid() ||
                blAntiRushBarrier ||
                self.pev.nextthink > g_Engine.time );
    }
    // Auxilliary entities required for antirush logic
    EHandle CreateIcon()
    {
        CSprite@ pAntiRushIcon = g_EntityFuncs.CreateSprite( strIcon, self.GetOrigin(), false, 0.0f );
        g_EntityFuncs.DispatchKeyValue( pAntiRushIcon.edict(), "vp_type", iVpType );
        pAntiRushIcon.SetScale( self.pev.scale <= 0.0f ? 0.15f : self.pev.scale );
        pAntiRushIcon.pev.nextthink     = 0.0f;
        pAntiRushIcon.pev.angles        = self.pev.angles;
        pAntiRushIcon.pev.frame         = self.pev.frame;
        pAntiRushIcon.pev.rendermode    = self.pev.rendermode == kRenderFxNone ? int( kRenderTransTexture ) : self.pev.rendermode; // Using the enums here instead thows exception: "Can't implicitly convert from 'int' to 'RenderModes'" - wtf?
        pAntiRushIcon.pev.renderamt     = self.pev.renderamt == 0.0f ? 255.0f : self.pev.renderamt;
        pAntiRushIcon.pev.rendercolor   = self.pev.rendercolor == g_vecZero ? Vector( 255, 0, 0 ) : self.pev.rendercolor;

        return EHandle( pAntiRushIcon );
    }

    EHandle CreateLock()
    {
        if( ( strMaster != "" && self.pev.target == strMaster ) || 
            ( self.GetTargetname() != "" && self.pev.target == self.GetTargetname() ) ||
            ( self.pev.SpawnFlagBitSet( NO_MS ) && strLockEnts == "" ) )
            return EHandle( null );
            
        if( strLockEnts != "" )
        {
            if( self.pev.target == "" )
                self.pev.target = "" + self.GetClassname() + "_ent_ID" + self.entindex();

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

        dictionary ms = { { "targetname", "" + self.pev.target } };
        return EHandle( g_EntityFuncs.CreateEntity( "multisource", ms, true ) );
    }

    bool CreateBarrier()
    {
        self.pev.mins = vecBlockerCornerMin - self.GetOrigin();
        self.pev.maxs = vecBlockerCornerMax - self.GetOrigin();
        self.pev.solid = SOLID_BBOX;

        g_EntityFuncs.SetOrigin( self, self.pev.origin );
        g_EntityFuncs.SetSize( self.pev, self.pev.mins, self.pev.maxs );

        return( self.pev.solid == SOLID_BBOX );
    }

    uint DrawBorder()
    {
        const array<string> STR_BEAM_POINTS = strBorderBeamPoints.Split( ";" );
        // No such thing as a 2-sided shape.
        if( STR_BEAM_POINTS.length() < 3 )
            return 0;

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

            H_ANTIRUSH_BORDER_BEAMS.insertLast( EHandle( pBorderBeam ) );
        }

        return( H_ANTIRUSH_BORDER_BEAMS.length() );
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
        
        uint iPlayersAlive = 0, iPlayersInZone = 0;
        // Yeah. No method CPlayerFuncs method "int GetNumPlayersAlive". WHY.
        for( int playerID = 1; playerID <= g_PlayerFuncs.GetNumPlayers(); playerID++ )
        {
            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( playerID );
            
            if( pPlayer is null || !pPlayer.IsConnected() || !pPlayer.IsAlive() )
                continue;
            
            ++iPlayersAlive;
            // Check if player is within these bounds
            if( vecZoneCornerMin != g_vecZero && vecZoneCornerMax != g_vecZero && vecZoneCornerMin != vecZoneCornerMax )
            {   // No EntityFuncs "bool EntityInBounds" method. Piss off.
                if( ( pPlayer.pev.origin.x >= vecZoneCornerMin.x && pPlayer.pev.origin.x <= vecZoneCornerMax.x ) &&
                    ( pPlayer.pev.origin.y >= vecZoneCornerMin.y && pPlayer.pev.origin.y <= vecZoneCornerMax.y ) &&
                    ( pPlayer.pev.origin.z >= vecZoneCornerMin.z && pPlayer.pev.origin.z <= vecZoneCornerMax.z ) )
                    ++iPlayersInZone;
            }
            else// Check if a player is within a radius instead, if no bounding box is defined
            {   // No EntityFuncs "bool EntityInRadius" method either, starting to question sanity
                if( ( self.pev.origin - pPlayer.pev.origin ).Length() <= flZoneRadius && 
                    self.FVisibleFromPos( pPlayer.pev.origin, self.pev.origin ) )
                    ++iPlayersInZone;
            }
        }
        
        if( iPlayersAlive >= 1 )
        {
            const float flCurrentPercent = float( iPlayersInZone ) / float( iPlayersAlive ) + 0.00001f;
            const float flRequiredPercent = self.pev.frame / 100.0f;

            if( flCurrentPercent >= flRequiredPercent )
            {
                self.Use( self, self, USE_ON );
                self.pev.nextthink = 0.0f; // We are done here, stop thinking
                return;
            }
        }

        self.pev.nextthink = g_Engine.time + 0.5f;
    }
    // Main triggering business
    void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float value)
    {
        if( !blInitialised )
        {
            blInitialised = Initialise();
            return;
        }
        
        if( !self.pev.SpawnFlagBitSet( NO_SOUND ) )
            g_SoundSystem.EmitSound( self.edict(), CHAN_ITEM, strSound, 0.5f, ATTN_NORM );

        if( hAntiRushIcon )
        {
            CSprite@ pAntiRushIcon = cast<CSprite@>( hAntiRushIcon.GetEntity() );
            pAntiRushIcon.SetColor( 0, 255, 0 );
            // !-BUG-!: CSprite method "float Frames() const" doesn't work. This is the current workaround.
            int iAntiRushIconFrames = Math.max( 0, g_EngineFuncs.ModelFrames( g_EngineFuncs.ModelIndex( pAntiRushIcon.pev.model ) ) - 1 );
            // Change the icon to display 100% when applicable
            if( self.pev.frame > 0.0f && iAntiRushIconFrames >= 100 )
                pAntiRushIcon.pev.frame = 100.0f;

            if( flFadeTime > 0 )
                g_Scheduler.SetTimeout( this, "RemoveIcon", flFadeTime );
        }

        if( blAntiRushBarrier )
        {
            self.pev.solid = SOLID_NOT;
            blAntiRushBarrier = false;
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
                g_Scheduler.SetTimeout( this, "RemoveBorder", flFadeTime + 5.0f );
        }
        // Have to delay killtarget as well, else FireTargets would replace the scheduled function for delay
        g_Scheduler.SetTimeout( this, "TriggerTargets", flTargetDelay, EHandle( pActivator ), EHandle( pCaller ) );
    }

    void TriggerTargets(EHandle hActivator, EHandle hCaller)
    {
        CBaseEntity@ pActivator = hActivator ? hActivator.GetEntity() : ( hCaller ? hCaller.GetEntity() : self );

        if( self.pev.target != "" && self.pev.target != self.GetTargetname() )
            self.SUB_UseTargets( pActivator, USE_TOGGLE, 0.0f );
        // !-BUG-!: USE_KILL doesn't delete the entity(s), just triggers it. Forced to delete manually.
        if( strKillTarget != "" && strKillTarget != self.GetTargetname() )
        {
            do
                g_EntityFuncs.Remove( g_EntityFuncs.FindEntityByTargetname( null, strKillTarget ) );
            while( g_EntityFuncs.FindEntityByTargetname( null, strKillTarget ) !is null );
        }
    }

    void RemoveIcon()
    {
        if( hAntiRushIcon )
            g_EntityFuncs.Remove( hAntiRushIcon.GetEntity() );
    }

    void RemoveBorder()
    {
        for( uint i = 0; i < H_ANTIRUSH_BORDER_BEAMS.length(); i++ )
        {
            if( !H_ANTIRUSH_BORDER_BEAMS[i] )
                continue;

            g_EntityFuncs.Remove( H_ANTIRUSH_BORDER_BEAMS[i].GetEntity() );
        }
    }

    void UpdateOnRemove()
    {
        RemoveIcon();
        RemoveBorder();

        if( hAntiRushLock )
            g_EntityFuncs.Remove( hAntiRushLock.GetEntity() );

        BaseClass.UpdateOnRemove();
    }
}

}
/* Special Thanks to:-
- CubeMath - building concept and basis for AntiRush logic
- I_Ka - icon sprites
- H2 - programming support
*/