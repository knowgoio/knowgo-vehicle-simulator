import 'package:flutter/material.dart';

class TextFieldAlertDialog extends StatefulWidget {
  final String title;
  final String initialValue;
  final ValueChanged<String> onSubmitted;

  TextFieldAlertDialog({
    @required this.title,
    this.initialValue,
    @required this.onSubmitted,
  });

  @override
  _TextFieldAlertDialogState createState() => _TextFieldAlertDialogState();
}

class _TextFieldAlertDialogState extends State<TextFieldAlertDialog> {
  var controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    controller.text = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: TextStyle(color: Theme.of(context).accentColor),
      ),
      content: TextField(
        controller: controller,
        onSubmitted: (_) {
          widget.onSubmitted(controller.text);
          Navigator.pop(context, true);
        },
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, false);
          },
          child: Text(
            'CANCEL',
            style: TextStyle(color: Theme.of(context).accentColor),
          ),
        ),
        TextButton(
          onPressed: () {
            widget.onSubmitted(controller.text);
            Navigator.pop(context, true);
          },
          child: Text(
            'UPDATE',
            style: TextStyle(
              color: Theme.of(context).accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
