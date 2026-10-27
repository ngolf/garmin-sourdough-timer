import Toybox.Application;
import Toybox.Application.Storage;
import Toybox.Attention;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.WatchUi;

(:background)
class SourdoughApp extends Application.AppBase {
    var session as Session or Null;
    var store as RecipeStore or Null;
    var pulse as Timer.Timer or Null;
    var lastAlert as Number = 0;
    var pendingAction as Method or Null;

    function initialize() { AppBase.initialize(); }

    (:typecheck(disableBackgroundCheck))
    function getInitialView() {
        Background.deleteTemporalEvent();
        var recipes = new RecipeStore();
        store = recipes;
        try {
            session = Session.restore();
        } catch (error instanceof RecipeError) {
            recipes.errors.add(error.getMessage());
        }
        var timer = new Timer.Timer();
        pulse = timer;
        timer.start(method(:tick), 1000, true);
        return [new TimerView(), new TimerInput()];
    }

    function getServiceDelegate() { return [new TimerBackground()]; }

    (:typecheck(disableBackgroundCheck))
    function onStop(state) as Void {
        var timer = pulse;
        if (timer != null) { timer.stop(); }
        var active = session;
        if (active == null) { return; }
        active.tick(Time.now().value());
        active.save();
        if (active.state.equals("running") || active.state.equals("due")) {
            var when = active.deadline;
            var last = Background.getLastTemporalEventTime();
            if (last != null && when < last.value() + 300) {
                when = last.value() + 300;
            }
            // Waking the app is best-effort: registration throws when it is too
            // soon after the previous wake, so fall back to the minimum delay.
            try {
                Background.registerForTemporalEvent(new Time.Moment(when));
            } catch (error) {
                try {
                    Background.registerForTemporalEvent(new Time.Duration(300));
                } catch (ignored) {
                }
            }
        }
    }

    (:typecheck(disableBackgroundCheck))
    function onSettingsChanged() as Void {
        var recipes = store;
        if (recipes != null) {
            recipes.importPhone();
            WatchUi.requestUpdate();
        }
    }

    (:typecheck(disableBackgroundCheck))
    function tick() as Void {
        var action = pendingAction;
        // Native pickers and confirmations close themselves after their callbacks.
        if (action != null && WatchUi.getCurrentView()[0] instanceof TimerView) {
            pendingAction = null;
            action.invoke();
        }
        var active = session;
        if (active != null) {
            var now = Time.now().value();
            if (active.tick(now)) { active.save(); }
            if (active.state.equals("due") && (lastAlert == 0 || now - lastAlert >= 30)) {
                lastAlert = now;
                alert();
            }
        }
        WatchUi.requestUpdate();
    }

    // Ring and vibrate together. The watch's own Sound & Vibe "Tones" setting
    // must be on for any app tone to be audible.
    (:typecheck(disableBackgroundCheck))
    function alert() as Void {
        if (Attention has :playTone) {
            Attention.playTone(Attention.TONE_ALARM);
        }
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(100, 700),
                new Attention.VibeProfile(0, 200), new Attention.VibeProfile(100, 700)]);
        }
    }

    (:typecheck(disableBackgroundCheck))
    function defer(action as Method) as Void {
        pendingAction = action;
    }

    (:typecheck(disableBackgroundCheck))
    function start(recipe as Recipe) as Void {
        var active = new Session(recipe);
        session = active;
        lastAlert = 0;
        active.save();
        WatchUi.requestUpdate();
    }

    (:typecheck(disableBackgroundCheck))
    function stop() as Void {
        session = null;
        lastAlert = 0;
        Storage.deleteValue("session");
        Background.deleteTemporalEvent();
        WatchUi.requestUpdate();
    }

    (:typecheck(disableBackgroundCheck))
    function getStore() as RecipeStore {
        var recipes = store;
        if (recipes == null) { throw new RecipeError("Recipe store is not initialized."); }
        return recipes;
    }
}

function timerApp() as SourdoughApp {
    return Application.getApp() as SourdoughApp;
}
