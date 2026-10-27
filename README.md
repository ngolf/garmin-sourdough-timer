# Sourdough Timer

A Garmin Connect IQ watch app originally developed for the **fenix 8 Solar
47 mm and 51 mm**, with additional build-checked round-screen watches listed in
the manifest. It runs recipes made of timed waits and manually confirmed actions.

## Timer behavior

- Select any saved recipe. There are no fixed slots or locked presets.
- The first step waits for **START**. In the Sourdough recipe this is the
  **Initial mix**: press START after mixing to begin the first wait.
- A wait is part of the action that follows it, not a separate step. While it
  counts down, the screen shows that action (e.g. "Fold 1 of 4", "in 00:44:59",
  status WAITING). When it expires the watch beeps and vibrates and the action
  becomes due (**NOW**). A single START press ("Done") completes the action and
  starts the next action's wait. Step numbers count actions only.
- Expired countdowns request Garmin's predefined alarm tone and vibration,
  repeated every 30 seconds until confirmed. Manual actions and button presses
  do not trigger this alarm. Audible playback still depends on watch sound settings.
- A timed step that is not followed by a manual action (e.g. a trailing wait or
  consecutive timers) stays on that step when it expires until START is pressed.
- Current action, countdown, and next action (with its wait, e.g. "Next: Fold 2
  of 4 in 45 min") are shown together. UP/DOWN toggles a
  text-focused view showing the full step label; the countdown stays visible.
- The **last fold** of a recipe shows **FINAL** with the hint "Into banneton if
  needed", and appears as "Fold … (final)" when it is the next step.
- The upper-right label points to START/STOP and shows its current action (Done,
  Next, Start, Pause, Resume, Recipes, or Dismiss). Press it to pause a running
  timer or resume a paused timer, like starting/pausing a Garmin activity.
  Paused countdowns use black text in a white rectangle.
- Screen taps on the timer view do nothing; use the physical START/STOP button
  to start, pause, resume, or confirm steps. Menus and editors still support touch.
- The left-edge menu icon with "Hold" points to **UP/MENU**. Hold it to choose
  recipes, edit recipes, or stop. Opening the menu does not pause the
  timer. START/STOP cannot skip a running timer.
- Replacing or stopping a recipe requires confirmation.
- The active recipe and deadline are saved. Closing and reopening the app
  preserves elapsed time; edits to saved recipes do not change an active run.

On first launch the list is seeded with two ordinary recipes, built with the
same steps as the builder. They can be edited, duplicated, or deleted like any
other recipe. **Sourdough** contains:

1. Initial mix: Water, Flour, Leaven (manual confirmation)
2. Wait (30 minutes)
3. Add Salt (manual)
4. Four rounds of 45-minute wait, then fold (each fold is manual); the fourth
   fold is marked **final**: into the banneton if needed
5. Wait (30 minutes)
6. Cold proof (manual; completing this ends the recipe)

Total timed waiting is four hours, excluding time spent on manual actions. There
is also a short **Quick fold practice**
recipe: initial mix, then two folds with one-minute waits.

## Editing recipes on the watch

Hold UP and choose **Edit recipes**. The list shows **New recipe** followed by
every saved recipe. **New recipe** (and any blank recipe) goes straight to the
**Mix ingredients** screen; Cancel there returns to the list without creating
anything. Selecting a recipe shows its steps plus **Add action**, **Rename
recipe**, **Duplicate recipe**, **Delete recipe** (with confirmation), and
**Back to recipes**. Choose **Add action** to build without typing:

- **Initial mix:** always the first step. Switch on any of Water, Flour,
  Leaven, and Salt (on/off toggles), then Continue. The step is labeled e.g.
  `Initial mix: Water, Flour`. It cannot be deleted or moved, and no step can
  be moved before it; select it in the step list and choose
  **Change ingredients** to edit it.
- **Add ingredients:** the same multiple-selection list, for later additions.
  Both ingredient actions require at least one selection.
- **Fold:** choose the number of folds, then the wait before **each** fold.
  Four repeats at 45 minutes creates `Wait, Fold, Wait, Fold, Wait, Fold,
  Wait, Fold`, not four folds followed by a single wait.
- **Cold proof**, **Warm proof**, or **Bake:** add the action directly.
  Existing steps named exactly "Refrigerate" are renamed to "Cold proof" when loaded.
  In code, templates use named `RecipeTemplates.Action` enum values rather than
  positions in the action menu; reordering the menu does not change action behavior.

No action is mandatory. Except for the first action, the builder asks for a
wait **before** the action; choose 0 to omit it. Fold repetitions always include
their chosen wait, even when Fold is the first action.

Waits are assumed between actions: the duration picker opens automatically
before adding every subsequent action. The **HH:MM** screen mimics Garmin's
Timer app: the selected field is highlighted, UP/DOWN (or swipes) change it,
START goes from hours to minutes and then confirms, and BACK returns to hours
and then cancels. Tapping a field selects it. The range is
00:00 to 24:00; 00:00 explicitly omits the wait. Existing step durations use
the same screen. The number of folds (1-16) uses a matching single-number screen:
UP/DOWN change it, START confirms, BACK cancels.
There is no number typing. Cancel leaves the recipe
unchanged. A completed action (including all its waits/repeats) saves immediately;
an addition exceeding the 32-step limit is rejected without partially saving.
Waits count towards this limit.

A group of repeated folds (with their waits) is shown as **one step**, e.g.
`Fold x4 - 45 min wait before each`. Selecting it lets you change **Repeats**
or **Wait before each**; the change applies to every fold and wait in the group.
Moving or deleting the group moves or deletes all of its folds and waits.

Select any other step to edit its label or duration, move it earlier/later, or
delete it. Waits added before ingredients, bake, or proofing remain separate
steps. **0 minutes means a manual action**, not a timer. Renaming and
step-label editing use an on-watch letter picker (the native text picker crashes
on fenix 8): UP/DOWN choose a character, START adds it, BACK deletes the last
character (or cancels when empty), holding UP clears, and choosing **OK** saves.
Letters are capitalized automatically at the start of each word. Active timers keep their original
recipe.

Limits: 20 recipes, 32 steps per recipe (each fold and wait counts), 24-character recipe names,
40-character step labels, and whole-minute durations from 0 to 1440.
Labels cannot contain `|`, `;`, tabs, or newlines.

## Custom recipes on a phone

Phone editing uses the app's settings in Garmin's **Connect IQ mobile app**,
not a separate companion app. For a store/beta-installed build, open the watch's
installed apps, select Sourdough Timer, then Settings.

The settings have three phone recipe slots, each with a name and a steps text
field. For example:

```text
Initial mix: Water, Flour, Leaven|0;Wait|30;Add Salt|0;Wait before fold 1 of 2|45;Fold 1 of 2|0;Wait before fold 2 of 2|45;Fold 2 of 2|0;Wait|30;Cold proof|0
```

Separate steps with `;` and separate a label from its minutes with `|`.
Enter `0` for an action.

The first time a phone slot is filled, it **adds** a recipe to the watch list.
Later changes to that slot replace that same recipe (if it was deleted on the
watch, a new one is added). Clearing the steps field changes nothing on the
watch. Invalid settings display an error on the watch and keep the watch
recipes. Unchanged phone settings do not overwrite watch edits. There is no watch-to-phone recipe
sync: the settings form may show an older phone-authored recipe. Avoid editing
the same recipe simultaneously in both places; the last save wins. An active run
always keeps its original recipe.

**Sideloading limitation:** copying a `.prg` onto a watch generally does not make
its settings available in the phone app. Use on-watch editing for a sideloaded
build; phone-side settings require distribution through Garmin's store/beta
installation flow. Settings can also be exercised in the development simulator.

## Alerts and Garmin limitations

While the app is open, expiry uses Garmin's alarm tone and a double vibration,
repeated every 30 seconds until acknowledged. Device sound/vibration settings
can affect alerts; verify them on the actual watch.

When the app closes with a running timer, it schedules a Connect IQ temporal
background event. At expiry Garmin displays a prompt to reopen the app.
This is **not the same as a continuously running foreground alarm** and does not
automatically advance the recipe. Background prompts are one-shot; reopen the
app to acknowledge the step. Native watch settings control prompt presentation.

Garmin restricts temporal background events to at least five minutes after the
previous event. If necessary the app delays a background prompt to that earliest
allowed time; the stored countdown deadline itself does not change. Short timers
are therefore best used with the app open. The app is not an OS-level alarm:
power-off, reboot, firmware policies, Do Not Disturb, and other app/activity
restrictions can prevent or delay notification. Reopening still reconstructs
the countdown from its saved wall-clock deadline. Changing the watch clock
affects that deadline.
