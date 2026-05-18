import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/errors/app_exception.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_error_view.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../core/widgets/loading_button.dart';
import '../../models/vehicle_models.dart';
import '../../providers/vehicle_provider.dart';

class MyVehiclesScreen extends StatefulWidget {
  const MyVehiclesScreen({super.key});

  @override
  State<MyVehiclesScreen> createState() => _MyVehiclesScreenState();
}

class _MyVehiclesScreenState extends State<MyVehiclesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      await context.read<VehicleProvider>().loadMine();
    } catch (_) {
      if (mounted) {
        AppSnackBar.showError(context, 'Could not load vehicles.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VehicleProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('My Vehicles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Builder(
          builder: (_) {
            if (provider.isLoading && provider.vehicles.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.errorMessage != null && provider.vehicles.isEmpty) {
              return AppErrorView(message: 'Could not load vehicles.', onRetry: _load);
            }

            if (provider.vehicles.isEmpty) {
              return AppEmptyState(
                icon: Icons.garage_outlined,
                title: 'No vehicles added',
                message: 'Add your car or bike before offering a ride.',
                action: FilledButton.icon(
                  onPressed: () => _openForm(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Add vehicle'),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: provider.vehicles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final vehicle = provider.vehicles[index];
                return _VehicleCard(
                  vehicle: vehicle,
                  onEdit: () => _openForm(context, vehicle: vehicle),
                  onDelete: () => _confirmDelete(context, vehicle),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {Vehicle? vehicle}) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => VehicleFormScreen(vehicle: vehicle)));
  }

  Future<void> _confirmDelete(BuildContext context, Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete vehicle?'),
        content: Text('${vehicle.vehicleName} will be removed from your garage.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await context.read<VehicleProvider>().delete(vehicle.id);
      if (context.mounted) {
        AppSnackBar.showSuccess(context, 'Vehicle deleted.');
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackBar.showError(context, 'Could not delete vehicle.');
      }
    }
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle, required this.onEdit, required this.onDelete});

  final Vehicle vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(vehicle.vehicleType == VehicleType.bike ? Icons.two_wheeler : Icons.directions_car),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle.vehicleName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      Text('${vehicle.vehicleNumber} | ${vehicle.vehicleType.label} | ${vehicle.color}'),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${vehicle.seats} seats')),
                Chip(label: Text(vehicle.isVerified ? 'Verified' : 'Pending verification')),
                if (vehicle.rcImagePath?.isNotEmpty == true) const Chip(label: Text('RC uploaded')),
                if (vehicle.vehicleImagePath?.isNotEmpty == true) const Chip(label: Text('Vehicle image uploaded')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class VehicleFormScreen extends StatefulWidget {
  const VehicleFormScreen({super.key, this.vehicle});

  final Vehicle? vehicle;

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _number;
  late final TextEditingController _color;
  late final TextEditingController _rcImage;
  late final TextEditingController _vehicleImage;
  late VehicleType _type;
  late int _seats;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle;
    _name = TextEditingController(text: vehicle?.vehicleName ?? '');
    _number = TextEditingController(text: vehicle?.vehicleNumber ?? '');
    _color = TextEditingController(text: vehicle?.color ?? '');
    _rcImage = TextEditingController(text: vehicle?.rcImagePath ?? '');
    _vehicleImage = TextEditingController(text: vehicle?.vehicleImagePath ?? '');
    _type = vehicle?.vehicleType ?? VehicleType.sedan;
    _seats = vehicle?.seats ?? 4;
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _color.dispose();
    _rcImage.dispose();
    _vehicleImage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.vehicle != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Vehicle' : 'Add Vehicle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Vehicle name', prefixIcon: Icon(Icons.directions_car)),
              validator: (value) => _required(value, 'Vehicle name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Vehicle number', prefixIcon: Icon(Icons.confirmation_number_outlined)),
              validator: (value) => _required(value, 'Vehicle number'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<VehicleType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Vehicle type', prefixIcon: Icon(Icons.category_outlined)),
              items: VehicleType.values.map((type) => DropdownMenuItem(value: type, child: Text(type.label))).toList(),
              onChanged: (value) => setState(() => _type = value ?? VehicleType.sedan),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _color,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Color', prefixIcon: Icon(Icons.palette_outlined)),
              validator: (value) => _required(value, 'Color'),
            ),
            const SizedBox(height: 16),
            _SeatStepper(
              seats: _seats,
              onChanged: (value) => setState(() => _seats = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rcImage,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'RC image URL or path', prefixIcon: Icon(Icons.image_outlined)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _vehicleImage,
              decoration: const InputDecoration(labelText: 'Vehicle image URL or path', prefixIcon: Icon(Icons.photo_camera_outlined)),
            ),
            const SizedBox(height: 20),
            LoadingButton(
              isLoading: _isSaving,
              label: isEdit ? 'Update vehicle' : 'Save vehicle',
              icon: Icons.save_outlined,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    final input = UpsertVehicleInput(
      vehicleName: _name.text.trim(),
      vehicleNumber: _number.text.trim().toUpperCase(),
      vehicleType: _type,
      color: _color.text.trim(),
      seats: _seats,
      rcImagePath: _rcImage.text.trim().isEmpty ? null : _rcImage.text.trim(),
      vehicleImagePath: _vehicleImage.text.trim().isEmpty ? null : _vehicleImage.text.trim(),
    );

    try {
      final provider = context.read<VehicleProvider>();
      if (widget.vehicle == null) {
        await provider.add(input);
      } else {
        await provider.update(widget.vehicle!.id, input);
      }

      if (mounted) {
        AppSnackBar.showSuccess(context, widget.vehicle == null ? 'Vehicle added.' : 'Vehicle updated.');
        Navigator.pop(context);
      }
    } on DioException catch (exception) {
      final error = exception.error;
      if (mounted) {
        AppSnackBar.showError(context, error is AppException ? error.message : 'Could not save vehicle.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }
}

class _SeatStepper extends StatelessWidget {
  const _SeatStepper({required this.seats, required this.onChanged});

  final int seats;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_seat_outlined),
          const SizedBox(width: 12),
          const Expanded(child: Text('Seats')),
          IconButton(
            onPressed: seats > 1 ? () => onChanged(seats - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(width: 32, child: Center(child: Text('$seats'))),
          IconButton(
            onPressed: seats < 8 ? () => onChanged(seats + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }
}
