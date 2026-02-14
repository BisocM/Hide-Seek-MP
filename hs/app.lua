#include "core/init.lua"
#include "shared/init.lua"

#include "util/math.lua"
#include "util/time.lua"
#include "util/table.lua"

#include "contracts/command_types.lua"
#include "contracts/event_types.lua"
#include "contracts/schemas.lua"
#include "contracts/validate.lua"
#include "contracts/ability_errors.lua"

#include "domain/events.lua"
#include "domain/model/state.lua"
#include "domain/reducers/internal.lua"
#include "domain/reducers/command.lua"
#include "domain/reducers/tick.lua"

#include "infra/clock.lua"
#include "infra/players.lua"
#include "infra/world.lua"
#include "infra/targeting.lua"
#include "infra/spatial.lua"
#include "infra/player_tools.lua"
#include "infra/combat.lua"
#include "infra/mimic.lua"
#include "infra/events.lua"
#include "infra/effects.lua"
#include "infra/loadout.lua"
#include "infra/snapshot_writer.lua"

#include "server/round.lua"

#include "presentation/client/widgets/ui_helpers.lua"
#include "presentation/client/widgets/hud_runtime.lua"
#include "presentation/client/scenes/team_select_scene.lua"

#include "presentation/client/widgets/primitives.lua"
#include "presentation/client/widgets/hud_widget.lua"
#include "presentation/client/widgets/toast_widget.lua"
#include "presentation/client/widgets/feed_widget.lua"
#include "presentation/client/widgets/admin_menu_widget.lua"

#include "presentation/client/controllers/spectate_controller.lua"
#include "presentation/client/controllers/abilities_controller.lua"
#include "presentation/client/scenes/setup.lua"

#include "app/common/store.lua"
#include "app/common/command_dedupe.lua"
#include "app/client/commands.lua"
#include "app/server/runtime.lua"
#include "app/client/runtime.lua"

#include "infra/adapters/net/server_handlers.lua"
#include "infra/adapters/net/client_handlers.lua"

#include "presentation/client/runtime/runtime.lua"

#include "app/init.lua"
