import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofencing_alarm/Service/geofence_service.dart';
import 'package:geofencing_alarm/Service/location_service.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:shared_preferences/shared_preferences.dart';
import 'reminder_list.dart';


class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  MyApp({required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: FullMap(prefs: prefs),
    );
  }
}

class FullMap extends StatefulWidget {
  final SharedPreferences prefs;

  const FullMap({super.key, required this.prefs});

  @override
  State createState() => FullMapState();
}

class FullMapState extends State<FullMap> {
  MapboxMap? mapboxMap;
  geolocator.Position? _currentPosition;
  late GeofenceServiceHandler _geofenceServiceHandler;
  CircleAnnotationManager? circleAnnotationManager;

  @override
  void initState() {
    super.initState();
    _geofenceServiceHandler = GeofenceServiceHandler(prefs: widget.prefs);
    _initializeLocation();
  }

  void _initializeLocation() async {
    geolocator.Position? position = await LocationService.initializeLocation();
    setState(() {
      _currentPosition = position;
    });

    if (mapboxMap != null && _currentPosition != null) {
      mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ),
          ),
          zoom: 14.0,
        ),
        MapAnimationOptions(duration: 1000, startDelay: 0),
      );
    }
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    this.mapboxMap = mapboxMap;
    mapboxMap.location.updateSettings(LocationComponentSettings(enabled: true));

    mapboxMap.annotations.createCircleAnnotationManager().then((manager) {
      circleAnnotationManager = manager;
    });

    if (_currentPosition != null) {
      mapboxMap.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(
              _currentPosition!.longitude,
              _currentPosition!.latitude,
            ),
          ),
          zoom: 14.0,
        ),
        MapAnimationOptions(duration: 1000, startDelay: 0),
      );
    }
  }

  void _onMapTap(MapContentGestureContext context) {
    print('Tapped on map at: ${context.point.coordinates}');
  }

  void _onMapLongPress(MapContentGestureContext context) {
    final lat = context.point.coordinates.lat;
    final lng = context.point.coordinates.lng;
    print("Long press at: $lat, $lng");

    _showGeofenceDialog(
      this.context,
      _geofenceServiceHandler,
      mapboxMap!,
      lat.toDouble(),
      lng.toDouble(),
      widget.prefs,
    );
  }

  void _showGeofenceDialog(
    BuildContext context,
    GeofenceServiceHandler geofenceServiceHandler,
    MapboxMap mapboxMap,
    double latitude,
    double longitude,
    SharedPreferences prefs,
  ) {
    TextEditingController radiusController = TextEditingController();
    TextEditingController enterMessageController = TextEditingController();
    List<String> enterMessages = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Geofence'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Do you want to add a geofence here?'),
                  TextField(
                    controller: radiusController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Enter radius (in meters)',
                    ),
                  ),
                  TextField(
                    controller: enterMessageController,
                    decoration: const InputDecoration(
                      labelText: 'Enter enter notification message',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      if (enterMessageController.text.isNotEmpty) {
                        setState(() {
                          enterMessages.add(enterMessageController.text);
                          enterMessageController.clear();
                        });
                      }
                    },
                    child: const Text('Add Message'),
                  ),
                  const SizedBox(height: 10),
                  Text('Messages: ${enterMessages.join(', ')}'),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    double radius = double.tryParse(radiusController.text) ?? 100.0;

                    geofenceServiceHandler.addGeofence(
                      mapboxMap,
                      latitude,
                      longitude,
                      radius,
                      enterMessages: enterMessages,
                    );
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openReminderList() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReminderListPage(prefs: widget.prefs),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapbox Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: _openReminderList,
          ),
        ],
      ),
      body: MapWidget(
        key: const ValueKey("mapWidget"),
        onMapCreated: _onMapCreated,
        onTapListener: _onMapTap,
        onLongTapListener: _onMapLongPress,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_currentPosition != null) {
            double defaultRadius = 100.0;
            _geofenceServiceHandler.addGeofence(
                mapboxMap!,
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                defaultRadius,
                enterMessages: []);
          } else {
            print('Current position not available');
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    mapboxMap?.dispose();
    circleAnnotationManager?.deleteAll();
  }
}
