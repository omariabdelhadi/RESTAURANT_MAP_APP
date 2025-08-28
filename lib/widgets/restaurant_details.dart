import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/restaurant_model.dart';
import 'restaurant_image_carousel.dart';
import '../services/local_db_sqlite.dart';

class RestaurantDetails extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback? onEdit;
  final VoidCallback? onDeleted;
  final VoidCallback? onRoute;
  final String currentUserId;

  const RestaurantDetails({
    super.key,
    required this.restaurant,
    required this.currentUserId,
    this.onEdit,
    this.onDeleted,
    this.onRoute,
  });
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
  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce restaurant ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await LocalDbSqlite.deleteRestaurant(restaurant.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Restaurant supprimé')),
          );
          if (onDeleted != null) {
            onDeleted!();
          }
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (restaurant.userId == currentUserId) ...[
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: onEdit,
              ),
            IconButton(
              icon: const Icon(Icons.delete),
              color: Colors.red,
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ],
      ),
      body: Scrollbar(
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
            if (restaurant.images.isNotEmpty)
              RestaurantImageCarousel(images: restaurant.images),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // État (Ouvert/Fermé)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: restaurant.isOpen ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      restaurant.isOpen ? 'Ouvert' : 'Fermé',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildSectionTitle('Informations de base'),
                  Text(
                      'Nom du restaurant:',
                      style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(restaurant.name),
                  const SizedBox(height: 16),
                  if (restaurant.description?.isNotEmpty == true) ...[
                    Text(
                      'Description:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(restaurant.description!),
                    const SizedBox(height: 16),
                  ],

      
                  if (restaurant.ownerName?.isNotEmpty == true ||
                      restaurant.ownerDegrees?.isNotEmpty == true) ...[
                    _buildSectionTitle('Informations sur le propriétaire'),
                    if (restaurant.ownerName?.isNotEmpty == true) ...[
                    Text(
                      'Nom de propriétaire:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('${restaurant.ownerName}'),
                    const SizedBox(height: 16),
                    ],
                    if (restaurant.ownerDegrees?.isNotEmpty == true) ...[
                    Text(
                      'Diplomes:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('${restaurant.ownerDegrees}'),
                    const SizedBox(height: 16),
                    ],
                  ],

                  if ((restaurant.openingYear != null && restaurant.openingYear.toString().isNotEmpty) ||
                      (restaurant.employeeCount != null && restaurant.employeeCount.toString().isNotEmpty)) ...[
                    _buildSectionTitle('Informations générales'),
                    if (restaurant.openingYear != null && restaurant.openingYear.toString().isNotEmpty) ...[
                    Text(
                      'Année d\'ouverture:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('${restaurant.openingYear}'),
                    const SizedBox(height: 16),
                    ],
                    if (restaurant.employeeCount != null && restaurant.employeeCount.toString().isNotEmpty) ...[
                    Text(
                      'nombre d\'employés:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('${restaurant.employeeCount}'),
                    const SizedBox(height: 16),
                    ],
                  ],
                  if(restaurant.signatureDishes?.isNotEmpty == true ||
                      restaurant.cuisineTypes.isNotEmpty == true ||
                      restaurant.availableServices.isNotEmpty == true
                      ) ...[
                    _buildSectionTitle('Cuisine et services'),
                  ],                          
                  if (restaurant.signatureDishes?.isNotEmpty == true) ...[
        
                    Text(
                      'Plats signature',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(restaurant.signatureDishes!),
                    const SizedBox(height: 16),
                  ],

                  // Types de cuisine
                  if (restaurant.cuisineTypes.isNotEmpty) ...[
                    Text(
                      'Types de cuisine',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Wrap(
                      spacing: 8,
                      children: restaurant.cuisineTypes
                          .map((type) => Chip(label: Text(type)))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Services disponibles
                  if (restaurant.availableServices.isNotEmpty) ...[
                    Text(
                      'Services disponibles',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Wrap(
                      spacing: 8,
                      children: restaurant.availableServices
                          .map((service) => Chip(label: Text(service)))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],
            
                  if (restaurant.priceRange?.isNotEmpty == true ||
                      restaurant.noiseLevel?.isNotEmpty == true ||
                      restaurant.atmosphere?.isNotEmpty == true || restaurant.paymentMethods.isNotEmpty == true
                      ) ...[
                    _buildSectionTitle('Paiement et ambiance'),
                    if (restaurant.paymentMethods.isNotEmpty) ...[
                      Text(
                        'Modes de paiement acceptés',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Wrap(
                        spacing: 8,
                        children: restaurant.paymentMethods
                          .map((method) => Chip(label: Text(method)))
                          .toList(),
                        ),
                      const SizedBox(height: 16),
                    ],
                    if (restaurant.priceRange?.isNotEmpty == true) ...[
                    Text(
                      'Gamme de prix:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('${restaurant.priceRange}'),
                    const SizedBox(height: 16),
                    ],
                    if (restaurant.noiseLevel?.isNotEmpty == true) ...[
                    Text(
                      'Niveau sonore:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('${restaurant.noiseLevel}'),
                    const SizedBox(height: 16),
                    ],
                    if (restaurant.atmosphere?.isNotEmpty == true) ...[
                    Text(
                      'Ambiance:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('${restaurant.atmosphere}'),
                    const SizedBox(height: 16),
                    ],
                  ],
                  
                  if (restaurant.rating != null || restaurant.ratingComment?.isNotEmpty == true) ...[
                    _buildSectionTitle('Évaluation'),
                    if (restaurant.rating != null)
                      Row(
                        children: [
                          ...List.generate(
                            5,
                            (index) => Icon(
                              index < (restaurant.rating ?? 0) ? Icons.star : Icons.star_border,
                              color: Colors.amber,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    if (restaurant.ratingComment?.isNotEmpty == true) ...[
                    Text(
                      'Commentaire:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('${restaurant.ratingComment}'),
                    const SizedBox(height: 16),
                    ],
                
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Bouton d'itinéraire
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onRoute,
                      icon: const Icon(Icons.directions),
                      label: const Text('Obtenir l\'itinéraire'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
