import 'package:flutter/material.dart';

class CustomRadioGroup extends StatelessWidget {
  final String? groupValue;
  final Map<String, String> options;
  final Function(String?) onChanged;

  const CustomRadioGroup({
    super.key,
    required this.groupValue,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries.map((entry) => 
        GestureDetector(
          onTap: () {
            if (entry.value == groupValue) {
              onChanged(null); // Désélectionne si déjà sélectionné
            } else {
              onChanged(entry.value);
            }
          },
          child: Container(
            width: 160,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: entry.value == groupValue ? Theme.of(context).primaryColor : Colors.grey,
              ),
              borderRadius: BorderRadius.circular(8),
              color: entry.value == groupValue ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: entry.value == groupValue ? Theme.of(context).primaryColor : Colors.grey,
                    ),
                    color: entry.value == groupValue ? Theme.of(context).primaryColor : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      color: entry.value == groupValue ? Theme.of(context).primaryColor : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ).toList(),
    );
  }
}