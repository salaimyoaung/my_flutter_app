import 'package:flutter/material.dart';
import '../../../../core/constants/device_types.dart';

class DeviceTypeConditionSection extends StatelessWidget {
  final String selectedDeviceType;
  final String selectedCondition;
  final ValueChanged<String?> onDeviceTypeChanged;
  final ValueChanged<String?> onConditionChanged;
  final List<String> conditions;

  const DeviceTypeConditionSection({
    super.key,
    required this.selectedDeviceType,
    required this.selectedCondition,
    required this.onDeviceTypeChanged,
    required this.onConditionChanged,
    required this.conditions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: selectedDeviceType,
          decoration: const InputDecoration(
            labelText: "Device Type",
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: DeviceTypes.androidPhone, child: Text("Android Phone")),
            DropdownMenuItem(value: DeviceTypes.androidTablet, child: Text("Android Tablet")),
            DropdownMenuItem(value: DeviceTypes.iphone, child: Text("iPhone")),
            DropdownMenuItem(value: DeviceTypes.ipad, child: Text("iPad")),
          ],
          onChanged: onDeviceTypeChanged,
        ),
        const SizedBox(height: 15),
        DropdownButtonFormField<String>(
          initialValue: selectedCondition,
          isExpanded: true, // ✅ prevents overflow on long condition strings
          decoration: const InputDecoration(
            labelText: "Condition",
            border: OutlineInputBorder(),
          ),
          items: conditions
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(
                      c,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: onConditionChanged,
        ),
      ],
    );
  }
}