#include <sourcemod>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define ACT_REACH_OUT_IDLE 7
#define ACT_REACH_OUT_WALK 10

ConVar cvar_plugin_enabled;
ConVar cvar_obey_ff, cvar_ff_enabled, cvar_ignite_time, cvar_max_reach;
ConVar cvar_ignite_players, cvar_ignite_zombies, cvar_ignite_props;

public Plugin myinfo =
{
	name = "[NMRiH] Zippo Ignition",
	author = "Dysphie",
	description = "Lets players set entities on fire with the lighter",
	version = "1.0.1",
	url = "https://forums.alliedmods.net/showthread.php?t=319626"
};

public void OnPluginStart()
{
	cvar_plugin_enabled = CreateConVar("sm_zippo_ignite_enabled", "1", "Toggle the ability to light stuff on fire with the zippo");
	cvar_ignite_time = CreateConVar("sm_zippo_ignite_time", "30", "Entities ignited by the zippo remain on fire for this many seconds");
	cvar_max_reach = CreateConVar("sm_zippo_max_reach", "95", "Maximum reach of the zippo in units");
	cvar_ignite_players = CreateConVar("sm_zippo_ignite_players", "1", "Zippo can ignite players");
	cvar_obey_ff = CreateConVar("sm_zippo_override_friendly_fire", "0", "Zippo is not affected by friendly fire settings");
	cvar_ignite_zombies = CreateConVar("sm_zippo_ignite_zombies", "1", "Zippo can ignite zombies");
	cvar_ignite_props = CreateConVar("sm_zippo_ignite_props", "1", "Zippo can ignite miscellaneous props");
	cvar_ff_enabled = FindConVar("mp_friendlyfire");

	HookEvent("player_death", OnPlayerDeath);
}

// Fix players remaining on fire post-mortem 
public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	NMRiH_ExtinguishEntity(client);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon)
{
	if(!cvar_plugin_enabled.BoolValue)
		return Plugin_Continue;

	if(!IsPlayerAlive(client) || !(buttons & IN_ATTACK))
		return Plugin_Continue;

	// Does the player have a lighter
	int active_weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(active_weapon == -1)
		return Plugin_Continue;

	char weapon_class[64];
	GetEdictClassname(active_weapon, weapon_class, sizeof(weapon_class));
	if(!StrEqual(weapon_class, "item_zippo"))
		return Plugin_Continue;

	// Is the lighter lit up
	int ignited = GetEntProp(active_weapon, Prop_Send, "_ignited");
	if(!ignited)
		return Plugin_Continue;

	// Is the player reaching out with it
	int sequence = GetEntProp(active_weapon, Prop_Send, "m_nSequence");
	if(sequence != ACT_REACH_OUT_WALK && sequence != ACT_REACH_OUT_IDLE)
		return Plugin_Continue;

	// Get entity being aimed at
	int target = GetClientAimTarget(client, false);
	if(target != client && IsValidEdict(target))
	{
		// Is entity within reach
		float target_pos[3], client_pos[3];
		GetEntPropVector(target, Prop_Send, "m_vecOrigin", target_pos);
		GetClientEyePosition(client, client_pos);

		if(GetVectorDistance(target_pos, client_pos) > cvar_max_reach.FloatValue)
			return Plugin_Continue;
		
		// Run filters

		char target_class[64];
		GetEdictClassname(target, target_class, sizeof(target_class));

		if(StrEqual(target_class, "player"))
		{	
			if(!cvar_ignite_players.BoolValue)
				return Plugin_Continue;

			if(IsTargetFriendly(client, target) && !cvar_ff_enabled.BoolValue && cvar_obey_ff.BoolValue) 
				return Plugin_Continue;
		}

		else if(StrContains(target_class, "npc_nmrih_") != -1)
		{
			if(!cvar_ignite_zombies.BoolValue)
				return Plugin_Continue;
		}

		else if (!cvar_ignite_props.BoolValue)
			return Plugin_Continue;

		// Attempt to ignite
		NMRiH_IgniteEntity(target, cvar_ignite_time.FloatValue);

	}
	return Plugin_Continue;
}

stock bool IsClientInfected(int client)
{
	return (GetEntPropFloat(client, Prop_Send, "m_flInfectionTime") != -1);
}

stock bool IsTargetFriendly(int attacker, int victim)
{
	// Mimick game logic for team damage
	if(GetClientTeam(attacker) == GetClientTeam(victim))
		return (!IsClientInfected(victim));
	return true;
}

stock void NMRiH_IgniteEntity(int entity, float time)
{
	// IgniteEntity lead to crashes, do this instead
	SetVariantFloat(time);
	AcceptEntityInput(entity, "ignitelifetime");	
}

stock void NMRiH_ExtinguishEntity(int entity)
{
	// Extinguish entity doesn't work, manually remove fire
	int fire = GetEntPropEnt(entity, Prop_Data, "m_hEffectEntity");
	if(IsValidEdict(fire))
		SetEntPropFloat(fire, Prop_Data, "m_flLifetime", 0.0); 	
}