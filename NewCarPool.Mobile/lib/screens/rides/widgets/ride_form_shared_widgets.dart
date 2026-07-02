import 'package:flutter/material.dart';

class RideLocationField extends StatelessWidget {
  const RideLocationField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    this.onChanged,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      onChanged: onChanged,
      decoration: InputDecoration(
          labelText: label, prefixIcon: Icon(icon, color: color)),
      validator: (v) =>
          (v?.trim().isNotEmpty ?? false) ? null : '$label required',
    );
  }
}

class RideSeatSelector extends StatelessWidget {
  const RideSeatSelector({
    super.key,
    required this.seats,
    required this.onDec,
    required this.onInc,
  });
  final int seats;
  final VoidCallback? onDec;
  final VoidCallback? onInc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          IconButton(
              onPressed: onDec, icon: const Icon(Icons.remove_circle_outline)),
          Text('$seats', style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
              onPressed: onInc, icon: const Icon(Icons.add_circle_outline)),
        ],
      ),
    );
  }
}

class RidePickField extends StatelessWidget {
  const RidePickField({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

class RideRouteSummaryCard extends StatelessWidget {
  const RideRouteSummaryCard({
    super.key,
    this.distanceKm,
    this.etaMinutes,
    this.warning,
  });

  final double? distanceKm;
  final int? etaMinutes;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.route),
        title: Text('Distance: ${distanceKm?.toStringAsFixed(1) ?? '--'} km'),
        subtitle: Text(
            'ETA: ${etaMinutes ?? '--'} min${warning == null ? '' : ' • $warning'}'),
      ),
    );
  }
}

class RideTimeline extends StatelessWidget {
  const RideTimeline({
    super.key,
    required this.pickup,
    required this.stops,
    required this.destination,
  });
  final String pickup;
  final List<String> stops;
  final String destination;

  @override
  Widget build(BuildContext context) {
    final items = <String>[pickup, ...stops, destination];
    return Column(
      children: items.asMap().entries.map((e) {
        final first = e.key == 0;
        final last = e.key == items.length - 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Icon(
                    first
                        ? Icons.trip_origin
                        : (last ? Icons.location_on : Icons.more_horiz),
                    size: 18),
                if (!last)
                  Container(width: 2, height: 24, color: Colors.grey.shade300),
              ],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child:
                    Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
