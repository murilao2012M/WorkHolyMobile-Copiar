package br.com.workholyia.workholy_mobile

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

internal object LembreteTreino {
    private const val PREFERENCIAS = "workholy_lembrete_treino"
    private const val CHAVE_ATIVO = "ativo"
    private const val CHAVE_DIA = "dia"
    private const val CHAVE_HORA = "hora"
    private const val CHAVE_MINUTO = "minuto"
    private const val ID_NOTIFICACAO = 7301
    private const val ID_ALARME = 7302

    fun agendar(context: Context, diaSemana: Int, hora: Int, minuto: Int) {
        require(diaSemana in 1..7 && hora in 0..23 && minuto in 0..59)
        context.getSharedPreferences(PREFERENCIAS, Context.MODE_PRIVATE).edit()
            .putBoolean(CHAVE_ATIVO, true)
            .putInt(CHAVE_DIA, diaSemana)
            .putInt(CHAVE_HORA, hora)
            .putInt(CHAVE_MINUTO, minuto)
            .apply()
        agendarAlarme(context, diaSemana, hora, minuto)
    }

    fun cancelar(context: Context) {
        context.getSharedPreferences(PREFERENCIAS, Context.MODE_PRIVATE).edit()
            .putBoolean(CHAVE_ATIVO, false)
            .apply()
        val intent = Intent(context, LembreteTreinoReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context,
            ID_ALARME,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
            .cancel(pending)
    }

    fun restaurar(context: Context) {
        val prefs = context.getSharedPreferences(PREFERENCIAS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(CHAVE_ATIVO, false)) return
        agendarAlarme(
            context,
            prefs.getInt(CHAVE_DIA, Calendar.MONDAY),
            prefs.getInt(CHAVE_HORA, 18),
            prefs.getInt(CHAVE_MINUTO, 0),
        )
    }

    private fun agendarAlarme(context: Context, diaSemana: Int, hora: Int, minuto: Int) {
        val androidDiaSemana = when (diaSemana) {
            1 -> Calendar.MONDAY
            2 -> Calendar.TUESDAY
            3 -> Calendar.WEDNESDAY
            4 -> Calendar.THURSDAY
            5 -> Calendar.FRIDAY
            6 -> Calendar.SATURDAY
            else -> Calendar.SUNDAY
        }
        val agora = Calendar.getInstance()
        val diasAteLembrete =
            (androidDiaSemana - agora.get(Calendar.DAY_OF_WEEK) + 7) % 7
        val proximo = (agora.clone() as Calendar).apply {
            add(Calendar.DAY_OF_YEAR, diasAteLembrete)
            set(Calendar.HOUR_OF_DAY, hora)
            set(Calendar.MINUTE, minuto)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) {
                add(Calendar.DAY_OF_YEAR, 7)
            }
        }
        val intent = Intent(context, LembreteTreinoReceiver::class.java)
        val pending = PendingIntent.getBroadcast(
            context,
            ID_ALARME,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager)
            .setInexactRepeating(
                AlarmManager.RTC_WAKEUP,
                proximo.timeInMillis,
                AlarmManager.INTERVAL_DAY * 7,
                pending,
            )
    }

    fun mostrarNotificacao(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
            android.content.pm.PackageManager.PERMISSION_GRANTED
        ) return

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as android.app.NotificationManager
        val canalId = "workholy_lembrete_treino"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                android.app.NotificationChannel(
                    canalId,
                    "Lembretes de treino",
                    android.app.NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
        }
        val abrir = PendingIntent.getActivity(
            context,
            ID_NOTIFICACAO,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notificacao = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, canalId)
        } else {
            @Suppress("DEPRECATION")
            android.app.Notification.Builder(context)
        }.setSmallIcon(android.R.drawable.ic_menu_my_calendar)
            .setContentTitle("Hora de treinar")
            .setContentText("Seu lembrete semanal do Moveria chegou.")
            .setContentIntent(abrir)
            .setAutoCancel(true)
            .build()
        manager.notify(ID_NOTIFICACAO, notificacao)
    }
}

class LembreteTreinoReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> LembreteTreino.restaurar(context)
            else -> LembreteTreino.mostrarNotificacao(context)
        }
    }
}
