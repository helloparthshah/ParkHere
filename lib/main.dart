import 'dart:isolate';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:parkhere/models/spot.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future showNotification(String message) async {
  var android = const AndroidNotificationDetails(
      'id', 'channel ', "description",
      priority: Priority.high, importance: Importance.max);
  var platform = NotificationDetails(android: android);
  await flutterLocalNotificationsPlugin.show(
    0,
    'Updating Location',
    message,
    platform,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Location location = new Location();

  bool _serviceEnabled = false;
  late PermissionStatus _permissionGranted;
  late LocationData _locationData =
      LocationData.fromMap({"latitude": 0.0, "longitude": 0.0});
  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> markers = Set();

  static const double zoom = 20.0;

  double calculateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  late String _darkMapStyle;
  late String _lightMapStyle;

  Future _loadMapStyles() async {
    _darkMapStyle = await rootBundle.loadString('assets/dark.json');
    _lightMapStyle = await rootBundle.loadString('assets/light.json');
  }

  late LocationData previousLocation =
      LocationData.fromMap({"latitude": 100.0, "longitude": 100.0});

  bool isParked = false;
  bool wantPark = true;

  Spot currentSpot = Spot(0.0, 0.0, 0.0, "", "", false);

  void updateLocation() {
    late Marker marker = markers.last;

    location.onLocationChanged.listen((LocationData currentLocation) async {
      if (calculateDistance(
              previousLocation.latitude,
              previousLocation.longitude,
              currentLocation.latitude,
              currentLocation.longitude) <=
          0.0001) {
        setState(() {
          if (isParked == false) {
            wantPark = true;
          }
          isParked = true;
        });
        print("Parked");
        // get the closest marker to the current location
        var distance = double.infinity;
        for (var m in markers) {
          if (m.markerId.value == "Current Location") continue;
          var d = calculateDistance(
              currentLocation.latitude,
              currentLocation.longitude,
              m.position.latitude,
              m.position.longitude);
          /* double multiplier = marker.infoWindow.title!.split(" ")[0] == "No"
              ? 10
              : double.parse(marker.infoWindow.title!.split(" ")[0]);
          if (marker.infoWindow.title!.split(" ")[1] == "Minutes") {
            multiplier /= 60;
          }
          d *= multiplier; */
          if (d < distance) {
            distance = d;
            marker = m;
          }
        }
      } else {
        setState(() {
          isParked = false;
        });
      }
      setState(() {
        _locationData = currentLocation;
        previousLocation = currentLocation;
      });
      addMarkers();
      if (isParked) {
        setState(() {
          markers.add(Marker(
            markerId: const MarkerId("Closest Spot"),
            position:
                LatLng(marker.position.latitude, marker.position.longitude),
            infoWindow: const InfoWindow(title: "Closest Spot"),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange),
          ));
          // find the marker in spots
          for (var spot in spots) {
            if (spot.lat == marker.position.latitude &&
                spot.long == marker.position.longitude) {
              currentSpot = spot;
              break;
            }
          }
        });
      }
    });
  }

  void onDidReceiveLocalNotification(
      int id, String title, String body, String payload) async {
    // display a dialog with the notification details, tap ok to go to another page
    showDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: Text('Ok'),
            onPressed: () async {
              Navigator.of(context, rootNavigator: true).pop();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyHomePage(
                    title: 'Test',
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  Future onSelectNotification(String? payload) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => const MyHomePage(
              title: '',
            )));
  }

  @override
  void initState() {
    var initializationSettingsAndroid =
        const AndroidInitializationSettings('@mipmap/ic_launcher');

    var initSetttings =
        InitializationSettings(android: initializationSettingsAndroid);

    flutterLocalNotificationsPlugin.initialize(initSetttings,
        onSelectNotification: onSelectNotification);

    _loadMapStyles();
    initLocation();
    updateLocation();
    readFile();

    super.initState();
  }

  CameraPosition _kGooglePlex = const CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: zoom,
  );

  List<Spot> spots = [];

  void readFile() async {
    String text = await rootBundle.loadString('assets/spots.csv');
    List<List<dynamic>> rowsAsListOfValues =
        const CsvToListConverter(eol: '\n', fieldDelimiter: ',').convert(text);
    for (int i = 1; i < rowsAsListOfValues.length; i++) {
      List<dynamic> row = rowsAsListOfValues[i];
      double timeLimit = double.infinity;
      if (row[11] == "No Parking" || row[11] == "No Parking Anytime") {
        timeLimit = 0;
      } else if (row[11] == "No Limit") {
        timeLimit = double.infinity;
      } else {
        var times = row[11].toString().split(" ");
        var t = times.length >= 2 ? (times[1] == "Hours" ? 1 : 60) : 1;
        timeLimit = row[11] != ""
            ? double.parse(times[0].replaceAll("+", "")) / t
            : timeLimit;
      }
      Spot spot = Spot(double.parse(row[0].toString()),
          double.parse(row[1].toString()), timeLimit, row[12], row[13], false);

      spots.add(spot);
    }
    addMarkers();
  }

  void addMarkers() async {
    markers.clear();
    markers.add(Marker(
      markerId: const MarkerId("Current Location"),
      position: LatLng(_locationData.latitude!, _locationData.longitude!),
      infoWindow: const InfoWindow(title: "Current Location"),
    ));
    for (Spot spot in spots) {
      var distance = calculateDistance(_locationData.latitude!,
          _locationData.longitude!, spot.lat, spot.long);

      if (distance < 0.1) {
        setState(() {
          String title;
          if (spot.timeLim == double.infinity) {
            title = "No Time Limit";
          } else if (spot.timeLim < 1) {
            title = "${spot.timeLim * 60} Minutes";
          } else {
            title = "${spot.timeLim} Hours";
          }
          if (spot.timeLim != 0) {
            markers.add(Marker(
              markerId: MarkerId(spot.lat.toString() + spot.long.toString()),
              position: LatLng(spot.lat, spot.long),
              infoWindow: InfoWindow(
                title: title,
              ),
              alpha: 0.5,
              icon: BitmapDescriptor.defaultMarkerWithHue(spot.timeLim == 0
                  ? BitmapDescriptor.hueRed
                  : spot.timeLim == double.infinity
                      ? BitmapDescriptor.hueGreen
                      : BitmapDescriptor.hueYellow),
              onTap: () {
                // print time limit
                print(spot.timeLim);
              },
            ));
          }
        });
      }
    }
  }

  void initLocation() async {
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _locationData = await location.getLocation();
    print(_locationData);
    setState(() {
      _kGooglePlex = CameraPosition(
        target: LatLng(_locationData.latitude!, _locationData.longitude!),
        zoom: zoom,
      );
      markers.add(Marker(
          markerId: const MarkerId("Current Location"),
          position: LatLng(_locationData.latitude!, _locationData.longitude!),
          infoWindow: const InfoWindow(title: "Current Location")));
    });
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(_kGooglePlex));

    setState(() {
      previousLocation = _locationData;
    });

    // check if dark mode is enabled
    if (Theme.of(context).brightness == Brightness.dark) {
      controller.setMapStyle(_darkMapStyle);
    } else {
      controller.setMapStyle(_lightMapStyle);
    }
  }

  static Future<void> printHello() async {
    final DateTime now = DateTime.now();
    final int isolateId = Isolate.current.hashCode;
    print("[$now] Hello, world! isolate=${isolateId} function='$printHello'");
    await showNotification("Time to move your car!");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: GoogleMap(
                  // liteModeEnabled: true,
                  mapType: MapType.normal,
                  initialCameraPosition: _kGooglePlex,
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                  markers: markers,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.0),
              child: AnimatedContainer(
                height: wantPark ? 200 : 0,
                width: MediaQuery.of(context).size.width,
                decoration: const BoxDecoration(
                  color: Colors.black,
                ),
                duration: const Duration(milliseconds: 200),
                curve: Curves.bounceInOut,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Did you park here?',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TextButton(
                            onPressed: () async {
                              print("yes");
                              print(currentSpot.timeLim);
                              Duration duration;
                              if (currentSpot.timeLim == double.infinity) {
                                duration = const Duration(days: 365);
                              } else if (currentSpot.timeLim < 1) {
                                duration = Duration(
                                    minutes:
                                        (currentSpot.timeLim * 60).toInt());
                              } else {
                                duration = Duration(
                                    hours: currentSpot.timeLim.toInt());
                              }
                              setState(() {
                                wantPark = false;
                              });
                              const int helloAlarmID = 0;
                              await AndroidAlarmManager.oneShot(
                                duration,
                                helloAlarmID,
                                printHello,
                              );
                            },
                            child: const Text('Yes')),
                        TextButton(
                            onPressed: () {
                              setState(() {
                                wantPark = false;
                              });
                            },
                            child: const Text('No')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          _kGooglePlex = CameraPosition(
            target: LatLng(_locationData.latitude!, _locationData.longitude!),
            zoom: zoom,
          );

          final GoogleMapController controller = await _controller.future;
          controller
              .animateCamera(CameraUpdate.newCameraPosition(_kGooglePlex));
        },
        child: const Icon(Icons.my_location),
      ),
    );
  }
}
