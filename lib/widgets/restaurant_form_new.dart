import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/restaurant_model.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../services/session_manager.dart';
import 'restaurant_image_carousel.dart';

class RestaurantForm extends StatefulWidget {
  final Restaurant? restaurant;
  final LatLng? initialLocation;
  final Function(Restaurant) onSubmit;

  const RestaurantForm({
    super.key,
    this.restaurant,
    this.initialLocation,
    required this.onSubmit,
  });

  @override
  RestaurantFormState createState() => RestaurantFormState();
}

class RestaurantFormState extends State<RestaurantForm> {
  final _formKey = GlobalKey<FormState>();
  
  // Champs de base
  late String _name;
  late String? _description;
  List<String> _images = [];
  late LatLng _coordinates;
  late bool _isOpen;
  
  // Nouveaux champs
  int? _employeeCount;
  String? _ownerName;
  String? _ownerDegrees;
  int? _openingYear;
  String? _signatureDishes;
  final Set<String> _cuisineTypes = {};
  final Set<String> _services = {};
  final Set<String> _paymentMethods = {};
  String? _priceRange;
  String? _noiseLevel;
  String? _atmosphere;

  @override
  void initState() {
    super.initState();
    // Initialisation des champs de base
    _name = widget.restaurant?.name ?? '';
    _description = widget.restaurant?.description;
    _images = widget.restaurant?.images ?? [];
    _coordinates = widget.restaurant?.coordinates ?? widget.initialLocation ?? const LatLng(0, 0);
    _isOpen = widget.restaurant?.isOpen ?? true;
    
    // Initialisation des nouveaux champs
    _employeeCount = widget.restaurant?.employeeCount;
    _ownerName = widget.restaurant?.ownerName;
    _ownerDegrees = widget.restaurant?.ownerDegrees;
    _openingYear = widget.restaurant?.openingYear;
    _signatureDishes = widget.restaurant?.signatureDishes;
    _cuisineTypes.addAll(widget.restaurant?.cuisineTypes ?? []);
    _services.addAll(widget.restaurant?.availableServices ?? []);
    _paymentMethods.addAll(widget.restaurant?.paymentMethods ?? []);
    _priceRange = widget.restaurant?.priceRange;
    _noiseLevel = widget.restaurant?.noiseLevel;
    _atmosphere = widget.restaurant?.atmosphere;
  }

  Future<void> _pickImage() async {
    if (_images.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 images autorisées')),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 70,
      );
      
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final Uint8List compressed = await FlutterImageCompress.compressWithList(
          bytes,
          minHeight: 800,
          minWidth: 800,
          quality: 70,
        );
        setState(() {
          _images.add(base64Encode(compressed));
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de la sélection de l\'image')),
      );
    }
  }

  Future<void> _captureImage() async {
    bool retry = true;
    while (retry) {
      if (_images.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maximum 3 images autorisées')),
        );
        return;
      }

      try {
        final picker = ImagePicker();
        final XFile? pickedFile = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 70,
        );
        
        if (pickedFile != null) {
          final bool? confirm = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Confirmer la photo'),
                content: const Text('Voulez-vous garder cette photo ?'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Annuler'),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () => Navigator.of(context).pop(true),
                  ),
                ],
              );
            },
          );

          if (confirm == true) {
            final bytes = await pickedFile.readAsBytes();
            final Uint8List compressed = await FlutterImageCompress.compressWithList(
              bytes,
              minHeight: 800,
              minWidth: 800,
              quality: 70,
            );
            setState(() {
              _images.add(base64Encode(compressed));
            });
            retry = false;
          }
        } else {
          retry = false;
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Échec de la capture de la photo')),
        );
        retry = false;
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  Widget _buildCheckbox(String label, String value, Set<String> values) {
    return FilterChip(
      label: Text(label),
      selected: values.contains(value),
      onSelected: (bool selected) {
        setState(() {
          if (selected) {
            values.add(value);
          } else {
            values.remove(value);
          }
        });
      },
    );
  }

  Widget _buildRadioGroup(String name, String? groupValue, Map<String, String> options, Function(String) onChanged) {
    return Wrap(
      children: options.entries.map((entry) => 
        SizedBox(
          width: 160,
          child: RadioListTile<String>(
            title: Text(entry.key),
            value: entry.value,
            groupValue: groupValue,
            onChanged: (String? value) {
              if (value != null) {
                onChanged(value);
              }
            },
          ),
        ),
      ).toList(),
    );
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final userId = Provider.of<SessionManager>(context, listen: false).currentUser?.id ?? '';
      final restaurant = Restaurant(
        id: widget.restaurant?.id ?? DateTime.now().toIso8601String(),
        name: _name,
        description: _description,
        images: _images,
        coordinates: _coordinates,
        createdAt: widget.restaurant?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        userId: userId,
        isOpen: _isOpen,
        employeeCount: _employeeCount,
        ownerName: _ownerName,
        ownerDegrees: _ownerDegrees,
        openingYear: _openingYear,
        signatureDishes: _signatureDishes,
        cuisineTypes: _cuisineTypes.toList(),
        availableServices: _services.toList(),
        paymentMethods: _paymentMethods.toList(),
        priceRange: _priceRange,
        noiseLevel: _noiseLevel,
        atmosphere: _atmosphere,
      );

      widget.onSubmit(restaurant);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RestaurantImageCarousel(
            images: _images,
            isEditable: true,
            onDelete: _removeImage,
            onEdit: (index) async {
              try {
                final picker = ImagePicker();
                final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                
                if (pickedFile != null) {
                  final bytes = await pickedFile.readAsBytes();
                  final Uint8List compressed = await FlutterImageCompress.compressWithList(
                    bytes,
                    minHeight: 800,
                    minWidth: 800,
                    quality: 70,
                  );
                  setState(() {
                    _images[index] = base64Encode(compressed);
                  });
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Échec de la modification de l\'image'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _images.length < 3 ? _pickImage : null,
                  icon: const Icon(Icons.add_photo_alternate),
                  label: Text('Ajouter une image (${_images.length}/3)'),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _images.length < 3 ? _captureImage : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(12),
                ),
                child: const Icon(Icons.camera_alt),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Champs de base existants
          TextFormField(
            initialValue: _name,
            decoration: const InputDecoration(labelText: 'Nom du restaurant'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez entrer un nom';
              }
              return null;
            },
            onSaved: (value) {
              _name = value!;
            },
          ),
          TextFormField(
            initialValue: _description,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 3,
            onSaved: (value) {
              _description = value;
            },
          ),
          
          // Nouveaux champs
          TextFormField(
            decoration: const InputDecoration(labelText: 'Nombre d\'employés'),
            keyboardType: TextInputType.number,
            initialValue: _employeeCount?.toString() ?? '',
            onSaved: (value) => _employeeCount = int.tryParse(value ?? ''),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Nom du propriétaire'),
            initialValue: _ownerName ?? '',
            onSaved: (value) => _ownerName = value,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Diplômes du propriétaire'),
            initialValue: _ownerDegrees ?? '',
            onSaved: (value) => _ownerDegrees = value,
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Année d\'ouverture'),
            keyboardType: TextInputType.number,
            initialValue: _openingYear?.toString() ?? '',
            onSaved: (value) => _openingYear = int.tryParse(value ?? ''),
          ),
          TextFormField(
            decoration: const InputDecoration(labelText: 'Plats signature'),
            initialValue: _signatureDishes ?? '',
            onSaved: (value) => _signatureDishes = value,
          ),
          
          const SizedBox(height: 20),
          const Text('Type de cuisine servie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8.0,
            children: [
              _buildCheckbox('Marocaine', 'Marocaine', _cuisineTypes),
              _buildCheckbox('Italienne', 'Italienne', _cuisineTypes),
              _buildCheckbox('Française', 'Française', _cuisineTypes),
              _buildCheckbox('Chinoise', 'Chinoise', _cuisineTypes),
              _buildCheckbox('Végétarienne', 'Végétarienne', _cuisineTypes),
              _buildCheckbox('Fast food', 'Fast food', _cuisineTypes),
            ],
          ),
          
          const SizedBox(height: 20),
          const Text('Services disponibles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8.0,
            children: [
              _buildCheckbox('Livraison', 'Livraison', _services),
              _buildCheckbox('À emporter', 'À emporter', _services),
              _buildCheckbox('Réservation en ligne', 'Réservation en ligne', _services),
              _buildCheckbox('Terrasse', 'Terrasse', _services),
              _buildCheckbox('Accès handicapé', 'Accès handicapé', _services),
              _buildCheckbox('Wifi gratuit', 'Wifi gratuit', _services),
            ],
          ),
          
          const SizedBox(height: 20),
          const Text('Modes de paiement acceptés', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Wrap(
            spacing: 8.0,
            children: [
              _buildCheckbox('Espèces', 'Espèces', _paymentMethods),
              _buildCheckbox('Carte bancaire', 'Carte bancaire', _paymentMethods),
              _buildCheckbox('Paiement mobile', 'Paiement mobile', _paymentMethods),
              _buildCheckbox('Chèques', 'Chèques', _paymentMethods),
            ],
          ),
          
          const SizedBox(height: 20),
          const Text('Gamme de prix moyenne', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          _buildRadioGroup('priceRange', _priceRange, {
            'Économique': 'Économique',
            'Moyenne gamme': 'Moyenne gamme',
            'Haut de gamme': 'Haut de gamme',
          }, (value) => setState(() => _priceRange = value)),
          
          const SizedBox(height: 20),
          const Text('Niveau de bruit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          _buildRadioGroup('noiseLevel', _noiseLevel, {
            'Calme': 'Calme',
            'Modéré': 'Modéré',
            'Bruyant': 'Bruyant',
          }, (value) => setState(() => _noiseLevel = value)),
          
          const SizedBox(height: 20),
          const Text('Ambiance principale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          _buildRadioGroup('atmosphere', _atmosphere, {
            'Familiale': 'Familiale',
            'Romantique': 'Romantique',
            'Amicale': 'Amicale',
            'Professionnelle': 'Professionnelle',
          }, (value) => setState(() => _atmosphere = value)),
          
          const SizedBox(height: 10),
          SwitchListTile(
            title: const Text('Restaurant ouvert'),
            value: _isOpen,
            onChanged: (bool value) {
              setState(() {
                _isOpen = value;
              });
            },
          ),
          
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _handleSubmit,
            child: Text(widget.restaurant == null ? 'Ajouter' : 'Mettre à jour'),
          ),
        ],
      ),
    );
  }
}
