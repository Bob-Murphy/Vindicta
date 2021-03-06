#include "common.hpp"

/*
Unit action.
*/

#define pr private

#define THIS_ACTION_NAME "MyAction"

CLASS("ActionUnit", "Action")

	VARIABLE("hO");
	
	METHOD("new") {
		params [["_thisObject", "", [""]], ["_AI", "", [""]] ];
		
		pr _a = GETV(_AI, "agent"); // cache the object handle
		pr _oh = CALLM(_a, "getObjectHandle", []);
		SETV(_thisObject, "hO", _oh);
	} ENDMETHOD;

ENDCLASS;