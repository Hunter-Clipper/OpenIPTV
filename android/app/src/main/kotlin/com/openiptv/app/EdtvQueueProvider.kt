package com.openiptv.app

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.Bundle

/** Read-only EDTV integration. Returns display metadata only, never stream URLs or credentials. */
class EdtvQueueProvider : ContentProvider() {
    override fun onCreate(): Boolean = true

    override fun call(method: String, arg: String?, extras: Bundle?): Bundle? {
        if (method != "getQueueSnapshot") return super.call(method, arg, extras)
        if (callingPackage != "tv.edtv.home") return null
        val ctx = context ?: return null
        val prefs = ctx.getSharedPreferences("edtv_bridge", android.content.Context.MODE_PRIVATE)
        return Bundle().apply {
            putInt("apiVersion", 1)
            putString("snapshot", prefs.getString("queue_snapshot", null))
            putLong("updatedAt", prefs.getLong("queue_snapshot_updated_at", 0L))
        }
    }

    override fun query(uri: Uri, projection: Array<out String>?, selection: String?,
                       selectionArgs: Array<out String>?, sortOrder: String?): Cursor? = null
    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?,
                        selectionArgs: Array<out String>?): Int = 0
}
