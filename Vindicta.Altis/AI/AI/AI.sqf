#define OOP_INFO
#define OOP_ERROR
#define OOP_WARNING
#define OFSTREAM_FILE "AI.rpt"
#define PROFILER_COUNTERS_ENABLE
#include "..\..\OOP_Light\OOP_Light.h"
#include "..\..\Message\Message.hpp"
#include "..\..\CriticalSection\CriticalSection.hpp"
#include "..\..\MessageTypes.hpp"
#include "..\Action\Action.hpp"
#include "..\..\defineCommon.inc"
#include "..\goalRelevance.hpp"
#include "..\Stimulus\Stimulus.hpp"
#include "AI.hpp"

/*
Class: AI
Base class for AI_GOAP.
It can manage world facts and sensors. Process method is empty.
Author: Sparker 03.03.2019
*/

#define pr private


#define AI_TIMER_SERVICE gTimerServiceMain

CLASS("AI", "MessageReceiverEx")

	/* Variable: agent
	Holds a reference to the unit/group/whatever that owns this AI object*/
	/* save */	VARIABLE_ATTR("agent", [ATTR_SAVE]);		// Pointer to the unit which holds this AI object
	/* Variable: currentAction */
	/* save */	VARIABLE_ATTR("worldFacts", [ATTR_SAVE]);	// Array with world facts
				VARIABLE("timer");							// The timer of this object
				VARIABLE("processInterval");				// The update interval for the timer, in seconds
				VARIABLE("sensorStimulusTypes");			// Array with stimulus types of the sensors of this AI object
				VARIABLE("sensors");						// Array with sensors

	// ----------------------------------------------------------------------
	// |                              N E W                                 |
	// ----------------------------------------------------------------------

	METHOD("new") {
		params [["_thisObject", "", [""]], ["_agent", "", [""]]];

		OOP_INFO_1("NEW %1", _this);

		PROFILER_COUNTER_INC("AI");

		// Make sure the required global objects exist
		ASSERT_GLOBAL_OBJECT(AI_TIMER_SERVICE);

		SETV(_thisObject, "agent", _agent);
		SETV(_thisObject, "sensors", []);
		SETV(_thisObject, "sensorStimulusTypes", []);
		SETV(_thisObject, "timer", "");
		SETV(_thisObject, "processInterval", 1);
		SETV(_thisObject, "worldFacts", []);
	} ENDMETHOD;

	// ----------------------------------------------------------------------
	// |                            D E L E T E                             |
	// ----------------------------------------------------------------------

	METHOD("delete") {
		params [["_thisObject", "", [""]]];

		OOP_INFO_0("DELETE");

		PROFILER_COUNTER_DEC("AI");

		// Stop the AI if it is currently running
		CALLM(_thisObject, "stop", []);

		// Delete all sensors
		pr _sensors = GETV(_thisObject, "sensors");
		{
			DELETE(_x);
		} forEach _sensors;
	} ENDMETHOD;

	// ----------------------------------------------------------------------
	// |                              P R O C E S S
	// | Must be called every update interval
	// ----------------------------------------------------------------------

	METHOD("process") {
		params [["_thisObject", "", [""]]];
	} ENDMETHOD;

	// ----------------------------------------------------------------------
	// |                    H A N D L E   M E S S A G E
	// |
	// ----------------------------------------------------------------------

	METHOD("handleMessageEx") { //Derived classes must implement this method
		params [ ["_thisObject", "", [""]] , ["_msg", [], [[]]] ];
		pr _msgType = _msg select MESSAGE_ID_TYPE;
		switch (_msgType) do {
			case AI_MESSAGE_PROCESS: {
				CALLM(_thisObject, "process", []);
				true
			};

			case AI_MESSAGE_DELETE: {
				DELETE(_thisObject);
				true
			};

			default {false}; // Message not handled
		};
	} ENDMETHOD;







	// ------------------------------------------------------------------------------------------------------
	// -------------------------------------------- S E N S O R S -------------------------------------------
	// ------------------------------------------------------------------------------------------------------




	// ----------------------------------------------------------------------
	// |                A D D   S E N S O R
	// | Adds a given sensor to the AI object
	// ----------------------------------------------------------------------
	/*
	Method: addSensor
	Adds a sensor to this AI object.

	Parameters: _sensor

	_sensor - <Sensor> or <SensorStimulatable>

	Returns: nil
	*/
	METHOD("addSensor") {
		params [["_thisObject", "", [""]], ["_sensor", "ERROR_NO_SENSOR", [""]]];

		ASSERT_OBJECT_CLASS(_sensor, "Sensor");

		// Add the sensor to the sensor list
		pr _sensors = GETV(_thisObject, "sensors");
		_sensors pushBackUnique _sensor;

		// Check the stimulus types this sensor responds to
		pr _stimTypesSensor = CALLM(_sensor, "getStimulusTypes", []);
		pr _stimTypesThis = GETV(_thisObject, "sensorStimulusTypes");
		// Add the stimulus types to the stimulus type array
		{
			_stimTypesThis pushBackUnique _x;
		} forEach _stimTypesSensor;
	} ENDMETHOD;

	// ----------------------------------------------------------------------
	// |                    U P D A T E   S E N S O R S
	// | Update values of all sensors, according to their settings
	// ----------------------------------------------------------------------

	METHOD("updateSensors") {
		params [["_thisObject", "", [""]], ["_forceUpdate", false]];
		pr _sensors = GETV(_thisObject, "sensors");
		//OOP_INFO_1("Updating sensors: %1", _sensors);
		{
			pr _sensor = _x;
			
			// Update the sensor if it's time to update it
			pr _interval = CALLM(_sensor, "getUpdateInterval", []); // If it returns 0, we never update it
			if (_interval > 0) then {
				pr _timeNextUpdate = GETV(_sensor, "timeNextUpdate");
				//OOP_INFO_2("  Updating sensor: %1, time next update: %2", _sensor, _timeNextUpdate);
				if ((TIME_NOW > _timeNextUpdate) || _forceUpdate) then {
					//OOP_INFO_0("  Calling UPDATE!");
					//OOP_INFO_1("Updating sensor: %1", _sensor);
					CALLM(_sensor, "update", []);
					SETV(_sensor, "timeNextUpdate", TIME_NOW + _interval);
				};
			};
		} forEach _sensors;
	} ENDMETHOD;

	// ----------------------------------------------------------------------
	// |                    H A N D L E   S T I M U L U S
	// | Handles external stimulus.
	// ----------------------------------------------------------------------

	METHOD("handleStimulus") {
		params [["_thisObject", "", [""]], ["_stimulus", [], [[]]] ];
		pr _type = _stimulus select STIMULUS_ID_TYPE;
		if (_type in T_GETV("sensorStimulusTypes")) then {
			pr _sensors = GETV(_thisObject, "sensors");
			{
				pr _stimTypes = CALLM(_x, "getStimulusTypes", []);
				if (_type in _stimTypes) then {
					CALLM(_x, "stimulate", [_stimulus]);
				};
			} foreach _sensors;
		};
	} ENDMETHOD;
	
	
	// ------------------------------------------------------------------------------------------------------
	// -------------------------------------------- W O R L D   F A C T S -----------------------------------
	// ------------------------------------------------------------------------------------------------------

	// Adds a world fact
	METHOD("addWorldFact") {
		params [["_thisObject", "", [""]], ["_fact", [], [[]]]];
		pr _facts = GETV(_thisObject, "worldFacts");
		_facts pushBack _fact;
	} ENDMETHOD;

	// Finds a world fact that matches a query
	// Returns the found world fact or nil if nothing was found
	METHOD("findWorldFact") {
		params [["_thisObject", "", [""]], ["_query", [], [[]]]];
		pr _facts = GETV(_thisObject, "worldFacts");
		pr _i = 0;
		pr _c = count _facts;
		pr _return = nil;
		while {_i < _c} do {
			pr _fact = _facts select _i;
			if ([_fact, _query] call wf_fnc_matchesQuery) exitWith {_return = _fact;};
			_i = _i + 1;
		};
		if (!isNil "_return") then {_return} else {nil};
	} ENDMETHOD;

	// Finds all world facts that match a query
	// Returns array with facts that satisfy criteria or []
	METHOD("findWorldFacts") {
		params [["_thisObject", "", [""]], ["_query", [], [[]]]];
		pr _facts = GETV(_thisObject, "worldFacts");
		pr _i = 0;
		pr _c = count _facts;
		pr _return = [];
		while {_i < _c} do {
			pr _fact = _facts select _i;
			if ([_fact, _query] call wf_fnc_matchesQuery) then {_return pushBack _fact;};
			_i = _i + 1;
		};
		_return
	} ENDMETHOD;

	// Deletes all facts that match query
	METHOD("deleteWorldFacts") {
		params [["_thisObject", "", [""]], ["_query", [], [[]]]];
		pr _facts = GETV(_thisObject, "worldFacts");
		pr _i = 0;
		while {_i < count _facts} do {
			pr _fact = _facts select _i;
			if ([_fact, _query] call wf_fnc_matchesQuery) then {_facts deleteAt _i} else {_i = _i + 1;};
		};
	} ENDMETHOD;

	// Maintains the array of world facts
	// Deletes world facts that have exceeded their lifetime
	METHOD("updateWorldFacts") {
		params [["_thisObject", "", [""]]];
		pr _facts = GETV(_thisObject, "worldFacts");
		pr _i = 0;
		while {_i < count _facts} do {
			pr _fact = _facts select _i;
			if ([_fact] call wf_fnc_hasExpired) then {
				diag_log format ["[AI:updateWorldFacts] AI: %1, deleted world fact: %2", _thisObject, _fact];
				_facts deleteAt _i;
			} else {
				_i = _i + 1;
			};
		};
	} ENDMETHOD;

	// ----------------------------------------------------------------------
	// |                S T A R T
	// | Starts the AI brain
	// ----------------------------------------------------------------------
	/*
	Method: start
	Starts the AI brain. From now process method will be called periodically.
	*/
	METHOD("start") {
		params [["_thisObject", "", [""]], ["_processCategoryTag", ""]];
		if (_processCategoryTag != "") then {
			pr _msgLoop = CALLM0(_thisObject, "getMessageLoop");
			CALLM2(_msgLoop, "addProcessCategoryObject", _processCategoryTag, _thisObject);
		} else {
			if (GETV(_thisObject, "timer") == "") then {
				// Starts the timer
				private _msg = MESSAGE_NEW();
				_msg set [MESSAGE_ID_DESTINATION, _thisObject];
				_msg set [MESSAGE_ID_SOURCE, ""];
				_msg set [MESSAGE_ID_DATA, 0];
				_msg set [MESSAGE_ID_TYPE, AI_MESSAGE_PROCESS];
				pr _processInterval = GETV(_thisObject, "processInterval");
				private _args = [_thisObject, _processInterval, _msg, AI_TIMER_SERVICE]; // message receiver, interval, message, timer service
				private _timer = NEW("Timer", _args);
				SETV(_thisObject, "timer", _timer);

				// Post a message to process immediately to accelerate start up
				CALLM1(_thisObject, "postMessage", +_msg);
			};
		};

		nil
	} ENDMETHOD;

	// ----------------------------------------------------------------------
	// |                S T O P
	// | Stops the AI brain
	// ----------------------------------------------------------------------
	/*
	Method: stop
	Stops the periodic call of process function.
	*/
	METHOD("stop") {
		params [["_thisObject", "", [""]]];
		
		// Delete this object from process category 
		pr _msgLoop = CALLM0(_thisObject, "getMessageLoop");
		CALLM1(_msgLoop, "deleteProcessCategoryObject", _thisObject);

		pr _timer = GETV(_thisObject, "timer");
		if (_timer != "") then {
			SETV(_thisObject, "timer", "");
			DELETE(_timer);
		};
		nil
	} ENDMETHOD;



	// ----------------------------------------------------------------------
	// |               S E T   P R O C E S S   I N T E R V A L
	// | Sets the process interval of this AI object
	// ----------------------------------------------------------------------
	/*
	Method: setProcessInterval
	Sets the process interval of this AI object.

	Parameters: _interval

	_interval - Number, interval in seconds.

	Returns: nil
	*/
	METHOD("setProcessInterval") {
		params [["_thisObject", "", [""]], ["_interval", 5, [5]]];
		SETV(_thisObject, "processInterval", _interval);

		// If the AI object is already running, also change the interval of the timer which is already started
		pr _timer = GETV(_thisObject, "timer");
		if (_timer != "") then {
			CALLM(_timer, "setInterval", [_interval]);
		};
	} ENDMETHOD;

	// - - - - STORAGE - - - - -

	/* override */ METHOD("postDeserialize") {
		params [P_THISOBJECT, P_OOP_OBJECT("_storage")];

		//diag_log "AI postDeserialize";

		// Call method of all base classes
		CALL_CLASS_METHOD("MessageReceiverEx", _thisObject, "postDeserialize", [_storage]);

		// Set reasonable default values
		T_SETV("timer", "");
		T_SETV("processInterval", 1);
		T_SETV("sensorStimulusTypes", []);
		T_SETV("sensors", []);

		// It's up to the inherited class's postDeserialize to restore these variables ^
		// By reinitializing sensors and doing other things

		true
	} ENDMETHOD;
	
ENDCLASS;