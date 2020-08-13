import 'package:flutter/material.dart';

class VehicleDataCard extends StatelessWidget {
  final _scrollController = ScrollController();
  final String title;
  final Widget child;
  final VoidCallback onReset;

  VehicleDataCard({@required this.title, @required this.child, this.onReset});

  Widget generateActionButtons(BuildContext context) {
    if (onReset != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            child: IconButton(
              icon: Icon(Icons.refresh, color: Theme.of(context).primaryColor),
              onPressed: () => onReset(),
            ),
          ),
        ],
      );
    } else {
      return Container();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              fit: StackFit.loose,
              children: [
                Container(
                  height: 30,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(4.0),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(4.0),
                    ),
                  ),
                  child: Text(
                    title,
                    style: TextStyle(color: Colors.white),
                    softWrap: false,
                    maxLines: 1,
                  ),
                ),
                generateActionButtons(context),
              ],
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(10),
                child: Scrollbar(
                  isAlwaysShown: true,
                  controller: _scrollController,
                  child: LayoutBuilder(
                    builder: (context, constraint) {
                      return SingleChildScrollView(
                        controller: _scrollController,
                        child: ConstrainedBox(
                          constraints: constraint,
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
