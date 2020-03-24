import 'package:flutter_downloader/flutter_downloader.dart';
import 'dart:async';
import 'dart:io';
import 'package:fluster/fluster.dart';
import 'package:flutter/material.dart';
import 'package:covid_19_brasil/helpers/map_marker.dart';
import 'package:covid_19_brasil/helpers/map_helper.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with AutomaticKeepAliveClientMixin {
  final Completer<GoogleMapController> _mapController = Completer();
  
  // Load tab only once
  @override
  bool get wantKeepAlive => true;

  /// Set of displayed markers and cluster markers on the map
  final Set<Marker> _markers = Set();

  /// Minimum zoom at which the markers will cluster
  final int _minClusterZoom = 4;

  /// Maximum zoom at which the markers will cluster
  final int _maxClusterZoom = 12;

  /// [Fluster] instance used to manage the clusters
  Fluster<MapMarker> _clusterManager;

  /// Current map zoom
  double _currentZoom = 4;

  /// Map loading flag
  bool _isMapLoading = true;

  /// Markers loading flag
  bool _areMarkersLoading = true;

  /// Url image used on normal markers
  final String _markerImageUrl = 'https://img.icons8.com/office/80/000000/marker.png';

  /// Color of the cluster circle
  final Color _clusterColor = Colors.red;

  /// Color of the cluster text
  final Color _clusterTextColor = Colors.white;

  final List<MapMarker> markers = [];

  /// Called when the Google Map widget is created. Updates the map loading state
  /// and inits the markers.
  void _onMapCreated(GoogleMapController controller) async {
    _mapController.complete(controller);

    setState(() {
      _isMapLoading = false;
    });

     _requestDownload('https://raw.githubusercontent.com/wcota/covid19br/master/cases-gps.csv', 'cases-gps.csv');
  }

  void _requestDownload(link, filename) async{
    var dir = await getExternalStorageDirectory();
    await FlutterDownloader.enqueue(
        url: link,
        savedDir: dir.path,
        showNotification: false,
        openFileFromNotification: false).then((result){
          sleep(Duration(seconds:1)); // File was not found without timeout
          _fileToString(filename);
        });
  }

  void _fileToString(filename) async{
    var dir = await getExternalStorageDirectory();
    var full_path = dir.path + "/" + filename;
    File file = new File(full_path);
    String text = await file.readAsString();
    _createMarkers(text);
  }

  void _createMarkers(txt) async{
    final BitmapDescriptor markerImage = await MapHelper.getMarkerImageFromUrl(_markerImageUrl);
    var rows = txt.split("\n");

    var count = 1;

    rows.forEach((str_row){
      if(str_row == "") return false;
      if(count > 1){
        var city = str_row.split(",");
        LatLng markerLocation = LatLng(double.parse(city[2].toString()), double.parse(city[3].toString()));
        InfoWindow info = new InfoWindow(title: city[1], snippet: 'Total: ' + city[4]);

        markers.add(
          MapMarker(
            id: count.toString(),
            position: markerLocation,
            icon: markerImage,
            infoWindow: info
          ),
        );
      }
      count++;
    });

    _clusterManager = await MapHelper.initClusterManager(
      markers,
      _minClusterZoom,
      _maxClusterZoom,
    );

    _updateMarkers();
  }

  /// Gets the markers and clusters to be displayed on the map for the current zoom level and
  /// updates state.
  Future<void> _updateMarkers([double updatedZoom]) async {
    if (_clusterManager == null || updatedZoom == _currentZoom) return;

    if (updatedZoom != null) {
      _currentZoom = updatedZoom;
    }

    setState(() {
      _areMarkersLoading = true;
    });

    final updatedMarkers = await MapHelper.getClusterMarkers(
      _clusterManager,
      _currentZoom,
      _clusterColor,
      _clusterTextColor,
      80,
    );

    _markers
      ..clear()
      ..addAll(updatedMarkers);

    setState(() {
      _areMarkersLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          // Google Map widget
          Opacity(
            opacity: _isMapLoading ? 0 : 1,
            child: GoogleMap(
              mapToolbarEnabled: false,
              initialCameraPosition: CameraPosition(
                target: LatLng(-17.2660996, -51.0877282),
                zoom: _currentZoom,
              ),
              markers: _markers,
              onMapCreated: (controller) => _onMapCreated(controller),
              onCameraMove: (position) => _updateMarkers(position.zoom),
              gestureRecognizers: Set()
              ..add(Factory<PanGestureRecognizer>(() => PanGestureRecognizer()))
              ..add(Factory<VerticalDragGestureRecognizer>(
                  () => VerticalDragGestureRecognizer())),
            ),
          ),

          // Map loading indicator
          Opacity(
            opacity: _isMapLoading ? 1 : 0,
            child: Center(child: CircularProgressIndicator()),
          ),

          // Map markers loading indicator
          if (_areMarkersLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Align(
                alignment: Alignment.topCenter,
                child: Card(
                  elevation: 2,
                  color: Colors.grey.withOpacity(0.9),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      'Carregando...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
