import Toybox.Application.Storage;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;

(:background)
class TimerBackground extends System.ServiceDelegate {
    function initialize() { ServiceDelegate.initialize(); }

    function onTemporalEvent() as Void {
        var data = Storage.getValue("session");
        if (data instanceof Dictionary) {
            var state = data["state"];
            var deadline = data["deadline"];
            if (state instanceof String && deadline instanceof Number &&
                (state.equals("running") || state.equals("due")) && deadline <= Time.now().value()) {
                Background.requestApplicationWake("Timer finished. Open Sourdough Timer to confirm the next step.");
            }
        }
        Background.deleteTemporalEvent();
        Background.exit(null);
    }
}
