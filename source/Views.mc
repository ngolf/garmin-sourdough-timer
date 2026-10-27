import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

function drawLines(dc as Graphics.Dc, text as String, y as Number, maxLines as Number) as Void {
    var width = dc.getWidth() - 48;
    var words = Recipes.split(text, " ");
    var line = "";
    var lines = [] as Array<String>;
    for (var i = 0; i < words.size(); i += 1) {
        var candidate = line.length() == 0 ? words[i] : line + " " + words[i];
        if (dc.getTextWidthInPixels(candidate, Graphics.FONT_SMALL) <= width) {
            line = candidate;
        } else {
            if (line.length() > 0) { lines.add(line); }
            line = words[i];
            while (dc.getTextWidthInPixels(line, Graphics.FONT_SMALL) > width) {
                var cut = line.length() - 1;
                while (cut > 1 && dc.getTextWidthInPixels(line.substring(0, cut) as String,
                    Graphics.FONT_SMALL) > width) { cut -= 1; }
                lines.add(line.substring(0, cut) as String);
                line = line.substring(cut, line.length()) as String;
            }
        }
    }
    if (line.length() > 0) { lines.add(line); }
    var height = dc.getFontHeight(Graphics.FONT_SMALL);
    for (var n = 0; n < lines.size() && n < maxLines; n += 1) {
        var value = lines[n];
        if (n == maxLines - 1 && lines.size() > maxLines) {
            while (value.length() > 0 &&
                dc.getTextWidthInPixels(value + "...", Graphics.FONT_SMALL) > width) {
                value = value.substring(0, value.length() - 1) as String;
            }
            value += "...";
        }
        dc.drawText(dc.getWidth() / 2, y + n * height, Graphics.FONT_SMALL,
            value, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class TimerView extends WatchUi.View {
    var detail as Boolean = false;
    function initialize() { View.initialize(); }

    function drawButtonHints(dc as Graphics.Dc, action as String or Null) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var font = Graphics.FONT_XTINY;
        if (action != null) {
            var y = height * 21 / 100;
            dc.drawText(width - 40, y, font, action,
                Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawLine(width - 33, y - 4, width - 29, y);
            dc.drawLine(width - 29, y, width - 33, y + 4);
        }
        var menuY = height / 2;
        dc.drawLine(7, menuY, 11, menuY - 4);
        dc.drawLine(7, menuY, 11, menuY + 4);
        for (var i = -1; i <= 1; i += 1) {
            dc.drawLine(16, menuY + i * 4, 27, menuY + i * 4);
        }
        dc.drawText(17, menuY + 9, font, "Hold", Graphics.TEXT_JUSTIFY_CENTER);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var height = dc.getHeight();
        var app = timerApp();
        var session = app.session;
        var store = app.getStore();
        if (store.errors.size() > 0) {
            drawButtonHints(dc, "Dismiss");
            drawLines(dc, store.errors[0], height * 29 / 100, 5);
            return;
        }
        if (session == null) {
            drawButtonHints(dc, "Recipes");
            drawLines(dc, "Sourdough Timer", height * 29 / 100, 2);
            drawLines(dc, "Choose a recipe", height * 62 / 100, 2);
            return;
        }
        if (session.state.equals("done")) {
            drawButtonHints(dc, "Recipes");
            drawLines(dc, session.recipe.name, height * 29 / 100, 2);
            drawLines(dc, "Recipe complete", height * 62 / 100, 2);
            return;
        }
        var action = "Done";
        var waiting = session.isWaiting();
        var timed = session.currentMinutes() > 0;
        var status = "NOW";
        if (session.state.equals("running")) { action = "Pause"; status = waiting ? "WAITING" : "RUNNING"; }
        if (session.state.equals("paused")) { action = "Resume"; status = "PAUSED"; }
        if (session.state.equals("ready") && timed) { action = "Start"; status = "READY"; }
        if (session.state.equals("due") && timed) { action = "Next"; status = "TIME UP"; }
        drawButtonHints(dc, action);
        var shown = session.actionIndex();
        var progress = session.progress();
        dc.drawText(dc.getWidth()/2, 24, Graphics.FONT_XTINY,
            "Step " + progress[0] + "/" + progress[1] + "  " + status,
            Graphics.TEXT_JUSTIFY_CENTER);
        var seconds = session.secondsLeft(Time.now().value());
        var finalFold = Recipes.isFinalFold(session.recipe, shown);
        var display = (timed && !session.state.equals("due")) ?
            (seconds / 3600).format("%02d") + ":" +
            ((seconds % 3600) / 60).format("%02d") + ":" + (seconds % 60).format("%02d") :
            (finalFold ? "FINAL" : (timed ? "00:00:00" : "NOW"));
        if (waiting) { display = "in " + display; }
        if (detail) {
            // Full-text view for long labels; the countdown stays visible.
            var currentLabel = session.recipe.labels[shown];
            if (finalFold) { currentLabel += " (final): into banneton if needed"; }
            drawLines(dc, currentLabel, height * 22 / 100, 4);
            if (session.state.equals("paused")) {
                var boxWidth = dc.getTextWidthInPixels(display, Graphics.FONT_SMALL);
                dc.fillRectangle((dc.getWidth() - boxWidth) / 2 - 6, height * 66 / 100 - 2,
                    boxWidth + 12, dc.getFontHeight(Graphics.FONT_SMALL) + 4);
                dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
            }
            dc.drawText(dc.getWidth()/2, height * 66 / 100, Graphics.FONT_SMALL, display,
                Graphics.TEXT_JUSTIFY_CENTER);
            return;
        }
        drawLines(dc, session.recipe.labels[shown], height * 28 / 100, 2);
        var timerY = height * (finalFold ? 46 : 51) / 100;
        if (session.state.equals("paused")) {
            var textWidth = dc.getTextWidthInPixels(display, Graphics.FONT_MEDIUM);
            var textHeight = dc.getFontHeight(Graphics.FONT_MEDIUM);
            dc.fillRectangle((dc.getWidth() - textWidth) / 2 - 6, timerY - 2,
                textWidth + 12, textHeight + 4);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        }
        dc.drawText(dc.getWidth()/2, timerY, Graphics.FONT_MEDIUM,
            display, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        if (finalFold) {
            dc.drawText(dc.getWidth()/2, timerY + dc.getFontHeight(Graphics.FONT_MEDIUM),
                Graphics.FONT_XTINY, "Into banneton if needed", Graphics.TEXT_JUSTIFY_CENTER);
        }
        drawLines(dc, "Next: " + nextText(session, shown + 1), height * 69 / 100, 2);
    }

    // The next action, with its wait folded in ("Fold 2 of 4 in 45 min").
    function nextText(session as Session, index as Number) as String {
        var recipe = session.recipe;
        if (index >= recipe.labels.size()) { return "Recipe complete"; }
        var target = session.isWaitFor(index) ? index + 1 : index;
        var text = recipe.labels[target] + (Recipes.isFinalFold(recipe, target) ? " (final)" : "");
        if (target != index) { text += " in " + formatMinutes(recipe.minutes[index]); }
        return text;
    }
}
class TimerInput extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean { return true; }
    function onSelect() as Boolean { return false; }
    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ENTER) { return select(); }
        return false;
    }
    function select() as Boolean {
        var app = timerApp();
        var store = app.getStore();
        var session = app.session;
        if (store.errors.size() > 0) {
            store.errors.remove(store.errors[0]);
        } else if (session == null || session.state.equals("done")) {
            showHome();
        } else {
            session.select(Time.now().value());
            session.save();
            app.lastAlert = 0;
            // Confirming the last action closes the recipe.
            if (session.state.equals("done")) { app.stop(); }
        }
        WatchUi.requestUpdate();
        return true;
    }
    function onMenu() as Boolean { showHome(); return true; }
    function onBack() as Boolean { return false; }
    function onNextPage() as Boolean { return toggleDetail(); }
    function onPreviousPage() as Boolean { return toggleDetail(); }
    function toggleDetail() as Boolean {
        var view = WatchUi.getCurrentView()[0];
        if (view instanceof TimerView) { view.detail = !view.detail; }
        WatchUi.requestUpdate();
        return true;
    }
}

class CommandDelegate extends WatchUi.Menu2InputDelegate {
    var callback as Method;
    function initialize(action as Method) { Menu2InputDelegate.initialize(); callback = action; }
    function onSelect(item as WatchUi.MenuItem) as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        callback.invoke(item.getId());
    }
}

function pushMenu(menu as WatchUi.Menu2, callback as Method) as Void {
    WatchUi.pushView(menu, new CommandDelegate(callback), WatchUi.SLIDE_UP);
}

function showHome() as Void {
    var menu = new WatchUi.Menu2({:title => "Recipes & timer"});
    var app = timerApp();
    var actions = new HomeActions();
    var session = app.session;
    if (session != null && !session.state.equals("done")) {
        menu.addItem(new WatchUi.MenuItem("Return to timer", null, -1, null));
    }
    menu.addItem(new WatchUi.MenuItem("Stop / clear timer", null, -3, null));
    var recipes = app.getStore().recipes;
    for (var i = 0; i < recipes.size(); i += 1) {
        if (recipes[i].labels.size() > 0) {
            menu.addItem(new WatchUi.MenuItem(recipes[i].name, "Start", i, null));
        }
    }
    menu.addItem(new WatchUi.MenuItem("Edit recipes", "New, edit, delete", -4, null));
    pushMenu(menu, actions.method(:select));
}

class HomeActions {
    var pending as Recipe or Null;
    function select(id as Number) as Void {
        var app = timerApp();
        var session = app.session;
        if (id == -1) { return; }
        if (id == -3) {
            WatchUi.pushView(new WatchUi.Confirmation("Stop current timer?"),
                new ConfirmAction(method(:stop)), WatchUi.SLIDE_UP);
            return;
        }
        if (id == -4) { new RecipeEditor().showSlots(); return; }
        pending = app.getStore().recipes[id].copy();
        if (session != null && !session.state.equals("done")) {
            WatchUi.pushView(new WatchUi.Confirmation("Replace current timer?"),
                new ConfirmAction(method(:start)), WatchUi.SLIDE_UP);
        } else { start(); }
    }
    function start() as Void {
        var recipe = pending;
        if (recipe != null) { timerApp().start(recipe); }
    }
    function stop() as Void { timerApp().stop(); }
}

class ConfirmAction extends WatchUi.ConfirmationDelegate {
    var callback as Method;
    function initialize(action as Method) { ConfirmationDelegate.initialize(); callback = action; }
    function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) { timerApp().defer(callback); }
        return true;
    }
}
