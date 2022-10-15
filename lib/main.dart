import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:parkhere/models/spot.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
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
  late LocationData _locationData;
  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> markers = Set();

  static const double zoom = 18.0;

  double calculateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  @override
  void initState() {
    initLocation();
    location.onLocationChanged.listen((LocationData currentLocation) async {
      setState(() {
        _locationData = currentLocation;
      });
      _kGooglePlex = CameraPosition(
        target: LatLng(_locationData.latitude!, _locationData.longitude!),
        zoom: zoom,
      );

      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newCameraPosition(_kGooglePlex));
      // get the closest marker to the current location
      var distance = double.infinity;
      var spot = Spot(0, 0, 0, "", "", false);
      for (var i = 0; i < spots.length; i++) {
        var temp = calculateDistance(_locationData.latitude!,
            _locationData.longitude!, spots[i].lat, spots[i].long);
        if (temp < distance) {
          distance = temp;
          spot = spots[i];
        }
      }
      print(distance);
      addMarkers();
      setState(() {
        markers.add(Marker(
            markerId: MarkerId("Closest Spot"),
            position: LatLng(spot.lat, spot.long),
            infoWindow: InfoWindow(title: "Closest Spot")));
      });
    });
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
        timeLimit = row[11] != ""
            ? double.parse(row[11].toString().split(" ")[0].replaceAll("+", ""))
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
        markerId: MarkerId("Current Location"),
        position: LatLng(_locationData.latitude!, _locationData.longitude!),
        infoWindow: InfoWindow(title: "Current Location")));
    for (Spot spot in spots) {
      var distance = calculateDistance(_locationData.latitude!,
          _locationData.longitude!, spot.lat, spot.long);

      if (distance < 0.1) {
        setState(() {
          if (spot.timeLim != 0) {
            markers.add(Marker(
              markerId: MarkerId(spot.lat.toString() + spot.long.toString()),
              position: LatLng(spot.lat, spot.long),
              infoWindow: InfoWindow(
                  title: spot.timeLim == double.infinity
                      ? "No Time Limit"
                      : "${spot.timeLim.toInt()} Hour Limit"),
              icon: BitmapDescriptor.defaultMarkerWithHue(spot.timeLim == 0
                  ? BitmapDescriptor.hueRed
                  : spot.timeLim == double.infinity
                      ? BitmapDescriptor.hueGreen
                      : BitmapDescriptor.hueYellow),
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
          markerId: MarkerId("Current Location"),
          position: LatLng(_locationData.latitude!, _locationData.longitude!),
          infoWindow: InfoWindow(title: "Current Location")));
    });
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(_kGooglePlex));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
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
            child: Container(
              height: 200,
              decoration: const BoxDecoration(
                color: Colors.black,
              ),
            ),
          ),
        )
      ],
    );
  }
}
