package com.dadafinanza.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class DadaFinanceWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val balance = widgetData.getString("balance", "0.00") ?: "0.00"
            val quick = List(4) { index ->
                widgetData.getString("quick_category_$index", "Spesa") ?: "Spesa"
            }

            val views = RemoteViews(context.packageName, R.layout.dada_finance_widget).apply {
                setTextViewText(R.id.widget_balance, "$balance €")
                setTextViewText(R.id.widget_quick_0, quick[0])
                setTextViewText(R.id.widget_quick_1, quick[1])
                setTextViewText(R.id.widget_quick_2, quick[2])
                setTextViewText(R.id.widget_quick_3, quick[3])

                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
                setOnClickPendingIntent(R.id.widget_add, quickAddIntent(context, null, widgetId * 10))
                setOnClickPendingIntent(R.id.widget_quick_0, quickAddIntent(context, quick[0], widgetId * 10 + 1))
                setOnClickPendingIntent(R.id.widget_quick_1, quickAddIntent(context, quick[1], widgetId * 10 + 2))
                setOnClickPendingIntent(R.id.widget_quick_2, quickAddIntent(context, quick[2], widgetId * 10 + 3))
                setOnClickPendingIntent(R.id.widget_quick_3, quickAddIntent(context, quick[3], widgetId * 10 + 4))
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun quickAddIntent(context: Context, category: String?, requestCode: Int) =
        HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse(
                buildString {
                    append("dadafinanza://quick-add?type=expense")
                    if (!category.isNullOrBlank()) {
                        append("&category=")
                        append(Uri.encode(category))
                    }
                    append("&request=")
                    append(requestCode)
                },
            ),
        )
}
