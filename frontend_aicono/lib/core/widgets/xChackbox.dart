import 'package:flutter/material.dart';

class XCheckBox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const XCheckBox({Key? key, required this.value, required this.onChanged})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          onChanged(!value);
        },
        borderRadius: BorderRadius.circular(2),
        child: Container(
          width: 20,
          height: 20,
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black87, width: 1),
            borderRadius: BorderRadius.circular(2),
          ),
          child: value == true
              ? const Center(
                  child: Icon(
                    Icons.close, // X icon
                    size: 14,
                    color: Colors.black,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}
