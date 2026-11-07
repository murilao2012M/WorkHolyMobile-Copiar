package br.com.workholyia.workholy_mobile

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val canalBackup =
        "br.com.workholyia.workholy_mobile/backup"
    private val canalLembretes =
        "br.com.workholyia.workholy_mobile/lembretes"
    private val canalCompartilhamento =
        "br.com.workholyia.workholy_mobile/sharing"
    private val codigoSalvarBackup = 4983
    private var resultadoSalvarBackup: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            canalBackup,
        ).setMethodCallHandler { chamada, resultado ->
            when (chamada.method) {
                "salvarBackup" -> salvarBackupNoProvedor(chamada, resultado)
                else -> resultado.notImplemented()
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            canalLembretes,
        ).setMethodCallHandler { chamada, resultado ->
            try {
                when (chamada.method) {
                    "agendar" -> {
                        val dia = chamada.argument<Int>("diaSemana")
                        val hora = chamada.argument<Int>("hora")
                        val minuto = chamada.argument<Int>("minuto")
                        require(dia != null && hora != null && minuto != null)
                        LembreteTreino.agendar(this, dia, hora, minuto)
                        resultado.success(null)
                    }
                    "cancelar" -> {
                        LembreteTreino.cancelar(this)
                        resultado.success(null)
                    }
                    else -> resultado.notImplemented()
                }
            } catch (erro: Exception) {
                resultado.error("LEMBRETE_INVALIDO", erro.message, null)
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            canalCompartilhamento,
        ).setMethodCallHandler { chamada, resultado ->
            when (chamada.method) {
                "compartilharTexto" -> compartilharTexto(chamada, resultado)
                else -> resultado.notImplemented()
            }
        }
    }

    private fun compartilharTexto(
        chamada: io.flutter.plugin.common.MethodCall,
        resultado: MethodChannel.Result,
    ) {
        val texto = chamada.argument<String>("texto")
        val titulo = chamada.argument<String>("titulo")
        if (texto.isNullOrBlank() || titulo.isNullOrBlank()) {
            resultado.error(
                "COMPARTILHAMENTO_INVALIDO",
                "O título ou o conteúdo do compartilhamento está vazio.",
                null,
            )
            return
        }

        try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_SUBJECT, titulo)
                putExtra(Intent.EXTRA_TEXT, texto)
            }
            startActivity(Intent.createChooser(intent, titulo))
            resultado.success(true)
        } catch (erro: Exception) {
            resultado.error("COMPARTILHAMENTO_FALHOU", erro.message, null)
        }
    }

    private fun salvarBackupNoProvedor(
        chamada: io.flutter.plugin.common.MethodCall,
        resultado: MethodChannel.Result,
    ) {
        if (resultadoSalvarBackup != null) {
            resultado.error(
                "BACKUP_EM_ANDAMENTO",
                "Já existe uma solicitação de salvamento aberta.",
                null,
            )
            return
        }

        val conteudo = chamada.argument<String>("conteudo")
        val nomeArquivo = chamada.argument<String>("nomeArquivo")
        if (conteudo == null || nomeArquivo.isNullOrBlank()) {
            resultado.error(
                "BACKUP_INVALIDO",
                "O conteúdo ou o nome do arquivo está inválido.",
                null,
            )
            return
        }

        resultadoSalvarBackup = resultado
        try {
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/json"
                putExtra(Intent.EXTRA_TITLE, nomeArquivo)
            }
            startActivityForResult(intent, codigoSalvarBackup)
            conteudoBackupPendente = conteudo
        } catch (erro: Exception) {
            resultadoSalvarBackup = null
            conteudoBackupPendente = null
            resultado.error("BACKUP_SEM_PROVEDOR", erro.message, null)
        }
    }

    private var conteudoBackupPendente: String? = null

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != codigoSalvarBackup) return

        val resultado = resultadoSalvarBackup
        resultadoSalvarBackup = null
        val conteudo = conteudoBackupPendente
        conteudoBackupPendente = null
        if (resultado == null) return

        if (resultCode != RESULT_OK || data?.data == null) {
            resultado.success(false)
            return
        }

        try {
            val uri: Uri = data.data!!
            contentResolver.openOutputStream(uri, "wt").use { saida ->
                checkNotNull(saida) { "Não foi possível abrir o arquivo de destino." }
                saida.write(checkNotNull(conteudo).toByteArray(Charsets.UTF_8))
                saida.flush()
            }
            resultado.success(true)
        } catch (erro: Exception) {
            resultado.error("BACKUP_FALHOU", erro.message, null)
        }
    }
}
