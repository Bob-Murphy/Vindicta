#include "common.hpp"

/*
Garrison moves on available vehicles
*/

#define pr private

#define THIS_ACTION_NAME "ActionGarrisonRepairAllVehicles"

CLASS(THIS_ACTION_NAME, "ActionGarrison")

	VARIABLE("repairUnit"); // The unit that will perform repairs on vehicles
	VARIABLE("fubarcar"); // The broken vehicle, beyond all repair

	METHOD("new") {
		params [["_thisObject", "", [""]]];
		T_SETV("repairUnit", "");
		T_SETV("fubarcar", "");
	} ENDMETHOD;


	// logic to run when the goal is activated
	METHOD("activate") {
		params [["_thisObject", "", [""]]];
		
		pr _AI = T_GETV("AI");
		pr _gar = T_GETV("gar");
		
		// Find all broken vehicles
		pr _vehicles = [_gar, [[T_VEH, -1], [T_DRONE, -1]]] call GETM(_gar, "findUnits");
		pr _brokenVehicles = _vehicles select {
		
			pr _oh = CALLM(_x, "getObjectHandle", []);
			//diag_log format ["Vehicle: %1, can move: %2", _oh, canMove _oh];
			CALLM0(_x, "getMainData") params ["_catID", "_subcatID"]; //, "_className"];
			pr _isStatic = [_catID, _subcatID] in T_static;
			pr _anyWheelDamaged = if (!_isStatic) then {[_oh] call AI_misc_fnc_isAnyWheelDamaged} else {false};
			pr _canNotMove = (((!canMove _oh) || _anyWheelDamaged) && !_isStatic);
			(getDammage _oh > 0.61) || _canNotMove
		};
		
		OOP_INFO_1("Broken vehicles: %1", _brokenVehicles);
		
		if (count _brokenVehicles == 0) exitWith {
			SETV(_thisObject, "state", ACTION_STATE_COMPLETED);			
			// Return ACTIVE state
			ACTION_STATE_COMPLETED
		};
		
		// Find all infantry
		// Find all engineers
		pr _infUnits = CALLM0(_gar, "getInfantryUnits");
		pr _engineerUnits = _infUnits select {
			pr _hO = CALLM(_x, "getObjectHandle", []);
			(_hO getUnitTrait "engineer")
		};
		
		// Send a random guy to perform repairs for now
		if (count _infUnits > 0 || count _engineerUnits > 0) then {
			// Just repair one vehicle at a time for now
			pr _brokenVehicle = _brokenVehicles select 0;
			T_SETV("fubarcar", _brokenVehicle);
			pr _brokenVehicleHandle = CALLM0(_brokenVehicle, "getObjectHandle");
		
			pr _repairUnit = if (count _engineerUnits > 0) then {selectRandom _engineerUnits} else {
				// Sort all units by distance to the broken vehicle
				pr _infUnitsSorted = _infUnits apply {[CALLM0(_x, "getPos") distance2D _brokenVehicleHandle, _x]};
				_infUnitsSorted sort true; // Ascending
				// Return
				_infUnitsSorted select 0 select 1
			};
			T_SETV("repairUnit", _repairUnit);
			pr _repairUnitAI = CALLM0(_repairUnit, "getAI");
			
			// Add goals to the repair unit
			/*
			{				
				pr _args = ["GoalUnitRepairVehicle", 0, [["vehicle", _x]], _AI, false];
				CALLM2(_repairUnitAI, "postMethodAsync", "addExternalGoal", _args);
			} forEach _brokenVehicles;
			*/
			
			pr _args = ["GoalUnitRepairVehicle", 0, [["vehicle", _brokenVehicle]], _AI, false];
			CALLM2(_repairUnitAI, "postMethodAsync", "addExternalGoal", _args);
			
			T_SETV("state", ACTION_STATE_ACTIVE);
			ACTION_STATE_ACTIVE
		} else {
			// Set state
			SETV(_thisObject, "state", ACTION_STATE_FAILED);			
			// Return ACTIVE state
			ACTION_STATE_FAILED
		};
				
	} ENDMETHOD;
	
	// logic to run each update-step
	METHOD("process") {
		params [["_thisObject", "", [""]]];

		// Bail if not spawned
		pr _gar = T_GETV("gar");
		if (!CALLM0(_gar, "isSpawned")) exitWith {T_GETV("state")};
		
		pr _state = CALLM0(_thisObject, "activateIfInactive");
		
		if (_state == ACTION_STATE_ACTIVE) then {
			pr _AI = T_GETV("AI");
			pr _repairUnit = T_GETV("repairUnit");
			pr _goalState = CALLM2(CALLM0(_repairUnit, "getAI"), "getExternalGoalActionState", "GoalUnitRepairVehicle", _AI);
			if (_goalState == ACTION_STATE_COMPLETED) then {
				// Update sensors affected by this action
				CALLM0(GETV(_AI, "sensorState"), "update");
				
				_state = ACTION_STATE_COMPLETED;
			};
		};
		
		// Return the current state
		T_SETV("state", _state);
		_state
	} ENDMETHOD;
	
	// logic to run when the action is satisfied
	METHOD("terminate") {
		params [["_thisObject", "", [""]]];
		
		// Bail if not spawned
		pr _gar = T_GETV("gar");
		if (!CALLM0(_gar, "isSpawned")) exitWith {};

		pr _AI = T_GETV("AI");
		
		// Delete assigned goal
		pr _repairUnit = T_GETV("repairUnit");
		if (_repairUnit != "") then {
			pr _repairUnitAI = CALLM0(_repairUnit, "getAI");
			pr _args = ["GoalUnitRepairVehicle", _AI];
			CALLM2(_repairUnitAI, "postMethodAsync", "deleteExternalGoal", _args);
		};
		
	} ENDMETHOD;
	


	METHOD("handleGroupsAdded") {
		params [["_thisObject", "", [""]], ["_groups", [], [[]]]];
		
		{
			CALLM1(_thisObject, "handleUnitsAdded", CALLM0(_x, "getUnits"));
		} forEach _groups;
		
		nil
	} ENDMETHOD;

	METHOD("handleGroupsRemoved") {
		params [["_thisObject", "", [""]], ["_groups", [], [[]]]];
		
		{
			CALLM1(_thisObject, "handleUnitsRemoved", CALLM0(_x, "getUnits"));
		} forEach _groups;
		
		nil
	} ENDMETHOD;
	
	METHOD("handleUnitsRemoved") {
		params [["_thisObject", "", [""]], ["_units", [], [[]]]];
		
			// Fail if either broken vehicle or repair unit is in the array with removed units
			if (count ([T_GETV("fubarcar"), T_GETV("repairUnit")] arrayIntersect _units) != 0) then {
				T_SETV("fubarcar", "");
				T_SETV("repairUnit", "");
				T_SETV("state", ACTION_STATE_FAILED);
			};
		
		nil
	} ENDMETHOD;

	METHOD("handleUnitsAdded") {
		params [["_thisObject", "", [""]], ["_units", [], [[]]]];
			
		nil
	} ENDMETHOD;

ENDCLASS;