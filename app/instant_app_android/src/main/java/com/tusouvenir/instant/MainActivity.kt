package com.tusouvenir.instant

import android.os.Bundle
import android.content.Intent
import android.net.Uri
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.grid.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.URL

class MainActivity : ComponentActivity() {
    private val SUPABASE_URL = "https://apknmsbrbmtjidmrngnk.supabase.co"
    private val SUPABASE_KEY = "sb_publishable_1ZymSc3eQia5scNC2mmWXw_ke1Wlppb"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Extract UUID from NFC URL: https://tomas-falcon.github.io/souvenir-config/m/{uuid}
        val data: Uri? = intent.data
        val uuid = data?.lastPathSegment ?: ""

        setContent {
            InstantAppTheme {
                InstantAppContent(uuid)
            }
        }
    }

    @Composable
    fun InstantAppContent(uuid: String) {
        var albumData by remember { mutableStateOf<JSONObject?>(null) }
        var mediaList by remember { mutableStateOf<List<String>>(emptyList()) }
        var isLoading by remember { mutableStateOf(true) }
        var isUnassigned by remember { mutableStateOf(false) }

        LaunchedEffect(uuid) {
            fetchData(uuid) { album, media, unassigned ->
                albumData = album
                mediaList = media
                isUnassigned = unassigned
                isLoading = false
            }
        }

        Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
            if (isLoading) {
                Box(contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            } else if (isUnassigned) {
                UnassignedView()
            } else {
                GalleryView(albumData?.optString("title") ?: "Souvenir", mediaList)
            }
        }
    }

    @Composable
    fun UnassignedView() {
        Column(
            modifier = Modifier.fillMaxSize().padding(24.dp),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("¡Este souvenir está listo!", style = MaterialTheme.typography.headlineMedium)
            Spacer(modifier = Modifier.height(16.dp))
            Text("Personalízalo con tus fotos descargando la app completa.")
            Spacer(modifier = Modifier.height(32.dp))
            Button(onClick = { openPlayStore() }) {
                Text("Descargar App Completa")
            }
        }
    }

    @Composable
    fun GalleryView(title: String, images: List<String>) {
        Column {
            Text(title, modifier = Modifier.padding(16.dp), style = MaterialTheme.typography.headlineSmall)
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                contentPadding = PaddingValues(4.dp)
            ) {
                items(images) { imageUrl ->
                    AsyncImage(
                        model = imageUrl,
                        contentDescription = null,
                        modifier = Modifier.aspectRatio(1f).padding(2.dp),
                        contentScale = ContentScale.Crop
                    )
                }
            }
        }
    }

    private fun openPlayStore() {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            data = Uri.parse("https://play.google.com/store/apps/details?id=com.tusouvenir.app")
            setPackage("com.android.vending")
        }
        startActivity(intent)
    }

    // Ultra-light Supabase fetcher using pure Kotlin/JSON to keep size under 15MB
    private suspend fun fetchData(uuid: String, onResult: (JSONObject?, List<String>, Boolean) -> Unit) {
        withContext(Dispatchers.IO) {
            try {
                // 1. Fetch Tag and Album info
                val tagUrl = "$SUPABASE_URL/rest/v1/tags?uuid=eq.$uuid&select=*,albums(*)"
                val connection = URL(tagUrl).openConnection()
                connection.setRequestProperty("apikey", SUPABASE_KEY)
                val response = connection.getInputStream().bufferedReader().readText()
                val tagArray = org.json.JSONArray(response)
                
                if (tagArray.length() == 0 || tagArray.getJSONObject(0).isNull("album_id")) {
                    withContext(Dispatchers.Main) { onResult(null, emptyList(), true) }
                    return@withContext
                }

                val albumId = tagArray.getJSONObject(0).getString("album_id")
                val album = tagArray.getJSONObject(0).getJSONObject("albums")

                // 2. Fetch Media
                val mediaUrl = "$SUPABASE_URL/rest/v1/media?album_id=eq.$albumId&select=url"
                val mediaConn = URL(mediaUrl).openConnection()
                mediaConn.setRequestProperty("apikey", SUPABASE_KEY)
                val mediaResponse = mediaConn.getInputStream().bufferedReader().readText()
                val mediaArray = org.json.JSONArray(mediaResponse)
                
                val urls = mutableListOf<String>()
                for (i in 0 until mediaArray.length()) {
                    urls.add(mediaArray.getJSONObject(i).getString("url"))
                }

                withContext(Dispatchers.Main) { onResult(album, urls, false) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) { onResult(null, emptyList(), false) }
            }
        }
    }
}
