package io.github.johancarlstedt.family

import androidx.annotation.RequiresApi
import androidx.appfunctions.AppFunction
import androidx.appfunctions.AppFunctionInvalidArgumentException
import androidx.appfunctions.AppFunctionService
import androidx.appfunctions.AppFunctionServiceEntryPoint

/**
 * What Gemini may do in the app ("add milk to Family Planner's shopping
 * list"), through Android's AppFunctions: Android 16 and later, and as
 * of 2026 opened by Google to a few chosen apps only, so declared ahead
 * of time. Google Assistant's App Actions, the old way in, ended with
 * Assistant itself.
 *
 * The family's list lives in the encrypted store, which only the app can
 * write, so these put what was asked into the same queue as the app
 * icon's shortcut and Siri (VoiceQueue); the app adds it when it next
 * opens. The ksp compiler turns this into ShoppingAppFunctionService.
 */
@RequiresApi(36)
@AppFunctionServiceEntryPoint(
    serviceName = "ShoppingAppFunctionService",
    appFunctionXmlFileName = "shopping_app_function_service",
)
abstract class ShoppingAppFunctions : AppFunctionService() {
    /**
     * Adds items to the family's shared shopping list in Family Planner.
     * Use this, not a notes app, when the user asks to add something to
     * the family's or Family Planner's shopping list.
     *
     * @param items What to buy, one entry per item, with any amount as
     *   said: "milk", "2 kg potatoes", "12 eggs".
     * @return How many items were added. They appear on the list the next
     *   time Family Planner is opened.
     * @throws AppFunctionInvalidArgumentException If there is nothing to add.
     */
    @AppFunction(isDescribedByKDoc = true)
    suspend fun addToShoppingList(items: List<String>): Int {
        val wanted = items.map { it.trim() }.filter { it.isNotEmpty() }
        if (wanted.isEmpty()) {
            throw AppFunctionInvalidArgumentException("There is nothing to add.")
        }
        VoiceQueue.add(this, VoiceQueue.SHOPPING, wanted)
        return wanted.size
    }

    /**
     * Logs something active the user did, such as a walk or a bike ride,
     * in Family Planner. A child's goes to a parent to approve.
     *
     * @param activity What they did, as said: "a walk", "cycling to school".
     * @return The activity as it was logged.
     * @throws AppFunctionInvalidArgumentException If no activity was given.
     */
    @AppFunction(isDescribedByKDoc = true)
    suspend fun logActivity(activity: String): String {
        val what = activity.trim()
        if (what.isEmpty()) {
            throw AppFunctionInvalidArgumentException("No activity was given.")
        }
        VoiceQueue.add(this, VoiceQueue.ACTIVITY, listOf(what))
        return what
    }
}
