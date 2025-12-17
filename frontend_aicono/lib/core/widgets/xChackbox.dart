import 'package:flutter/material.dart';

class XCheckBox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;

  const XCheckBox({Key? key, required this.value, required this.onChanged})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),

      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black87, width: 1),
        ),
        child: value
            ? const Center(
                child: Icon(
                  Icons.close, // X icon
                  size: 16,
                  color: Colors.black,
                ),
              )
            : null,
      ),
    );
  }
}
