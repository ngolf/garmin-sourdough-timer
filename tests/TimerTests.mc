import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;
import Toybox.Test;

(:test)
function initialMixIsPinnedAndEditable(logger as Test.Logger) as Boolean {
    var recipe = RecipeTemplates.append(Recipes.parse("Builder", ""), RecipeTemplates.INITIAL_MIX,
        [true, true, false, false], 0, 1);
    recipe = RecipeTemplates.append(recipe, RecipeTemplates.FOLD, [], 45, 1);
    Test.assert(RecipeTemplates.hasInitialMix(recipe));
    Test.assert(RecipeTemplates.isLocked(recipe, 0));
    Test.assert(!RecipeTemplates.isLocked(recipe, 1));
    var selected = RecipeTemplates.mixSelection(recipe);
    Test.assert(selected[0] && selected[1] && !selected[2] && !selected[3]);
    var changed = RecipeTemplates.setMix(recipe, [true, true, true, true]);
    Test.assertEqual(changed.labels[0], "Initial mix: Water, Flour, Leaven, Salt");
    Test.assertEqual(changed.labels.size(), recipe.labels.size());
    Test.assertEqual(recipe.labels[0], "Initial mix: Water, Flour");
    Test.assert(!RecipeTemplates.isLocked(Recipes.parse("Preset", "Mix|0;Rest|5"), 0));
    return true;
}

(:test)
function ingredientTemplatesAllowMultipleSelections(logger as Test.Logger) as Boolean {
    var empty = Recipes.parse("Builder", "");
    var mix = RecipeTemplates.append(empty, RecipeTemplates.INITIAL_MIX, [true, true, true, true], 30, 1);
    Test.assertEqual(mix.encode(), "Initial mix: Water, Flour, Leaven, Salt|0");
    Test.assertEqual(empty.labels.size(), 0);
    var added = RecipeTemplates.append(mix, RecipeTemplates.ADD_INGREDIENTS, [true, false, false, true], 10, 1);
    Test.assertEqual(added.encode(),
        "Initial mix: Water, Flour, Leaven, Salt|0;Wait|10;Add Water, Salt|0");
    Test.assertEqual(mix.labels.size(), 1);
    Test.assertEqual(Recipes.parse(added.name, added.encode()).encode(), added.encode());
    return true;
}

(:test)
function foldRepeatsIncludeEveryWait(logger as Test.Logger) as Boolean {
    var recipe = RecipeTemplates.append(Recipes.parse("Builder", "Mix|0"),
        RecipeTemplates.FOLD, [], 45, 4);
    Test.assertEqual(recipe.labels.size(), 9);
    for (var i = 0; i < 4; i += 1) {
        Test.assertEqual(recipe.minutes[1 + i * 2], 45);
        Test.assertEqual(recipe.minutes[2 + i * 2], 0);
        Test.assertEqual(recipe.labels[2 + i * 2], "Fold " + (i + 1) + " of 4");
    }
    var first = RecipeTemplates.append(Recipes.parse("Builder", ""), RecipeTemplates.FOLD, [], 45, 1);
    Test.assertEqual(first.encode(), "Wait before fold 1 of 1|45;Fold|0");
    return true;
}

(:test)
function optionalActionsAndZeroWaits(logger as Test.Logger) as Boolean {
    var recipe = RecipeTemplates.append(Recipes.parse("Builder", ""), RecipeTemplates.BAKE, [], 60, 1);
    Test.assertEqual(recipe.encode(), "Bake|0");
    recipe = RecipeTemplates.append(recipe, RecipeTemplates.COLD_PROOF, [], 0, 1);
    Test.assertEqual(recipe.encode(), "Bake|0;Cold proof|0");
    recipe = RecipeTemplates.append(recipe, RecipeTemplates.FOLD, [], 0, 2);
    Test.assertEqual(recipe.encode(), "Bake|0;Cold proof|0;Fold 1 of 2|0;Fold 2 of 2|0");
    recipe = RecipeTemplates.append(recipe, RecipeTemplates.WARM_PROOF, [], 30, 1);
    Test.assertEqual(recipe.labels[recipe.labels.size() - 1], "Warm proof");
    Test.assertEqual(recipe.minutes[recipe.minutes.size() - 2], 30);
    Test.assertEqual(recipe.minutes[recipe.minutes.size() - 1], 0);
    Test.assertEqual(Recipes.parse("Legacy", "Refrigerate|0").encode(), "Cold proof|0");
    return true;
}

(:test)
function builderLimitsAreAtomic(logger as Test.Logger) as Boolean {
    var original = Recipes.parse("Builder", "Mix|0");
    var rejected = false;
    try { RecipeTemplates.append(original, RecipeTemplates.FOLD, [], 45, 16); }
    catch (error instanceof RecipeError) { rejected = true; }
    Test.assert(rejected);
    Test.assertEqual(original.encode(), "Mix|0");
    var exact = RecipeTemplates.append(Recipes.parse("Builder", ""), RecipeTemplates.FOLD, [], 1440, 16);
    Test.assertEqual(exact.labels.size(), 32);
    Test.assertEqual(Recipes.parse(exact.name, exact.encode()).encode(), exact.encode());
    return true;
}

(:test)
function builderRejectsInvalidSelections(logger as Test.Logger) as Boolean {
    var recipe = Recipes.parse("Builder", "");
    var failures = 0;
    try { RecipeTemplates.append(recipe, RecipeTemplates.INITIAL_MIX, [false, false, false, false], 0, 1); }
    catch (error instanceof RecipeError) { failures += 1; }
    try { RecipeTemplates.append(recipe, RecipeTemplates.ADD_INGREDIENTS, [], 0, 1); }
    catch (error instanceof RecipeError) { failures += 1; }
    try { RecipeTemplates.append(recipe, RecipeTemplates.FOLD, [], 1441, 4); }
    catch (error instanceof RecipeError) { failures += 1; }
    try { RecipeTemplates.append(recipe, RecipeTemplates.FOLD, [], -1, 4); }
    catch (error instanceof RecipeError) { failures += 1; }
    try { RecipeTemplates.append(recipe, RecipeTemplates.FOLD, [], 45, 0); }
    catch (error instanceof RecipeError) { failures += 1; }
    try { RecipeTemplates.append(recipe, RecipeTemplates.BAKE, [], 0, 2); }
    catch (error instanceof RecipeError) { failures += 1; }
    try {
        RecipeTemplates.append(Recipes.parse("Builder", "Bake|0"),
            RecipeTemplates.INITIAL_MIX, [true, false, false, false], 0, 1);
    } catch (error instanceof RecipeError) { failures += 1; }
    Test.assertEqual(failures, 7);
    Test.assertEqual(recipe.labels.size(), 0);
    return true;
}

(:test)
function presetHasFourRounds(logger as Test.Logger) as Boolean {
    var recipe = Recipes.presets()[0];
    var rests = 0;
    var total = 0;
    for (var i = 0; i < recipe.minutes.size(); i += 1) {
        if (recipe.minutes[i] == 45) { rests += 1; }
        total += recipe.minutes[i];
    }
    Test.assertEqual(rests, 4);
    Test.assertEqual(total, 240);
    Test.assertEqual(recipe.labels.size(), 13);
    Test.assert(RecipeTemplates.isLocked(recipe, 0));
    Test.assertEqual(recipe.labels[12], "Cold proof");
    Test.assert(Recipes.isFinalFold(recipe, 10));
    for (var i = 0; i < 10; i += 1) { Test.assert(!Recipes.isFinalFold(recipe, i)); }
    Test.assert(!Recipes.isFinalFold(recipe, 9));
    Test.assert(Recipes.isFinalFold(Recipes.presets()[1], 4));
    Test.assert(Recipes.isFinalFold(Recipes.parse("One", "Fold|0;Bake|0"), 0));
    Test.assert(!Recipes.isFinalFold(Recipes.parse("Add", "Add salt, fold|0"), 0));
    return true;
}

(:test)
function recipeRoundTrip(logger as Test.Logger) as Boolean {
    var recipe = Recipes.presets()[0];
    var copy = Recipes.parse(recipe.name, recipe.encode());
    Test.assertEqual(copy.encode(), recipe.encode());
    Test.assertEqual(Recipes.parse("Empty slot", "").labels.size(), 0);
    Test.assertEqual(Recipes.parseMinutes("1440"), 1440);
    Test.assertEqual(Recipes.parseMinutes("0"), 0);
    return true;
}

(:test)
function invalidRecipesRejected(logger as Test.Logger) as Boolean {
    var bad = ["No duration", "Label|-1", "Label|1.5", "Label|1441", "Label|",
        "Label|5minutes", "Label|1;", "|1", " |1", "Label|1|2", "Label| 1",
        "Label|99999", "Label\nline|1", "Label|+1", "Label|1e2"];
    for (var i = 0; i < bad.size(); i += 1) {
        var rejected = false;
        try { Recipes.parse("Test", bad[i]); }
        catch (error instanceof RecipeError) { rejected = true; }
        Test.assertMessage(rejected, "Invalid input accepted: " + bad[i]);
    }
    Test.assert(!Recipes.validLabel("                         ", 24));
    Test.assert(!Recipes.validLabel("Name;bad", 24));
    Test.assert(!Recipes.validLabel("1234567890123456789012345", 24));
    var tooMany = "Step|1";
    for (var n = 1; n < 33; n += 1) { tooMany += ";Step|1"; }
    var limited = false;
    try { Recipes.parse("Test", tooMany); }
    catch (error instanceof RecipeError) { limited = true; }
    Test.assert(limited);
    return true;
}

(:test)
function mixRequiresButtonThenExactDeadline(logger as Test.Logger) as Boolean {
    var session = new Session(Recipes.presets()[0]);
    Test.assertEqual(session.state, "ready");
    session.tick(100000);
    Test.assertEqual(session.index, 0);
    session.select(100000);
    Test.assertEqual(session.index, 1);
    Test.assertEqual(session.deadline, 101800);
    Test.assertEqual(session.secondsLeft(101799), 1);
    Test.assert(!session.tick(101799));
    Test.assert(session.tick(101800));
    Test.assertEqual(session.state, "due");
    Test.assertEqual(session.index, 2);
    Test.assert(!session.tick(200000));
    Test.assertEqual(session.index, 2);
    return true;
}

(:test)
function waitAndActionNeedOneConfirmation(logger as Test.Logger) as Boolean {
    var session = new Session(Recipes.presets()[0]);
    Test.assertEqual(session.progress()[0], 1);
    Test.assertEqual(session.progress()[1], 7);
    session.select(100);
    Test.assert(session.isWaiting());
    Test.assertEqual(session.recipe.labels[session.actionIndex()], "Add Salt");
    Test.assertEqual(session.progress()[0], 2);
    session.tick(1900);
    Test.assertEqual(session.index, 2);
    Test.assertEqual(session.state, "due");
    Test.assert(!session.isWaiting());
    session.select(2500);
    Test.assertEqual(session.index, 3);
    Test.assertEqual(session.state, "running");
    Test.assertEqual(session.deadline, 5200);
    Test.assertEqual(session.recipe.labels[session.actionIndex()], "Fold 1 of 4");
    session.tick(5200);
    Test.assertEqual(session.index, 4);
    Test.assertEqual(session.state, "due");
    session.select(5300);
    Test.assertEqual(session.index, 5);
    Test.assertEqual(session.state, "running");
    return true;
}

(:test)
function runningCannotBeSkipped(logger as Test.Logger) as Boolean {
    var session = new Session(Recipes.parse("Test", "Wait|1;Action|0"));
    session.select(100);
    session.select(110);
    Test.assertEqual(session.index, 0);
    Test.assertEqual(session.deadline, 160);
    Test.assertEqual(session.state, "paused");
    Test.assertEqual(session.remaining, 50);
    session.select(200);
    Test.assertEqual(session.state, "running");
    Test.assertEqual(session.index, 0);
    Test.assertEqual(session.deadline, 250);
    return true;
}

(:test)
function pauseResumePreservesRemainingTime(logger as Test.Logger) as Boolean {
    var session = new Session(Recipes.parse("Test", "Wait|1;Done|0"));
    session.select(100);
    session.select(120);
    Test.assertEqual(session.state, "paused");
    Test.assertEqual(session.secondsLeft(900), 40);
    Test.assert(!session.tick(900));
    session.select(1000);
    Test.assertEqual(session.deadline, 1040);
    Test.assert(!session.tick(1039));
    Test.assert(session.tick(1040));
    session.pause(1041);
    Test.assertEqual(session.state, "due");
    return true;
}

(:test)
function adjacentTimersStartOnlyOnConfirmation(logger as Test.Logger) as Boolean {
    var session = new Session(Recipes.parse("Test", "First|1;Second|2"));
    session.select(100);
    session.tick(160);
    session.tick(1000);
    Test.assertEqual(session.index, 0);
    session.select(2000);
    Test.assertEqual(session.index, 1);
    Test.assertEqual(session.deadline, 2120);
    return true;
}

(:test)
function finalStepMustBeConfirmed(logger as Test.Logger) as Boolean {
    var session = new Session(Recipes.parse("Test", "Cold fermentation|0"));
    session.tick(99999);
    Test.assertEqual(session.state, "ready");
    session.select(100000);
    Test.assertEqual(session.state, "done");
    session.select(100001);
    Test.assertEqual(session.index, 1);
    return true;
}

(:test)
function sessionSnapshotIndependentOfRecipeEdits(logger as Test.Logger) as Boolean {
    var recipe = Recipes.parse("Test", "Wait|1;Fold|0");
    var session = new Session(recipe);
    recipe.labels[0] = "Changed";
    recipe.minutes[0] = 20;
    Test.assertEqual(session.recipe.labels[0], "Wait");
    Test.assertEqual(session.recipe.minutes[0], 1);
    return true;
}

(:test)
function sessionStorageRoundTrip(logger as Test.Logger) as Boolean {
    var previous = Storage.getValue("session");
    try {
        var session = new Session(Recipes.parse("Test", "Wait|1;Fold|0"));
        session.select(100);
        session.save();
        var restored = Session.restore();
        Test.assert(restored != null);
        if (restored != null) {
            Test.assertEqual(restored.deadline, 160);
            restored.tick(900);
            Test.assertEqual(restored.state, "due");
            Test.assertEqual(restored.index, 1);
        }
        session.pause(120);
        session.save();
        restored = Session.restore();
        if (restored != null) {
            Test.assertEqual(restored.state, "paused");
            Test.assertEqual(restored.remaining, 40);
        } else { Test.assert(false); }
    } finally {
        if (previous == null) { Storage.deleteValue("session"); }
        else { Storage.setValue("session", previous); }
    }
    return true;
}

(:test)
function corruptSessionIsReported(logger as Test.Logger) as Boolean {
    var previous = Storage.getValue("session");
    try {
        Storage.setValue("session", {"version" => 99});
        var rejected = false;
        try { Session.restore(); }
        catch (error instanceof RecipeError) { rejected = true; }
        Test.assert(rejected);
    } finally {
        if (previous == null) { Storage.deleteValue("session"); }
        else { Storage.setValue("session", previous); }
    }
    return true;
}

function storageKeys() as Array<String> {
    var keys = ["recipeCount", "phone0", "phone1", "phone2", "custom0", "custom1", "custom2"];
    for (var i = 0; i < 25; i += 1) { keys.add("recipe" + i); }
    return keys;
}

// Runs `check` with empty recipe storage and blank phone settings, then restores both.
function withCleanStore(check as Method) as Boolean {
    var keys = storageKeys();
    var saved = {} as Dictionary<String, Storage.ValueType>;
    var properties = {} as Dictionary<String, String>;
    for (var i = 0; i < keys.size(); i += 1) { saved[keys[i]] = Storage.getValue(keys[i]); }
    for (var n = 1; n <= 3; n += 1) {
        var prefix = "custom" + n;
        var name = Properties.getValue(prefix + "Name");
        var steps = Properties.getValue(prefix + "Steps");
        if (!(name instanceof String) || !(steps instanceof String)) { return false; }
        properties[prefix + "Name"] = name;
        properties[prefix + "Steps"] = steps;
    }
    try {
        for (var k = 0; k < keys.size(); k += 1) { Storage.deleteValue(keys[k]); }
        for (var slot = 1; slot <= 3; slot += 1) {
            Properties.setValue("custom" + slot + "Name", "Custom " + slot);
            Properties.setValue("custom" + slot + "Steps", "");
        }
        check.invoke();
    } finally {
        for (var j = 0; j < keys.size(); j += 1) {
            var old = saved[keys[j]];
            if (old == null) { Storage.deleteValue(keys[j]); }
            else { Storage.setValue(keys[j], old); }
        }
        var names = properties.keys();
        for (var p = 0; p < names.size(); p += 1) {
            Properties.setValue(names[p], properties[names[p]] as String);
        }
    }
    return true;
}

class StoreChecks {
    function initialize() {}

    function listIsSeededEditableAndDeletable() as Void {
        Storage.setValue("custom0", {"name" => "Legacy", "steps" => "Mix|0"});
        var store = new RecipeStore();
        Test.assertEqual(store.recipes.size(), 2);
        Test.assertEqual(store.recipes[0].name, "Sourdough");
        Test.assert(Storage.getValue("custom0") == null);
        var edited = store.recipes[0].copy();
        edited.name = "My sourdough";
        store.put(0, edited);
        var added = store.put(-1, Recipes.parse("Third", "Initial mix: Water|0;Bake|0"));
        Test.assertEqual(added, 2);
        store.remove(1);
        var reloaded = new RecipeStore();
        Test.assertEqual(reloaded.recipes.size(), 2);
        Test.assertEqual(reloaded.recipes[0].name, "My sourdough");
        Test.assertEqual(reloaded.recipes[1].name, "Third");
        Test.assert(Storage.getValue("recipe2") == null);
        reloaded.remove(0);
        reloaded.remove(0);
        Test.assertEqual(new RecipeStore().recipes.size(), 0);
        for (var i = 0; i < RecipeStore.MAX_RECIPES; i += 1) {
            reloaded.put(-1, Recipes.parse("R" + i, "Bake|0"));
        }
        var rejected = false;
        try { reloaded.put(-1, Recipes.parse("Too many", "Bake|0")); }
        catch (error instanceof RecipeError) { rejected = true; }
        Test.assert(rejected);
    }

    function phoneImportsAddThenReplaceOnlyWhenChanged() as Void {
        var store = new RecipeStore();
        Test.assertEqual(store.recipes.size(), 2);
        Properties.setValue("custom2Name", "Phone recipe");
        Properties.setValue("custom2Steps", "Wait|1;Fold|0");
        store.importPhone();
        Test.assertEqual(store.recipes.size(), 3);
        Test.assertEqual(store.recipes[2].name, "Phone recipe");
        var edit = store.recipes[2].copy();
        edit.name = "Watch edit";
        store.put(2, edit);
        store.importPhone();
        Test.assertEqual(store.recipes[2].name, "Watch edit");
        Properties.setValue("custom2Steps", "Invalid duration|nope");
        store.importPhone();
        Test.assertEqual(store.errors.size(), 1);
        Test.assertEqual(store.recipes[2].encode(), "Wait|1;Fold|0");
        Properties.setValue("custom2Steps", "New wait|2");
        store.importPhone();
        Test.assertEqual(store.recipes.size(), 3);
        Test.assertEqual(store.recipes[2].encode(), "New wait|2");
        Properties.setValue("custom2Steps", "");
        store.importPhone();
        Test.assertEqual(store.recipes.size(), 3);
        Test.assertEqual(new RecipeStore().recipes[2].name, "Phone recipe");
    }
}

(:test)
function recipeListIsEditableAndDeletable(logger as Test.Logger) as Boolean {
    return withCleanStore(new StoreChecks().method(:listIsSeededEditableAndDeletable));
}

(:test)
function phoneImportsDoNotOverwriteWatchEditsUnlessChanged(logger as Test.Logger) as Boolean {
    return withCleanStore(new StoreChecks().method(:phoneImportsAddThenReplaceOnlyWhenChanged));
}

(:test)
function foldGroupsEditAsOneStep(logger as Test.Logger) as Boolean {
    var recipe = Recipes.presets()[0];
    var all = RecipeTemplates.blocks(recipe);
    // Initial mix, Wait, Add Salt, Fold x4, Wait, Cold proof
    Test.assertEqual(all.size(), 6);
    Test.assertEqual(all[3][0], 3);
    Test.assertEqual(all[3][1], 8);
    Test.assertEqual(all[3][2], 4);
    Test.assertEqual(all[3][3], 45);
    Test.assertEqual(all[1][2], 0);
    var changed = RecipeTemplates.replaceSteps(recipe, 3, 8, RecipeTemplates.foldSteps(2, 30));
    Test.assertEqual(changed.labels.size(), 9);
    Test.assertEqual(changed.labels[3], "Wait before fold 1 of 2");
    Test.assertEqual(changed.minutes[5], 30);
    Test.assertEqual(changed.labels[6], "Fold 2 of 2");
    Test.assertEqual(changed.labels[8], "Cold proof");
    var noWait = RecipeTemplates.replaceSteps(recipe, 3, 8, RecipeTemplates.foldSteps(3, 0));
    var block = RecipeTemplates.blocks(noWait)[3];
    Test.assertEqual(block[1], 3);
    Test.assertEqual(block[2], 3);
    Test.assertEqual(block[3], 0);
    var single = RecipeTemplates.blocks(Recipes.parse("One", "Bake|0;Fold|0"));
    Test.assertEqual(single[1][2], 1);
    var moved = RecipeTemplates.moveBlock(recipe, 3, -1);
    Test.assertEqual(moved.labels[2], "Wait before fold 1 of 4");
    Test.assertEqual(moved.labels[10], "Add Salt");
    Test.assertEqual(RecipeTemplates.moveBlock(recipe, 1, -1).encode(), recipe.encode());
    var tooMany = false;
    try { RecipeTemplates.replaceSteps(recipe, 3, 8, RecipeTemplates.foldSteps(16, 45)); }
    catch (error instanceof RecipeError) { tooMany = true; }
    Test.assert(tooMany);
    return true;
}

(:test)
function heldMinutesSnapToFive(logger as Test.Logger) as Boolean {
    var view = new DurationView("Wait", 62);
    view.fastAdjust(1);
    Test.assertEqual(view.hours, 2);
    view.focus = 1;
    view.fastAdjust(1);
    Test.assertEqual(view.mins, 5);
    view.fastAdjust(1);
    Test.assertEqual(view.mins, 10);
    view.mins = 57;
    view.fastAdjust(1);
    Test.assertEqual(view.mins, 0);
    view.mins = 13;
    view.fastAdjust(-1);
    Test.assertEqual(view.mins, 10);
    view.fastAdjust(-1);
    Test.assertEqual(view.mins, 5);
    view.mins = 0;
    view.fastAdjust(-1);
    Test.assertEqual(view.mins, 55);
    return true;
}
