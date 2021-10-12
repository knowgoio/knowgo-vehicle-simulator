import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_picker/flutter_picker.dart';
import 'package:knowgo/api.dart' as knowgo;
import 'package:knowgo_vehicle_simulator/icons.dart';
import 'package:knowgo_vehicle_simulator/services.dart';
import 'package:knowgo_vehicle_simulator/simulator.dart';
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
  RangeValues _pedalValues = const RangeValues(0, 100);
  EventTrigger _newEvent = EventTrigger.none;
  UniqueKey _eventTimelineKey = UniqueKey();
  List<StepState> _newEventStepState =
      List.generate(3, (_) => StepState.indexed);

  void _setNewEventStepState(int index, StepState stepState) {
    if (_newEventStepState[index] != stepState) {
      setState(() {
        _newEventStepState[index] = stepState;
      });
    }
  }

  void _newEventStepError(int index) {
    _setNewEventStepState(index, StepState.error);
  }

  void _newEventStepComplete(int index) {
    _setNewEventStepState(index, StepState.indexed);
  }

  String describeTimedEvent(TimedEvent event) {
    String eventDesc = event.injectionTime.toHoursMinutesSecondsAnnotated();

    switch (event.trigger) {
      case EventTrigger.harsh_acceleration: // fall through
      case EventTrigger.harsh_braking:
        eventDesc += ', Pedal Variance: ' +
            (event.data['pedal_end_position'] -
                    event.data['pedal_start_position'])
                .toString() +
            '%';
        break;
      default:
        break;
    }

    return eventDesc;
  }

  List<Step> generateScheduledEventSteps() {
    final injector = Provider.of<EventInjectorModel>(context, listen: false);
    List<Step> steps = [];

    injector.events.forEach((event) {
      final step = Step(
        title: Text(describeEnum(event.trigger).snakeCaseToSentenceCaseUpper()),
        subtitle: Text(describeTimedEvent(event)),
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
                      primary: Theme.of(context).colorScheme.secondary,
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
                primary: Theme.of(context).colorScheme.secondary,
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

  // Construct the per-event payload based on the user-provided data
  Map<String, dynamic> eventTriggerDataToMap(EventTrigger trigger) {
    Map<String, dynamic> eventMap = {};
    switch (trigger) {
      case EventTrigger.harsh_acceleration: // fall through
      case EventTrigger.harsh_braking:
        eventMap['pedal_start_position'] = _pedalValues.start.floorToDouble();
        eventMap['pedal_end_position'] = _pedalValues.end.floorToDouble();
        break;
      default:
        break;
    }
    return eventMap;
  }

  // Generate the requisite widgets for obtaining necessary per-event data,
  // the results of which are encoded by [eventTriggerDataToMap] and passed
  // off to the event injector.
  Widget generateEventTriggerContent(EventTrigger trigger) {
    switch (trigger) {
      case EventTrigger.harsh_acceleration: // fall through
      case EventTrigger.harsh_braking:
        return Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              trigger == EventTrigger.harsh_acceleration
                  ? 'Accelerator Pedal Positions'
                  : 'Brake Pedal Positions',
              style: Theme.of(context)
                  .textTheme
                  .headline6!
                  .copyWith(color: Colors.black45, fontSize: 14),
            ),
            RangeSlider(
              min: 0,
              max: 100,
              divisions: 100,
              labels: RangeLabels(
                _pedalValues.start.round().toString(),
                _pedalValues.end.round().toString(),
              ),
              values: _pedalValues,
              onChanged: (RangeValues values) {
                int start = values.start.round();
                int end = values.end.round();

                // Restrict possible ranges such that there's a sufficient
                // difference in relative pedal positioning to trigger the
                // event detector.
                if ((end - start) >= 65) {
                  setState(() {
                    _pedalValues = values;
                  });
                }
              },
            ),
            Text(
                '${(_pedalValues.end.round() - _pedalValues.start.round()).toString()}%'),
          ],
        );
      default:
        break;
    }

    return Text('No event type selected');
  }

  void addTimedEvent(EventInjectorModel injector) {
    final _consoleService = serviceLocator<ConsoleService>();
    final vehicleSimulator =
        Provider.of<VehicleSimulator>(context, listen: false);

    injector.addTimedEvent(
      TimedEvent(
        injectionTime: _newEventDuration,
        trigger: _newEvent,
        data: eventTriggerDataToMap(_newEvent),
        callback: (timedEvent) {
          List<knowgo.Event> events = [];

          switch (timedEvent.trigger) {
            case EventTrigger.harsh_acceleration:
              var prevState = knowgo.Event();
              var newState = knowgo.Event();

              prevState.acceleratorPedalPosition =
                  timedEvent.data['pedal_start_position'];
              newState.acceleratorPedalPosition =
                  timedEvent.data['pedal_end_position'];

              events.add(prevState);
              events.add(newState);

              break;
            case EventTrigger.harsh_braking:
              var prevState = knowgo.Event();
              var newState = knowgo.Event();

              prevState.brakePedalPosition =
                  timedEvent.data['pedal_start_position'];
              newState.brakePedalPosition =
                  timedEvent.data['pedal_end_position'];

              events.add(prevState);
              events.add(newState);

              break;
            default:
              break;
          }

          if (events.isNotEmpty) {
            vehicleSimulator.enqueueUpdates(events);
          }

          _consoleService.write(
              'Injecting ${describeEnum(timedEvent.trigger).snakeCaseToSentenceCaseUpper()} event');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final injector = Provider.of<EventInjectorModel>(context);
    final portraitMode =
        MediaQuery.of(context).orientation == Orientation.portrait;
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
          // TODO: Split out about widget for sharing across views
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
                applicationVersion: '1.2.0',
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
            child: Flex(
              direction: portraitMode ? Axis.vertical : Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      Text(
                        'Schedule an Event',
                        style: Theme.of(context)
                            .textTheme
                            .headline6!
                            .copyWith(color: Colors.black45),
                        textAlign: TextAlign.center,
                      ),
                      Stepper(
                        steps: [
                          Step(
                            title: Text('Select Event'),
                            subtitle: _newEvent != EventTrigger.none
                                ? Text(describeEnum(_newEvent)
                                    .snakeCaseToSentenceCaseUpper())
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
                                    eventTriggerStringToEnum(
                                        value.toSnakeCase());
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
                                  child: Text(
                                      eventDesc.snakeCaseToSentenceCaseUpper()),
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
                                primary:
                                    Theme.of(context).colorScheme.secondary,
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
                          Step(
                            title: Text('Provide Additional Data'),
                            content: generateEventTriggerContent(_newEvent),
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
                  child: ListView(
                    children: [
                      Text(
                        'Timeline',
                        style: Theme.of(context)
                            .textTheme
                            .headline6!
                            .copyWith(color: Colors.black45),
                        textAlign: TextAlign.center,
                      ),
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
                          : Text('No events scheduled',
                              textAlign: TextAlign.center),
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
