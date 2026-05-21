import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/widgets/app_design_system.dart';
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
      if (mounted) AppSnackBar.showError(context, 'Could not load vehicles.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VehicleProvider>();
    return Scaffold(
      backgroundColor: AppDesignTokens.pageBg,
      appBar: AppBar(title: const Text('My Vehicles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: RefreshIndicator(
            onRefresh: _load,
            child: provider.isLoading && provider.vehicles.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.vehicles.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(12),
                        children: [
                          const AppGradientHeroCard(
                            title: 'Vehicle Garage',
                            subtitle: 'Add your vehicle to start offering rides',
                            icon: Icons.garage_outlined,
                          ),
                          const SizedBox(height: 120),
                          Icon(Icons.garage_outlined, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Center(child: Text('No vehicles added yet.')),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                        itemCount: provider.vehicles.length,
                        itemBuilder: (context, index) {
                          final v = provider.vehicles[index];
                          return _VehicleCard(
                            vehicle: v,
                            onEdit: () => _openForm(context, vehicle: v),
                            onDelete: () => _confirmDelete(context, v),
                          );
                        },
                      ),
          ),
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

    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<VehicleProvider>().delete(vehicle.id);
      if (context.mounted) AppSnackBar.showSuccess(context, 'Vehicle deleted.');
    } catch (_) {
      if (context.mounted) AppSnackBar.showError(context, 'Could not delete vehicle.');
    }
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.onEdit,
    required this.onDelete,
  });

  final Vehicle vehicle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final icon = vehicle.vehicleType == VehicleType.bike ? Icons.two_wheeler : Icons.directions_car;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF1FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppDesignTokens.brandStart),
        ),
        title: Text(vehicle.vehicleName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${vehicle.vehicleNumber} • ${vehicle.color} • ${vehicle.seats} seats'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
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
    final v = widget.vehicle;
    _name = TextEditingController(text: v?.vehicleName ?? '');
    _number = TextEditingController(text: v?.vehicleNumber ?? '');
    _color = TextEditingController(text: v?.color ?? '');
    _rcImage = TextEditingController(text: v?.rcImagePath ?? '');
    _vehicleImage = TextEditingController(text: v?.vehicleImagePath ?? '');
    _type = v?.vehicleType ?? VehicleType.sedan;
    _seats = v?.seats ?? 4;
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
      backgroundColor: AppDesignTokens.pageBg,
      appBar: AppBar(title: Text(isEdit ? 'Edit Vehicle' : 'Add Vehicle')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Vehicle Name', prefixIcon: Icon(Icons.directions_car)),
                  validator: (v) => _required(v, 'Vehicle name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _number,
                  decoration: const InputDecoration(labelText: 'Vehicle Number', prefixIcon: Icon(Icons.confirmation_number_outlined)),
                  validator: (v) => _required(v, 'Vehicle number'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<VehicleType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Vehicle Type', prefixIcon: Icon(Icons.category_outlined)),
                  items: VehicleType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.label))).toList(),
                  onChanged: (v) => setState(() => _type = v ?? VehicleType.sedan),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _color,
                  decoration: const InputDecoration(labelText: 'Color', prefixIcon: Icon(Icons.palette_outlined)),
                  validator: (v) => _required(v, 'Color'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.event_seat),
                    const SizedBox(width: 8),
                    Text('Seats: $_seats'),
                    const Spacer(),
                    IconButton(onPressed: _seats > 1 ? () => setState(() => _seats--) : null, icon: const Icon(Icons.remove_circle_outline)),
                    IconButton(onPressed: _seats < 8 ? () => setState(() => _seats++) : null, icon: const Icon(Icons.add_circle_outline)),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _rcImage,
                  decoration: const InputDecoration(labelText: 'RC Image URL/Path', prefixIcon: Icon(Icons.image_outlined)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _vehicleImage,
                  decoration: const InputDecoration(labelText: 'Vehicle Image URL/Path', prefixIcon: Icon(Icons.photo_camera_outlined)),
                ),
                const SizedBox(height: 18),
                LoadingButton(
                  isLoading: _isSaving,
                  label: isEdit ? 'Update Vehicle' : 'Save Vehicle',
                  icon: Icons.save_outlined,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
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
    } on DioException catch (e) {
      final error = e.error;
      if (mounted) {
        AppSnackBar.showError(context, error is AppException ? error.message : 'Could not save vehicle.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _required(String? value, String field) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }
}
