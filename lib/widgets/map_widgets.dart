// map_widgets.dart :

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import '../models/geometry_model.dart';

class GeometryToolbar extends StatelessWidget {
  final GeometryType selectedType;
  final Function(GeometryType) onTypeSelected;
  final VoidCallback onFinish;
  final VoidCallback onCancel;

  const GeometryToolbar({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
    required this.onFinish,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // IconButton(
            //   icon: const Icon(Icons.location_on),
            //   color: selectedType == GeometryType.point ? Colors.blue : null,
            //   onPressed: () => onTypeSelected(GeometryType.point),
            //   tooltip: 'Point',
            // ),
            IconButton(
              icon: const Icon(Icons.timeline),
              color: selectedType == GeometryType.polyline ? Colors.blue : null,
              onPressed: () => onTypeSelected(GeometryType.polyline),
              tooltip: 'Polyline',
            ),
            IconButton(
              icon: const Icon(Icons.pentagon),
              color: selectedType == GeometryType.polygon ? Colors.blue : null,
              onPressed: () => onTypeSelected(GeometryType.polygon),
              tooltip: 'Polygon',
            ),
            IconButton(
              icon: const Icon(Icons.circle_outlined),
              color: selectedType == GeometryType.circle ? Colors.blue : null,
              onPressed: () => onTypeSelected(GeometryType.circle),
              tooltip: 'Circle',
            ),
            const VerticalDivider(),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: onFinish,
              tooltip: 'Finish',
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onCancel,
              tooltip: 'Cancel',
            ),
          ],
        ),
      ),
    );
  }
}

class RestaurantMarker extends Marker {
  RestaurantMarker({
    required LatLng point,
    required VoidCallback onTap,
  }) : super(
          width: 40.0,
          height: 40.0,
          point: point,
          child: GestureDetector(
            onTap: onTap,
            child: const Icon(
              Icons.restaurant,
              color: Colors.red,
              size: 40.0,
            ),
          ),
        );
}

class RestaurantPopup extends StatelessWidget {
  final String name;
  final String? description;
  final String? imageData;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const RestaurantPopup({
    super.key,
    required this.name,
    this.description,
    this.imageData,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(description!),
            ],
            if (imageData != null) ...[
              const SizedBox(height: 8),
              Image.memory(
                base64Decode(imageData!),
                height: 100,
                width: 150,
                fit: BoxFit.cover,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
