# AdMob + AndroidX WorkManager (required by play-services-ads in release builds).
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.InputMerger
-keep class * extends androidx.work.ListenableWorker {
    public <init>(...);
}
-keep class androidx.work.WorkerParameters
-keep class androidx.work.impl.** { *; }

# Room (WorkManager persists jobs via Room).
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Entity class *
-keepclassmembers class * extends androidx.room.RoomDatabase {
    static ** sInstance;
}

-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.**
