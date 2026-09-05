package com.dadafinanza.app

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.ViewGroup
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.CheckBox
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import androidx.core.view.setPadding

class DadaWidgetConfigActivity : Activity() {
    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

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

        val prefs = getSharedPreferences("DadaWidgetConfig", MODE_PRIVATE)
        val density = resources.displayMetrics.density
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding((20 * density).toInt())
            setBackgroundColor(Color.rgb(9, 9, 11))
        }

        root.addView(TextView(this).apply {
            text = "Configura widget"
            textSize = 24f
            setTextColor(Color.WHITE)
        })

        addLabel(root, "Tipo movimento")
        val typeSpinner = Spinner(this)
        val types = listOf("Spesa", "Entrata", "Trasferisci")
        typeSpinner.adapter = ArrayAdapter(
            this,
            android.R.layout.simple_spinner_dropdown_item,
            types,
        )
        val savedType = prefs.getString("type_$appWidgetId", "expense") ?: "expense"
        typeSpinner.setSelection(
            when (savedType) {
                "income" -> 1
                "transfer" -> 2
                else -> 0
            },
        )
        root.addView(typeSpinner, matchWidth())

        addLabel(root, "Conto predefinito (ID, opzionale)")
        val account = edit("es. 1", prefs.getString("account_$appWidgetId", "") ?: "")
        root.addView(account, matchWidth())

        addLabel(root, "Categoria predefinita (nome, opzionale)")
        val category = edit(
            "es. Alimentari",
            prefs.getString("category_$appWidgetId", "") ?: "",
        )
        root.addView(category, matchWidth())

        addLabel(root, "Conto destinazione trasferimento (ID, opzionale)")
        val toAccount = edit(
            "es. 2",
            prefs.getString("to_account_$appWidgetId", "") ?: "",
        )
        root.addView(toAccount, matchWidth())

        addLabel(root, "Importi rapidi")
        val quick1 = edit("5", prefs.getString("amount_0_$appWidgetId", "5") ?: "5")
        val quick2 = edit("10", prefs.getString("amount_1_$appWidgetId", "10") ?: "10")
        val quick3 = edit("20", prefs.getString("amount_2_$appWidgetId", "20") ?: "20")
        val quick4 = edit("50", prefs.getString("amount_3_$appWidgetId", "50") ?: "50")
        root.addView(quick1, matchWidth())
        root.addView(quick2, matchWidth())
        root.addView(quick3, matchWidth())
        root.addView(quick4, matchWidth())

        val privateBalance = CheckBox(this).apply {
            text = "Nascondi saldo in questo widget"
            setTextColor(Color.WHITE)
            isChecked = prefs.getBoolean("hide_balance_$appWidgetId", false)
        }
        root.addView(privateBalance, matchWidth())

        val save = Button(this).apply {
            text = "Salva"
            setOnClickListener {
                val type = when (typeSpinner.selectedItemPosition) {
                    1 -> "income"
                    2 -> "transfer"
                    else -> "expense"
                }
                prefs.edit()
                    .putString("type_$appWidgetId", type)
                    .putString("account_$appWidgetId", account.text.toString().trim())
                    .putString("category_$appWidgetId", category.text.toString().trim())
                    .putString("to_account_$appWidgetId", toAccount.text.toString().trim())
                    .putString("amount_0_$appWidgetId", quick1.text.toString().trim())
                    .putString("amount_1_$appWidgetId", quick2.text.toString().trim())
                    .putString("amount_2_$appWidgetId", quick3.text.toString().trim())
                    .putString("amount_3_$appWidgetId", quick4.text.toString().trim())
                    .putBoolean("hide_balance_$appWidgetId", privateBalance.isChecked)
                    .apply()
                notifyWidgets()
                setResult(
                    RESULT_OK,
                    Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
                )
                finish()
            }
        }
        root.addView(save, matchWidth())
        setContentView(root)
    }

    private fun notifyWidgets() {
        val manager = AppWidgetManager.getInstance(this)
        listOf(
            DadaFinanceWidgetProvider::class.java,
            DadaBalanceWidgetProvider::class.java,
            DadaQuickAddWidgetProvider::class.java,
            DadaQuickAmountsWidgetProvider::class.java,
        ).forEach { provider ->
            sendBroadcast(
                Intent(this, provider).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
                },
            )
        }
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
        setSingleLine(true)
        textSize = 16f
    }

    private fun matchWidth() = LinearLayout.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.WRAP_CONTENT,
    )
}
