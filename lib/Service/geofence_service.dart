import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeofenceServiceHandler {
  final GeofenceService _geofenceService = GeofenceService.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final List<Geofence> _geofenceList = <Geofence>[];
  CircleAnnotationManager? _circleAnnotationManager;
  final SharedPreferences prefs;

  GeofenceServiceHandler({required this.prefs}) {
    _initializeService();
  }

  void _initializeService() {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    _flutterLocalNotificationsPlugin.initialize(initializationSettings);

    _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);
  }

  Future<void> addGeofence(
    MapboxMap mapboxMap,
    double latitude,
    double longitude,
    double radius, {
    required List<String> enterMessages,
  }) async {
    var geofence = Geofence(
      id: 'geofence_${latitude}_$longitude',
      latitude: latitude,
      longitude: longitude,
      radius: [
        GeofenceRadius(
            id: 'radius_${radius}_${latitude}_$longitude', length: radius),
      ],
    );

    _geofenceList.add(geofence);

    prefs.setStringList('enterMessages_${geofence.id}', enterMessages);

    for (String message in enterMessages) {
      _saveReminder(message);
    }

    try {
      await _geofenceService.start(_geofenceList);
      print('Geofence added successfully');
      await _drawCircle(mapboxMap, latitude, longitude, radius);
    } catch (error) {
      if (error.toString().contains('ErrorCodes.ALREADY_STARTED')) {
        _geofenceService.addGeofence(geofence);
        print('Geofence added successfully after service was already started');
        await _drawCircle(mapboxMap, latitude, longitude, radius);
      } else {
        print('Failed to add geofence: $error');
      }
    }
  }

  Future<void> _drawCircle(MapboxMap mapboxMap, double latitude,
      double longitude, double radius) async {
    _circleAnnotationManager ??=
        await mapboxMap.annotations.createCircleAnnotationManager();

    _circleAnnotationManager?.create(CircleAnnotationOptions(
      geometry: Point(
        coordinates: Position(
          longitude,
          latitude,
        ),
      ),
      circleColor: Colors.blue.value,
      circleRadius: radius,
      circleOpacity: 0.5,
    ));
  }

  Future<void> _onGeofenceStatusChanged(
      Geofence geofence,
      GeofenceRadius geofenceRadius,
      GeofenceStatus status,
      Location location) async {
    print('Geofence status changed: ${status.toString()}');
    if (status == GeofenceStatus.ENTER) {
      List<String> enterMessages =
          prefs.getStringList('enterMessages_${geofence.id}') ??
              ['You have entered the geofence'];
      int notificationId = DateTime.now()
          .millisecondsSinceEpoch
          .remainder(100000); 
      for (String message in enterMessages) {
        print('Showing notification: $message');
        await _showNotification('Entered Geofence', message, notificationId);
        notificationId++; 
        markReminderAsDone(message);
      }
    }
  }

  Future<void> _showNotification(
      String title, String body, int notificationId) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Notifications',
      channelDescription: 'Notifications for geofence events',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await _flutterLocalNotificationsPlugin.show(
      notificationId,
      title,
      body,
      platformChannelSpecifics,
      payload: 'item x',
    );
    print('Notification shown: $title - $body');
  }

  void _saveReminder(String reminder) {
    List<String> reminders = prefs.getStringList('reminders') ?? [];
    if (!reminders.contains(reminder)) {
      reminders.add(reminder);
      prefs.setStringList('reminders', reminders);
    }
  }

  void markReminderAsDone(String reminder) {
    List<String> reminders = prefs.getStringList('reminders') ?? [];
    if (reminders.contains(reminder)) {
      reminders.remove(reminder);
      prefs.setStringList('reminders', reminders);

      List<String> doneReminders = prefs.getStringList('doneReminders') ?? [];
      doneReminders.add(reminder);
      prefs.setStringList('doneReminders', doneReminders);
    }
  }

  List<String> getReminders() {
    return prefs.getStringList('reminders') ?? [];
  }

  List<String> getDoneReminders() {
    return prefs.getStringList('doneReminders') ?? [];
  }
}
