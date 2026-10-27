import Toybox.Lang;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class RecipeEditor {
    var slot as Number = 0;
    var step as Number = 0;
    var draft as Recipe or Null;
    var template as RecipeTemplates.Action = RecipeTemplates.INITIAL_MIX;
    var selectedIngredients as Array<Boolean> = [false, false, false, false];
    var repeats as Number = 1;
    var editingMix as Boolean = false;
    function recipe() as Recipe {
        var value = draft;
        if (value == null) { throw new RecipeError("Choose a recipe before editing."); }
        return value;
    }

    function showSlots() as Void {
        var recipes = timerApp().getStore().recipes;
        var menu = new WatchUi.Menu2({:title => "Edit recipes"});
        menu.addItem(new WatchUi.MenuItem("New recipe", "Starts with the initial mix", -1, null));
        for (var i = 0; i < recipes.size(); i += 1) {
            menu.addItem(new WatchUi.MenuItem(recipes[i].name,
                recipes[i].labels.size() + " steps", i, null));
        }
        pushMenu(menu, method(:chooseSlot));
    }
    function chooseSlot(id as Number) as Void {
        if (id == -1) {
            if (timerApp().getStore().isFull()) {
                listMessage("Maximum " + RecipeStore.MAX_RECIPES + " recipes. Delete one first.");
                return;
            }
            slot = -1;
            draft = Recipes.parse(nextName("Recipe"), "");
            startMix();
            return;
        }
        slot = id;
        draft = timerApp().getStore().recipes[slot].copy();
        if (recipe().labels.size() == 0) { startMix(); return; }
        showRecipe();
    }
    function nextName(base as String) as String {
        var recipes = timerApp().getStore().recipes;
        for (var n = 1; n <= recipes.size() + 1; n += 1) {
            var candidate = base + " " + n;
            var used = false;
            for (var i = 0; i < recipes.size(); i += 1) {
                if (recipes[i].name.equals(candidate)) { used = true; }
            }
            if (!used) { return candidate; }
        }
        return base;
    }
    function listMessage(message as String) as Void {
        var menu = new WatchUi.Menu2({:title => "Recipes"});
        menu.addItem(new WatchUi.MenuItem(message, "Select to return", 0, null));
        pushMenu(menu, method(:backToSlots));
    }
    function backToSlots(id as Number) as Void { showSlots(); }
    function startMix() as Void {
        template = RecipeTemplates.INITIAL_MIX;
        repeats = 1;
        editingMix = false;
        selectedIngredients = [false, false, false, false];
        showIngredients(0);
    }
    function editMix() as Void {
        template = RecipeTemplates.INITIAL_MIX;
        editingMix = true;
        selectedIngredients = RecipeTemplates.mixSelection(recipe());
        showIngredients(0);
    }

    function showRecipe() as Void {
        var value = recipe();
        var menu = new WatchUi.Menu2({:title => value.name});
        menu.addItem(new WatchUi.MenuItem("Add action", "Ingredients, fold, bake, refrigerate", -2, null));
        var all = RecipeTemplates.blocks(value);
        for (var i = 0; i < all.size(); i += 1) {
            var block = all[i];
            var title;
            var detail;
            if (block[2] > 0) {
                title = block[2] > 1 ? "Fold x" + block[2] : "Fold";
                detail = block[3] == 0 ? "No wait" : formatMinutes(block[3]) + " wait before each";
            } else {
                title = value.labels[block[0]];
                detail = value.minutes[block[0]] == 0 ? "Manual action" : formatMinutes(value.minutes[block[0]]);
            }
            menu.addItem(new WatchUi.MenuItem((i + 1) + ". " + title, detail, i, null));
        }
        menu.addItem(new WatchUi.MenuItem("Rename recipe", null, -1, null));
        menu.addItem(new WatchUi.MenuItem("Duplicate recipe", null, -3, null));
        menu.addItem(new WatchUi.MenuItem("Delete recipe", null, -4, null));
        menu.addItem(new WatchUi.MenuItem("Back to recipes", null, -5, null));
        pushMenu(menu, method(:chooseRecipeAction));
    }
    function chooseRecipeAction(id as Number) as Void {
        if (id == -1) { editText("Recipe name", recipe().name, 24, method(:rename), method(:showRecipe)); return; }
        if (id == -2) {
            if (recipe().labels.size() >= 32) { fail("Maximum 32 steps."); return; }
            showTemplates();
            return;
        }
        if (id == -3) { duplicate(); return; }
        if (id == -4) {
            WatchUi.pushView(new WatchUi.Confirmation("Delete " + recipe().name + "?"),
                new ConfirmAction(method(:deleteRecipe)), WatchUi.SLIDE_UP);
            return;
        }
        if (id == -5) { showSlots(); return; }
        step = id;
        showStep();
    }
    function duplicate() as Void {
        var store = timerApp().getStore();
        if (store.isFull()) { fail("Maximum " + RecipeStore.MAX_RECIPES + " recipes."); return; }
        var copy = recipe().copy();
        copy.name = nextName("Copy");
        slot = store.put(-1, copy);
        draft = copy;
        showRecipe();
    }
    function deleteRecipe() as Void {
        if (slot >= 0) { timerApp().getStore().remove(slot); }
        draft = null;
        showSlots();
    }
    function rename(text as String) as Void {
        if (!Recipes.validLabel(text, 24)) { fail("Name: 1-24 characters; no | or ;."); return; }
        recipe().name = text;
        save();
        showRecipe();
    }
    function showTemplates() as Void {
        if (recipe().labels.size() == 0) { startMix(); return; }
        var menu = new WatchUi.Menu2({:title => "Add action"});
        var actions = RecipeTemplates.actions();
        for (var i = 0; i < actions.size(); i += 1) {
            var action = actions[i];
            if (action == RecipeTemplates.INITIAL_MIX) { continue; }
            menu.addItem(new WatchUi.MenuItem(RecipeTemplates.actionLabel(action), null, action, null));
        }
        menu.addItem(new WatchUi.MenuItem("Cancel", null, -1, null));
        pushMenu(menu, method(:chooseTemplate));
    }
    function chooseTemplate(id as Number) as Void {
        if (id == -1) { showRecipe(); return; }
        var actions = RecipeTemplates.actions();
        var found = false;
        for (var i = 0; i < actions.size(); i += 1) {
            if (actions[i] == id) { template = actions[i]; found = true; break; }
        }
        if (!found) { fail("Invalid action."); return; }
        repeats = 1;
        selectedIngredients = [false, false, false, false];
        if (template == RecipeTemplates.INITIAL_MIX || template == RecipeTemplates.ADD_INGREDIENTS) {
            showIngredients(0);
            return;
        }
        if (template == RecipeTemplates.FOLD) {
            showNumberPicker("Number of folds", 4, 1, 16, "folds", method(:setRepeats), method(:showRecipe));
            return;
        }
        chooseWait();
    }
    function showIngredients(focus as Number) as Void {
        var title = template == RecipeTemplates.INITIAL_MIX ? "Mix ingredients" : "Ingredients to add";
        var menu = new WatchUi.Menu2({:title => title, :focus => focus});
        var names = RecipeTemplates.ingredients();
        for (var i = 0; i < names.size(); i += 1) {
            menu.addItem(new WatchUi.ToggleMenuItem(names[i], null, i, selectedIngredients[i], null));
        }
        menu.addItem(new WatchUi.MenuItem("Continue", "Use selected ingredients", -1, null));
        menu.addItem(new WatchUi.MenuItem("Cancel", null, -2, null));
        WatchUi.pushView(menu, new IngredientInput(self), WatchUi.SLIDE_UP);
    }
    function chooseIngredient(id as Number) as Void {
        if (id == -2) {
            if (editingMix) { showStep(); return; }
            if (recipe().labels.size() == 0) { showSlots(); return; }
            showRecipe();
            return;
        }
        var any = false;
        for (var i = 0; i < selectedIngredients.size(); i += 1) {
            if (selectedIngredients[i]) { any = true; }
        }
        if (!any) {
            var menu = new WatchUi.Menu2({:title => "Select an ingredient"});
            menu.addItem(new WatchUi.MenuItem("Back to ingredients", null, 4, null));
            pushMenu(menu, method(:showIngredients));
            return;
        }
        if (editingMix) {
            editingMix = false;
            try {
                draft = RecipeTemplates.setMix(recipe(), selectedIngredients);
            } catch (error instanceof RecipeError) { fail(error.getMessage()); return; }
            save();
            showStep();
            return;
        }
        chooseWait();
    }
    function setRepeats(value as Number) as Void {
        repeats = value;
        chooseWait();
    }
    function chooseWait() as Void {
        if (recipe().labels.size() == 0 && template != RecipeTemplates.FOLD) { appendAction(0); return; }
        showDurationPicker(template == RecipeTemplates.FOLD ? "Wait before EACH fold" : "Wait before action",
            template == RecipeTemplates.FOLD ? 45 : 0, method(:appendAction), method(:showRecipe));
    }
    function appendAction(wait as Number) as Void {
        try {
            draft = RecipeTemplates.append(recipe(), template, selectedIngredients, wait, repeats);
        } catch (error instanceof RecipeError) { fail(error.getMessage()); return; }
        save();
        showRecipe();
    }
    function currentBlock() as Array<Number> {
        var all = RecipeTemplates.blocks(recipe());
        if (step >= all.size()) { step = all.size() - 1; }
        return all[step];
    }
    function showStep() as Void {
        var value = recipe();
        if (value.labels.size() == 0) { showRecipe(); return; }
        var block = currentBlock();
        var count = RecipeTemplates.blocks(value).size();
        var start = block[0];
        if (RecipeTemplates.isLocked(value, start)) {
            var locked = new WatchUi.Menu2({:title => value.labels[start]});
            locked.addItem(new WatchUi.MenuItem("Change ingredients", "Initial mix stays first", 6, null));
            locked.addItem(new WatchUi.MenuItem("Back to recipe", null, 5, null));
            pushMenu(locked, method(:chooseStepAction));
            return;
        }
        var menu;
        if (block[2] > 0) {
            menu = new WatchUi.Menu2({:title => block[2] > 1 ? "Fold x" + block[2] : "Fold"});
            menu.addItem(new WatchUi.MenuItem("Repeats", block[2] + " folds", 7, null));
            menu.addItem(new WatchUi.MenuItem("Wait before each",
                block[3] == 0 ? "No wait" : formatMinutes(block[3]), 8, null));
        } else {
            menu = new WatchUi.Menu2({:title => value.labels[start]});
            menu.addItem(new WatchUi.MenuItem("Edit label", null, 0, null));
            menu.addItem(new WatchUi.MenuItem("Edit duration",
                value.minutes[start] == 0 ? "Manual action" : formatMinutes(value.minutes[start]), 1, null));
        }
        if (step > 0 && !RecipeTemplates.isLocked(value, RecipeTemplates.blocks(value)[step - 1][0])) {
            menu.addItem(new WatchUi.MenuItem("Move earlier", null, 2, null));
        }
        if (step + 1 < count) {
            menu.addItem(new WatchUi.MenuItem("Move later", null, 3, null));
        }
        menu.addItem(new WatchUi.MenuItem("Delete step", block[2] > 1 ? "Removes all folds and waits" : null, 4, null));
        menu.addItem(new WatchUi.MenuItem("Back to recipe", null, 5, null));
        pushMenu(menu, method(:chooseStepAction));
    }
    function chooseStepAction(id as Number) as Void {
        var block = currentBlock();
        if (id == 6) { editMix(); return; }
        if (id == 0) {
            editText("Step label", recipe().labels[block[0]], 40, method(:setLabel), method(:showStep));
            return;
        }
        if (id == 1) {
            showDurationPicker("Step duration", recipe().minutes[block[0]],
                method(:setMinutes), method(:showStep));
            return;
        }
        if (id == 7) {
            showNumberPicker("Number of folds", block[2], 1, 16, "folds", method(:setFoldRepeats),
                method(:showStep));
            return;
        }
        if (id == 8) {
            showDurationPicker("Wait before EACH fold", block[3], method(:setFoldWait), method(:showStep));
            return;
        }
        if (id == 4) {
            WatchUi.pushView(new WatchUi.Confirmation("Delete this step?"),
                new ConfirmAction(method(:deleteStep)), WatchUi.SLIDE_UP);
            return;
        }
        if (id == 5) { showRecipe(); return; }
        var direction = id == 2 ? -1 : 1;
        draft = RecipeTemplates.moveBlock(recipe(), step, direction);
        step += direction;
        save();
        showStep();
    }
    function replaceBlock(steps as Recipe) as Void {
        var block = currentBlock();
        try {
            draft = RecipeTemplates.replaceSteps(recipe(), block[0], block[1], steps);
        } catch (error instanceof RecipeError) { fail(error.getMessage()); return; }
        save();
        showStep();
    }
    function setFoldRepeats(value as Number) as Void {
        replaceBlock(RecipeTemplates.foldSteps(value, currentBlock()[3]));
    }
    function setFoldWait(value as Number) as Void {
        replaceBlock(RecipeTemplates.foldSteps(currentBlock()[2], value));
    }
    function deleteStep() as Void {
        var block = currentBlock();
        if (RecipeTemplates.isLocked(recipe(), block[0])) { showStep(); return; }
        draft = RecipeTemplates.replaceSteps(recipe(), block[0], block[1],
            new Recipe("", [] as Array<String>, [] as Array<Number>));
        save();
        showRecipe();
    }
    function setLabel(text as String) as Void {
        if (!Recipes.validLabel(text, 40)) { fail("Label: 1-40 characters; no | or ;."); return; }
        recipe().labels[currentBlock()[0]] = text;
        save();
        showStep();
    }
    function setMinutes(value as Number) as Void {
        recipe().minutes[currentBlock()[0]] = value;
        save();
        showStep();
    }
    function save() as Void {
        slot = timerApp().getStore().put(slot, recipe());
    }
    function fail(message as String) as Void {
        var menu = new WatchUi.Menu2({:title => "Not saved"});
        menu.addItem(new WatchUi.MenuItem(message, "Select to return to editor", 0, null));
        pushMenu(menu, method(:retry));
    }
    function retry(id as Number) as Void { showRecipe(); }
}

function formatMinutes(minutes as Number) as String {
    if (minutes < 60) { return minutes + " min"; }
    return (minutes / 60) + "h" + (minutes % 60 == 0 ? "" : (minutes % 60).format("%02d"));
}

class IngredientInput extends WatchUi.Menu2InputDelegate {
    var editor as RecipeEditor;
    function initialize(owner as RecipeEditor) { Menu2InputDelegate.initialize(); editor = owner; }
    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId() as Number;
        if (item instanceof WatchUi.ToggleMenuItem) {
            editor.selectedIngredients[id] = item.isEnabled();
            return;
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        editor.chooseIngredient(id);
    }
    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        editor.chooseIngredient(-2);
    }
}

function showDurationPicker(title as String, minutes as Number, callback as Method,
    cancelled as Method) as Void {
    var view = new DurationView(title, minutes);
    WatchUi.pushView(view, new DurationInput(view, callback, cancelled), WatchUi.SLIDE_UP);
}

// Garmin Timer-style HH:MM setter: UP/DOWN change the focused field,
// START moves to minutes then confirms, BACK returns to hours then cancels.
class DurationView extends WatchUi.View {
    var title as String;
    var hours as Number;
    var mins as Number;
    var focus as Number = 0;

    function initialize(label as String, minutes as Number) {
        View.initialize();
        title = label;
        if (minutes < 0) { minutes = 0; }
        if (minutes > 1440) { minutes = 1440; }
        hours = minutes / 60;
        mins = minutes % 60;
    }

    function total() as Number { return hours * 60 + mins; }

    // Held-button steps: hours move by one, minutes snap to the next/previous
    // multiple of 5 and then move by 5.
    function fastAdjust(delta as Number) as Void {
        if (focus == 0 || hours == 24) {
            adjust(delta);
            return;
        }
        if (delta > 0) {
            mins = (mins / 5 + 1) * 5;
            if (mins >= 60) { mins = 0; }
        } else {
            mins = mins % 5 == 0 ? mins - 5 : mins - mins % 5;
            if (mins < 0) { mins = 55; }
        }
        WatchUi.requestUpdate();
    }

    function adjust(delta as Number) as Void {
        if (focus == 0) {
            hours = (hours + delta + 25) % 25;
        } else {
            mins = (mins + delta + 60) % 60;
        }
        if (hours == 24) { mins = 0; }
        WatchUi.requestUpdate();
    }

    function setFocus(field as Number) as Void {
        focus = field;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var cy = height * 55 / 100;
        var small = Graphics.FONT_XTINY;
        var digits = Graphics.FONT_NUMBER_MEDIUM;

        dc.drawText(cx, height * 31 / 100, Graphics.FONT_TINY, title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var fieldWidth = dc.getTextWidthInPixels("00", digits) + 12;
        var fieldHeight = dc.getFontHeight(digits) * 4 / 5;
        var gap = dc.getTextWidthInPixels(":", digits) / 2 + 6;
        var centers = [cx - gap - fieldWidth / 2, cx + gap + fieldWidth / 2];
        var values = [hours, mins];
        var units = ["hrs", "min"];
        for (var i = 0; i < 2; i += 1) {
            var x = centers[i] as Number;
            if (i == focus) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
                dc.fillRoundedRectangle(x - fieldWidth / 2, cy - fieldHeight / 2,
                    fieldWidth, fieldHeight, 8);
                dc.fillPolygon([[x - 7, cy - fieldHeight / 2 - 4], [x + 7, cy - fieldHeight / 2 - 4],
                    [x, cy - fieldHeight / 2 - 11]]);
                dc.fillPolygon([[x - 7, cy + fieldHeight / 2 + 4], [x + 7, cy + fieldHeight / 2 + 4],
                    [x, cy + fieldHeight / 2 + 11]]);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(x, cy, digits, (values[i] as Number).format("%02d"),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, cy + fieldHeight / 2 + 12, small, units[i] as String,
                Graphics.TEXT_JUSTIFY_CENTER);
        }
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, digits, ":", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var y = height * 21 / 100;
        dc.drawText(width - 40, y, small, focus == 0 ? "Next" : "Done",
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawLine(width - 33, y - 4, width - 29, y);
        dc.drawLine(width - 29, y, width - 33, y + 4);
        dc.drawText(cx, height * 86 / 100, small,
            total() == 0 ? "0:00 = no wait" : (focus == 0 ? "Back: cancel" : "Back: hours"),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class DurationInput extends WatchUi.BehaviorDelegate {
    var view as DurationView;
    var callback as Method;
    var cancelled as Method;
    var repeater as Timer.Timer or Null;
    var direction as Number = 0;
    var heldTicks as Number = 0;
    var pressHandled as Boolean = false;
    function initialize(target as DurationView, action as Method, cancel as Method) {
        BehaviorDelegate.initialize();
        view = target;
        callback = action;
        cancelled = cancel;
    }
    function keyDirection(key as Number) as Number {
        if (key == WatchUi.KEY_UP) { return 1; }
        if (key == WatchUi.KEY_DOWN) { return -1; }
        return 0;
    }
    // UP/DOWN act on press; holding them repeats after a short delay.
    function onKeyPressed(keyEvent as WatchUi.KeyEvent) as Boolean {
        var delta = keyDirection(keyEvent.getKey());
        if (delta == 0) { return false; }
        stopRepeat();
        direction = delta;
        heldTicks = 0;
        pressHandled = true;
        view.adjust(delta);
        var timer = new Timer.Timer();
        repeater = timer;
        timer.start(method(:repeat), 150, true);
        return true;
    }
    function onKeyReleased(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyDirection(keyEvent.getKey()) == 0) { return false; }
        stopRepeat();
        return true;
    }
    function repeat() as Void {
        heldTicks += 1;
        if (heldTicks >= 4) { view.fastAdjust(direction); }
    }
    function stopRepeat() as Void {
        var timer = repeater;
        if (timer != null) { timer.stop(); }
        repeater = null;
    }
    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER) { return confirm(); }
        var delta = keyDirection(key);
        if (delta != 0) {
            if (pressHandled) { pressHandled = false; }
            else { view.adjust(delta); }
            return true;
        }
        if (key == WatchUi.KEY_ESC) { return back(); }
        return false;
    }
    function onSelect() as Boolean { return false; }
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var x = clickEvent.getCoordinates()[0];
        view.setFocus(x < System.getDeviceSettings().screenWidth / 2 ? 0 : 1);
        return true;
    }
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        var direction = swipeEvent.getDirection();
        if (direction == WatchUi.SWIPE_DOWN) { view.adjust(1); return true; }
        if (direction == WatchUi.SWIPE_UP) { view.adjust(-1); return true; }
        if (direction == WatchUi.SWIPE_RIGHT) { return back(); }
        return true;
    }
    function onMenu() as Boolean { return true; }
    function onBack() as Boolean { return back(); }
    function confirm() as Boolean {
        stopRepeat();
        if (view.focus == 0) {
            view.setFocus(1);
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        callback.invoke(view.total());
        return true;
    }
    function back() as Boolean {
        stopRepeat();
        if (view.focus == 1) {
            view.setFocus(0);
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        cancelled.invoke();
        return true;
    }
}

// Single-number setter styled like the HH:MM screen: UP/DOWN (or swipes)
// change the value, START confirms, BACK cancels.
function showNumberPicker(title as String, value as Number, low as Number, high as Number,
    unit as String, callback as Method, cancelled as Method) as Void {
    var view = new NumberView(title, value, low, high, unit);
    WatchUi.pushView(view, new NumberInput(view, callback, cancelled), WatchUi.SLIDE_UP);
}

class NumberView extends WatchUi.View {
    var title as String;
    var value as Number;
    var minimum as Number;
    var maximum as Number;
    var unit as String;

    function initialize(label as String, initial as Number, low as Number, high as Number,
        suffix as String) {
        View.initialize();
        title = label;
        minimum = low;
        maximum = high;
        unit = suffix;
        value = initial < low ? low : (initial > high ? high : initial);
    }

    function adjust(delta as Number) as Void {
        var span = maximum - minimum + 1;
        value = minimum + ((value - minimum + delta) % span + span) % span;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var cy = height * 55 / 100;
        var small = Graphics.FONT_XTINY;
        var digits = Graphics.FONT_NUMBER_MEDIUM;
        dc.drawText(cx, height * 31 / 100, Graphics.FONT_TINY, title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        var boxWidth = dc.getTextWidthInPixels("00", digits) + 12;
        var boxHeight = dc.getFontHeight(digits) * 4 / 5;
        dc.fillRoundedRectangle(cx - boxWidth / 2, cy - boxHeight / 2, boxWidth, boxHeight, 8);
        dc.fillPolygon([[cx - 7, cy - boxHeight / 2 - 4], [cx + 7, cy - boxHeight / 2 - 4],
            [cx, cy - boxHeight / 2 - 11]]);
        dc.fillPolygon([[cx - 7, cy + boxHeight / 2 + 4], [cx + 7, cy + boxHeight / 2 + 4],
            [cx, cy + boxHeight / 2 + 11]]);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, digits, value.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + boxHeight / 2 + 12, small, unit, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawStartHint(dc, "Done");
        dc.drawText(cx, height * 86 / 100, small, "Back: cancel",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class NumberInput extends WatchUi.BehaviorDelegate {
    var view as NumberView;
    var callback as Method;
    var cancelled as Method;
    function initialize(target as NumberView, action as Method, cancel as Method) {
        BehaviorDelegate.initialize();
        view = target;
        callback = action;
        cancelled = cancel;
    }
    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER) {
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            callback.invoke(view.value);
            return true;
        }
        if (key == WatchUi.KEY_UP) { view.adjust(1); return true; }
        if (key == WatchUi.KEY_DOWN) { view.adjust(-1); return true; }
        if (key == WatchUi.KEY_ESC) { return onBack(); }
        return false;
    }
    function onSelect() as Boolean { return false; }
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean { return true; }
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        var direction = swipeEvent.getDirection();
        if (direction == WatchUi.SWIPE_DOWN) { view.adjust(1); }
        if (direction == WatchUi.SWIPE_UP) { view.adjust(-1); }
        if (direction == WatchUi.SWIPE_RIGHT) { return onBack(); }
        return true;
    }
    function onMenu() as Boolean { return true; }
    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        cancelled.invoke();
        return true;
    }
}

function drawStartHint(dc as Graphics.Dc, label as String) as Void {
    var y = dc.getHeight() * 21 / 100;
    var x = dc.getWidth() - 40;
    dc.drawText(x, y, Graphics.FONT_XTINY, label,
        Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    dc.drawLine(x + 7, y - 4, x + 11, y);
    dc.drawLine(x + 11, y, x + 7, y + 4);
}

// Letter-by-letter text entry, replacing the native TextPicker (which crashes
// on fenix 8). UP/DOWN pick a character, START adds it (or saves on "OK"),
// BACK deletes the last character (or cancels when empty), hold UP clears.
function editText(title as String, value as String, maxLength as Number, callback as Method,
    cancelled as Method) as Void {
    var view = new TextEntryView(title, value, maxLength);
    WatchUi.pushView(view, new TextEntryInput(view, callback, cancelled), WatchUi.SLIDE_UP);
}

class TextEntryView extends WatchUi.View {
    static const CHARS = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-'&";
    var title as String;
    var text as String;
    var maxLength as Number;
    var index as Number = 0;

    function initialize(label as String, value as String, limit as Number) {
        View.initialize();
        title = label;
        text = value;
        maxLength = limit;
    }

    // Entry 0 is "OK" (save); the rest are characters, auto-capitalized per word.
    function size() as Number { return CHARS.length() + 1; }
    function entry(i as Number) as String {
        if (i == 0) { return "OK"; }
        var value = CHARS.substring(i - 1, i) as String;
        var upper = text.length() == 0 || (text.substring(text.length() - 1, null) as String).equals(" ");
        return upper ? value : value.toLower();
    }
    function label(i as Number) as String {
        var value = entry(i);
        return value.equals(" ") ? "Space" : value;
    }

    function adjust(delta as Number) as Void {
        index = ((index + delta) % size() + size()) % size();
        WatchUi.requestUpdate();
    }

    function add() as Void {
        if (text.length() < maxLength) { text += entry(index); }
        WatchUi.requestUpdate();
    }

    function backspace() as Void {
        text = text.substring(0, text.length() - 1) as String;
        WatchUi.requestUpdate();
    }

    function clear() as Void {
        text = "";
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var small = Graphics.FONT_XTINY;
        dc.drawText(cx, height * 31 / 100, Graphics.FONT_TINY, title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var shown = text + "_";
        var font = Graphics.FONT_SMALL;
        while (shown.length() > 1 && dc.getTextWidthInPixels(shown, font) > width - 70) {
            shown = shown.substring(1, null) as String;
        }
        dc.drawText(cx, height * 43 / 100, font, shown,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var cy = height * 61 / 100;
        var big = Graphics.FONT_MEDIUM;
        var current = label(index);
        var boxWidth = dc.getTextWidthInPixels(current, big) + 16;
        if (boxWidth < 40) { boxWidth = 40; }
        var boxHeight = dc.getFontHeight(big);
        dc.fillRoundedRectangle(cx - boxWidth / 2, cy - boxHeight / 2, boxWidth, boxHeight, 8);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var gap = boxWidth / 2 + 8;
        dc.drawText(cx - gap, cy, Graphics.FONT_TINY, label((index - 1 + size()) % size()),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx + gap, cy, Graphics.FONT_TINY, label((index + 1) % size()),
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy, big, current, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawStartHint(dc, index == 0 ? "Save" : "Add");
        dc.drawText(cx, height * 80 / 100, small,
            text.length() == 0 ? "Back: cancel" : "Back: delete",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

class TextEntryInput extends WatchUi.BehaviorDelegate {
    var view as TextEntryView;
    var callback as Method;
    var cancelled as Method;
    function initialize(target as TextEntryView, action as Method, cancel as Method) {
        BehaviorDelegate.initialize();
        view = target;
        callback = action;
        cancelled = cancel;
    }
    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER) { return confirm(); }
        if (key == WatchUi.KEY_UP) { view.adjust(1); return true; }
        if (key == WatchUi.KEY_DOWN) { view.adjust(-1); return true; }
        if (key == WatchUi.KEY_ESC) { return onBack(); }
        return false;
    }
    function confirm() as Boolean {
        if (view.index != 0) { view.add(); return true; }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        callback.invoke(view.text);
        return true;
    }
    function onSelect() as Boolean { return false; }
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean { return true; }
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        var direction = swipeEvent.getDirection();
        if (direction == WatchUi.SWIPE_DOWN) { view.adjust(1); }
        if (direction == WatchUi.SWIPE_UP) { view.adjust(-1); }
        if (direction == WatchUi.SWIPE_RIGHT) { return onBack(); }
        return true;
    }
    function onMenu() as Boolean { view.clear(); return true; }
    function onBack() as Boolean {
        if (view.text.length() > 0) { view.backspace(); return true; }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        cancelled.invoke();
        return true;
    }
}
