import Toybox.Application.Storage;
import Toybox.Lang;

class Session {
    var recipe as Recipe;
    var index as Number = 0;
    var state as String = "ready";
    var deadline as Number = 0;
    var remaining as Number = 0;

    function initialize(value as Recipe) {
        recipe = value.copy();
    }

    function currentMinutes() as Number { return recipe.minutes[index]; }

    // A timed step directly followed by a manual action is that action's wait:
    // when it ends the action becomes due, so the pair needs one confirmation.
    function isWaitFor(i as Number) as Boolean {
        return i >= 0 && i + 1 < recipe.labels.size() && recipe.minutes[i] > 0 &&
            recipe.minutes[i + 1] == 0;
    }

    // Step whose label is shown: the action a running wait leads to.
    function actionIndex() as Number { return isWaitFor(index) ? index + 1 : index; }

    function isWaiting() as Boolean { return isWaitFor(index); }

    // [position, count] counting a wait and its action as one step.
    function progress() as Array<Number> {
        var count = 0;
        var position = 0;
        var current = actionIndex();
        for (var i = 0; i < recipe.labels.size(); i += 1) {
            if (!isWaitFor(i)) {
                count += 1;
                if (i <= current) { position = count; }
            }
        }
        return [position, count];
    }

    function tick(now as Number) as Boolean {
        if (state.equals("running") && now >= deadline) {
            state = "due";
            remaining = 0;
            if (isWaitFor(index)) { index += 1; }
            return true;
        }
        return false;
    }

    function secondsLeft(now as Number) as Number {
        if (state.equals("running")) { return (deadline > now) ? deadline - now : 0; }
        if (state.equals("paused")) { return remaining; }
        if (state.equals("ready")) { return currentMinutes() * 60; }
        return 0;
    }

    function select(now as Number) as Void {
        tick(now);
        if (state.equals("done")) { return; }
        if (state.equals("running")) {
            pause(now);
            return;
        }
        if (state.equals("paused")) {
            deadline = now + remaining;
            state = "running";
            return;
        }
        if (state.equals("ready") && currentMinutes() > 0) {
            deadline = now + currentMinutes() * 60;
            state = "running";
            return;
        }
        index += 1;
        if (index == recipe.labels.size()) {
            state = "done";
            return;
        }
        if (currentMinutes() == 0) {
            state = "ready";
        } else {
            deadline = now + currentMinutes() * 60;
            state = "running";
        }
    }

    function pause(now as Number) as Void {
        tick(now);
        if (state.equals("running")) {
            remaining = secondsLeft(now);
            state = "paused";
        }
    }

    function save() as Void {
        Storage.setValue("session", {
            "version" => 1, "name" => recipe.name, "steps" => recipe.encode(),
            "index" => index, "state" => state, "deadline" => deadline,
            "remaining" => remaining
        });
    }

    static function restore() as Session or Null {
        var data = Storage.getValue("session");
        if (data == null) { return null; }
        if (!(data instanceof Dictionary) || !(data["version"] instanceof Number) ||
            !(data["version"] as Number).equals(1) ||
            !(data["name"] instanceof String) || !(data["steps"] instanceof String) ||
            !(data["index"] instanceof Number) || !(data["state"] instanceof String) ||
            !(data["deadline"] instanceof Number) || !(data["remaining"] instanceof Number)) {
            throw new RecipeError("Saved timer is invalid. Use Stop timer to clear it.");
        }
        var result = new Session(Recipes.parse(data["name"] as String, data["steps"] as String));
        var index = data["index"] as Number;
        var state = data["state"] as String;
        var deadline = data["deadline"] as Number;
        var remaining = data["remaining"] as Number;
        if (result.recipe.labels.size() == 0 || index < 0 || index > result.recipe.labels.size() ||
            (index == result.recipe.labels.size() && !state.equals("done")) ||
            (state.equals("done") && index != result.recipe.labels.size()) ||
            !(state.equals("ready") || state.equals("running") || state.equals("paused") ||
              state.equals("due") || state.equals("done")) ||
            deadline < 0 || remaining < 0 || remaining > 86400) {
            throw new RecipeError("Saved timer is invalid. Use Stop timer to clear it.");
        }
        result.index = index;
        result.state = state;
        result.deadline = deadline;
        result.remaining = remaining;
        return result;
    }
}
