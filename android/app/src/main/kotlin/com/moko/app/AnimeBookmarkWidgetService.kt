package com.moko.app

import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

class AnimeBookmarkWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return AnimeBookmarkViewsFactory(this.applicationContext)
    }
}

class AnimeBookmarkViewsFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private val items = ArrayList<JSONObject>()

    override fun onCreate() {
        loadData()
    }

    override fun onDataSetChanged() {
        loadData()
    }

    private fun loadData() {
        items.clear()
        try {
            val prefs = HomeWidgetPlugin.getData(context)
            val jsonStr = prefs.getString("bookmark_anime_list_json", "[]") ?: "[]"
            val array = JSONArray(jsonStr)
            for (i in 0 until array.length()) {
                val obj = array.optJSONObject(i)
                if (obj != null) {
                    items.add(obj)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews? {
        if (position < 0 || position >= items.size) return null
        val item = items[position]

        val rv = RemoteViews(context.packageName, R.layout.widget_anime_bookmark_item)

        val title = item.optString("title", "Anime")
        val episode = item.optString("episode", "Episode Terakhir")
        val progress = item.optInt("progress", 0).coerceIn(0, 100)
        val url = item.optString("url", "")
        val imagePath = item.optString("image", "")

        rv.setTextViewText(R.id.item_title, title)
        rv.setTextViewText(R.id.item_episode, episode)
        rv.setProgressBar(R.id.item_progress_bar, 100, progress, false)
        rv.setTextViewText(R.id.item_progress_text, "$progress%")

        if (imagePath.isNotEmpty()) {
            try {
                val file = File(imagePath)
                if (file.exists() && file.length() > 0) {
                    val bitmap = BitmapFactory.decodeFile(file.absolutePath)
                    if (bitmap != null) {
                        rv.setImageViewBitmap(R.id.item_image, bitmap)
                    }
                }
            } catch (_: Exception) {}
        }

        val fillInIntent = Intent().apply {
            data = if (url.isNotEmpty()) {
                Uri.parse("moko://continue?url=${Uri.encode(url)}")
            } else {
                Uri.parse("moko://home")
            }
        }
        rv.setOnClickFillInIntent(R.id.item_root, fillInIntent)

        return rv
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}

