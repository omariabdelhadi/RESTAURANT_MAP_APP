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
import 'custom_radio.dart';

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
  int? _rating;
  String? _ratingComment;
  final TextEditingController _ratingController = TextEditingController();
  final TextEditingController _ratingCommentController = TextEditingController();

  @override
  void dispose() {
    _ratingController.dispose();
    _ratingCommentController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    
    // Initialisation des champs de base
    _name = widget.restaurant?.name ?? '';
    _description = widget.restaurant?.description;
    _images = widget.restaurant?.images ?? [];
    _coordinates = widget.restaurant?.coordinates ?? widget.initialLocation ?? const LatLng(0, 0);
    _isOpen = widget.restaurant?.isOpen ?? true;
    
    // Initialisation des valeurs rating et comment
    _rating = widget.restaurant?.rating;
    _ratingComment = widget.restaurant?.ratingComment;
    
    // Initialisation des contrôleurs avec les valeurs existantes
    // Initialisation sécurisée des contrôleurs
    _ratingController.text = widget.restaurant?.rating?.toString() ?? '';
    _ratingCommentController.text = widget.restaurant?.ratingComment ?? '';
    
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
    
    debugPrint('Form initialized:');
    debugPrint('Rating: $_rating');
    debugPrint('RatingController: ${_ratingController.text}');
    debugPrint('Comment: $_ratingComment');
    debugPrint('CommentController: ${_ratingCommentController.text}');
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

  Future<void> _editImage(int index) async {
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
          _images[index] = base64Encode(compressed);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Échec de la modification de l\'image'),
            backgroundColor: Colors.red,
          ),
        );
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

  Widget _buildRadioSection(String title, String? groupValue, Map<String, String> options, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        CustomRadioGroup(
          groupValue: groupValue,
          options: options,
          onChanged: onChanged,
        ),
        const SizedBox(height: 16),
      ],
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
        rating: _rating,
        ratingComment: _ratingComment,
      );

      widget.onSubmit(restaurant);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantDetails() {
    return Scrollbar(
      thickness: 8.0,
      radius: const Radius.circular(8.0),
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 16.0, right: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Images du restaurant
          if (_images.isNotEmpty)
            RestaurantImageCarousel(images: _images),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom du restaurant
                // État (Ouvert/Fermé)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isOpen ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _isOpen ? 'Ouvert' : 'Fermé',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),

                const SizedBox(height: 16),

                _buildSectionTitle('Informations de base'),
                Text(
                  _name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),

                const SizedBox(height: 8),

                // Description
                if (_description?.isNotEmpty == true) ...[
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(_description!),
                  const SizedBox(height: 16),
                ],
                _buildSectionTitle('Informations sur le propriétaire'),
                // Informations sur le propriétaire
                if (_ownerName?.isNotEmpty == true || _ownerDegrees?.isNotEmpty == true) ...[
                  if (_ownerName?.isNotEmpty == true)
                    Text('Nom: $_ownerName'),
                  if (_ownerDegrees?.isNotEmpty == true)
                    Text('Diplômes: $_ownerDegrees'),
                  const SizedBox(height: 16),
                ],
                _buildSectionTitle('Informations générales'),
                // Année d'ouverture et nombre d'employés
                if (_openingYear != null || _employeeCount != null) ...[
                  if (_openingYear != null)
                    Text('Année d\'ouverture: $_openingYear'),
                  if (_employeeCount != null)
                    Text('Nombre d\'employés: $_employeeCount'),
                  const SizedBox(height: 16),
                ],
                _buildSectionTitle('cuisine et services'),
                // Plats signature
                if (_signatureDishes?.isNotEmpty == true) ...[
                  Text(
                    'Plats signature',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(_signatureDishes!),
                  const SizedBox(height: 16),
                ],

                // Types de cuisine
                if (_cuisineTypes.isNotEmpty) ...[
                  Text(
                    'Types de cuisine',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Wrap(
                    spacing: 8,
                    children: _cuisineTypes.map((type) => Chip(
                      label: Text(type),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Services disponibles
                if (_services.isNotEmpty) ...[
                  Text(
                    'Services disponibles',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Wrap(
                    spacing: 8,
                    children: _services.map((service) => Chip(
                      label: Text(service),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildSectionTitle('Paiement et ambiance'),
                // Modes de paiement
                if (_paymentMethods.isNotEmpty) ...[
                  Text(
                    'Modes de paiement acceptés',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Wrap(
                    spacing: 8,
                    children: _paymentMethods.map((method) => Chip(
                      label: Text(method),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Informations additionnelles
                if (_priceRange?.isNotEmpty == true || 
                    _noiseLevel?.isNotEmpty == true || 
                    _atmosphere?.isNotEmpty == true) ...[
                  Text(
                    'Ambiance et prix',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_priceRange?.isNotEmpty == true)
                    Text('Gamme de prix: $_priceRange'),
                  if (_noiseLevel?.isNotEmpty == true)
                    Text('Niveau sonore: $_noiseLevel'),
                  if (_atmosphere?.isNotEmpty == true)
                    Text('Ambiance: $_atmosphere'),
                  const SizedBox(height: 16),
                ],
                _buildSectionTitle('Évaluation'),
                // Évaluation (toujours visible)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('Note: ${_rating ?? "Non noté"}/5'),
                        const SizedBox(width: 8),
                        Row(
                          children: List.generate(
                            5,
                            (index) => Icon(
                              _rating != null && index < _rating! ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_ratingComment != null) ...[
                      const SizedBox(height: 8),
                      Text('Commentaire: $_ratingComment'),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),

          
              ],
            ),
          ),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Scrollbar(
        thickness: 8.0,
        radius: const Radius.circular(8.0),
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 16.0, right: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            // Images du restaurant
            if (_images.isNotEmpty)
              RestaurantImageCarousel(
                images: _images,
                isEditable: true,
                onDelete: _removeImage,
                onEdit: _editImage,
              ),

            const SizedBox(height: 16),

            // Boutons d'ajout d'images
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _images.length < 3 ? _pickImage : null,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: Text('Ajouter une image (${_images.length}/3)'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _images.length < 3 ? _captureImage : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                  ),
                  child: const Icon(Icons.camera_alt),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Informations de base
            _buildSectionTitle('Informations de base'),
            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(
                labelText: 'Nom du restaurant',
                border: OutlineInputBorder(),
              ),
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

            const SizedBox(height: 16),

            TextFormField(
              initialValue: _description,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onSaved: (value) {
                _description = value;
              },
            ),

            const SizedBox(height: 16),

            // État (Ouvert/Fermé)
            SwitchListTile(
              title: const Text('État du restaurant'),
              subtitle: Text(_isOpen ? 'Ouvert' : 'Fermé'),
              value: _isOpen,
              onChanged: (bool value) {
                setState(() {
                  _isOpen = value;
                });
              },
            ),

            // Informations sur le propriétaire
            _buildSectionTitle('Informations sur le propriétaire'),
            TextFormField(
              initialValue: _ownerName,
              decoration: const InputDecoration(
                labelText: 'Nom du propriétaire',
                border: OutlineInputBorder(),
              ),
              onSaved: (value) {
                _ownerName = value;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              initialValue: _ownerDegrees,
              decoration: const InputDecoration(
                labelText: 'Diplômes',
                border: OutlineInputBorder(),
              ),
              onSaved: (value) {
                _ownerDegrees = value;
              },
            ),

            _buildSectionTitle('Informations générales'),
            TextFormField(
              initialValue: _openingYear?.toString(),
              decoration: const InputDecoration(
                labelText: 'Année d\'ouverture',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onSaved: (value) {
                _openingYear = (value != null && value.isNotEmpty) 
                  ? int.tryParse(value)
                  : null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              initialValue: _employeeCount?.toString(),
              decoration: const InputDecoration(
                labelText: 'Nombre d\'employés',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onSaved: (value) {
                _employeeCount = (value != null && value.isNotEmpty)
                  ? int.tryParse(value)
                  : null;
              },
            ),

            // Cuisine et services
            _buildSectionTitle('Cuisine et services'),
            TextFormField(
              initialValue: _signatureDishes,
              decoration: const InputDecoration(
                labelText: 'Plats signature',
                border: OutlineInputBorder(),
              ),
              onSaved: (value) {
                _signatureDishes = value;
              },
            ),

            const SizedBox(height: 16),

            // Types de cuisine
            Text('Types de cuisine', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: 8,
              children: {
                'Italien': 'italien',
                'Français': 'français',
                'Japonais': 'japonais',
                'Indien': 'indien',
                'Mexicain': 'mexicain',
                'Américain': 'américain',
                'Korean': 'korean',
                'marocan': 'marocain',
              }.entries.map((entry) => _buildCheckbox(
                entry.key,
                entry.value,
                _cuisineTypes,
              )).toList(),
            ),

            const SizedBox(height: 16),

            // Services disponibles
            Text('Services disponibles', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: 8,
              children: {
                'Terrasse': 'terrasse',
                'Livraison': 'livraison',
                'À emporter': 'emporter',
                'Parking': 'parking',
                'WiFi': 'wifi',
              }.entries.map((entry) => _buildCheckbox(
                entry.key,
                entry.value,
                _services,
              )).toList(),
            ),

            // Paiement et ambiance
            _buildSectionTitle('Paiement et ambiance'),
            Text('Moyens de paiement', style: Theme.of(context).textTheme.titleMedium),
            Wrap(
              spacing: 8,
              children: {
                'Carte': 'carte',
                'Espèces': 'espèces',
                'Mobile': 'mobile',
              }.entries.map((entry) => _buildCheckbox(
                entry.key,
                entry.value,
                _paymentMethods,
              )).toList(),
            ),

            const SizedBox(height: 16),

            // Gamme de prix
            _buildRadioSection(
              'Gamme de prix',
              _priceRange,
              {
                'Économique': 'économique',
                'Modéré': 'modéré',
                'Élevé': 'élevé',
              },
              (value) => setState(() => _priceRange = value),
            ),

            // Niveau sonore
            _buildRadioSection(
              'Niveau sonore',
              _noiseLevel,
              {
                'Calme': 'calme',
                'Modéré': 'modéré',
                'Vacarme': 'vacarme',
              },
              (value) => setState(() => _noiseLevel = value),
            ),

            // Atmosphère
            _buildRadioSection(
              'Ambiance',
              _atmosphere,
              {
                'Décontracté': 'décontracté',
                'Familial': 'familial',
                'Romantique': 'romantique',
              },
              (value) => setState(() => _atmosphere = value),
            ),

            const SizedBox(height: 24),

            // Section Évaluation
            _buildSectionTitle('Évaluation'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ratingController,
                    decoration: const InputDecoration(
                      labelText: 'Note sur 5',
                      hintText: 'Entrez un nombre entre 1 et 5',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final rating = int.tryParse(value);
                        if (rating == null || rating < 1 || rating > 5) {
                          return 'La note doit être entre 1 et 5';
                        }
                      }
                      return null;
                    },
                    onSaved: (value) {
                      if (value?.isNotEmpty == true) {
                        final rating = int.tryParse(value!);
                        if (rating != null && rating >= 1 && rating <= 5) {
                          setState(() {
                            _rating = rating;
                          });
                        }
                      }
                    },
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        final rating = int.tryParse(value);
                        if (rating != null && rating >= 1 && rating <= 5) {
                          setState(() {
                            _rating = rating;
                          });
                        }
                      } else if (widget.restaurant?.rating != null) {
                        setState(() {
                          _rating = widget.restaurant!.rating;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ratingCommentController,
              decoration: const InputDecoration(
                labelText: 'Commentaire',
                hintText: 'Donnez votre avis sur le restaurant',
              ),
              maxLines: 3,
              onSaved: (value) {
                if (value?.isNotEmpty == true) {
                  setState(() {
                    _ratingComment = value;
                  });
                } else if (widget.restaurant?.ratingComment != null) {
                  setState(() {
                    _ratingComment = widget.restaurant!.ratingComment;
                  });
                }
              },
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    _ratingComment = value;
                  });
                } else if (widget.restaurant?.ratingComment != null) {
                  setState(() {
                    _ratingComment = widget.restaurant!.ratingComment;
                  });
                }
              },
            ),

            const SizedBox(height: 24),

            // Rangée de boutons
            Row(
              children: [
                // Bouton Annuler
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Ferme le formulaire sans sauvegarder
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.grey,
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(width: 16), // Espacement entre les boutons

                // Bouton de soumission
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        final userId = Provider.of<SessionManager>(context, listen: false).currentUser?.id ?? '';

                        // Préserver les valeurs existantes ou utiliser les nouvelles valeurs
                        int? finalRating;
                        String? finalComment;

                        // Pour le rating
                        if (_ratingController.text.isNotEmpty) {
                          // Nouvelle valeur entrée
                          final parsedRating = int.tryParse(_ratingController.text.trim());
                          if (parsedRating != null && parsedRating >= 1 && parsedRating <= 5) {
                            finalRating = parsedRating;
                          }
                        }
                        // Si pas de nouvelle valeur valide, garder l'ancienne
                        if (finalRating == null) {
                          finalRating = _rating ?? widget.restaurant?.rating;
                        }

                        // Pour le commentaire
                        if (_ratingCommentController.text.isNotEmpty) {
                          // Nouvelle valeur entrée
                          finalComment = _ratingCommentController.text.trim();
                        } else {
                          // Garder l'ancienne valeur
                          finalComment = _ratingComment ?? widget.restaurant?.ratingComment;
                        }

                        debugPrint('Valeurs finales avant mise à jour :');
                        debugPrint('Rating actuel: $_rating');
                        debugPrint('Rating final: $finalRating');
                        debugPrint('Comment actuel: $_ratingComment');
                        debugPrint('Comment final: $finalComment');

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
                          rating: finalRating ?? widget.restaurant?.rating,  // Utiliser la valeur existante si pas de nouvelle valeur
                          ratingComment: finalComment ?? widget.restaurant?.ratingComment,  // Utiliser la valeur existante si pas de nouvelle valeur
                        );

                        widget.onSubmit(restaurant);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(
                      widget.restaurant == null ? 'Ajouter' : 'Mettre à jour',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ));
  }
}
