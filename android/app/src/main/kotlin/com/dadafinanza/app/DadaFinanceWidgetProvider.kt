package com.dadafinanza.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

private object DadaWidgetIntents {
    fun openApp(context: Context) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

    fun quickAddIntent(
        context: Context,
        type: String,
        category: String? = null,
        requestCode: Int,
    ) = HomeWidgetLaunchIntent.getActivity(
        context,
        MainActivity::class.java,
        Uri.parse(
            buildString {
                append("dadafinanza://quick-add?type=")
                append(type)
                if (!category.isNullOrBlank()) {
                    append("&category=")
                    append(Uri.encode(category))
                }
                append("&request=")
                append(requestCode)
            },
        ),
    )

    fun balanceLabel(widgetData: SharedPreferences): String {
        if (widgetData.getBoolean("hide_balance", false)) return "••••"
        val balance = widgetData.getString("balance", "0.00") ?: "0.00"
        return "$balance €"
    }
}

class DadaFinanceWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val quick = List(4) { index ->
                widgetData.getString("quick_category_$index", "Spesa") ?: "Spesa"
            }
            val views = RemoteViews(context.packageName, R.layout.dada_finance_widget).apply {
                setTextViewText(R.id.widget_balance, DadaWidgetIntents.balanceLabel(widgetData))
                setTextViewText(R.id.widget_quick_0, quick[0])
                setTextViewText(R.id.widget_quick_1, quick[1])
                setTextViewText(R.id.widget_quick_2, quick[2])
                setTextViewText(R.id.widget_quick_3, quick[3])
                setOnClickPendingIntent(R.id.widget_root, DadaWidgetIntents.openApp(context))
                setOnClickPendingIntent(
                    R.id.widget_add,
                    DadaWidgetIntents.quickAddIntent(context, "expense", requestCode = widgetId * 10),
                )
                setOnClickPendingIntent(
                    R.id.widget_quick_0,
                    DadaWidgetIntents.quickAddIntent(context, "expense", quick[0], widgetId * 10 + 1),
                )
                setOnClickPendingIntent(
                    R.id.widget_quick_1,
                    DadaWidgetIntents.quickAddIntent(context, "expense", quick[1], widgetId * 10 + 2),
                )
                setOnClickPendingIntent(
                    R.id.widget_quick_2,
                    DadaWidgetIntents.quickAddIntent(context, "expense", quick[2], widgetId * 10 + 3),
                )
                setOnClickPendingIntent(
                    R.id.widget_quick_3,
                    DadaWidgetIntents.quickAddIntent(context, "expense", quick[3], widgetId * 10 + 4),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class DadaBalanceWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.dada_balance_widget).apply {
                setTextViewText(
                    R.id.balance_widget_value,
                    DadaWidgetIntents.balanceLabel(widgetData),
                )
                setOnClickPendingIntent(R.id.balance_widget_root, DadaWidgetIntents.openApp(context))
                setOnClickPendingIntent(
                    R.id.balance_widget_add,
                    DadaWidgetIntents.quickAddIntent(context, "expense", requestCode = widgetId * 20 + 1),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

class DadaQuickAddWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { widgetId ->
            val firstCategory = widgetData.getString("quick_category_0", "Spesa") ?: "Spesa"
            val views = RemoteViews(context.packageName, R.layout.dada_quick_add_widget).apply {
                setTextViewText(R.id.quick_widget_category, firstCategory)
                setOnClickPendingIntent(R.id.quick_widget_root, DadaWidgetIntents.openApp(context))
                setOnClickPendingIntent(
                    R.id.quick_widget_expense,
                    DadaWidgetIntents.quickAddIntent(context, "expense", requestCode = widgetId * 30 + 1),
                )
                setOnClickPendingIntent(
                    R.id.quick_widget_income,
                    DadaWidgetIntents.quickAddIntent(context, "income", requestCode = widgetId * 30 + 2),
                )
                setOnClickPendingIntent(
                    R.id.quick_widget_transfer,
                    DadaWidgetIntents.quickAddIntent(context, "transfer", requestCode = widgetId * 30 + 3),
                )
                setOnClickPendingIntent(
                    R.id.quick_widget_category,
                    DadaWidgetIntents.quickAddIntent(
                        context,
                        "expense",
                        firstCategory,
                        widgetId * 30 + 4,
                    ),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
