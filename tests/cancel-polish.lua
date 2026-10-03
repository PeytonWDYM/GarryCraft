-- Owned E2E: interrupt a real polish run and optionally restart it immediately afterward.
concommand.Add("garrycraft_test_cancel_polish", function(caller, _, arguments)
    assert(game.SinglePlayer(), "Cancellation tests require single-player")
    local GC = GarryCraft
    local owner = IsValid(caller) and caller or player.GetHumans()[1]
    local restart = arguments[1] == "restart"
    local replace = arguments[1] == "replace"
    local previous = GC.PolishSample
    local armed = true
    GC.PolishSample = function(state)
        previous(state)
        if not armed or state.polishPhase ~= "plain-armor" then return end
        armed = false
        GC.PolishSample = previous
        timer.Simple(0, function()
            if replace then GC.Start(owner) else GC.Stop() end
            file.Write("garrycraft-polish-cancel.json", util.TableToJSON({request = state.polishRequest, restart = restart, replace = replace}))
            if restart then timer.Simple(.15, function() owner:ConCommand("garrycraft_test polish") end) end
        end)
    end
    owner:ConCommand("garrycraft_test polish")
end)
