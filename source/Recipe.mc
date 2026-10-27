import Toybox.Lang;

class RecipeError extends Lang.Exception {
    var message as String;
    function initialize(message as String) {
        Exception.initialize();
        self.message = message;
    }
    function getMessage() as String { return message; }
}

class Recipe {
    var name as String;
    var labels as Array<String>;
    var minutes as Array<Number>;

    function initialize(title as String, titles as Array<String>, durations as Array<Number>) {
        name = title;
        labels = titles;
        minutes = durations;
    }

    function copy() as Recipe {
        return new Recipe(name, labels.slice(0, labels.size()), minutes.slice(0, minutes.size()));
    }

    function encode() as String {
        var result = "";
        for (var i = 0; i < labels.size(); i += 1) {
            if (i > 0) { result += ";"; }
            result += labels[i] + "|" + minutes[i].toString();
        }
        return result;
    }
}

module RecipeTemplates {
    enum Action {
        INITIAL_MIX,
        ADD_INGREDIENTS,
        FOLD,
        BAKE,
        COLD_PROOF,
        WARM_PROOF
    }

    function actions() as Array<Action> {
        return [INITIAL_MIX, ADD_INGREDIENTS, FOLD, BAKE, COLD_PROOF, WARM_PROOF];
    }

    function actionLabel(action as Action) as String {
        switch (action) {
            case INITIAL_MIX: return "Initial mix";
            case ADD_INGREDIENTS: return "Add ingredients";
            case FOLD: return "Fold";
            case BAKE: return "Bake";
            case COLD_PROOF: return "Cold proof";
            case WARM_PROOF: return "Warm proof";
        }
        throw new RecipeError("Invalid action.");
    }

    function ingredients() as Array<String> {
        return ["Water", "Flour", "Leaven", "Salt"];
    }

    function append(recipe as Recipe, action as Action, selected as Array<Boolean>,
        wait as Number, repeats as Number) as Recipe {
        if (wait < 0 || wait > 1440 ||
            repeats < 1 || repeats > 16 || (action != FOLD && repeats != 1)) {
            throw new RecipeError("Invalid action, wait, or repeat count.");
        }
        var label = actionLabel(action);
        if (action == INITIAL_MIX && recipe.labels.size() > 0) {
            throw new RecipeError("Initial mix must be the first action.");
        }
        if (action == INITIAL_MIX || action == ADD_INGREDIENTS) {
            var list = ingredientList(selected);
            label = (action == INITIAL_MIX ? "Initial mix: " : "Add ") + list;
        }
        var result = recipe.copy();
        if (action == FOLD) {
            var folds = foldSteps(repeats, wait);
            result.labels.addAll(folds.labels);
            result.minutes.addAll(folds.minutes);
        } else {
            if (wait > 0 && result.labels.size() > 0) {
                result.labels.add("Wait");
                result.minutes.add(wait);
            }
            result.labels.add(label);
            result.minutes.add(0);
        }
        if (result.labels.size() > 32) {
            throw new RecipeError("Maximum 32 steps including waits. Use fewer repeats or no wait.");
        }
        return result;
    }

    // Fold repetitions always include their wait, even at the start of a recipe.
    function foldSteps(repeats as Number, wait as Number) as Recipe {
        if (repeats < 1 || repeats > 16 || wait < 0 || wait > 1440) {
            throw new RecipeError("Invalid wait or repeat count.");
        }
        var result = new Recipe("", [] as Array<String>, [] as Array<Number>);
        for (var n = 0; n < repeats; n += 1) {
            if (wait > 0) {
                result.labels.add("Wait before fold " + (n + 1) + " of " + repeats);
                result.minutes.add(wait);
            }
            result.labels.add(repeats > 1 ? "Fold " + (n + 1) + " of " + repeats : "Fold");
            result.minutes.add(0);
        }
        return result;
    }

    // Groups steps into editor blocks: [start, length, repeats, wait].
    // repeats == 0 is a single ordinary step; repeats > 0 is a fold group.
    function blocks(recipe as Recipe) as Array<Array<Number> > {
        var result = [] as Array<Array<Number> >;
        var i = 0;
        while (i < recipe.labels.size()) {
            var block = foldBlockAt(recipe, i);
            if (block == null) { block = [i, 1, 0, 0]; }
            result.add(block);
            i += block[1];
        }
        return result;
    }

    function foldBlockAt(recipe as Recipe, start as Number) as Array<Number> or Null {
        var wait = recipe.labels[start].find("Wait before fold 1 of ") == 0 ? recipe.minutes[start] : 0;
        if (wait > 1440) { return null; }
        for (var repeats = 16; repeats >= 1; repeats -= 1) {
            var expected = foldSteps(repeats, wait);
            if (matches(recipe, start, expected)) {
                return [start, expected.labels.size(), repeats, wait];
            }
        }
        return null;
    }

    function matches(recipe as Recipe, start as Number, expected as Recipe) as Boolean {
        if (start + expected.labels.size() > recipe.labels.size()) { return false; }
        for (var i = 0; i < expected.labels.size(); i += 1) {
            if (!recipe.labels[start + i].equals(expected.labels[i]) ||
                recipe.minutes[start + i] != expected.minutes[i]) { return false; }
        }
        return true;
    }

    function replaceSteps(recipe as Recipe, start as Number, length as Number,
        steps as Recipe) as Recipe {
        var result = new Recipe(recipe.name, recipe.labels.slice(0, start),
            recipe.minutes.slice(0, start));
        result.labels.addAll(steps.labels);
        result.minutes.addAll(steps.minutes);
        result.labels.addAll(recipe.labels.slice(start + length, null));
        result.minutes.addAll(recipe.minutes.slice(start + length, null));
        if (result.labels.size() > 32) {
            throw new RecipeError("Maximum 32 steps including waits. Use fewer repeats or no wait.");
        }
        return result;
    }

    // Swaps block `index` with its neighbor (direction -1 or +1).
    function moveBlock(recipe as Recipe, index as Number, direction as Number) as Recipe {
        var all = blocks(recipe);
        var other = index + direction;
        if (other < 0 || other >= all.size() ||
            (isLocked(recipe, 0) && (index == 0 || other == 0))) {
            return recipe.copy();
        }
        var first = all[index < other ? index : other];
        var second = all[index < other ? other : index];
        var swapped = new Recipe("", recipe.labels.slice(second[0], second[0] + second[1]),
            recipe.minutes.slice(second[0], second[0] + second[1]));
        swapped.labels.addAll(recipe.labels.slice(first[0], first[0] + first[1]));
        swapped.minutes.addAll(recipe.minutes.slice(first[0], first[0] + first[1]));
        return replaceSteps(recipe, first[0], first[1] + second[1], swapped);
    }

    function ingredientList(selected as Array<Boolean>) as String {
        var names = ingredients();
        if (selected.size() != names.size()) {
            throw new RecipeError("Choose ingredients from the list.");
        }
        var list = "";
        for (var i = 0; i < names.size(); i += 1) {
            if (selected[i]) {
                if (list.length() > 0) { list += ", "; }
                list += names[i];
            }
        }
        if (list.length() == 0) { throw new RecipeError("Select at least one ingredient."); }
        return list;
    }

    function hasInitialMix(recipe as Recipe) as Boolean {
        return recipe.labels.size() > 0 && recipe.labels[0].find("Initial mix") == 0;
    }

    // The initial mix is pinned as step 1: it cannot be deleted or moved.
    function isLocked(recipe as Recipe, step as Number) as Boolean {
        return step == 0 && hasInitialMix(recipe);
    }

    function mixSelection(recipe as Recipe) as Array<Boolean> {
        var names = ingredients();
        var selected = [] as Array<Boolean>;
        var label = hasInitialMix(recipe) ? recipe.labels[0] : "";
        for (var i = 0; i < names.size(); i += 1) {
            selected.add(label.find(names[i]) != null);
        }
        return selected;
    }

    function setMix(recipe as Recipe, selected as Array<Boolean>) as Recipe {
        if (!hasInitialMix(recipe)) { throw new RecipeError("Recipe has no initial mix."); }
        var label = "Initial mix: " + ingredientList(selected);
        var result = recipe.copy();
        result.labels[0] = label;
        return result;
    }
}

module Recipes {
    function split(text as String, delimiter as String) as Array<String> {
        var parts = [] as Array<String>;
        var start = 0;
        for (var i = 0; i < text.length(); i += 1) {
            if ((text.substring(i, i + 1) as String).equals(delimiter)) {
                parts.add(text.substring(start, i) as String);
                start = i + 1;
            }
        }
        parts.add(text.substring(start, text.length()) as String);
        return parts;
    }

    function validLabel(text as String, limit as Number) as Boolean {
        if (text.length() == 0 || text.length() > limit || text.find("|") != null ||
            text.find(";") != null || text.find("\n") != null ||
            text.find("\r") != null || text.find("\t") != null) { return false; }
        for (var i = 0; i < text.length(); i += 1) {
            if (!(text.substring(i, i + 1) as String).equals(" ")) { return true; }
        }
        return false;
    }

    function parseMinutes(text as String) as Number {
        if (text.length() == 0 || text.length() > 4) {
            throw new RecipeError("Use whole minutes: 0 to 1440.");
        }
        for (var i = 0; i < text.length(); i += 1) {
            if ("0123456789".find(text.substring(i, i + 1) as String) == null) {
                throw new RecipeError("Use whole minutes: 0 to 1440.");
            }
        }
        var value = text.toNumber();
        if (value == null || value > 1440) {
            throw new RecipeError("Use whole minutes: 0 to 1440.");
        }
        return value;
    }

    function parse(name as String, text as String) as Recipe {
        if (!validLabel(name, 24)) {
            throw new RecipeError("Recipe name: 1-24 characters; no | or ;.");
        }
        var labels = [] as Array<String>;
        var minutes = [] as Array<Number>;
        if (text.length() == 0) { return new Recipe(name, labels, minutes); }
        var entries = split(text, ";");
        if (entries.size() > 32) {
            throw new RecipeError("A recipe can have at most 32 steps.");
        }
        for (var i = 0; i < entries.size(); i += 1) {
            var fields = split(entries[i], "|");
            if (fields.size() != 2 || !validLabel(fields[0], 40)) {
                throw new RecipeError("Step " + (i + 1) + ": use Label|minutes; label 1-40 characters.");
            }
            labels.add(fields[0].equals("Refrigerate") ? "Cold proof" : fields[0]);
            minutes.add(parseMinutes(fields[1]));
        }
        return new Recipe(name, labels, minutes);
    }

    // Built with the same labels the template builder produces.
    function presets() as Array<Recipe> {
        return [
            parse("Sourdough", "Initial mix: Water, Flour, Leaven|0;Wait|30;Add Salt|0;Wait before fold 1 of 4|45;Fold 1 of 4|0;Wait before fold 2 of 4|45;Fold 2 of 4|0;Wait before fold 3 of 4|45;Fold 3 of 4|0;Wait before fold 4 of 4|45;Fold 4 of 4|0;Wait|30;Cold proof|0"),
            parse("Quick fold practice", "Initial mix: Water, Flour, Leaven, Salt|0;Wait before fold 1 of 2|1;Fold 1 of 2|0;Wait before fold 2 of 2|1;Fold 2 of 2|0")
        ];
    }

    function isFold(label as String) as Boolean {
        return label.equals("Fold") || label.find("Fold ") == 0;
    }

    // The last fold of a recipe is when the dough goes into the banneton.
    function isFinalFold(recipe as Recipe, index as Number) as Boolean {
        if (index < 0 || index >= recipe.labels.size() || !isFold(recipe.labels[index])) {
            return false;
        }
        for (var i = index + 1; i < recipe.labels.size(); i += 1) {
            if (isFold(recipe.labels[i])) { return false; }
        }
        return true;
    }
}
