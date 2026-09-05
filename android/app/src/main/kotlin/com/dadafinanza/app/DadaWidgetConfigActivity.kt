package com.dadafinanza.app

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.text.InputType
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Spinner
import android.widget.TextView

class DadaWidgetConfigActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private val prefs by lazy {
        getSharedPreferences("dada_widget_config", MODE_PRIVATE)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        setContentView(buildContent())
    }

    private fun buildContent(): ScrollView {
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(20), dp(20), dp(32))
            setBackgroundColor(Color.rgb(9, 9, 11))
        }
        root.addView(TextView(this).apply {
            text = "Configura widget"
            textSize = 26f
            setTextColor(Color.WHITE)
            setPadding(0, 0, 0, dp(8))
        })
        root.addView(TextView(this).apply {
            text = "Ogni widget mantiene impostazioni proprie. I nomi di conto e categoria vengono verificati dall’app quando apri Quick Add."
            textSize = 14f
            setTextColor(Color.LTGRAY)
            setPadding(0, 0, 0, dp(24))
        })

        val typeSpinner = Spinner(this).apply {
            adapter = ArrayAdapter(
                this@DadaWidgetConfigActivity,
                android.R.layout.simple_spinner_dropdown_item,
                listOf("Spesa", "Entrata", "Trasferimento"),
            )
            val saved = prefs.getString("widget_${appWidgetId}_type", "expense")
            setSelection(
                when (saved) {
                    "income" -> 1
                    "transfer" -> 2
                    else -> 0
                },
            )
        }
        addLabel(root, "Tipo predefinito")
        root.addView(typeSpinner, matchWidth())

        val account = edit(
            "Conto (es. Revolut)",
            prefs.getString("widget_${appWidgetId}_account", "") ?: "",
        )
        root.addView(account, matchWidth())
        val category = edit(
            "Categoria (es. Bar)",
            prefs.getString("widget_${appWidgetId}_category", "") ?: "",
        )
        root.addView(category, matchWidth())
        val destination = edit(
            "Destinazione trasferimento (opzionale)",
            prefs.getString("widget_${appWidgetId}_destination", "") ?: "",
        )
        root.addView(destination, matchWidth())

        addLabel(root, "Importi rapidi")
        val amountRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
        }
        val defaults = listOf("1", "2", "5", "10")
        val amountFields = List(4) { index ->
            EditText(this).apply {
                setText(
                    prefs.getString(
                        "widget_${appWidgetId}_amount_$index",
                        defaults[index],
                    ) ?: defaults[index],
                )
                inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
                hint = defaults[index]
                setTextColor(Color.WHITE)
                setHintTextColor(Color.GRAY)
                textSize = 16f
                textAlignment = EditText.TEXT_ALIGNMENT_CENTER
                amountRow.addView(
                    this,
                    LinearLayout.LayoutParams(0, dp(52), 1f).apply {
                        marginStart = dp(3)
                        marginEnd = dp(3)
                    },
                )
            }
        }
        root.addView(amountRow, matchWidth())

        val showBalance = CheckBox(this).apply {
            text = "Mostra saldo nel widget"
            setTextColor(Color.WHITE)
            isChecked = prefs.getBoolean("widget_${appWidgetId}_show_balance", false)
        }
        root.addView(showBalance, matchWidth())
        val showAmounts = CheckBox(this).apply {
            text = "Mostra importi rapidi"
            setTextColor(Color.WHITE)
            isChecked = prefs.getBoolean("widget_${appWidgetId}_show_amounts", true)
        }
        root.addView(showAmounts, matchWidth())

        root.addView(Button(this).apply {
            text = "Salva widget"
            isAllCaps = false
            setOnClickListener {
                val type = when (typeSpinner.selectedItemPosition) {
                    1 -> "income"
                    2 -> "transfer"
                    else -> "expense"
                }
                val editor = prefs.edit()
                    .putString("widget_${appWidgetId}_type", type)
                    .putString("widget_${appWidgetId}_account", account.text.toString().trim())
                    .putString("widget_${appWidgetId}_category", category.text.toString().trim())
                    .putString(
                        "widget_${appWidgetId}_destination",
                        destination.text.toString().trim(),
                    )
                    .putBoolean("widget_${appWidgetId}_show_balance", showBalance.isChecked)
                    .putBoolean("widget_${appWidgetId}_show_amounts", showAmounts.isChecked)
                amountFields.forEachIndexed { index, field ->
                    val value = field.text.toString().trim().replace(',', '.')
                    editor.putString(
                        "widget_${appWidgetId}_amount_$index",
                        value.toDoubleOrNull()?.takeIf { it > 0 }?.toString() ?: defaults[index],
                    )
                }
                editor.apply()
                requestWidgetUpdate()
                setResult(
                    RESULT_OK,
                    Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
                )
                finish()
            }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(52)).apply {
            topMargin = dp(24)
        })

        return ScrollView(this).apply { addView(root) }
    }

    private fun requestWidgetUpdate() {
        val manager = AppWidgetManager.getInstance(this)
        val info = manager.getAppWidgetInfo(appWidgetId) ?: return
        sendBroadcast(
            Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                component = info.provider
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
            },
        )
    }

    private fun addLabel(root: LinearLayout, label: String) {
        val density = resources.displayMetrics.density
        root.addView(TextView(this).apply {
            text = label
            textSize = 13f
            setTextColor(Color.LTGRAY)
            setPadding(0, (16 * density).toInt(), 0, (4 * density).toInt())
        })
    }

    private fun edit(hintText: String, value: String) = EditText(this).apply {
        hint = hintText
        setText(value)
        setTextColor(Color.WHITE)
        setHintTextColor(Color.GRAY)
        singleLine = true
        textSize = 16f
    }

    private fun matchWidth() = LinearLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
    )
}
