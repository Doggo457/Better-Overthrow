#include "\overthrow_main\script_component.hpp"
/*
 * BO_fnc_requestSave
 *
 * Trigger an auto-save as soon as the next OT autosave-loop tick
 * fires. Use this when a team-critical event happens (leader
 * transfer, war declaration, factory completion) and we want the
 * change durable even if the server crashes minutes later.
 *
 * Does not block — the actual save still runs through OT's normal
 * 11-step path on the next tick.
 */

SERVER_ONLY;

// OT's autosave gate at fn_initOverthrow uses OT_autoSave_last_time
// to schedule the next save. By zeroing it we ask the next tick to
// save immediately.
OT_autoSave_last_time = time;
BO_LOG_INFO("save","Auto-save requested");
