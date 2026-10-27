import Toybox.Application.Properties;
import Toybox.Application.Storage;
import Toybox.Lang;

// Saved recipes form one editable list. Each recipe is stored under its own
// "recipe<i>" key; "recipeCount" holds the list length.
class RecipeStore {
    static const MAX_RECIPES = 20;
    var recipes as Array<Recipe> = [];
    // Phone settings slot (1-3) a recipe was imported from, or 0.
    var phoneSlots as Array<Number> = [];
    var errors as Array<String> = [];

    function initialize() {
        var count = Storage.getValue("recipeCount");
        if (count instanceof Number) {
            for (var i = 0; i < count; i += 1) { load(i); }
        } else {
            var presets = Recipes.presets();
            for (var p = 0; p < presets.size(); p += 1) {
                recipes.add(presets[p]);
                phoneSlots.add(0);
            }
            saveAll();
        }
        for (var legacy = 0; legacy < 3; legacy += 1) { Storage.deleteValue("custom" + legacy); }
        importPhone();
    }

    function load(i as Number) as Void {
        var saved = Storage.getValue("recipe" + i);
        try {
            if (!(saved instanceof Dictionary) || !(saved["name"] instanceof String) ||
                !(saved["steps"] instanceof String)) {
                throw new RecipeError("Invalid stored recipe.");
            }
            recipes.add(Recipes.parse(saved["name"] as String, saved["steps"] as String));
            var phone = saved["phone"];
            phoneSlots.add(phone instanceof Number ? phone : 0);
        } catch (error instanceof RecipeError) {
            errors.add("Recipe " + (i + 1) + ": " + error.getMessage());
        }
    }

    function saveAll() as Void {
        var previous = Storage.getValue("recipeCount");
        for (var i = 0; i < recipes.size(); i += 1) { write(i); }
        if (previous instanceof Number) {
            for (var stale = recipes.size(); stale < previous; stale += 1) {
                Storage.deleteValue("recipe" + stale);
            }
        }
        Storage.setValue("recipeCount", recipes.size());
    }

    function write(i as Number) as Void {
        Storage.setValue("recipe" + i, {
            "name" => recipes[i].name, "steps" => recipes[i].encode(), "phone" => phoneSlots[i]
        });
    }

    function isFull() as Boolean { return recipes.size() >= MAX_RECIPES; }

    // Saves `recipe` at `index`, or appends it when index is -1. Returns its index.
    function put(index as Number, recipe as Recipe) as Number {
        if (index < 0 || index >= recipes.size()) {
            if (isFull()) { throw new RecipeError("Maximum " + MAX_RECIPES + " recipes."); }
            recipes.add(recipe.copy());
            phoneSlots.add(0);
            saveAll();
            return recipes.size() - 1;
        }
        recipes[index] = recipe.copy();
        write(index);
        return index;
    }

    function remove(index as Number) as Void {
        if (index < 0 || index >= recipes.size()) { return; }
        var keptRecipes = [] as Array<Recipe>;
        var keptSlots = [] as Array<Number>;
        for (var i = 0; i < recipes.size(); i += 1) {
            if (i != index) { keptRecipes.add(recipes[i]); keptSlots.add(phoneSlots[i]); }
        }
        recipes = keptRecipes;
        phoneSlots = keptSlots;
        saveAll();
    }

    // Each phone settings slot adds one recipe to the list, then replaces that
    // same recipe whenever the phone values change. Unchanged phone values never
    // overwrite watch edits, and an empty steps field changes nothing.
    function importPhone() as Void {
        for (var slot = 1; slot <= 3; slot += 1) {
            var prefix = "custom" + slot;
            var name = Properties.getValue(prefix + "Name");
            var steps = Properties.getValue(prefix + "Steps");
            if (!(name instanceof String) || !(steps instanceof String)) {
                errors.add("Phone recipe " + slot + ": settings must be text.");
                continue;
            }
            var signature = name + "\n" + steps;
            var key = "phone" + (slot - 1);
            if (signature.equals(Storage.getValue(key))) { continue; }
            if (steps.length() == 0) {
                Storage.setValue(key, signature);
                continue;
            }
            try {
                var recipe = Recipes.parse(name, steps);
                var index = phoneSlots.indexOf(slot);
                if (index < 0) {
                    index = put(-1, recipe);
                    phoneSlots[index] = slot;
                    write(index);
                } else {
                    put(index, recipe);
                }
                Storage.setValue(key, signature);
            } catch (error instanceof RecipeError) {
                errors.add("Phone recipe " + slot + ": " + error.getMessage() +
                    " Watch recipes kept.");
            }
        }
    }
}
