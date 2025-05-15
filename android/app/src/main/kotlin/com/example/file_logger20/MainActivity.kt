package com.example.file_logger20
import android.os.Bundle
import android.os.FileObserver
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import okhttp3.*
import okhttp3.Credentials
import java.io.File
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import okhttp3.RequestBody.Companion.toRequestBody
 
 import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import okhttp3.OkHttpClient

import java.io.IOException
import okhttp3.Request
import okhttp3.Response
import org.apache.commons.net.ftp.FTP
import org.apache.commons.net.ftp.FTPClient

import kotlinx.coroutines.*
import android.os.Environment
  
import java.io.FileOutputStream
    
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

import java.io.*
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter


import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.net.UnknownHostException
import org.apache.commons.net.ftp.FTPConnectionClosedException
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService

 import kotlinx.serialization.json.JsonArray

import org.json.JSONArray
import java.util.Calendar
import java.util.concurrent.TimeUnit

import android.content.Context
import androidx.work.*
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import org.json.JSONObject

import java.io.FileInputStream
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import org.apache.commons.net.ftp.FTPReply

import java.net.URL
import java.net.HttpURLConnection
import android.util.Base64
import android.app.Service

import android.util.Log
import android.content.Intent
import android.os.IBinder
import android.os.Build
import android.app.NotificationChannel
import android.app.NotificationManager
import androidx.core.app.NotificationCompat
import java.nio.file.StandardWatchEventKinds
import java.nio.file.*
import java.time.Duration
import timber.log.Timber
import android.os.Handler
import android.os.Looper
private var scheduledExecutor: ScheduledExecutorService? = null
private val startHour = 8 // Начало рабочего дня
private val endHour = 23 // Конец рабочего дня
private var sendingsPerDay = 0 // Количество отправок в день
private var methodConnecrting="ftp"
private var passwordH=""
private var loginH=""
private var hostH=""
private var httpH=""
private var httpPrefix=""
private var portH=21

data class ApiSettings(
    val prefix: String,
    val login: String,
    val password: String,
    val host: String,
    val httpurl: String,
    val port: Int,
    val frequency: Int,
    val method: String,
    val separators: String
)
class FileWatcherService : Service() {
private var fileObserver: FileObserver? = null
private val fileObservers = mutableListOf<FileObserver>()
private var trackingEnabled = false
private var lastDirEventTime: LocalDateTime? = null
companion object {
const val CHANNEL = "samples.flutter.dev/files"
private var instance: FileWatcherService? = null
 const val MIN_EVENTS = 2
 
fun getInstance(): FileWatcherService? = instance
}

override fun onCreate() {
super.onCreate()
Timber.plant(Timber.DebugTree()) // дерево для отладочного режима
instance = this
startForeground()
}

override fun onBind(intent: Intent?): IBinder? = null


override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
return START_STICKY
}

private fun startForeground() {
// Создаем notification channel для Android 8.0 и выше
if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
val channel = NotificationChannel(
"file_watcher_channel",
"File Watcher Service",
NotificationManager.IMPORTANCE_LOW
)
val notificationManager = getSystemService(NotificationManager::class.java)
notificationManager.createNotificationChannel(channel)
}

// Создаем уведомление
val notification = NotificationCompat.Builder(this, "file_watcher_channel")
.setContentTitle("Аудит File Logger 2.0")
.setContentText("Сервис запущен")
.setSmallIcon(R.drawable.ic_notification)
.build()

startForeground(1, notification)
}

fun toggleTracking() {
if (fileObserver == null) {
fetchDirectoriesAndStartWatching()
CoroutineScope(Dispatchers.IO).launch {
scheduleFileSending(applicationContext)
}
}
toggleFileObserver()
}
class MyUtils {
    companion object {
        @JvmStatic
        val DIRECTORY_LIST_TYPE = object : TypeToken<List<Directory>>() {}.type
    }
}
data class Directory(val id: String, val directory_path: String)

fun fetchDirectoriesAndStartWatching() {
    val client = OkHttpClient()
    val request = Request.Builder()
        .url("https://ivnovav.ru/logger_api/get_directory.php")
        .build()

    client.newCall(request).enqueue(object : okhttp3.Callback {
        override fun onFailure(call: okhttp3.Call, e: IOException) {
            e.printStackTrace()
        }

        override fun onResponse(call: okhttp3.Call, response: okhttp3.Response) {
            response.use {
 if (!it.isSuccessful) throw IOException("Unexpected code ${response.code}")
        
        val responseBody = it.body!!.string()
        println("Response from server: $responseBody")

        // Использовать готовый TYPE из MyUtils
        val directories: List<Directory> = Gson().fromJson(responseBody, MyUtils.DIRECTORY_LIST_TYPE)


                // Проверяем каждую директорию на существование
                val existingDirectories = directories.filter { dir ->
                    File(dir.directory_path).exists()
                }.map { dir ->
                    dir.directory_path.replace("\\", "") // Очистка пути от слэшей
                }

                println("Existing directory paths: $existingDirectories")

                // Передаем только существующие директории дальше
                initializeFileObservers(existingDirectories)
            }
        }
    })
}


// Переменная для хранения временных меток последних событий по каждому пути
private val lastEventsByPath = mutableMapOf<Path, LocalDateTime>()
var lastEventTimes = mutableMapOf<File, LocalDateTime>()

private val fileEventCounter = mutableMapOf<String, Int>()

private fun initializeFileObservers(pathsToWatch: List<String>) {
    var prefix1 = "_default"
    var separators = "0"

    runBlocking {
        try {
            val client = OkHttpClient()
            val request = Request.Builder()
                .url("https://ivnovav.ru/logger_api/getSettings.php")
                .build()

            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) throw IOException("Unexpected code $response")

                val responseBody = response.body?.string() ?: throw IOException("Response body is null")
                val gson = Gson()
                val apiSettings = gson.fromJson(responseBody, ApiSettings::class.java)

                val ftpClient = FTPClient()
                ftpClient.connect(apiSettings.host, apiSettings.port)
                ftpClient.login(apiSettings.login, apiSettings.password)
                ftpClient.enterLocalPassiveMode()
                ftpClient.setFileType(FTP.BINARY_FILE_TYPE)

                prefix1 = apiSettings.prefix
                separators = apiSettings.separators
                ftpClient.logout()
                ftpClient.disconnect()
            }
        } catch (e: Exception) {
            println("Error getting prefix: ${e.message}")
        }
    }

    val watchedDirectories = mutableListOf<String>()
    pathsToWatch.forEach { pathToWatch ->
        val directory = File(pathToWatch)
        if (directory.exists() && directory.isDirectory && directory.canRead()) {
            val fileObserver = object : FileObserver(pathToWatch, FileObserver.ALL_EVENTS) {
override fun onEvent(event: Int, path: String?) {
    if (path != null) {
        val fullPath = File(pathToWatch, path)
    
if ((event == FileObserver.ACCESS || event == FileObserver.MODIFY || event == FileObserver.OPEN) && 
    fullPath.exists() && !fullPath.isDirectory && fullPath.extension.isNotBlank()) {
    
    // Базовые проверки
    if (!fullPath.canRead() || fullPath.length() == 0L) return
    
    // Проверка расширения
    val allowedExtensions = listOf(
        // Документы
        "doc", "docx", "pdf", "txt", "xls", "xlsx", "rtf", "odt", "ods",
        // Изображения
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "svg", "raw", "cr2", "nef",
        // Видео
        "mp4", "avi", "mkv", "mov", "wmv", "flv", "webm", "m4v", "mpeg", "mpg", "3gp"
    )
    
if (!allowedExtensions.contains(fullPath.extension.lowercase())) return
    
    // Проверка временных файлов
    if (fullPath.name.startsWith("~$") || fullPath.name.startsWith(".~")) return
    
    // Проверка минимального размера
    if (fullPath.length() < 1024L) return
    
    // Проверка количества событий
    val filePath = fullPath.absolutePath
    val eventCount = fileEventCounter.getOrDefault(filePath, 0) + 1
    fileEventCounter[filePath] = eventCount
    if (eventCount < MIN_EVENTS) return

    val now = LocalDateTime.now()
    val currentTime = LocalDateTime.now()
    val previousEventTime = lastEventsByPath[Paths.get(pathToWatch)]
    val previousDirEventTime = lastDirEventTime

    // Пропускаем событие, если после изменения директории прошло менее 3 секунд
    if (previousDirEventTime != null && Duration.between(previousDirEventTime, currentTime).seconds < 3L) {
        return
    }

    // Пропускаем событие, если интервал меньше 2 секунд
    if (previousEventTime != null && Duration.between(previousEventTime, currentTime).seconds < 2L) {
        return
    }

    val dateFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")
    val timeFormatter = DateTimeFormatter.ofPattern("HH:mm:ss")
    val timeFormatterf = DateTimeFormatter.ofPattern("HHmm")
    val dateFormatterf = DateTimeFormatter.ofPattern("ddMMyy")

    println("Event: $event at path: $fullPath.absolutePath on ${LocalDateTime.now()}")

    // Директория хранения логов
    val appDir = File(getExternalFilesDir(null), "logs")
    if (!appDir.exists()) {
        appDir.mkdirs()
    }

    // Поиск подходящего CSV файла
    val csvFile = appDir.listFiles { file ->
        file.name.endsWith(".csv")
    }?.firstOrNull() ?: File(appDir, "${prefix1}_${now.format(dateFormatterf)}_${now.format(timeFormatterf)}.csv")

    try {
        if (!csvFile.exists()) {
            csvFile.createNewFile()
        }
    
        // Подготовка записи
        val newEntry = when(separators.toInt()) {
            1 -> listOf(fullPath.absolutePath, now.format(dateFormatter), now.format(timeFormatter)).joinToString(",")
            else -> "${fullPath.absolutePath}${fullPath.name}${now.format(dateFormatter)}${now.format(timeFormatter)}"
        }.plus("\n")
    
        println("Adding entry for file: $fullPath")
    
        // Добавление записи в CSV
        csvFile.appendText(newEntry)
        println("Successfully added entry to $csvFile: $newEntry")
    
        // Сохраняем новую временную отметку
        lastEventsByPath[Paths.get(pathToWatch)] = currentTime
    } catch (e: Exception) {
        e.printStackTrace()
        println("Error writing to CSV: ${e.message}")
    }
}

// Добавляем обработку события изменения директории
if (fullPath.isDirectory) {
    lastDirEventTime = LocalDateTime.now() // Сохраняем время события директории
}    }
}
            }

            fileObserver.startWatching()
            fileObservers.add(fileObserver)
            watchedDirectories.add(pathToWatch)
        } else {
            println("Directory $pathToWatch cannot be read or does not exist.")
        }
    }

    if (watchedDirectories.isNotEmpty()) {
        println("Watching directories: $watchedDirectories")
    }
}

private suspend fun scheduleFileSending(context: Context) {
withContext(Dispatchers.IO) {
try {
val client = OkHttpClient()
val request = Request.Builder()
.url("https://ivnovav.ru/logger_api/getSettings.php")
.build()

client.newCall(request).execute().use { response ->
if (!response.isSuccessful) throw IOException("Unexpected code $response")

val responseBody = response.body?.string() ?: throw IOException("Response body is null")
val gson = Gson()
val apiSettings = gson.fromJson(responseBody, ApiSettings::class.java)

val ftpClient = FTPClient()
ftpClient.connect(apiSettings.host, apiSettings.port)
ftpClient.login(apiSettings.login, apiSettings.password)
ftpClient.enterLocalPassiveMode()
ftpClient.setFileType(FTP.BINARY_FILE_TYPE)

sendingsPerDay = apiSettings.frequency
methodConnecrting = apiSettings.method
println("testd")
println(apiSettings.frequency)
ftpClient.logout()
ftpClient.disconnect()
}
} catch (e: Exception) {
println("Error getting prefix: ${e.message}")
}
}

    if (scheduledExecutor != null) {
        scheduledExecutor?.shutdown()
    }

    scheduledExecutor = Executors.newSingleThreadScheduledExecutor()

    // Рассчитываем интервалы отправки


val workingHours = endHour - startHour
println("Количество отправок в день: $sendingsPerDay")

// Безопасное деление с проверкой на ноль
val intervalHours = workingHours.toDouble() / (if (sendingsPerDay <= 0) 1 else sendingsPerDay).toDouble()


    // Получаем текущее время
    val now = Calendar.getInstance()

    // Планируем отправки на сегодня
    for (i in 0 until sendingsPerDay) {
        val sendingTime = Calendar.getInstance()
    // Округляем сумму часов до целого числа
    sendingTime.set(
        Calendar.HOUR_OF_DAY,
        (startHour + (i * intervalHours)).toInt() // Преобразуем double в Int
    )
        sendingTime.set(Calendar.MINUTE, 0)
        sendingTime.set(Calendar.SECOND, 0)

        // Если время отправки уже прошло сегодня, планируем на завтра
        if (sendingTime.before(now)) {
            sendingTime.add(Calendar.DAY_OF_MONTH, 1)
        }

        val delay = sendingTime.timeInMillis - now.timeInMillis

        scheduledExecutor?.schedule({
             CoroutineScope(Dispatchers.IO).launch {
            sendFiles(context, methodConnecrting)   
                 }    // Передаем контекст
            scheduleNextDaySending(context, sendingTime, methodConnecrting) // И сюда передаем контекст
        }, delay, TimeUnit.MILLISECONDS)
    }
}

private fun scheduleNextDaySending(context: Context, previousTime: Calendar, methodConnecrting: String) {
    val nextDay = Calendar.getInstance()
    nextDay.timeInMillis = previousTime.timeInMillis
    nextDay.add(Calendar.DAY_OF_MONTH, 1)

    val now = Calendar.getInstance()
    val delay = nextDay.timeInMillis - now.timeInMillis

    scheduledExecutor?.schedule({
         CoroutineScope(Dispatchers.IO).launch {
        sendFiles(context, methodConnecrting)   
            }   // Опять передаем контекст
        scheduleNextDaySending(context, nextDay, methodConnecrting) // Тут тоже передаем контекст
    }, delay, TimeUnit.MILLISECONDS)
}
internal suspend fun sendFiles(context: Context, method: String): Boolean {
    return runBlocking {
        try {
            val client = OkHttpClient()
            val request = Request.Builder()
                .url("https://ivnovav.ru/logger_api/getSettings.php")
                .build()

            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) throw IOException("Unexpected code $response")

                val responseBody = response.body?.string() ?: throw IOException("Response body is null")
                val gson = Gson()
                val apiSettings = gson.fromJson(responseBody, ApiSettings::class.java)

                val ftpClient = FTPClient()
                ftpClient.connect(apiSettings.host, apiSettings.port)
                ftpClient.login(apiSettings.login, apiSettings.password)
                ftpClient.enterLocalPassiveMode()
                ftpClient.setFileType(FTP.BINARY_FILE_TYPE)
                passwordH = apiSettings.password
                loginH = apiSettings.login
                hostH = apiSettings.host
                httpH = apiSettings.httpurl
                portH = apiSettings.port
                sendingsPerDay = apiSettings.frequency
                methodConnecrting = apiSettings.method
                httpPrefix= apiSettings.prefix
                ftpClient.logout()
                ftpClient.disconnect()
            }
        } catch (e: Exception) {
            println("Error getting prefix: ${e.message}")
            return@runBlocking false
        }
    
        if (scheduledExecutor != null) {
            scheduledExecutor?.shutdown()
        }

        try {
            val logsDir = File(context.getExternalFilesDir(null), "logs")
            val csvFile = logsDir.walkTopDown().filter { it.extension == "csv" }.firstOrNull()
            
            if (csvFile == null) {
                println("CSV файл не найден")
                return@runBlocking false
            }
        
            println(csvFile)
            println(methodConnecrting)
            when (methodConnecrting.lowercase()) {
                "ftp" -> {
                    val ftpClient = FTPClient()
                    val ftpHost = hostH
                    val ftpPort = portH
                    val ftpUsername = loginH
                    val ftpPassword = passwordH
                    var inputStream: FileInputStream? = null

                    try {
                        println("Попытка подключения к FTP серверу $ftpHost:$ftpPort")
                        ftpClient.connect(ftpHost, ftpPort)
                        
                        // Проверка ответа после подключения
                        val replyCode = ftpClient.replyCode
                        if (!FTPReply.isPositiveCompletion(replyCode)) {
                            throw IOException("Ошибка подключения к FTP серверу. Код ответа: $replyCode")
                        }

                        println("Попытка входа с логином: $ftpUsername")
                        val loginSuccess = ftpClient.login(ftpUsername, ftpPassword)
                        if (!loginSuccess) {
                            throw IOException("Ошибка авторизации на FTP сервере")
                        }

                        println("Настройка параметров соединения")
                        ftpClient.enterLocalPassiveMode()
                        ftpClient.setFileType(FTP.BINARY_FILE_TYPE)

                        // Проверка существования файла
                        if (!csvFile.exists()) {
                            throw FileNotFoundException("Файл ${csvFile.name} не найден")
                        }

                        println("Начало загрузки файла: ${csvFile.name}")
                        inputStream = FileInputStream(csvFile)
                        val uploaded = ftpClient.storeFile(csvFile.name, inputStream)

                        if (uploaded) {
                            println("Файл успешно отправлен по FTP")
                            if (csvFile.delete()) {
                                println("Локальный файл успешно удален")
                            } else {
                                println("Не удалось удалить локальный файл")
                            }
                            return@runBlocking true
                        } else {
                            println("Ошибка при отправке файла по FTP")
                            println("Код ответа сервера: ${ftpClient.replyCode}")
                            println("Сообщение сервера: ${ftpClient.replyString}")
                            return@runBlocking false
                        }

                    } catch (e: FileNotFoundException) {
                        println("Ошибка: Файл не найден - ${e.message}")
                        e.printStackTrace()
                        return@runBlocking false
                    } catch (e: IOException) {
                        println("Ошибка ввода/вывода при работе с FTP: ${e.message}")
                        e.printStackTrace()
                        return@runBlocking false
                    } catch (e: Exception) {
                        println("Непредвиденная ошибка: ${e.message}")
                        e.printStackTrace()
                        return@runBlocking false
                    } finally {
                        try {
                            inputStream?.close()
                        } catch (e: IOException) {
                            println("Ошибка при закрытии потока: ${e.message}")
                        }

                        if (ftpClient.isConnected) {
                            try {
                                println("Отключение от FTP сервера")
                                ftpClient.logout()
                                ftpClient.disconnect()
                            } catch (e: IOException) {
                                println("Ошибка при отключении от FTP сервера: ${e.message}")
                            }
                        }
                    }
                }
                
                "http" -> {
                    val httpHost = httpH
                    val httpPort = portH
                    val httpUsername = loginH
                    val httpPassword = passwordH
                    val url = URL(httpHost)
                    val connection = url.openConnection() as HttpURLConnection

                    val jsonObject = JSONObject()
                    val dataArray = JSONArray()

                    csvFile.readLines().forEach { line ->
                        val values = line.split(",")
                        if (values.size >= 2) {
                            val entry = JSONObject()
                            
                            // Нормируем путь, убирая экранирование и заменяя его на относительный путь
                            val normalizedPath = values[0].trim().replace("\\", "/").replace("/storage/", "./storage/")
                            
                            // Сохраняем timestamp в нужном формате
                            val dateTime = values[1].trim()
                            val trTime = values[2].trim()
                            // Если необходимо, добавьте код для преобразования даты в нужный формат
                            // Например, если формат "YYYY-MM-DD" и нужно добавить время "HH:MM:SS":
                            val formattedDateTime = "$dateTime $trTime" // замените на нужное время, если оно есть
                            entry.put("date_time", formattedDateTime) // сохраняем timestamp
                            entry.put("file_name", normalizedPath) // сохраняем нормализованный путь
                            dataArray.put(entry)
                        }
                    }

                    // Создаем основной JSON объект
                    val mainObject = JSONObject()
                    mainObject.put("data", dataArray)
                    mainObject.put("$httpPrefix", "device name") // замените "device name" на фактическое имя устройства

                    // Преобразуем в строку JSON
                    val jsonString = mainObject.toString(4) // добавляем отступы для лучшей читаемости
                    println(jsonString)

                    jsonObject.put("data", dataArray)
                    jsonObject.put("$httpPrefix", "device name") // добавляем поле device
                    println(jsonObject.toString()) 
                    // Ваше подключение к серверу остается прежним...

                    try {
                        connection.requestMethod = "POST"
                        connection.setRequestProperty("Content-Type", "application/json")
                        connection.setRequestProperty("Accept", "application/json")
                        connection.setRequestProperty("X-Custom-Header", "custom-value")
                        connection.setRequestProperty(
                            "Authorization",
                            "Basic " + Base64.encodeToString("test.test:mECGHamla1".toByteArray(), Base64.NO_WRAP)
                        )
                        connection.doOutput = true

                        connection.outputStream.use { os ->
                            val input = jsonObject.toString().toByteArray(Charsets.UTF_8)
                            os.write(input, 0, input.size)
                        }

                        when (connection.responseCode) {
                            in 200..299 -> {
                                Timber.i("Данные успешно отправлены на сервер.")
                                csvFile.delete()
                                return@runBlocking true
                            }
                            else -> {
                                Timber.e("Ошибка при отправке данных: ${connection.responseCode}")
                                return@runBlocking false
                            }
                        }
                    } catch (e: Exception) {
                        Timber.e(e, "Исключение при отправке данных")
                        return@runBlocking false
                    } finally {
                        connection.disconnect()
                    }
                }
                else -> {
                    println("Неизвестный метод отправки")
                    return@runBlocking false
                }
            }
        } catch (e: Exception) {
            println("Ошибка при отправке файла: ${e.message}")
            return@runBlocking false
        }
    }
}

// Не забудьте освободить ресурсы при завершении работы
private fun cleanup() {
scheduledExecutor?.shutdown()
try {
if (scheduledExecutor?.awaitTermination(1, TimeUnit.SECONDS) == false) {
scheduledExecutor?.shutdownNow()
}
} catch (e: InterruptedException) {
scheduledExecutor?.shutdownNow()
}
}


fun stopForegroundService() {
    // Удаляем foreground статус и останавливаем сервис
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        stopForeground(STOP_FOREGROUND_REMOVE)
    } else {
        stopForeground(true)
    }
    
    // Остановка самого сервиса
    stopSelf()
}
private fun toggleFileObserver() {
trackingEnabled = !trackingEnabled
if (trackingEnabled) {
fileObserver?.startWatching()
} else {
fileObserver?.stopWatching()
        stopForegroundService() // Добавляем вызов метода для остановки сервиса и удаления уведомления

}
}



fun isTrackingEnabled() = trackingEnabled
}

// В вашей Activity или Application классе
class MainActivity : FlutterActivity() {

    private val REQUEST_PERMISSION_CODE = 100
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Устанавливаем обработчик каналов Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FileWatcherService.CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
"toggleTracking" -> {
    val serviceIntent = Intent(this, FileWatcherService::class.java)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        startForegroundService(serviceIntent)
    } else {
        startService(serviceIntent)
    }
    
    Handler(Looper.getMainLooper()).postDelayed({
        FileWatcherService.getInstance()?.toggleTracking()
        result.success(FileWatcherService.getInstance()?.isTrackingEnabled())
    }, 500) // задержка в 500 миллисекунд
}
                    "isTrackingEnabled" -> {
                        result.success(FileWatcherService.getInstance()?.isTrackingEnabled())
                    }

"sendFiles" -> {
    CoroutineScope(Dispatchers.IO).launch {
        try {
            val success = FileWatcherService.getInstance()?.sendFiles(applicationContext, "ftp")

            withContext(Dispatchers.Main) {
                when {
                    success == null -> {
                        result.error(
                            "SERVICE_UNAVAILABLE",
                            "Сервис недоступен",
                            null
                        )
                    }
                    success -> {
                        result.success("Файл успешно отправлен")
                    }
                    else -> {
                        result.error(
                            "SEND_ERROR",
                            "Ошибка при отправке файла",
                            null
                        )
                    }
                }
            }
        } catch (e: Exception) {
            withContext(Dispatchers.Main) {
                result.error(
                    "SEND_ERROR",
                    "Ошибка при отправке файла",
                    e.message
                )
            }
        }
    }
}                }
            }

        // Проверяем разрешения
        checkPermissions()


    }

    private fun checkPermissions() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE),
                               REQUEST_PERMISSION_CODE)
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_PERMISSION_CODE && grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
            Log.i("PERMISSIONS", "Все разрешения предоставлены")
        } else {
            Log.e("PERMISSIONS", "Необходимо предоставить разрешения для нормальной работы приложения")
        }
    }
}