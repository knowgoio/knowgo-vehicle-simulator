import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_picker/flutter_picker.dart';
import 'package:knowgo_vehicle_simulator/icons.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
import 'package:knowgo_vehicle_simulator/simulator/event_injector.dart';
import 'package:knowgo_vehicle_simulator/utils.dart';
import 'package:knowgo_vehicle_simulator/widgets.dart';
import 'package:provider/provider.dart';

class EventInjectionHome extends StatefulWidget {
  const EventInjectionHome({Key? key}) : super(key: key);

  @override
  _EventInjectionHomeState createState() => _EventInjectionHomeState();
}

class _EventInjectionHomeState extends State<EventInjectionHome> {
  var _newEventDuration = Duration();
  int _newEventStep = 0;
  int _currentEventTimelineStep = 0;
  EventTrigger _newEvent = EventTrigger.none;
  UniqueKey _eventTimelineKey = UniqueKey();
  List<StepState> _newEventStepState =
      List.generate(3, (_) => StepState.indexed);

  void _newEventStepError(int index) {
    if (_newEventStepState[index] != StepState.error) {
      setState(() {
        _newEventStepState[index] = StepState.error;
      });
    }
  }

  void _newEventStepComplete(int index) {
    if (_newEventStepState[index] != StepState.indexed) {
      setState(() {
        _newEventStepState[index] = StepState.indexed;
      });
    }
  }

  List<Step> generateScheduledEventSteps() {
    final injector = Provider.of<EventInjectorModel>(context, listen: false);
    List<Step> steps = [];

    injector.events.forEach((event) {
      final step = Step(
        title: Text(describeEnum(event.trigger)),
        subtitle: Text(event.injectionTime.toHoursMinutesSecondsAnnotated()),
        isActive: event.enabled,
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            event.enabled
                ? OutlinedButton.icon(
                    icon: Icon(Icons.cancel_outlined),
                    label: Text('DISABLE'),
                    onPressed: () {
                      setState(() {
                        event.disable();
                      });
                    },
                  )
                : ElevatedButton.icon(
                    icon: Icon(Icons.check_circle_outline, color: Colors.white),
                    label:
                        Text('ENABLE', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      primary: Theme.of(context).accentColor,
                      onPrimary: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        event.enable();
                      });
                    },
                  ),
            ElevatedButton.icon(
              icon: Icon(Icons.delete, color: Colors.white),
              label: Text('DELETE', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                primary: Theme.of(context).accentColor,
                onPrimary: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  injector.removeTimedEvent(event.id);
                });
              },
            ),
          ],
        ),
      );
      steps.add(step);
    });

    setState(() {
      // Force a new key for the timeline stepper on step changes in order
      // to cause a new Stepper instance to be created on update and the old
      // one disposed. This is required as the Stepper widget itself is not
      // dynamic and will blow up if the new and old widget states don't have
      // an identical number of steps.
      _eventTimelineKey = UniqueKey();
    });

    return steps;
  }

  void addTimedEvent(EventInjectorModel injector) {
    injector.addTimedEvent(
      TimedEvent(
        injectionTime: _newEventDuration,
        trigger: _newEvent,
        callback: () {
          print('Event injection callback fired');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final injector = Provider.of<EventInjectorModel>(context);
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              'Event Injection',
              style: Theme.of(context).textTheme.headline6,
            ),
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(KnowGoIcons.knowgo, color: Colors.white),
            tooltip: 'About KnowGo Vehicle Simulator',
            onPressed: () {
              return showAboutDialog(
                context: context,
                applicationIcon: Icon(
                  KnowGoIcons.knowgo,
                  color: Theme.of(context).primaryColor,
                ),
                applicationName: 'KnowGo Vehicle Simulator',
                applicationVersion: '1.1.1',
                applicationLegalese: '© 2020-2021 Adaptant Solutions AG',
              );
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.grey,
        child: VehicleDataCard(
          title: 'Scheduled Events',
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('Schedule an Event',
                          style: Theme.of(context)
                              .textTheme
                              .headline6!
                              .copyWith(color: Colors.black45)),
                      Stepper(
                        steps: [
                          Step(
                            title: Text('Select Event'),
                            subtitle: _newEvent != EventTrigger.none
                                ? Text(describeEnum(_newEvent))
                                : Container(),
                            content: DropdownButtonFormField(
                              decoration: InputDecoration(
                                labelText: 'Event',
                              ),
                              validator: (String? value) {
                                if (value == null) {
                                  return 'Invalid event selection';
                                }

                                EventTrigger selected =
                                    eventTriggerStringToEnum(value);
                                if (selected == EventTrigger.none) {
                                  return 'No event selected';
                                }

                                return null;
                              },
                              autovalidateMode: AutovalidateMode.always,
                              value: describeEnum(_newEvent),
                              items: injector.supportedEvents.map((event) {
                                String eventDesc = describeEnum(event);
                                return DropdownMenuItem<String>(
                                  value: eventDesc,
                                  child: Text(eventDesc),
                                );
                              }).toList(),
                              onChanged: (String? value) {
                                if (value != null) {
                                  setState(() {
                                    _newEvent = eventTriggerStringToEnum(value);
                                  });
                                }
                              },
                            ),
                            isActive: _newEvent != EventTrigger.none,
                            state: _newEventStepState[0],
                          ),
                          Step(
                            title: Text('Select Injection Time'),
                            subtitle: _newEventDuration.inSeconds > 0
                                ? Text(_newEventDuration
                                    .toHoursMinutesSecondsAnnotated())
                                : Container(),
                            content: ElevatedButton.icon(
                              label: Text('Select Time',
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                primary: Theme.of(context).accentColor,
                                onPrimary: Colors.white,
                              ),
                              icon: Icon(Icons.timer, color: Colors.white),
                              onPressed: () {
                                Picker(
                                  adapter: NumberPickerAdapter(
                                      data: <NumberPickerColumn>[
                                        const NumberPickerColumn(
                                          begin: 0,
                                          end: 999,
                                          suffix: Text(' h'),
                                        ),
                                        const NumberPickerColumn(
                                          begin: 0,
                                          end: 59,
                                          suffix: Text(' m'),
                                        ),
                                        const NumberPickerColumn(
                                          begin: 0,
                                          end: 59,
                                          suffix: Text(' s'),
                                        ),
                                      ]),
                                  delimiter: <PickerDelimiter>[
                                    PickerDelimiter(
                                      column: 1,
                                      child: Container(
                                        width: 20.0,
                                        alignment: Alignment.center,
                                        child: Icon(Icons.more_vert),
                                      ),
                                    ),
                                    PickerDelimiter(
                                      column: 3,
                                      child: Container(
                                        width: 20.0,
                                        alignment: Alignment.center,
                                        child: Icon(Icons.more_vert),
                                      ),
                                    ),
                                  ],
                                  builderHeader: (context) {
                                    return Text(
                                        'Select the time into the journey when the event should be injected into the simulation');
                                  },
                                  cancelText: 'CANCEL',
                                  cancelTextStyle: TextStyle(
                                    inherit: false,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  confirmText: 'OK',
                                  confirmTextStyle: TextStyle(
                                    inherit: false,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  title: Text('Select Injection Time',
                                      style: TextStyle(
                                          color:
                                              Theme.of(context).primaryColor)),
                                  selectedTextStyle: TextStyle(
                                      color: Theme.of(context).primaryColor),
                                  onConfirm: (Picker picker, List<int> value) {
                                    final values = picker.getSelectedValues();
                                    setState(() {
                                      _newEventDuration = Duration(
                                        hours: values[0],
                                        minutes: values[1],
                                        seconds: values[2],
                                      );
                                    });
                                  },
                                ).showDialog(context);
                              },
                            ),
                            isActive: _newEventDuration.inSeconds > 0,
                            state: _newEventStepState[1],
                          ),
                          // TODO: Add trigger-specific data configuration
                          Step(
                            title: Text('Provide Additional Data'),
                            content: Container(),
                            isActive: _newEventStep >= 2,
                            state: _newEventStepState[2],
                          ),
                        ],
                        currentStep: _newEventStep,
                        onStepTapped: (step) {
                          setState(() {
                            _newEventStep = step;
                          });
                        },
                        onStepContinue: () {
                          if (_newEventStep < 3) {
                            if (_newEventStep == 0 &&
                                _newEvent == EventTrigger.none) {
                              _newEventStepError(_newEventStep);
                              return;
                            } else if (_newEventStep == 1 &&
                                _newEventDuration.inSeconds == 0) {
                              _newEventStepError(_newEventStep);
                              return;
                            } else if (_newEventStep == 2 &&
                                _newEvent != EventTrigger.none &&
                                _newEventDuration.inSeconds > 0) {
                              // Insert the new event into the injector model
                              addTimedEvent(injector);

                              // As all steps are complete, collapse the last
                              // step and reset the selections.
                              setState(() {
                                _newEventStepComplete(_newEventStep);
                                _newEventStep = 0;
                                _newEvent = EventTrigger.none;
                                _newEventDuration = Duration();
                              });

                              return;
                            }

                            // Don't advance beyond the last step
                            if (_newEventStep < 2) {
                              setState(() {
                                _newEventStepComplete(_newEventStep);
                                _newEventStep += 1;
                              });
                            }
                          }
                        },
                        onStepCancel: () {
                          if (_newEventStep > 0) {
                            setState(() {
                              _newEventStep -= 1;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                VerticalDivider(),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text('Timeline',
                          style: Theme.of(context)
                              .textTheme
                              .headline6!
                              .copyWith(color: Colors.black45)),
                      injector.events.length > 0
                          ? Stepper(
                              key: _eventTimelineKey,
                              steps: generateScheduledEventSteps(),
                              currentStep: _currentEventTimelineStep,
                              onStepTapped: (step) {
                                setState(() {
                                  _currentEventTimelineStep = step;
                                });
                              },
                              onStepContinue: () {
                                if (_currentEventTimelineStep <
                                    injector.events.length - 1) {
                                  setState(() {
                                    _currentEventTimelineStep += 1;
                                  });
                                } else {
                                  setState(() {
                                    _currentEventTimelineStep = 0;
                                  });
                                }
                              },
                              onStepCancel: () {
                                if (_currentEventTimelineStep > 0) {
                                  setState(() {
                                    _currentEventTimelineStep -= 1;
                                  });
                                }
                              },
                            )
                          : Text('No events scheduled'),
                    ],
                  ),
                ),
                VerticalDivider(),
                Expanded(
                  child: Column(
                    children: [
                      Container(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
