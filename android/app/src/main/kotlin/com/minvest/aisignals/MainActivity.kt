package com.minvest.aisignals

import io.flutter.embedding.android.FlutterActivity
// ▼▼▼ THÊM CÁC DÒNG NÀY ▼▼▼
import android.os.Bundle
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
// ▲▲▲ KẾT THÚC PHẦN THÊM MỚI ▲▲▲

class MainActivity: FlutterActivity() {
    // ▼▼▼ THÊM HÀM NÀY VÀO ĐÂY ▼▼▼
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Khởi tạo Facebook SDK
        FacebookSdk.sdkInitialize(applicationContext)
        AppEventsLogger.activateApp(application)
    }
    // ▲▲▲ KẾT THÚC PHẦN THÊM MỚI ▲▲▲
}