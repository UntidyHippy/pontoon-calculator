import 'package:flutter/material.dart';

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;

//
// ToDo - 'Done' button not activating on the start-up screen. (Fixed 29/2/2024)

void main() {
  // Because am running the app after getting preferences, I have
  // to run this first otherwise it complains.
  WidgetsFlutterBinding.ensureInitialized();

  // Because preferences are handled asynchronously, have to wait
  // until I have fetched them before running the app.
  AppData.initBoatData().whenComplete(() {
    //AppData.showWelcomeDialog = true;
    //AppData.boatName = null;

    /* ADD SOME TEST DATA TO STAYS FOR DEBUGGING.
    AppData.setStays(CalculatedStay.getCalculatedStayTestList());

    AppData.getStays().forEach((element) {
      element.printCalculatedStay();
    });

     */

    runApp(const MyApp());
  });
}


class Rates {
  static const double standardRate = 1.30;
  static const double visitorRate = 2.60;
  static const double membersDiscountRate = 0.65;

  static String getFormattedRate(double rate) {
    return '£' + rate.toStringAsFixed(2);
  }
}

class Constants {
  static const double rowHeight = 50;

  static const TextStyle boldStyle = TextStyle(fontWeight: FontWeight.bold, height: 1.2);

  static const TextStyle textLabelStyle = TextStyle(
      color: Colors.black45,
      fontSize: 22,
      fontWeight: FontWeight.bold,
      height: 1.2);

  static const TextStyle questionsStyle = TextStyle(
      color: Colors.black45,
      fontSize: 16,
      fontWeight: FontWeight.bold,
      height: 1.2);

  static const TextStyle welcomeTextStyle = TextStyle(
      fontSize: 18,
      color: Colors.black45,
      fontWeight: FontWeight.normal,
      height: 1.5);

  static const TextStyle baseListOwed = TextStyle(
      fontSize: 18, color: Colors.black, fontWeight: FontWeight.normal);

  static const TextStyle baseListPaid = TextStyle(
      fontSize: 18, color: Colors.black45, fontWeight: FontWeight.normal);

  static const TextStyle listTextStyle = TextStyle(
      fontWeight: FontWeight.normal, height: 1.5, color: Colors.black);

  static const TextStyle itemBackgroundFeeOwedStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.purpleAccent,
      height: 1.2);

  static final TextStyle itemBackgroundFeePaidStyle = TextStyle(
      fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple[75]);

  static final TextStyle boatNameStyle = TextStyle(
      fontSize: 20, fontWeight: FontWeight.normal, color: Colors.purple[75]);

  static const TextStyle feePaidStyle = TextStyle(
      fontWeight: FontWeight.bold, color: Colors.brown, height: 1.5);

  static const TextStyle feeOwedStyle = TextStyle(
      fontWeight: FontWeight.bold, color: Colors.blue, height: 1.5);

  static String formatDate(DateTime dateTime) {
    return dateTime.day.toString() +
        '/' +
        dateTime.month.toString() +
        '/' +
        dateTime.year.toString();
  }
}

/*
 Wrapper class for list of Calculated stays to be able to
 serialise this list into JSON so that it can be stored in
 preferences.

 */
class CalculatedStayList {

  final List<CalculatedStay> stays;

  CalculatedStayList(this.stays);

  CalculatedStayList.fromJson(Map<String, dynamic> json)
      : stays = json['stays'] != null
  //? List<CalculatedStay>.from(json['stays'])
      ? buildList(json)
      : <CalculatedStay>[];

  Map<String, dynamic> toJson() => {
    'stays': stays,
  };

  List<CalculatedStay> getStays() {
    return stays;
  }

  static List<CalculatedStay> buildList(Map<String, dynamic> decodedStays) {
    List<dynamic> decodedJson = decodedStays['stays'];
    List<CalculatedStay> stays = <CalculatedStay>[];
    decodedJson.forEach((elem) {
      stays.add(CalculatedStay.fromJson(elem));
    });
    return stays;
  }
}

class CalculatedStay {
  String boatName;
  DateTime startStay;
  DateTime endStay;
  String fee;

  bool isMember;
  bool paid = false;

  double standardRate;
  double visitorRate;
  double membersDiscountRate;
  String boatLengthNearestHalfMeter;

  double pontoonCharge = 0;

  int daysAtVisitorRate = 0;
  int daysAtStandardRate = 0;
  int daysAtMembersDiscountRate = 0;

  CalculatedStay(
      this.boatName,
      this.startStay,
      this.endStay,
      this.fee,
      this.isMember,
      this.standardRate,
      this.visitorRate,
      this.membersDiscountRate,
      this.boatLengthNearestHalfMeter);

  CalculatedStay.fromJson(Map<String, dynamic> json)
      : boatName = json['boatName'],
        startStay = DateTime.parse(json['startDate']),
        endStay = DateTime.parse(json['endDate']),
        fee = json['fee'],
        isMember = json['isMember'],
        standardRate = json['standardRate'],
        visitorRate = json['visitorRate'],
        membersDiscountRate = json['membersDiscountRate'],
        boatLengthNearestHalfMeter = json['lengthToHalfMeter'];

  Map<String, dynamic> toJson() => {
    'boatName': boatName,
    'startDate': startStay.toString(),
    'endDate': endStay.toString(),
    'fee': fee,
    'isMember': isMember,
    'standardRate': standardRate,
    'visitorRate': visitorRate,
    'membersDiscountRate': membersDiscountRate,
    'lengthToHalfMeter': boatLengthNearestHalfMeter
  };

  void printCalculatedStay() {
    print(boatName +
        ' ' +
        startStay.toString() +
        ' ' +
        endStay.toString() +
        ' £' +
        fee +
        ' ' +
        isMember.toString() +
        ' ');
  }

  String getBreakdown() {
    String visitorRateText = daysAtVisitorRate.toString() +
        ' day(s) at ' +
        Rates.getFormattedRate(visitorRate) +
        '/M ';
    String standardRateText = daysAtStandardRate.toString() +
        ' day(s) at ' +
        Rates.getFormattedRate(standardRate) +
        '/M ';
    String discountRateText = daysAtMembersDiscountRate.toString() +
        ' day(s) at ' +
        Rates.getFormattedRate(membersDiscountRate) +
        '/M';

    print(
        'Days at visitor $visitorRateText $standardRateText $discountRateText');

    List<String> days = ['Mon', 'Tues', 'Weds', 'Thurs', 'Fri', 'Sat', 'Sun'];

    return 'Arrival\n' +
        days[startStay.weekday].toString() +
        ' - ' +
        Constants.formatDate(startStay) +
        '\n\n' +
        'Departure\n' +
        days[endStay.weekday].toString() +
        ' - ' +
        Constants.formatDate(endStay) +
        '\n\n' +
        '$boatName (' +
        boatLengthNearestHalfMeter +
        'M)\n\n' +
        '' +
        (daysAtVisitorRate == 0 ? '' : '$visitorRateText\n\n') +
        (daysAtStandardRate == 0 ? '' : '$standardRateText\n\n') +
        (daysAtMembersDiscountRate == 0 ? '' : '$discountRateText\n\n') +
        'Fee: ' +
        fee;
  }

  void calculateFee() {
    pontoonCharge = 0;

    daysAtVisitorRate = 0;
    daysAtStandardRate = 0;
    daysAtMembersDiscountRate = 0;

    double boatLength = double.parse(AppData.boatLengthNearestHalfMeter);
    bool isMember = AppData.getIsMember();

    //if (errorMsg != '') return;

    Duration day = const Duration(days: 1);

    /* for (DateTime d = startStay;
        endStay.difference(d).inDays > 0;
        d = d.add(day)) {*/

    print('Start stay:' + startStay.toString());
    print('End stay:' + endStay.toString());

    //print('Difference in days ' + endStay.difference(d).inDays.toString());

    for (DateTime d = startStay;
    endStay.difference(d).inDays > 0;
    d = d.add(day)) {
      if (isMember == false) {
        pontoonCharge += Rates.visitorRate * boatLength;
        daysAtVisitorRate++;
        continue;
      }

      if (d.weekday == DateTime.friday || d.weekday == DateTime.saturday) {
        pontoonCharge += Rates.standardRate * boatLength;
        daysAtStandardRate++;
        print("Discount day");
      } else {
        pontoonCharge += Rates.membersDiscountRate * boatLength;
        daysAtMembersDiscountRate++;
        print("Non Discount day");
      }
    }

    fee = Rates.getFormattedRate(pontoonCharge);
  }

  static List<CalculatedStay> getCalculatedStayTestList() {
    List<CalculatedStay> list = <CalculatedStay>[];
    list.add(CalculatedStay("Dorado1", DateTime.now(), DateTime.now(), "34.54",
        true, 1.20, 2.40, 0.6, "7.5"));
    list.add(CalculatedStay("Dorado2", DateTime.now(), DateTime.now(), "34.54",
        false, 1.20, 2.40, 0.6, "7.5"));
    list.add(CalculatedStay("Dorado3", DateTime.now(), DateTime.now(), "34.54",
        true, 1.20, 2.40, 0.6, "7.5"));
    list.add(CalculatedStay("Dorado4", DateTime.now(), DateTime.now(), "34.54",
        false, 1.20, 2.40, 0.6, "7.5"));

    return list;
  }
}

class AppData {
  static String boatLength = "";
  static String boatName = "";
  static bool isMember = true;
  static bool isInFeet = true;
  static bool gotBoatData = false;
  static bool showWelcomeDialog = true;

  static List<CalculatedStay> stays = <CalculatedStay>[];

  static String boatLengthNearestHalfMeter = '';

  static Future initBoatData() async {
    List<Future> futureList = <Future>[];

    futureList.add(initBoatLength().then((value) => boatLength = value));
    futureList.add(initBoatName().then((value) => boatName = value));
    futureList.add(initIsMember().then((value) => isMember = value));
    futureList.add(initIsInFeet().then((value) => isInFeet = value));
    futureList.add(_getStays().then((value) => stays = value));
    futureList.add(
        initShowWelcomeDialog().then((value) => showWelcomeDialog = value));

    await Future.wait(futureList).whenComplete(() => gotBoatData = true);
  }

  static bool getIsBoatDataComplete() {

    print('TEST: boatLength: $boatLength');
    print('TEST: boatName: $boatName');
    print('TEST: isMember: $isMember');

    if (boatLength == "") return false;
    if (boatName == "" || boatName == '') return false;

    return true;

  }

  static List<CalculatedStay> getStays() {
    //if (stays == null) stays = <CalculatedStay>[];
    return stays;
  }

  static String getBoatLength() {
    //if (boatLength == null) boatLength = '';
    return boatLength;
  }

  static String getBoatName() {
    //if (boatName == null) boatName = '';
    return boatName;
  }

  static bool getIsInFeet() {
    //if (isInFeet == null) isInFeet = true;
    return isInFeet;
  }

  static bool getIsMember() {
    //print('Stack trace: \n' + StackTrace.current.toString());
    //if (isMember == null) isMember = false;
    return isMember;
  }

  static bool getShowWelcomeDialog() {
    //if (showWelcomeDialog == null) showWelcomeDialog = true;
    return showWelcomeDialog;
  }


  static Future<List<CalculatedStay>> _getStays() async {
    final prefs = await SharedPreferences.getInstance();
    String staysEncoded = prefs.getString('Stays') as String;

    print ("What value does String have4 in _getStays? " +  staysEncoded);

    // First time run the app there will be nothing here
    /* if (staysEncoded == null) {
      return <CalculatedStay>[];
    }
*/
    Map<String, dynamic> decodedStays = json.decode(staysEncoded);
    CalculatedStayList testStayList = CalculatedStayList.fromJson(decodedStays);

    // For debugging
    print('Test doing it by calculated stay');
    for (var element in testStayList.stays) {
      element.printCalculatedStay();
    }

    return testStayList.stays;
  }

  static Future<String> nullSafeGetStringPref (String key, String defaultValue) async {

    final prefs = await SharedPreferences.getInstance();
    String? value = prefs.getString(key);
    value ?? defaultValue; // If value is null, set it to the default value
    return value as String; // this isn't null safe
  }

  static Future<bool> nullSafeGetBoolPref (String key, bool defaultValue) async {

    final prefs = await SharedPreferences.getInstance();
    bool? value = prefs.getBool(key);
    value ??= defaultValue; // If value is null, set it to the default value
    return value;
  }

  static Future<String> initBoatLength() async {
    return nullSafeGetStringPref('BoatLength', '');
  }

  static Future<bool> initIsInFeet() async {
    return nullSafeGetBoolPref('IsInFeet', true);
  }

  static Future<String> initBoatName() async {
    return nullSafeGetStringPref('BoatName', '');
  }

  static Future<bool> initIsMember() async {
    return nullSafeGetBoolPref('IsMember', false);
  }

  static Future<bool> initShowWelcomeDialog() async {
    return nullSafeGetBoolPref('ShowWelcomeDialog', true);
  }

  /*
  Setters
   */

  static void setStays(List<CalculatedStay> listOfStays) {
    final prefs = SharedPreferences.getInstance();
    stays = listOfStays;
    prefs.whenComplete(() {
      print('Encoding stays');
      for (var element in stays) {
        element.printCalculatedStay();
      }

      prefs.then((value) =>
          value.setString('Stays', json.encode(CalculatedStayList(stays))));
    });
  }

  static void setBoatLength(String _boatLength) {
    final prefs = SharedPreferences.getInstance();
    prefs.whenComplete(() {
      prefs.then((value) => value.setString('BoatLength', _boatLength));
    });
    boatLength = _boatLength;
  }

  static void setBoatName(String _boatName) {
    final prefs = SharedPreferences.getInstance();
    prefs.whenComplete(() {
      prefs.then((value) => value.setString('BoatName', _boatName));
    });
    //await prefs.setString('BoatName', _boatName);
    boatName = _boatName;
  }

  static void setIsMember(bool _isMember) {
    final prefs = SharedPreferences.getInstance();
    prefs.whenComplete(() {
      prefs.then((value) => value.setBool('IsMember', _isMember));
    });
    //await prefs.setBool('IsMember', _isMember);
    isMember = _isMember;
  }

  static void setIsInFeet(bool _isInFeet) {
    final prefs = SharedPreferences.getInstance();
    prefs.whenComplete(() {
      prefs.then((value) => value.setBool('IsInFeet', _isInFeet));
    });
    //await prefs.setBool('IsMember', _isMember);
    isInFeet = _isInFeet;
  }

  static void setShowWelcomeDialog(bool _showWelcomeDialog) {
    final prefs = SharedPreferences.getInstance();
    prefs.whenComplete(() {
      prefs.then(
              (value) => value.setBool('ShowWelcomeDialog', _showWelcomeDialog));
    });
    //await prefs.setBool('IsMember', _isMember);
    showWelcomeDialog = _showWelcomeDialog;
  }

  static void calculateToNearestHalfMeter() {
    //if (isInFeet == null) return;

    // Initialise
    getIsInFeet();

    if (boatLength == '0' || boatLength == '') {
      boatLengthNearestHalfMeter = '0';
      return;
    }

    double boatLengthDouble = double.parse(AppData.getBoatLength());

    // Is the value in feet? Then convert to meters
    if (isInFeet) {
      boatLengthDouble = boatLengthDouble / 3.2808;
    }

    // String boatLengthString = boatLengthDouble.toString();
    // List<String> list = boatLengthString.split("\.");
    int wholeNumber =
    boatLengthDouble.truncateToDouble().toInt(); //int.parse(list.first);

    print('Boat length double: $boatLengthDouble');

    print('Boat length whole number: $wholeNumber');

    double decimalPart = boatLengthDouble - wholeNumber;

    print('Decimal part: $decimalPart');

    String rounded = '.0';

    if (decimalPart >= 0.25 && decimalPart < 0.75) {
      rounded = '.5';
    } else if (decimalPart >= 0.75) {
      wholeNumber += 1;
    }

    boatLengthNearestHalfMeter = '$wholeNumber$rounded';
  }
}





class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.green,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),

      initialRoute: '/',
      routes: {
        // When navigating to the "/" route, build the FirstScreen widget.
        '/': (context) => HomePage(),
        // When navigating to the "/second" route, build the SecondScreen widget.
        '/second': (context) => CalculateFee(),
      },

      //home: CalculateFee(title: 'Flutter Demo Home Page'),
      //home: HomePage(title: 'Click plus to calculate fee'),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TextEditingController boatLengthTextEditingController =
  TextEditingController();
  TextEditingController boatNameTextEditingController = TextEditingController();

  int memberOrVisitorRadioValue = -1;
  int feetOrMetersRadioValue = -1;

  pushToScreen(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => CalculateFee()));
  }

  @override
  void initState() {
    super.initState();

    boatLengthTextEditingController.text = AppData.getBoatLength().toString();
    boatNameTextEditingController.text = AppData.getBoatName();

    if (AppData.getIsMember() == true) {
      memberOrVisitorRadioValue = 0;
    } else {
      memberOrVisitorRadioValue = 1;
    }

    if (AppData.getIsInFeet() == true) {
      feetOrMetersRadioValue = 0;
    } else {
      feetOrMetersRadioValue = 1;
    }

    AppData.calculateToNearestHalfMeter();

    if (AppData.getIsBoatDataComplete() == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSetupDialog().then((_) {
          if (AppData.getShowWelcomeDialog()) {
            showWelcomeDialogue();
          }
        });
      });
    } else if (AppData.getShowWelcomeDialog()) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          showWelcomeDialogue());
    }
  }

  void handleClick(String value) {
    switch (value) {
      case 'Your details':
        _showSetupDialog();
        break;
      case 'Show rates':
        showRatesDialogue();
        break;
      case 'How to pay':
        showHowToPayDialogue();
        break;
    }
  }

  void calculatedStayListMenuClick(
      String value, CalculatedStay calcStay) async {
    switch (value) {
      case 'Show calculation':
        print('Show calculation');
        //calcStay.calculateFee();
        showCalculationDialog(calcStay);
        break;

      case 'Mark as paid':
        print('Mark as Paid');
        setState(() => calcStay.paid = true);
        AppData.setStays(AppData.stays);
        break;

      case 'Mark as owed':
        print('Mark as Owed');
        setState(() => calcStay.paid = false);
        AppData.setStays(AppData.stays);
        break;

      case 'Delete':
        String text = "Are you sure want to delete the record of your stay";
        String outcome = await areYouSureDialog(text);
        if (outcome == "Yes") {
          setState(() {
            AppData.stays.remove(calcStay);
            AppData.setStays(AppData.stays);
          });
        }
        break;
    }
  }

  Future<dynamic> areYouSureDialog(String text) async {
    // flutter defined function
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text("Are you sure?"),
          content: new Text(text),
          actions: <Widget>[
            // usually buttons at the bottom of the dialog
            new TextButton(
              child: new Text("Yes"),
              onPressed: () {
                Navigator.of(context).pop("Yes");
              },
            ),
            new TextButton(
              child: new Text("No"),
              onPressed: () {
                Navigator.of(context).pop("No");
              },
            ),
          ],
        );
      },
    );
  }

  Future<dynamic> showMessageDialogue(String title, String text) {
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              // return object of type Dialog
              return AlertDialog(
                title: Text(title),
                content: SingleChildScrollView(
                    child: Column(children: [
                      Text(text, style: Constants.welcomeTextStyle),
                    ])),
                actions: <Widget>[
                  // usually buttons at the bottom of the dialog
                  new TextButton(
                    child: new Text("Done"),
                    onPressed: () {
                      Navigator.of(context).pop("Done");
                    },
                  ),
                ],
              );
            },
          );
        });
  }

  Future<dynamic> showRatesDialogue() async {
    String ratesText = 'Visitor Rates:\n' +
        Rates.getFormattedRate(Rates.visitorRate) +
        '/M per night\n\n' +
        'Members\' Rates:\n' +
        'Sunday to Thursday night\n' +
        Rates.getFormattedRate(Rates.standardRate) +
        '/M per night\n\n' +
        'Friday and Saturday night\n' +
        Rates.getFormattedRate(Rates.membersDiscountRate) +
        '/M per night\n';

    return showMessageDialogue('Rates', ratesText);
  }

  Future<dynamic> showHowToPayDialogue() async {
    String howToPayText =
        'These are the different ways you can pay:\n\n' + 'blah blah blah';

    return showMessageDialogue('How to pay', howToPayText);
  }

  Future<dynamic> showWelcomeDialogue() async {
    String welcomeText = 'This is the Edinburgh Marina Ltd app for '
        'calculating pontoon charges at Granton Harbour.\n\n'
        'Click on the \'plus\' button at the '
        'bottom right hand corner of the screen to add a new '
        'stay on the pontoon.\n';

    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              // return object of type Dialog
              return AlertDialog(
                title: Text('Welcome'),
                content: SingleChildScrollView(
                    child: Column(children: [
                      Text(welcomeText, style: Constants.welcomeTextStyle),
                      Container(
                        //color: Colors.green,
                        child: CheckboxListTile(
                            title: const Text('Do not show this message again'),
                            value: !AppData.getShowWelcomeDialog(),
                            onChanged: (bool? value) {
                              setState(() {
                                AppData.setShowWelcomeDialog( value == null ? false : !value);
                              });
                            }),
                      )
                    ])),
                actions: <Widget>[
                  // usually buttons at the bottom of the dialog
                  new TextButton(
                    child: new Text("Done"),
                    onPressed: () {
                      Navigator.of(context).pop("Done");
                    },
                  ),
                ],
              );
            },
          );
        });
  }

  Future<dynamic> showCalculationDialog(CalculatedStay calcStay) async {
    // flutter defined function
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text('Pontoon Fee Calculation'),
          content: new Text(calcStay.getBreakdown()),
          actions: <Widget>[
            // usually buttons at the bottom of the dialog
            new TextButton(
              child: new Text("Copy to clipboard"),
              onPressed: () {
                Clipboard.setData(
                    new ClipboardData(text: calcStay.getBreakdown()));
              },
            ),
            new TextButton(
              child: new Text("Close"),
              onPressed: () {
                Navigator.of(context).pop("Close");
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stays on the pontoon'),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: handleClick,
            itemBuilder: (BuildContext context) {
              return {'Your details', 'Show rates', 'How to pay'}
                  .map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: Center(child: ListView(children: listBuilder())),
      /*
      drawer: Drawer(

        // Add a ListView to the drawer. This ensures the user can scroll
        // through the options in the drawer if there isn't enough vertical
        // space to fit everything.
        child: ListView(
          // Important: Remove any padding from the ListView.
          padding: EdgeInsets.zero,
          children: <Widget>[
            /*
            DrawerHeader(
              child: Text('Drawer Header'),
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
            ),

             */
            ListTile(
              title: Text('Update boat details'),
              onTap: () {
                Navigator.pop(context);
                //_showSetupDialog();
                // Update the state of the app.
                // ...
              },
            ),
            ListTile(
              title: Text('Item 2'),
              onTap: () {
                // Update the state of the app.
                // ...
              },
            ),
          ],
        ),
      ),

         */

      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.add, color: Colors.white),
          //onPressed: () => this.setState(() => pushToScreen(context)),
          onPressed: (() => Navigator.pushNamed(context, '/second')
              .whenComplete(
                  () => setState(() => print('Setting state Done'))))),
    );
  }

  Widget getRichTextForCalcStay(CalculatedStay calculatedStay) {
    return Row(children: [
      Expanded(
          child: RichText(
            text: TextSpan(
                style: calculatedStay.paid
                    ? Constants.baseListPaid
                    : Constants.baseListOwed,
                children: <TextSpan>[
                  TextSpan(
                    style: Constants.boatNameStyle,
                    text: calculatedStay.boatName +
                        ' (' +
                        calculatedStay.boatLengthNearestHalfMeter +
                        'M)',
                  ),
                  TextSpan(text: '\n'),
                  TextSpan(style: Constants.listTextStyle, text: 'Arrival: '),
                  // TextSpan(text: '\n'),
                  TextSpan(
                      style: Constants.boldStyle,
                      text: '      ' +
                          Constants.formatDate(calculatedStay.startStay)),
                  TextSpan(text: '\n'),
                  TextSpan(style: Constants.listTextStyle, text: 'Departure: '),
                  //TextSpan(text: '\n'),
                  TextSpan(
                      style: Constants.boldStyle,
                      text: Constants.formatDate(calculatedStay.endStay)),
                  TextSpan(text: '\n'),

                  if (calculatedStay.paid == false)
                    TextSpan(
                      style: Constants.feeOwedStyle,
                      text: 'Marked as owed',
                    )
                  else
                    TextSpan(
                      style: Constants.feePaidStyle,
                      text: 'Marked as paid',
                    ),
                  TextSpan(text: '\n'),
                ]),
          )),
      RichText(
          text: TextSpan(
              style: calculatedStay.paid
                  ? Constants.baseListPaid
                  : Constants.baseListOwed,
              children: <TextSpan>[
                TextSpan(
                  style: calculatedStay.paid
                      ? Constants.itemBackgroundFeePaidStyle
                      : Constants.itemBackgroundFeeOwedStyle,
                  text: '' + calculatedStay.fee,
                ),
                TextSpan(text: '\n'),
              ])),
    ]);
  }

  List<Widget> listBuilder() {
    List<Container> listTiles = <Container>[];

    //print('List Builder ' + AppData.getStays().length.toString());

    AppData.getStays().map((calculatedStay) {
      print('Adding ListTile ' + calculatedStay.fee);
      listTiles.add(Container(
          decoration: calculatedStay.paid
              ? new BoxDecoration(color: Colors.brown[50])
              : new BoxDecoration(color: Colors.blue[50]),
          child: new ListTile(
            title: Container(
                decoration: new BoxDecoration(), //color: Colors.green),
                child: getRichTextForCalcStay(calculatedStay)),
            trailing: PopupMenuButton<String>(
              onSelected: (value) =>
                  calculatedStayListMenuClick(value, calculatedStay),
              itemBuilder: (BuildContext context) {
                return {
                  'Show calculation',
                  'Mark as paid',
                  'Mark as owed',
                  'Delete'
                }.map((String choice) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(choice),
                  );
                }).toList();
              },
            ),
          )));
    }).toList();

    return listTiles;
  }

  Future _showSetupDialog() {
    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
                title: new Text("About you and your boat"),
                content: SingleChildScrollView(
                  // Center is a layout widget. It takes a single child and positions it
                  // in the middle of the parent.
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          TextField(
                            decoration: new InputDecoration(
                                labelText: "Boat name",
                                labelStyle: Constants.textLabelStyle),
                            keyboardType: TextInputType.text,
                            controller: boatNameTextEditingController,
                            onChanged: (text) {
                              setState(() {
                                AppData.setBoatName(text);
                              });
                            },
                            //inputFormatters: <TextInputFormatter>[
                            //   DecimalTextInputFormatter (decimalRange: 2)
                            //]
                          ),
                          Row(children: <Widget>[
                            ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: 70,
                                  minHeight: 70,
                                  maxWidth: 80,
                                  maxHeight: 150,
                                ),
                                child: TextField(
                                    decoration: new InputDecoration(
                                        labelText: "Length",
                                        labelStyle: Constants.textLabelStyle),
                                    keyboardType: TextInputType.numberWithOptions(
                                        decimal: true),
                                    onChanged: (text) {
                                      setState(() {
                                        AppData.setBoatLength(text);
                                        print("Changed length to: " + text);
                                        AppData.calculateToNearestHalfMeter();
                                      });
                                    },
                                    controller: boatLengthTextEditingController,
                                    inputFormatters: <TextInputFormatter>[
                                      DecimalTextInputFormatter(
                                        decimalRange: 2,
                                      )
                                    ])),
                            Radio(
                                value: 0,
                                groupValue: feetOrMetersRadioValue,
                                onChanged: (value) {
                                  setState(() {
                                    feetOrMetersRadioValue = value as int;
                                    AppData.setIsInFeet(true);
                                    AppData.calculateToNearestHalfMeter();
                                  });
                                }),
                            Text(
                              'ft',
                              style: TextStyle(
                                  color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                            Radio(
                                value: 1,
                                groupValue: feetOrMetersRadioValue,
                                onChanged: (value) {
                                  setState(() {
                                    AppData.setIsInFeet(false);
                                    feetOrMetersRadioValue = value as int;
                                    AppData.calculateToNearestHalfMeter();
                                  });
                                }),
                            Text(
                              'M',
                              style: TextStyle(
                                  color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ]),
                          Text(
                            'Boat length to nearest half meter:',
                            style: TextStyle(
                                color: Colors.black, fontWeight: FontWeight.normal),
                          ),
                          Text(
                            AppData.boatLengthNearestHalfMeter + 'M',
                            style: TextStyle(
                                color: Colors.blueGrey,
                                fontWeight: FontWeight.normal,
                                fontSize: 25),
                          ),
                          Text(
                            ' ',
                            style: TextStyle(
                                color: Colors.black, fontWeight: FontWeight.normal),
                          ),
                          Text(
                              'Are you a member of FCYC or RFYC, or are you a visitor?',
                              style: Constants.questionsStyle),
                          Row(children: <Widget>[
                            Radio(
                                value: 0,
                                groupValue: memberOrVisitorRadioValue,
                                onChanged: (value) {
                                  setState(() {
                                    print('Member or visitor radio value: $value');
                                    memberOrVisitorRadioValue = value as int;
                                    AppData.setIsMember(true);
                                  });
                                }),
                            Text(
                              'Member',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.normal),
                            ),
                          ]),
                          Row(children: <Widget>[
                            Radio(
                                value: 1,
                                groupValue: memberOrVisitorRadioValue,
                                onChanged: (value) {
                                  setState(() {
                                    print('Member or visitor radio value: $value');
                                    memberOrVisitorRadioValue = value as int;
                                    AppData.setIsMember(false);
                                  });
                                }),
                            Text(
                              'Visitor',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.normal),
                            ),
                          ]),
                          ElevatedButton(
                            child: Text('Done'),
                            onPressed: AppData.getIsBoatDataComplete()
                                ? () {
                              Navigator.pop(context);
                            }
                                : null, // If null then button deactivated
                          ),
                        ])));
          });
        });
  }
}

class CalculateFee extends StatefulWidget {
  CalculateFee({Key? key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String? title;

  @override
  _CalculateFeePageState createState() => _CalculateFeePageState();
}

class _CalculateFeePageState extends State<CalculateFee> {
  CalculatedStay calculatedStay = new CalculatedStay(
      AppData.getBoatName(),
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      '',
      AppData.getIsMember(),
      Rates.standardRate,
      Rates.visitorRate,
      Rates.membersDiscountRate,
      AppData.boatLengthNearestHalfMeter);

  String errorMsg = '';

  @override
  void initState() {
    super.initState();
  }

  void _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: calculatedStay.startStay, // Refer step 1
      firstDate: DateTime(2000),
      lastDate: DateTime(2025),
    );
    if (picked != null && picked != calculatedStay.startStay) {
      setState(() {
        calculatedStay.startStay = picked;
        _errorMsg(context);
        calculatedStay.calculateFee();
      });
    }
  }

  void _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: calculatedStay.endStay, // Refer step 1
      firstDate: DateTime(2000),
      lastDate: DateTime(2025),
    );
    if (picked != null && picked != calculatedStay.endStay) {
      setState(() {
        calculatedStay.endStay = picked;
        _errorMsg(context);
        calculatedStay.calculateFee();
      });
    }
  }

  Widget _getRates() {
    String text = 'Sun to Thu £' +
        Rates.membersDiscountRate.toString() +
        'Overnight rate for members\n ' +
        'Fri to Sat £' +
        Rates.standardRate.toString() +
        '\n';

    if (AppData.isMember == false) {
      return Text('Overnight rate for visitors: £' +
          Rates.visitorRate.toString() +
          ' per meter');
    }

    return Table(children: [
      TableRow(children: [
        TableCell(child: Text('Fri to Sat ')),
        TableCell(child: Text('£' + Rates.standardRate.toString())),
      ]),
      TableRow(children: [
        TableCell(child: Text('Sun to Thu ')),
        TableCell(child: Text('£' + Rates.membersDiscountRate.toString())),
      ]),
    ]);
  }

  Widget getSetDateTable(BuildContext context) {
    return Table(children: [
      getRateTableRow("Boat", AppData.getBoatName()),
      getRateTableRow("Length", AppData.boatLengthNearestHalfMeter + 'M'),
      TableRow(children: [
        TableCell(
            child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 50,
                  minHeight: Constants.rowHeight,
                  maxWidth: 70,
                  maxHeight: Constants.rowHeight,
                ),
                child: Center(
                    child: Text('Arrival',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.normal,
                            fontSize: 20)))),
            verticalAlignment: TableCellVerticalAlignment.middle),
        TableCell(
          child: ElevatedButton (
            onPressed: () => _selectStartDate(context), // Refer step 3
            child: Text(
              Constants.formatDate(calculatedStay.startStay),
              style:
              TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        )
      ]),
      TableRow(children: [
        TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: 50,
                  minHeight: Constants.rowHeight,
                  maxWidth: 70,
                  maxHeight: Constants.rowHeight,
                ),
                child: Center(
                    child: Text('Departure',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.normal,
                            fontSize: 20))))),
        TableCell(
          child: ElevatedButton (
            onPressed: () => _selectEndDate(context), // Refer step 3
            child: Text(
              Constants.formatDate(calculatedStay.endStay),
              style:
              TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ]),
      if (calculatedStay.daysAtVisitorRate != 0)
        getRateTableRow(
            'Days at ' + Rates.getFormattedRate(Rates.visitorRate) + '/M',
            calculatedStay.daysAtVisitorRate.toString()),
      if (calculatedStay.daysAtStandardRate != 0)
        getRateTableRow(
            'Days at ' + Rates.getFormattedRate(Rates.standardRate) + '/M',
            calculatedStay.daysAtStandardRate.toString()),
      if (calculatedStay.daysAtMembersDiscountRate != 0)
        getRateTableRow(
            'Days at ' +
                Rates.getFormattedRate(Rates.membersDiscountRate) +
                '/M',
            calculatedStay.daysAtMembersDiscountRate.toString()),
      getRateTableRow(
          "Fee", Rates.getFormattedRate(calculatedStay.pontoonCharge)),
    ]);
  }

  TableRow getRateTableRow(String rate, String days) {
    return TableRow(children: [
      TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 50,
              minHeight: Constants.rowHeight,
              maxWidth: 70,
              maxHeight: Constants.rowHeight,
            ),
            child: Center(
                child: Text(rate,
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.normal,
                        fontSize: 20)))),
      ),
      TableCell(
          child: Center(
              child: Text(days,
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.normal,
                      fontSize: 20))),
          verticalAlignment: TableCellVerticalAlignment.middle),
    ]);
  }

  void _errorMsg(BuildContext context) async {
    if (calculatedStay.startStay.isAfter(calculatedStay.endStay)) {
      errorMsg = 'Departure date must be after arrival date';
    } else {
      errorMsg = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    //return _getSetupInfo(context);
    //_showSetupDialog();
    return _getMainDisplay(context);
  }

  Scaffold _getMainDisplay(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text("Calculate fee"),
        ),
        body: Center(
          child: SingleChildScrollView(
            // Center is a layout widget. It takes a single child and positions it
            // in the middle of the parent.
            child: Column(
              // Column is also a layout widget. It takes a list of children and
              // arranges them vertically. By default, it sizes itself to fit its
              // children horizontally, and tries to be as tall as its parent.
              //
              // Invoke "debug painting" (press "p" in the console, choose the
              // "Toggle Debug Paint" action from the Flutter Inspector in Android
              // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
              // to see the wireframe for each widget.
              //
              // Column has various properties to control how it sizes itself and
              // how it positions its children. Here we use mainAxisAlignment to
              // center the children vertically; the main axis here is the vertical
              // axis because Columns are vertical (the cross axis would be
              // horizontal).
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Calculate pontoon fees for your stay',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                /*
            Text(
              "Fees are charged by boat length to the nearest half meter.",
              style: Theme.of(context).textTheme.bodyText1,
            ),
            _getRates(),

             */
                Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: getSetDateTable(context)),
                Text(
                  '$errorMsg',
                  style:
                  TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                ElevatedButton (
                  onPressed: calculatedStay.pontoonCharge == 0
                      ? null
                      : () {
                    AppData.stays.insert(0, calculatedStay);
                    AppData.setStays(AppData.stays);
                    Navigator.pop(context);
                  },
                  child: Text('Save'),
                ),
                /*
            Text(
              'Pontoon fee: $pontoonCharge',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),

             */
              ],
            ),
          ),
        )

      /*
      floatingActionButton: FloatingActionButton(
        //onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
*/
    );
  }
}

class DecimalTextInputFormatter extends TextInputFormatter {
  DecimalTextInputFormatter({this.decimalRange})
      : assert(decimalRange == null || decimalRange > 0);

  final int? decimalRange;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, // unused.
      TextEditingValue newValue,
      ) {
    TextSelection newSelection = newValue.selection;
    String truncated = newValue.text;

    if (decimalRange != null) {
      String value = newValue.text;

      if (value.contains(".") &&
          value.substring(value.indexOf(".") + 1).length > (decimalRange as int)) {
        truncated = oldValue.text;
        newSelection = oldValue.selection;
      } else if (value == ".") {
        truncated = "0.";

        newSelection = newValue.selection.copyWith(
          baseOffset: math.min(truncated.length, truncated.length + 1),
          extentOffset: math.min(truncated.length, truncated.length + 1),
        );
      }

      return TextEditingValue(
        text: truncated,
        selection: newSelection,
        composing: TextRange.empty,
      );
    }
    return newValue;
  }
}

/*
class SetUpBlaBla extends StatefulWidget {
  SetUpBlaBla({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _SetUpPageState createState() => _SetUpPageState();
}

class _SetUpPageState extends State<SetUpBlaBla> {
  int memberOrVisitorRadioValue = -1;
  int feetOrMetersRadioValue = -1;


  @override
  Widget build(BuildContext context) {
    return _getSetupInfo(context);

  }

  Scaffold _getSetupInfo(BuildContext context) {
    TextEditingController boatLengthTextEditingController =
        TextEditingController();
    TextEditingController boatNameTextEditingController =
        TextEditingController();

    boatLengthTextEditingController.text = BoatData.getBoatLength().toString();
    boatNameTextEditingController.text = BoatData.getBoatName();

    if (BoatData.getIsMember() == true)
      memberOrVisitorRadioValue = 0;
    else
      memberOrVisitorRadioValue = 1;

    if (BoatData.isInFeet == true)
      feetOrMetersRadioValue = 0;
    else
      feetOrMetersRadioValue = 1;

    BoatData._calculateToNearestHalfMeter();

    return Scaffold(
        appBar: AppBar(
          // Here we take the value from the MyHomePage object that was created by
          // the App.build method, and use it to set our appbar title.
          title: Text(widget.title),
        ),
        body: Container(
          padding: EdgeInsets.only(left: 10, top: 10, right: 10, bottom: 10),
          decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              color: Colors.white,
              borderRadius: BorderRadius.circular(5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black, offset: Offset(0, 10), blurRadius: 10)
              ]),

          // Center is a layout widget. It takes a single child and positions it
          // in the middle of the parent.
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <
              Widget>[
            TextField(
              decoration: new InputDecoration(labelText: "Boat name"),
              keyboardType: TextInputType.text,
              controller: boatNameTextEditingController,
              onChanged: (text) {
                BoatData.setBoatName(text);
                print('Boat name: $text');
              },
              //inputFormatters: <TextInputFormatter>[
              //   DecimalTextInputFormatter (decimalRange: 2)
              //]
            ),
            Row(children: <Widget>[
              ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 70,
                    minHeight: 70,
                    maxWidth: 150,
                    maxHeight: 150,
                  ),
                  child: TextField(
                      maxLength: 5,
                      maxLengthEnforced: true,
                      decoration: new InputDecoration(labelText: "Boat length"),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                      onChanged: (text) {
                        BoatData.setBoatLength(text);
                        BoatData._calculateToNearestHalfMeter();
                      },
                      controller: boatLengthTextEditingController,
                      inputFormatters: <TextInputFormatter>[
                        DecimalTextInputFormatter(
                          decimalRange: 2,
                        )
                      ])),
              Radio(
                  value: 0,
                  groupValue: feetOrMetersRadioValue,
                  onChanged: (value) {
                    setState(() {
                      feetOrMetersRadioValue = value;
                      BoatData.setIsInFeet(true);
                      BoatData._calculateToNearestHalfMeter();
                    });
                  }),
              Text(
                'ft',
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              Radio(
                  value: 1,
                  groupValue: feetOrMetersRadioValue,
                  onChanged: (value) {
                    setState(() {
                      BoatData.setIsInFeet(false);
                      feetOrMetersRadioValue = value;
                      BoatData._calculateToNearestHalfMeter();
                    });
                  }),
              Text(
                'M',
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ]),
            Text(
              'Are you a member of FCYC or RFYC, or are you a visitor?',
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            Row(children: <Widget>[
              Text(
                'Member of FCYC or RFYC',
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              Radio(
                  value: 0,
                  groupValue: memberOrVisitorRadioValue,
                  onChanged: (value) {
                    setState(() {
                      print('Member or visitor radio value: $value');
                      memberOrVisitorRadioValue = value;
                      BoatData.setIsMember(true);
                    });
                  })
            ]),
            Row(children: <Widget>[
              Text(
                'Visitor',
                style:
                    TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
              Radio(
                  value: 1,
                  groupValue: memberOrVisitorRadioValue,
                  onChanged: (value) {
                    setState(() {
                      print('Member or visitor radio value: $value');
                      memberOrVisitorRadioValue = value;
                      BoatData.setIsMember(false);
                    });
                  })
            ]),
            Text(
              'Boat length to nearest half meter ' + BoatData.boatLengthNearestHalfMeter,
              style:
                  TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            ElevatedButton(
              child: Text('Done'),
              onPressed: () {
                Navigator.pop(context); // Navigate to second route when tapped.
                BoatData.isBoatDataComplete();
                setState(() {});
              },
            ),
          ]),
        ));
  }
}


 */

/*
void main() {
  runApp(const MyApp());
}
*/

/*
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
*/

