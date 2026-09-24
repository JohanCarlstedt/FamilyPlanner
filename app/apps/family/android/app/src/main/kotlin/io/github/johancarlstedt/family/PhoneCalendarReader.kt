package io.github.johancarlstedt.family

import android.Manifest
import android.app.Activity
import android.content.ContentUris
import android.content.pm.PackageManager
import android.provider.CalendarContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Reads the phone's own calendars for the family's, and never writes.
 *
 * The device_calendar plugin refuses every call on Android unless the app
 * also holds WRITE_CALENDAR, and this app asks only to read: nothing it
 * does ever changes anyone's calendar, so asking to would be a promise
 * broken in the permission list. This is the few queries the app needs,
 * on READ_CALENDAR alone (docs/calendars.md).
 */
class PhoneCalendarReader(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var asking: MethodChannel.Result? = null

    private fun allowed() = activity.checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
        PackageManager.PERMISSION_GRANTED

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "allowed" -> result.success(allowed())
            "ask" -> {
                if (allowed()) {
                    result.success(true)
                    return
                }
                asking?.success(false)
                asking = result
                activity.requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), REQUEST)
            }
            "calendars" -> result.success(if (allowed()) calendars() else emptyList<Any>())
            "events" -> {
                val id = call.argument<String>("calendar")?.toLongOrNull()
                val from = call.argument<Number>("from")?.toLong()
                val until = call.argument<Number>("until")?.toLong()
                if (!allowed() || id == null || from == null || until == null) {
                    result.success(emptyList<Any>())
                } else {
                    result.success(events(id, from, until))
                }
            }
            else -> result.notImplemented()
        }
    }

    /** Called from the activity with the answer to [REQUEST]. */
    fun answered(requestCode: Int, grants: IntArray) {
        if (requestCode != REQUEST) return
        asking?.success(grants.isNotEmpty() && grants[0] == PackageManager.PERMISSION_GRANTED)
        asking = null
    }

    /** Calendars that sync events: a calendar Android keeps no events for has nothing to show. */
    private fun calendars(): List<Map<String, Any?>> {
        val out = mutableListOf<Map<String, Any?>>()
        activity.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            arrayOf(
                CalendarContract.Calendars._ID,
                CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
                CalendarContract.Calendars.ACCOUNT_NAME,
                CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL,
            ),
            "${CalendarContract.Calendars.SYNC_EVENTS} = 1",
            null,
            null,
        )?.use { c ->
            while (c.moveToNext()) {
                out += mapOf(
                    "id" to c.getLong(0).toString(),
                    "name" to c.getString(1),
                    "account" to c.getString(2),
                    "readOnly" to (c.getInt(3) < CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR),
                )
            }
        }
        return out
    }

    /**
     * Occurrences in [from, until), repeating events expanded by Android
     * itself. A repeating event's occurrences share an event id, so each
     * is told apart by when it begins; a single event keeps its own id,
     * so moving it updates it rather than making another.
     */
    private fun events(calendar: Long, from: Long, until: Long): List<Map<String, Any?>> {
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, from)
            ContentUris.appendId(it, until)
        }.build()
        val out = mutableListOf<Map<String, Any?>>()
        activity.contentResolver.query(
            uri,
            arrayOf(
                CalendarContract.Instances.EVENT_ID,
                CalendarContract.Instances.BEGIN,
                CalendarContract.Instances.END,
                CalendarContract.Instances.TITLE,
                CalendarContract.Instances.EVENT_LOCATION,
                CalendarContract.Instances.DESCRIPTION,
                CalendarContract.Instances.ALL_DAY,
                CalendarContract.Instances.RRULE,
                CalendarContract.Instances.ORIGINAL_ID,
                CalendarContract.Instances.STATUS,
            ),
            "${CalendarContract.Instances.CALENDAR_ID} = ?",
            arrayOf(calendar.toString()),
            "${CalendarContract.Instances.BEGIN} ASC",
        )?.use { c ->
            while (c.moveToNext()) {
                // Cancelled on the phone: left out, so the family's copy is
                // marked cancelled the way a vanished feed entry is.
                if (!c.isNull(9) && c.getInt(9) == CalendarContract.Events.STATUS_CANCELED) continue
                val eventId = c.getLong(0)
                val begin = c.getLong(1)
                val repeating = !c.isNull(7) || !c.isNull(8)
                out += mapOf(
                    "id" to if (repeating) "$eventId@$begin" else "$eventId",
                    "begin" to begin,
                    "end" to c.getLong(2),
                    "title" to c.getString(3),
                    "location" to c.getString(4),
                    "description" to c.getString(5),
                    "allDay" to (c.getInt(6) == 1),
                )
            }
        }
        return out
    }

    companion object {
        const val CHANNEL = "family/phone_calendars"
        private const val REQUEST = 4711
    }
}
