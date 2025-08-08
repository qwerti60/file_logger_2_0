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
import java.time.temporal.ChronoUnit
 
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
import kotlin.math.abs

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

import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicInteger
import android.media.MediaMetadataRetriever
import java.nio.file.Paths
import java.util.*

import java.time.*
import java.nio.file.Files
import java.nio.charset.StandardCharsets
import java.util.concurrent.locks.ReentrantLock

import java.text.SimpleDateFormat
import java.util.Locale      // and Date if you also use it
// import java.util.Date


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
private var separator="1"
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

// Глобальный список зарегистрированных видео
val loggedVideos = mutableSetOf<String>()
companion object {
const val CHANNEL = "samples.flutter.dev/files"
private var instance: FileWatcherService? = null
 const val MIN_EVENTS = 2
 
fun getInstance(): FileWatcherService? = instance
}

    override fun onDestroy() {
        super.onDestroy()
        cleanup()
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
        fetchDirectoriesAndStartWatching(applicationContext)
        CoroutineScope(Dispatchers.IO).launch {
            scheduleFileSending(applicationContext)
        }
    }
    toggleFileObserver()
}
// Новый класс Directory заменяется простым списком строк
fun fetchDirectoriesAndStartWatching(context: Context) {
    try {
        // Читаем файл из внутреннего хранилища
        val jsonFileString = readFromInternalStorage()
        
        if (jsonFileString.isNullOrEmpty()) {
            throw IllegalArgumentException("No valid directories.json file found!")
        }

        println("JSON content: $jsonFileString")

        // Преобразование JSON-массива строк в обычный List<String>
        val directories: List<String> = Gson().fromJson(jsonFileString, object : TypeToken<List<String>>(){}.type)

        // Проверяем каждую директорию на существование
        val existingDirectories = directories.filter { dir ->
            File(dir).exists()
        }

        println("Existing directory paths: $existingDirectories")

        // Передаем только существующие директории дальше
        initializeFileObservers(existingDirectories,applicationContext)

    } catch (e: Exception) {
        println("Error reading directories: ${e.message}")
        e.printStackTrace()
    }
}
// Функция для чтения файла из внутреннего хранилища
private fun readFromInternalStorage(): String? {
    val context = applicationContext
    val appDir = context.getFilesDir()?.parentFile?.absolutePath ?: return null
    val filePath = "$appDir/app_flutter/directories.json"
    val file = File(filePath)

    if (!file.exists()) {
        Log.w("FileReader", "File not found: $filePath")
        return null
    }

    return file.readText(Charsets.UTF_8)
}


// Переменная для хранения временных меток последних событий по каждому пути
private val lastEventsByPath = mutableMapOf<Path, LocalDateTime>()
var lastEventTimes = mutableMapOf<File, LocalDateTime>()

private val fileEventCounter = mutableMapOf<String, Int>()
    private var lastAccessTime: LocalDateTime = LocalDateTime.MIN
    private var currentTime: LocalDateTime = LocalDateTime.now()
    private val duration: Long = 1000L // Минимальная задержка между двумя событиями
    var prefix1 = "_default"
    private fun initializeFileObservers(pathsToWatch: List<String>, context: Context) {

    var separators = "0"

 
runBlocking {
    try {

        // Получаем остальные настройки из API
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

            // Используем только separators из API
            separators = apiSettings.separators
            
            ftpClient.logout()
            ftpClient.disconnect()
        }
    } catch (e: Exception) {
        println("Error getting settings: ${e.message}")
        // В случае ошибки при получении separators можно установить значение по умолчанию
       // separators = listOf("_default_separator")
    }
}

    val watchedDirectories = mutableListOf<String>()
    pathsToWatch.forEach { pathToWatch ->
        val directory = File(pathToWatch)
        if (directory.exists() && directory.isDirectory && directory.canRead()) {
            val fileObserver = object : FileObserver(pathToWatch, FileObserver.ALL_EVENTS) {

// Хранилище времени последнего обращения к файлам
var lastEventsByPath = ConcurrentHashMap<String, LocalDateTime>()

// Набор зарегистрированных видеофайлов
val registeredVideos = HashSet<String>()
var lastOpenTime = System.currentTimeMillis()
val recentlyOpenedFiles = mutableSetOf<String>()

    private val videoExtensions = setOf("mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "mpeg", "mpg", "3gp")
    private val documentAndImageExtensions = setOf(
        "doc", "docx", "pdf", "txt", "xls", "xlsx", "rtf", "odt", "ods",
        "jpg", "gif", "jpeg", "png", "gif", "bmp", "tiff", "webp", "svg", "raw", "cr2", "nef"
    )
private val recentEventsCounter = AtomicInteger(0)
override fun onEvent(event: Int, path: String?) {
    if (path != null) {
        val fullPath = File(pathToWatch, path)
        
        if ((event != FileObserver.OPEN||event != FileObserver.ACCESS) && fullPath.extension.isNotBlank()) {
            
            // Проверка читаемости файла и размера
            if (!fullPath.canRead() || fullPath.length() == 0L) {
                println("Skipped unreadable or empty file: $fullPath")
                return
            }

            // Проверка временного имени и малого размера файла
            if (fullPath.name.startsWith("~$") || fullPath.name.startsWith(".~")) {
                println("Skipped temporary file: $fullPath")
                return
            }
            if (fullPath.length() < 1024L) {
                println("Skipped small file: $fullPath")
                return
            }
            val now = System.currentTimeMillis()
            if ((now - lastOpenTime) < 3000L) {
                println("Skipped too-frequent event: $fullPath")
                return
            }
            
            lastOpenTime = now


            // Получаем абсолютный путь
            val absolutePath = fullPath.absolutePath

            // Проверка расширения файла
            val ext = fullPath.extension.lowercase()

            // Исключаем APK-файлы
            if (ext == "apk") {
                println("Skipped APK file: $fullPath")
                return
            }

            // Логика обработки файлов
            when {
                videoExtensions.contains(ext) -> handleVideoFile(fullPath)
                documentAndImageExtensions.contains(ext) -> handleDocumentOrImageFile(fullPath)
                else -> println("Unknown file type skipped: $absolutePath")
            }
        }
    }
}

private fun handleVideoFile(file: File) {
    val absolutePath = file.absolutePath
    
    // Если видео уже зарегистрировано, пропускаем событие
    if (registeredVideos.contains(absolutePath)) {
        println("Skipped duplicate video log: $absolutePath")
        // Очищаем регистрации других видео
        registeredVideos.clear()
        return
    }

    // Добавляем запись и помечаем её как зарегистрированную
    println("Adding video to CSV: $absolutePath")
    synchronized(this) {
        addCsvRecord(file)
    }
    // Очищаем предыдущие регистрации и добавляем текущее видео
    registeredVideos.clear()
    registeredVideos.add(absolutePath)
}

private fun handleDocumentOrImageFile(file: File) {
    val absolutePath = file.absolutePath
    val previousEventTime = lastEventsByPath[absolutePath]
    val currentTime = LocalDateTime.now()
    
    // Счетчик событий в короткий промежуток времени
    var recentEventsCount = recentEventsCounter.get() // Используем get() вместо getOrDefault
    
    if (previousEventTime != null) {
        val interval = Duration.between(previousEventTime, currentTime)
        
        // Увеличенный интервал для игнорирования частых событий (например, 1 секунда)
        if (interval.toMillis() < 2000) { 
            recentEventsCount++
            recentEventsCounter.set(recentEventsCount)
            
            // Если много событий за короткий промежуток — вероятно это скроллинг или смена директории
            if (recentEventsCount > 5) {
                println("Skipping bulk changes: $absolutePath")
                return
            }
            
            println("Skipped frequent event: $absolutePath ($interval)")
            return
        } else {
            // Сбрасываем счетчик, если прошло достаточно времени
            recentEventsCounter.set(0)
        }
    }
    
    // Обновляем время последнего события
    lastEventsByPath[absolutePath] = currentTime
    
    // Подтверждаем успешное чтение файла перед добавлением в CSV
    try {
        BufferedReader(FileReader(file)).use { reader ->
            reader.readLine() // Пробуем прочитать первую строку
            println("Successfully read first line from: $file")
        }
    } catch (ex: IOException) {
        println("Failed to open file for reading: ${file.absolutePath}")
        return
    }

    // Добавляем запись
    println("Adding non-video file to CSV: $absolutePath")
    synchronized(this) {
        addCsvRecord(file)
    }
}
// Лок для предотвращения одновременного доступа к операции записи
private val lock = ReentrantLock()

fun Context.addCsvRecord(fullPath: File) {
    synchronized(lock) {
        fun readPrefix(): String {
            val context = this
            val appDir = context.filesDir?.parentFile?.absolutePath ?: run {
                Log.e("FileError", "Файловые пути не найдены.")
                return ""
            }
            val filePath = "$appDir/app_flutter/prefix.txt"
            val file = File(filePath)
            
            return if (file.exists()) {
                file.readText().trim()
            } else {
                "_default"
            }
        }
        
        val prefix1 = readPrefix()
    
        val now = LocalDateTime.now()
        val dateFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd")
        val timeFormatter = DateTimeFormatter.ofPattern("HH:mm:ss")
        val timeFormatterf = DateTimeFormatter.ofPattern("HHmm")
        val dateFormatterf = DateTimeFormatter.ofPattern("ddMMyy")
    
        // Директория для логов
        val appDir = File(getExternalFilesDir(null), "logs")
        if (!appDir.exists()) {
            if (!appDir.mkdirs()) {
                throw IOException("Failed to create directory: ${appDir.path}")
            }
        }
    
        // Получаем путь к существующему CSV-файлу или создаем новый
        val csvFile = appDir.listFiles { file -> file.name.endsWith(".csv") }?.firstOrNull()
            ?: File(appDir, "${prefix1}_${now.format(dateFormatterf)}_${now.format(timeFormatterf)}.csv").apply {
                writeText("\n")
            }
    
        try {
            println("Debug: Starting CSV operation")
            println("Debug: CSV file exists: ${csvFile.exists()}")
            println("Debug: CSV file length: ${csvFile.length()}")
    
            // Формат даты и времени
            val dateFormat = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")
    
            // Новая запись
            val separators = 1 // Предположительно используем дефолтный вариант разделения полей
            val newEntry = "${fullPath.absolutePath},${now.format(dateFormatter)},${now.format(timeFormatter)}"
            println("Debug: New entry formed: $newEntry")
    
            // Преобразование временной метки новой записи
            val newDateTimeParsed = LocalDateTime.parse("${now.format(dateFormatter)} ${now.format(timeFormatter)}", dateFormat)
            println("Debug: New DateTime parsed as: $newDateTimeParsed")
    
            // Чтение существующих строк из файла
            val existingLines = if (csvFile.exists() && csvFile.length() > 0L) {
                csvFile.readLines().also {
                    println("Debug: Read ${it.size} existing lines")
                }
            } else {
                mutableListOf()
            }.toMutableList()
    
            // Удаляем повторяющиеся строки
            val updatedLines = existingLines.filterNot { line ->
                try {
                    val fields = line.split(",").map { it.trim() }
                    if (fields.size == 3) {
                        val existingDateTimeStr = "${fields[1]} ${fields[2]}"
                        val existingDateTimeParsed = LocalDateTime.parse(existingDateTimeStr, dateFormat)
                        
                        // Проверка временного интервала между новыми и старыми записями
                        val timeDiffInMillis = abs(ChronoUnit.MILLIS.between(existingDateTimeParsed, newDateTimeParsed))
                        
                        // Если интервал меньше 2 секунд — считаем запись дублем
                        val isDuplicate = (existingDateTimeParsed == newDateTimeParsed) || (timeDiffInMillis < 2000)
                        println("Debug: Line: $line, Time difference: $timeDiffInMillis ms, Is duplicate: $isDuplicate")
                        isDuplicate
                    } else {
                        false
                    }
                } catch (e: Exception) {
                    println("Debug: Error processing line '$line': ${e.message}")
                    false
                }
            }.toMutableList()
    
            // Добавляем новую запись, если нет конфликта
            if (updatedLines.size == existingLines.size) {
                updatedLines.add(newEntry)
            }
    
            // Перезапись обновленных данных в файл
            try {
                Files.write(
                    Paths.get(csvFile.absolutePath),
                    updatedLines,
                    StandardCharsets.UTF_8
                )
                println("Debug: Written ${updatedLines.size} lines to file")
            } catch (e: Exception) {
                println("Debug: Error writing to file: ${e.message}")
                throw e
            }
    
            println("Success: Added record to CSV: $newEntry")
            println("File path: ${csvFile.absolutePath}")
            println("Number of records: ${updatedLines.size}")
        } catch (e: Exception) {
            e.printStackTrace()
            println("Error adding record to CSV: ${e.message}")
        }
    }
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

private val timeFmt = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
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

    require(startHour in 0..23 && endHour in 1..24 && startHour < endHour)
    require(sendingsPerDay > 0)

    val workMinutes   = (endHour - startHour) * 60
    val intervalMin   = workMinutes / sendingsPerDay   // равный интервал
    val sendTimes     = mutableListOf<LocalTime>()

    // 1. Считаем «чистое» время-дня для каждой отправки
    repeat(sendingsPerDay) { index ->
        val total = index * intervalMin
        val hour  = startHour + total / 60
        val min   = total % 60
        sendTimes += LocalTime.of(hour, min)
    }

    println("Время ежедневных отправок: $sendTimes")

    // 2. Планируем каждую отправку отдельно
    sendTimes.forEachIndexed { i, time ->
        val firstDelay = delayUntil(time)
        println(
            "Отправка №${i + 1} первое срабатывание через ${firstDelay / 1000} сек. " +
            "($time сегодняшнего/завтрашнего дня)"
        )

        scheduler.scheduleAtFixedRate(
            {
                CoroutineScope(Dispatchers.IO).launch {
                    sendFiles(context, methodConnecrting)
                }
            },
            firstDelay,                           // initialDelay
            TimeUnit.DAYS.toMillis(1),            // период 24 ч
            TimeUnit.MILLISECONDS
        )
    }
}
private val scheduler = Executors.newScheduledThreadPool(1)
/* Сколько миллисекунд осталось до ближайшего наступления `time` сегодня/завтра. */
private fun delayUntil(time: LocalTime): Long {
    val now     = LocalDateTime.now()
    var nextRun = now.withHour(time.hour)
                     .withMinute(time.minute)
                     .withSecond(0)
                     .withNano(0)

    if (nextRun.isBefore(now)) nextRun = nextRun.plusDays(1)   // уже прошло – переносим на завтра
    return Duration.between(now, nextRun).toMillis()
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
                separator = apiSettings.separators
                httpPrefix= prefix1
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
                        else {
                                val appDir = File(getExternalFilesDir(null), "logs") // получаем директорию приложения

val csvFile = File(appDir, csvFile.name) // создаем путь к CSV файлу

reformatCsvFile(csvFile, separator.toInt())
                           // convertJsonToCsv(csvFile.name, separator.toInt())
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


fun reformatCsvFile(file: File, separator: Int) {
println("Starting CSV file reformatting...")
println("Input file: ${file.absolutePath}")
println("Selected separator: $separator")

try {
// Проверяем корректность separator
val delimiterChar = when (separator) {
0 -> ','
1 -> ';'
else -> {
println("Error: Invalid separator value ($separator). Must be 0 (comma) or 1 (semicolon)")
throw IllegalArgumentException("Separator must be 0 (comma) or 1 (semicolon)")
}
}
println("Using delimiter: '$delimiterChar'")

// Читаем все строки из файла
println("Reading file contents...")
val lines = file.readLines()
println("Read ${lines.size} lines from file")

// Создаем форматтеры для парсинга и форматирования даты/времени
println("Initializing date/time formatters...")
val inputFormatter = DateTimeFormatter.ofPattern("yyyy-MM-dd,HH:mm:ss")
val dateOutputFormatter = DateTimeFormatter.ofPattern("dd.MM.yyyy")
val timeOutputFormatter = DateTimeFormatter.ofPattern("HH:mm")

// Преобразуем строки
println("Processing lines...")
var processedLines = 0
var skippedLines = 0

val newLines = lines.map { line ->
try {
val parts = line.split(',')
if (parts.size < 3) {
println("Warning: Invalid line format: $line")
skippedLines++
return@map line
}

val filePath = parts[0]
val dateTimeStr = "${parts[1]},${parts[2]}"

// Парсим дату/время
val dateTime = LocalDateTime.parse(dateTimeStr, inputFormatter)

// Форматируем в новый формат
val newDate = dateTime.format(dateOutputFormatter)
val newTime = dateTime.format(timeOutputFormatter)

processedLines++
"$filePath$delimiterChar$newDate, $newTime"
} catch (e: Exception) {
println("Warning: Error processing line: $line")
println("Error details: ${e.message}")
skippedLines++
line
}
}

// Записываем обновленные строки обратно в файл
println("Writing processed data back to file...")
file.writeText(newLines.joinToString("\n"))

println("File processing completed:")
println("- Total lines: ${lines.size}")
println("- Successfully processed: $processedLines")
println("- Skipped/unchanged: $skippedLines")

} catch (e: Exception) {
println("Critical error processing file:")
println("Error type: ${e.javaClass.simpleName}")
println("Error message: ${e.message}")
e.printStackTrace()
}

println("Operation finished")
}

    /**
     * Чистка и освобождение ресурсов при завершении работы сервиса.
     */
    private fun cleanup() {
        // Останавливаем все активные наблюдатели
        fileObservers.forEach { observer ->
            observer.stopWatching()
        }
        fileObservers.clear()

        // Отменяем все запланированные задачи
        scheduledExecutor?.shutdown()
        try {
            if (scheduledExecutor?.awaitTermination(1, TimeUnit.SECONDS) == false) {
                scheduledExecutor?.shutdownNow()
            }
        } catch (e: InterruptedException) {
            scheduledExecutor?.shutdownNow()
        }
        scheduledExecutor = null
    }
   /**
     * Завершаем фореграунд-статус и сами себя уничтожаем.
     */
    fun stopForegroundService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            stopForeground(true)
        }
        stopSelf()
    }


    /**
     * Переключает режим трекинга.
     */
    private fun toggleFileObserver() {
        trackingEnabled = !trackingEnabled
        if (trackingEnabled) {
            fileObserver?.startWatching()
        } else {
            fileObserver?.stopWatching()
            stopForegroundService() // Обязательно вызываем остановку фореграунд-сервисов
        }
    }

fun isTrackingEnabled() = trackingEnabled
}

// В вашей Activity или Application классе
class MainActivity : FlutterActivity() {

    private val REQUEST_PERMISSION_CODE = 100
    
override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

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
                    }, 500)
                }
                "isTrackingEnabled" -> {
                    result.success(FileWatcherService.getInstance()?.isTrackingEnabled())
                }
                "sendFiles" -> {
    CoroutineScope(Dispatchers.IO).launch {
        try {
            // Сначала проверяем, активен ли трекинг
            val instance = FileWatcherService.getInstance()
            if (instance == null || !instance.isTrackingEnabled()) {
                withContext(Dispatchers.Main) {
                    result.error("TRACKING_DISABLED", "Для тестового запроса отправки файла, включите сервис.", null)
                }
                return@launch
            }

            // Сервис активен, отправляем файлы
            val success = instance.sendFiles(applicationContext, "ftp")

            withContext(Dispatchers.Main) {
                when {
                    success == null -> {
                        result.error("SERVICE_UNAVAILABLE", "Сервис недоступен", null)
                    }
                    success -> {
                        result.success("Файл успешно отправлен")
                    }
                    else -> {
                        result.error("SEND_ERROR", "Ошибка при отправке файла", null)
                    }
                }
            }
        } catch (e: Exception) {
            withContext(Dispatchers.Main) {
                result.error("SEND_ERROR", "Ошибка при отправке файла", e.message)
            }
        }
    }
}
            }
        }

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