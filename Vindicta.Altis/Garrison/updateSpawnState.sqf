#include "common.hpp"

#define pr private

params [P_THISOBJECT];

ASSERT_THREAD(_thisObject);

#define DEBUG

#ifdef DEBUG
OOP_INFO_0("UPDATE SPAWN STATE");
OOP_INFO_1("  this side: %1", T_GETV("side"));
#endif

if(T_CALLM("isDestroyed", [])) exitWith {
	OOP_WARNING_MSG("Attempted to call function on destroyed garrison %1", [_thisObject]);
	DUMP_CALLSTACK;
};
pr _dstSpawnMin = 1200; // Temporary, spawn distance
pr _dstSpawnMax = 1400; // Temporary, spawn distance

pr _side = T_GETV("side");
pr _loc = T_GETV("location");
pr _thisPos = if (_loc == "") then {
	CALLM0(_thisObject, "getPos")
} else {
	CALLM0(_loc, "getPos")
};

// Check garrison distances first, this should be quick
pr _speedMax = 60;

// Get distances to all garrisons of other sides
pr _garrisonDist = if(_side != CIVILIAN) then {
		CALLSM0("Garrison", "getAll") select {
			GETV(_x, "active") &&											// Is active
			{ !(GETV(_x, "side") in [_side, CIVILIAN]) } && 				// Side is not our side and is not civilian
			{ (GETV(_x, "countInf") > 0) || (GETV(_x, "countDrone") > 0) }	// There is some infantry or drones
		} apply {
			CALLM(_x, "getPos", []) distance _thisPos
		};
		//CALL_STATIC_METHOD("Garrison", "getAllActive", [[] ARG [_side ARG CIVILIAN]]) apply {CALLM(_x, "getPos", []) distance _thisPos}
	} else {
		[]
	};
pr _dstMin = if (count _garrisonDist > 0) then {selectMin _garrisonDist} else {666666};

#ifdef DEBUG
OOP_INFO_1("  distance to garrisons: %1", _dstMin);
#endif

// Double check unit distances as well
if(_dstMin >= _dstSpawnMin) then {
	// TODO we should use BIS getNearest functions here maybe? It might be faster.
	pr _unitDist = CALL_METHOD(gLUAP, "getUnitArray", [_side]) apply {_x distance _thisPos};
	_dstMin = if (count _unitDist > 0) then {selectMin _unitDist} else {666666};
	#ifdef DEBUG
	OOP_INFO_1("  distance to units: %1", _dstMin);
	#endif
};

// Limit the min distance to some reasonable number
_dstMin = _dstMin min worldSize;

switch (T_GETV("spawned")) do {
	case false: { // Garrison is currently not spawned

		pr _timer = T_GETV("timer");

		if (_dstMin < _dstSpawnMin) then {
			OOP_INFO_0("  Spawning...");

			CALLM0(_thisObject, "spawn");

			// Set timer interval
			pr _interval = 4;
			#ifdef DEBUG
			OOP_INFO_1("  Set interval: %1", _interval);
			#endif
			CALLM1(_timer, "setInterval", _interval); // Despawn conditions can be evaluated with even lower frequency
		} else {
			// Set timer interval
			pr _dstToThreshold = _dstMin - _dstSpawnMin;
			pr _interval = (_dstToThreshold / _speedMax) max 5;
			//pr _interval = 2; // todo override this some day later
			//diag_log format ["[Location] Info: interval was set to %1 for %2, distance: %3:", _interval, GET_VAR(_thisObject, "name"), _dstMin];

			#ifdef DEBUG
			OOP_INFO_1("  Set interval: %1", _interval);
			#endif

			CALLM1(_timer, "setInterval", _interval);
		};
	};
	case true: { // Garrison is currently spawned
		if (_dstMin > _dstSpawnMax) then {
			OOP_INFO_0("  Despawning...");
			
			CALLM0(_thisObject, "despawn");
		};
	}; // case 1
}; // switch spawn state