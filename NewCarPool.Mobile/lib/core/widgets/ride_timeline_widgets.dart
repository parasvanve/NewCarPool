import 'package:flutter/material.dart';

import '../utils/location_display_formatter.dart';
import '../../models/ride_models.dart';

class RideTimelineNode {
  const RideTimelineNode({
    required this.label,
    required this.locationTitle,
    required this.timeLabel,
    required this.color,
  });

  final String label;
  final String locationTitle;
  final String timeLabel;
  final Color color;
}

List<RideTimelineNode> buildRideTimeline({
  required RideOffer ride,
  String? yourPickupName,
  String? yourDropName,
  required DateTime departureUtc,
}) {
  final nodes = <RideTimelineNode>[];
  final names = <String>[
    LocationDisplayFormatter.title(ride.origin),
    ...ride.intermediateStops
        .map((s) => LocationDisplayFormatter.title({'name': s.name, 'address': s.address})),
    LocationDisplayFormatter.title(ride.destination),
  ];
  for (var i = 0; i < names.length; i++) {
    final name = names[i];
    final isStart = i == 0;
    final isDestination = i == names.length - 1;
    final eta = departureUtc.toLocal().add(Duration(minutes: i * 10));
    final periodHour = eta.hour % 12;
    final hour = periodHour == 0 ? 12 : periodHour;
    final minute = eta.minute.toString().padLeft(2, '0');
    final meridian = eta.hour < 12 ? 'AM' : 'PM';
    final timeLabel = i == 0 ? '$hour:$minute $meridian' : '~$hour:$minute $meridian';

    var label = isStart
        ? 'Start (Driver Pickup)'
        : isDestination
            ? 'Destination'
            : 'Stop $i';
    if ((yourPickupName ?? '').trim().isNotEmpty && name == yourPickupName) {
      label = 'Stop $i (Your Pickup)';
    }
    if ((yourDropName ?? '').trim().isNotEmpty && name == yourDropName) {
      label = isDestination ? 'Destination (Your Drop)' : 'Stop $i (Your Drop)';
    }

    final color = isStart
        ? const Color(0xFF16A34A)
        : isDestination
            ? const Color(0xFFEF4444)
            : const Color(0xFF4F46E5);

    nodes.add(
      RideTimelineNode(
        label: label,
        locationTitle: name,
        timeLabel: timeLabel,
        color: color,
      ),
    );
  }
  return nodes;
}

class RideVerticalTimeline extends StatelessWidget {
  const RideVerticalTimeline({super.key, required this.nodes});

  final List<RideTimelineNode> nodes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < nodes.length; i++)
          _TimelineRow(node: nodes[i], showConnector: i < nodes.length - 1),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.node, required this.showConnector});

  final RideTimelineNode node;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: node.color, shape: BoxShape.circle),
              ),
              if (showConnector)
                Container(
                  width: 2,
                  height: 36,
                  color: const Color(0xFFD1D5DB),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        node.label,
                        style: TextStyle(fontWeight: FontWeight.w600, color: node.color),
                      ),
                    ),
                    Text(node.timeLabel, style: const TextStyle(color: Color(0xFF6B7280))),
                  ],
                ),
                const SizedBox(height: 3),
                Text(node.locationTitle, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class RideMiniProgressTimeline extends StatelessWidget {
  const RideMiniProgressTimeline({super.key, required this.nodes});

  final List<RideTimelineNode> nodes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < nodes.length; i++) ...[
              Container(width: 10, height: 10, decoration: BoxDecoration(color: nodes[i].color, shape: BoxShape.circle)),
              if (i < nodes.length - 1) const Expanded(child: Divider(thickness: 1.2, color: Color(0xFFC7CCD8))),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final node in nodes)
              Expanded(
                child: Text(
                  node.label.split(' ').first,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
