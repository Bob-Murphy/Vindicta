#define OOP_INFO
#define OOP_ERROR
#define OOP_WARNING
#define OOP_DEBUG
#define OFSTREAM_FILE "ArrestAction.rpt"
#include "..\..\OOP_Light\OOP_Light.h"
#include "..\..\Message\Message.hpp"
#include "..\Action\Action.hpp"
#include "..\..\MessageTypes.hpp"
#include "..\..\defineCommon.inc"
#include "..\Stimulus\Stimulus.hpp"
#include "..\WorldFact\WorldFact.hpp"
#include "..\stimulusTypes.hpp"
#include "..\worldFactTypes.hpp"
#define IS_TARGET_ARRESTED_UNCONSCIOUS_DEAD !(alive _target) || (animationState _target == "unconsciousoutprone") || (animationState _target == "unconsciousfacedown") || (animationState _target == "unconsciousfaceup") || (animationState _target == "unconsciousrevivedefault") || (animationState _target == "acts_aidlpsitmstpssurwnondnon_loop") || (animationState _target == "acts_aidlpsitmstpssurwnondnon01")

/*
Template of an Action class
*/

#define pr private
#define MIN_ARREST_DIST 2 // minimum distance for arrest animation and method call
#define MAX_CHASE_TIME 45 

CLASS("ActionUnitArrest", "Action")
	
	VARIABLE("target");
	VARIABLE("objectHandle");
	VARIABLE("stateTimer");
	VARIABLE("stateMachine");
	VARIABLE("stateChanged");
	VARIABLE("spawnHandle");
	VARIABLE("screamTime");

	METHOD("new") {
		params [["_thisObject", "", [""]], ["_AI", "", [""]], ["_target", objNull, [objNull]] ];
		pr _a = GETV(_AI, "agent");
		pr _captor = CALLM(_a, "getObjectHandle", []);
		T_SETV("objectHandle", _captor);
		T_SETV("target", _target);
		
		//FSM
		T_SETV("stateChanged", true);
		T_SETV("stateMachine", 0);
		
		T_SETV("spawnHandle", scriptNull);
		T_SETV("screamTime", 0);
	} ENDMETHOD;
	
	METHOD("activate") {
		params [["_thisObject", "", [""]]];
		
		pr _captor = T_GETV("objectHandle");		
		_captor lockWP false;
		_captor setSpeedMode "NORMAL";

		//OOP_INFO_0("ActionUnitArrest: ACTIVATE");
		// Set state
		T_SETV("state", ACTION_STATE_ACTIVE);

		// Return ACTIVE state
		ACTION_STATE_ACTIVE
	} ENDMETHOD;
	
	METHOD("process") {
		params [["_thisObject", "", [""]]];

		CALLM(_thisObject, "activateIfInactive", []);
		
		pr _state = T_GETV("state");
		if (_state != ACTION_STATE_ACTIVE) exitWith {_state};

		pr _captor = T_GETV("objectHandle");
		pr _target = T_GETV("target");

		if (!(alive _captor) || (behaviour _captor == "COMBAT")) then {
			//OOP_INFO_0("ActionUnitArrest: FAILED, reason: Captor unit dead or in combat."); 
			T_SETV("stateChanged", true);
			T_SETV("stateMachine", 2);
		};

		if (IS_TARGET_ARRESTED_UNCONSCIOUS_DEAD) then {
			//OOP_INFO_0("ActionUnitArrest: completed, reason: target unit dead, unconscious or arrested."); 
			T_SETV("stateChanged", true);
			T_SETV("stateMachine", 3);
		};
		
		scopename "switch";
		switch (T_GETV("stateMachine")) do {

			// CATCH UP
			case 0: {
				OOP_DEBUG_1("ActionUnitArrest: CATCH UP, Distance: %1", ((getPos _captor) distance (getPos _target)));

				if (IS_TARGET_ARRESTED_UNCONSCIOUS_DEAD) exitWith {
					T_SETV("state", ACTION_STATE_COMPLETED);
					ACTION_STATE_COMPLETED
				};

				if (
					getPos _captor distance getPos _target < MIN_ARREST_DIST && 
					!(IS_TARGET_ARRESTED_UNCONSCIOUS_DEAD) &&
					random 4 <= 2
				) then {
					CALLSM1("ActionUnitArrest", "performArrest", _target);				
					T_SETV("stateMachine", 1);
					breakTo "switch";
				};

				if (T_GETV("stateChanged")) then {

					T_SETV("stateChanged", false);
					T_SETV("stateTimer", time);
					
					_captor dotarget _target;

					pr _handle = [_target,_captor] spawn {
						params ["_target", "_captor"];
						waitUntil {
							pr _pos = (eyeDirection _target vectorMultiply 1.6) vectorAdd getpos _target;
							
							_captor doMove _pos;
							_captor doWatch _target;
							_pos_arrest = getpos _target;

							if (getpos _target distance getpos _captor > 30) then { sleep 3;};
							sleep 1;

							_isMoving = !(_pos_arrest distance getpos _target < 0.1);
							_target setVariable ["isMoving", _isMoving];
							
							pr _return = !_isMoving && {_pos distance getpos _captor < MIN_ARREST_DIST};
							_return
						};
					};
					terminate T_GETV("spawnHandle");
					T_SETV("spawnHandle", _handle);

				} else {

					// been following for X secs
					if (time - T_GETV("stateTimer") > MAX_CHASE_TIME) then {
						T_SETV("stateMachine", 2);
						breakTo "switch";

					} else {

						// mitigate the msg flood
						if (random 10 < 1) then {
							if (time > T_GETV("screamTime") && (_target getVariable ["isMoving", false])) then {
								pr _newScreamTime = time + random [10, 15, 20];
								T_SETV("screamTime", _newScreamTime);
								
								pr _sentence = "Hey you, stop here.";
								if (selectRandom [true,false]) then { 
									_captor say "stop";
									_sentence = selectRandom [
									"STOP! Get on the fucking ground!",
									"STOP! Get down on the ground!",
									"DO NOT MOVE! Get down on the ground!"
									]; 
								} else {
									_captor say "halt";
									_sentence = selectRandom [
									"HALT! Get on the fucking ground!",
									"HALT! Get down on the ground!",
									"DO NOT MOVE! Get down on the ground!"
									]; 
								};
								
								[_captor, _sentence, _target] call Dialog_fnc_hud_createSentence;
								_captor setSpeedMode "FULL";
							};
						};
					};
				}; // end state changed
				
				if (scriptDone T_GETV("spawnHandle")) then {
					T_SETV("stateChanged", true);
					T_SETV("stateMachine", 1);
				};
			}; // end CATCH UP

			/*
				MOVE TO AND ARREST
				AI unit is now close and closing the gap to perform the actual arrest.
			*/
			case 1: {
				//OOP_INFO_0("ActionUnitArrest: Searching/Arresting target.");

				if (T_GETV("stateChanged")) then {
					T_SETV("stateChanged", false);
					T_SETV("stateTimer", time);
					
					pr _handle = [_captor, _target] spawn {
						params ["_captor", "_target"];
						waitUntil {
							
							_animationDone = false;
							_pos = (eyeDirection _target vectorMultiply 1.6) vectorAdd getpos _target;
							_captor doMove _pos;
							_captor doWatch _target;
							_pos_search = getpos _target;

							// play animation if close enough, finishing the script
							if (getPos _captor distance getPos _target < MIN_ARREST_DIST) then {
								pr _currentWeapon = currentWeapon _captor;
								pr _animation = call {
									if(_currentWeapon isequalto primaryWeapon _captor) exitWith {
										"amovpercmstpsraswrfldnon_ainvpercmstpsraswrfldnon_putdown" //primary
									};
									if(_currentWeapon isequalto secondaryWeapon _captor) exitWith {
										"amovpercmstpsraswlnrdnon_ainvpercmstpsraswlnrdnon_putdown" //launcher
									};
									if(_currentWeapon isequalto handgunWeapon _captor) exitWith {
										"amovpercmstpsraswpstdnon_ainvpercmstpsraswpstdnon_putdown" //pistol
									};
									if(_currentWeapon isequalto binocular _captor) exitWith {
										"amovpercmstpsoptwbindnon_ainvpercmstpsoptwbindnon_putdown" //bino
									};
									"amovpercmstpsnonwnondnon_ainvpercmstpsnonwnondnon_putdown" //non
								};

								_captor playMove _animation;
								_animationDone = true;
								
								// only perform arrest if unit IS actually close enough, prevent magic hands
								if (getPos _captor distance getPos _target < MIN_ARREST_DIST) then {
									CALLSM1("ActionUnitArrest", "performArrest", _target);
								} else {
									CALLSM2("ActionUnitArrest", "killArrestTarget", _target, _captor);
								};
							};
							sleep 1;
							_animationDone
						}; // end waitUntil
					}; // end spawn script
						
					//[_captor,"So who do whe have here?",_target] call Dialog_fnc_hud_createSentence;
					// arrest player by sending a message to unit's undercoverMonitor				
					
					T_SETV("spawnHandle", _handle);
				} else {
					if ((T_GETV("stateTimer") + 30) < time) then {
						T_SETV("stateMachine", 2);

						breakTo "switch";
					};
				};
				
				if (scriptDone T_GETV("spawnHandle")) then {
					T_SETV("stateChanged", true);
					T_SETV("stateMachine", 3);

					breakTo "switch";
				};
			}; // end MOVE TO AND ARREST

			// FAILED
			case 2: {
				//OOP_INFO_0("ActionUnitArrest: FAILED CATCH UP. Player will be made overt.");

				CALLSM2("ActionUnitArrest", "killArrestTarget", _target, _captor);	

				_state = ACTION_STATE_FAILED;
			};
			
			// COMPLETED SUCCESSFULLY
			case 3: {
				//OOP_INFO_0("ActionUnitArrest: COMPLETED.");

				_state = ACTION_STATE_COMPLETED;
			};
		};

		// Return the current state
		T_SETV("state", _state);
		_state
	} ENDMETHOD;

	/*
		Performs the actual arrest of targeted civilian or player.
		
	*/
	STATIC_METHOD("performArrest") {
		params [P_THISCLASS, P_OBJECT("_target")];

		// If it's a civilian presence target...
		if ([_target] call CivPresence_fnc_isUnitCreatedByCP) then {
			[_target, true] call CivPresence_fnc_arrestUnit;
		} else {
			// Otherwise it's a player
			_target playMoveNow "acts_aidlpsitmstpssurwnondnon01"; // sitting down and tied up

			if (!isPlayer _target) then {
				// Some inspiration from https://forums.bohemia.net/forums/topic/193304-hostage-script-using-holdaction-function-download/
				_target disableAI "MOVE"; // Disable AI Movement
				_target disableAI "AUTOTARGET"; // Disable AI Autotarget
				_target disableAI "ANIM"; // Disable AI Behavioural Scripts
				_target allowFleeing 0; // Disable AI Fleeing
				_target setBehaviour "Careless"; // Set Behaviour to Careless because, you know, ARMA AI.
			};
		
			_target setVariable ["timeArrested", time+10];
			REMOTE_EXEC_CALL_STATIC_METHOD("UndercoverMonitor", "onUnitArrested", [_target], _target, false);
		};
	} ENDMETHOD;

	/*
		Called only for PLAYER. Player is presumed to have purposely evaded arrest.
		Makes player (target) go overt in Undercover. Makes unit doing the arrest (captor) go into combat.
	*/
	STATIC_METHOD("killArrestTarget") {
		params [P_THISCLASS, P_OBJECT("_target"), P_OBJECT("_captor")];
		if (isPlayer _target) then {
			pr _sentence = selectRandom [
				"NEVER SHOULD HAVE COME HERE!",
				"YOU ASKED FOR IT!",
				"HE'S GOT A GUN!",
				"DO NOT MOVE!",
				"HOSTILE!",
				"SHOTS FIRED!",
				"OPEN FIRE!"
			]; 

			[_captor, _sentence, _target] call Dialog_fnc_hud_createSentence;

			pr _args = [_target, 3.0];
			REMOTE_EXEC_CALL_STATIC_METHOD("undercoverMonitor", "boostSuspicion", _args, _target, false);

			_captor setBehaviour "COMBAT";
			_captor doWatch _target;
		};
	} ENDMETHOD;
	
	// logic to run when the action is satisfied
	METHOD("terminate") {
		params [["_thisObject", "", [""]]];

		terminate T_GETV("spawnHandle");
		pr _captor = T_GETV("objectHandle");
		_captor doWatch objNull;
		_captor lookAt objNull;
		_captor lockWP false;
		_captor setSpeedMode "LIMITED";
		
	} ENDMETHOD;

ENDCLASS;
