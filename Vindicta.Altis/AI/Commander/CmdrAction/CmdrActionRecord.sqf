#define OOP_DEBUG
#define OOP_INFO
#define OOP_WARNING
#define OOP_ERROR

#define PROFILER_COUNTERS_ENABLE

// It's really part of GarrisonServer, so we don't want to output text into the CmdrAI log file
//#define OFSTREAM_FILE "CmdrAI.rpt"

#include "..\..\..\OOP_Light\OOP_Light.h"
#include "..\..\..\Templates\Efficiency.hpp"
#include "..\..\..\Mutex\Mutex.hpp"
#include "..\CmdrAction\CmdrActionStates.hpp"
#include "..\..\..\Location\Location.hpp"
#include "..\AICommander.hpp"

/*
Class: AI.CmdrAI.CmdrAction.CmdrActionRecord

Commander action records are serializable objects having data about the current action given to a garrison by commander.
It's used by <GarrisonServer> and <GarrisonDatabaseClient> to send data about friendly garrisons to players of the same side.

Author: Sparker

Parent: none
*/

#define pr private

CLASS("CmdrActionRecord", "")
	
	STATIC_METHOD("getText") {
		params [P_THISCLASS];
		OOP_ERROR_0("getText must be called on final classes!");
		"<Base class>"
	} ENDMETHOD;
ENDCLASS;

// - - - - Targeted at position or location - - - -

CLASS("DirectedCmdrActionRecord", "CmdrActionRecord")

	// Destination position
	VARIABLE_ATTR("pos", [ATTR_SERIALIZABLE]);

	// Destination actual location reference (if exists)
	VARIABLE_ATTR("locRef", [ATTR_SERIALIZABLE]);

	// Destination garrison (if exists)
	VARIABLE_ATTR("dstGarRef", [ATTR_SERIALIZABLE]);

	// Returns position, location position or garrison position, !! ON CLIENT !!
	METHOD("getPos") {
		params [P_THISOBJECT];

		pr _pos = T_GETV("pos");
		if (!isNil "_pos") exitWith {_pos};

		pr _loc = T_GETV("locRef");
		if (!isNil "_loc") exitWith {CALLM0(_loc, "getPos")};

		pr _gar = T_GETV("dstGarRef");
		if (!isNil "_gar") exitWith {
			pr _garRecord = CALLM1(gGarrisonDBClient, "getGarrisonRecord", _gar);
			if (IS_NULL_OBJECT(_garRecord)) then {
				OOP_ERROR_1("Can't resolve position of target garrison: %1", _gar);
				[_thisObject] call OOP_dumpAllVariables;
				[]
			} else {
				GETV(_garRecord, "pos")
			};
		};

		// Else return [] and print an error
		OOP_ERROR_1("No target in cmdr action record %1", _thisObject);
		[_thisObject] call OOP_dumpAllVariables;
		[]
	} ENDMETHOD;

	STATIC_METHOD("getText") {
		params [P_THISCLASS];
		OOP_ERROR_0("getText must be called on final classes!");
		"<Directed base class>"
	} ENDMETHOD;

ENDCLASS;

// Done
CLASS("MoveCmdrActionRecord", "DirectedCmdrActionRecord")
	STATIC_METHOD("getText") {
		"MOVE"
	} ENDMETHOD;
ENDCLASS;

// Done
CLASS("TakeLocationCmdrActionRecord", "DirectedCmdrActionRecord")
	STATIC_METHOD("getText") {
		"CAPTURE"
	} ENDMETHOD;
ENDCLASS;

// Done
CLASS("AttackCmdrActionRecord", "DirectedCmdrActionRecord")
	STATIC_METHOD("getText") {
		"ATTACK"
	} ENDMETHOD;
ENDCLASS;

// Done
CLASS("ReinforceCmdrActionRecord", "DirectedCmdrActionRecord")
	STATIC_METHOD("getText") {
		"REINFORCE"
	} ENDMETHOD;
ENDCLASS;

// Done
CLASS("SupplyCmdrActionRecord", "DirectedCmdrActionRecord")
	STATIC_METHOD("getText") {
		"SUPPLY"
	} ENDMETHOD;
ENDCLASS;

/*
// NYI
CLASS("ReconCmdrActionRecord", "DirectedCmdrActionRecord")

ENDCLASS;
*/

// - - - - Targeted at another garrison - - - -

// - - - - Other - - - -

// todo
CLASS("PatrolCmdrActionRecord", "CmdrActionRecord")

	STATIC_METHOD("getText") {
		"Patrol"
	} ENDMETHOD;
ENDCLASS;