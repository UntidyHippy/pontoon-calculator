import 'dart:async';
import 'dart:ffi';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:currency_textfield/currency_textfield.dart';
import 'package:sprintf/sprintf.dart';


// Update Rates dialogue fixed. Values entered are now displayed correctly (02/06/2022)
// Prompted to update rates when rates have expired (29/04/2024)
// Sequence for checking rates based on expiry date (28/04/2024)
// Simplified AppData code (28/03/2023)
// Fixed bug so that the paid / owed flag is saved (26/03/2024)
// Test on the fetch Rates code - this is working (23/03/2024)
// Fixed some null handling errors (21/03/2024)
// Now loads latest rates from the server (14/03/2024)
// Reimplemented the 'Rates' class to be able to initiate it with json (13/03/2024)
// Next -  be able to fees based on new information and get these from t'Internet
// tidied how async, then and after calls are  handled (12/3/2024)
// debug conditional print  (Fixed 8/3/2024)
// refactor to interpolate strings (Fixed 8/3/2024)
// 'Done' button not activating on the start-up screen. (Fixed 29/2/2024)

// Logger used by this app
final log = Logger('PontoonFeesApp');

Map<String, dynamic> recodedRates = json.decode('{"Rates": {'
    '"standardRate" : 1.50,'
    '"visitorRate" : 3.00,'
    '"membersDiscountRate" : 0.75,'
    '"dateExpires" : "2022-10-11 23:59:59.00"}}');

// Rates used to calculated fees.
//final rates = Rates(1.30, 2.60, 0.65);

//Rates rates = Rates.fromJson(decodedRates['Rates']);

void main() {
  // Configure logging
  Logger.root.level = Level.ALL; // defaults to Level.INFO
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  // Because am running the app after getting preferences, I have
  // to run this first otherwise it complains.
  WidgetsFlutterBinding.ensureInitialized();

  // Because preferences are handled asynchronously, have to wait
  // until I have fetched them before running the app.
  AppData.initBoatData().whenComplete(() {
    /* ADD SOME TEST DATA TO STAYS FOR TESTING.
    AppData.setStays(CalculatedStay.getCalculatedStayTestList());

    AppData.getStays().forEach((element) {
      element.printCalculatedStay();
    });

     */

    runApp(const MyApp());
  });
}

class Constants {
  static const double rowHeight = 50;

  static const TextStyle boldStyle =
      TextStyle(fontWeight: FontWeight.bold, height: 1.2);

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

  static const TextStyle alertStyle = TextStyle(
      color: Colors.red,
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

  static const TextStyle feePaidStyle =
      TextStyle(fontWeight: FontWeight.bold, color: Colors.brown, height: 1.5);

  static const TextStyle feeOwedStyle =
      TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, height: 1.5);

  static String formatDate(DateTime dateTime) {
    return "${dateTime.day.toString()}/"
        "${dateTime.month.toString()}/"
        "${dateTime.year.toString()}";
  }
}

/// AppData handles storing the data used in the app using
/// the SharedPreferences module which stores it locally on
/// the user's phone.
///
/// Use the setter functions to update variables so that
/// SharedPreferences are also updated.
///

class AppData {
  static String boatLength = "";
  static String boatName = "";
  static bool isMember = true;
  static bool isInFeet = true;
  static bool gotBoatData = false;
  static bool showWelcomeDialog = true;
  static int numRuns = 0;

  static List<CalculatedStay> stays = <CalculatedStay>[];
  static String boatLengthNearestHalfMeter = '';

  static Rates rates = Rates(0, 0, 0, DateTime.now());

  static Future initBoatData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    boatLength = prefs.getString('BoatLength') ?? '';
    boatName = prefs.getString('BoatName') ?? '';
    isMember = prefs.getBool('IsMember') ?? true;
    isInFeet = prefs.getBool('IsInFeet') ?? false;
    showWelcomeDialog = prefs.getBool('ShowWelcomeDialog') ?? true;

    // Increment the number of times the app has been run
    // This can be useful for testing. Left in as a feature for now.
    numRuns = prefs.getInt('NumRuns') ?? 0;
    prefs.setInt('NumRuns', ++numRuns);


    Map<String, dynamic> decodedStays =
        json.decode(prefs.getString('Stays') ?? "{}");
    stays = CalculatedStayList.fromJson(decodedStays).stays;

    calculateToNearestHalfMeter();

    // Load the current rates for pontoon use
    Map<String, dynamic> ratesMap =
        json.decode(prefs.getString('Rates') ?? "{}");

    // If we didn't manage to load rates as part of app data then
    // take the hard-coded version
    if (ratesMap.isEmpty) {
      rates = Rates.fromJson(recodedRates['Rates']);
      prefs.setString('Rates', jsonEncode(rates));

      rates.whereHaveRatesComeFrom = "Hardcoded rates";
    } else {
      rates = Rates.fromJson(ratesMap);
      rates.whereHaveRatesComeFrom = "Rates save on device";
    }

    // Are the rates current?
    log.shout("Rates have expired? ${rates.ratesHaveExpired(rates.dateExpires)}");
    log.shout("Rates are from: ${rates.whereHaveRatesComeFrom}");

    // If the rates have expired, try getting some fresh rates from
    // the internet.
    if (rates.ratesHaveExpired(rates.dateExpires) == true) {
      Rates.fetchRates().then((r) {
        // Make sure that the rates that we fetch have not
        // expired as well.
        if (r.ratesHaveExpired(rates.dateExpires) == false) {
          rates = r;
          rates.whereHaveRatesComeFrom = "Rates updated from internet";
          log.shout("Rates are from 3 ${rates.whereHaveRatesComeFrom}");
        }
      });
    }

    // We may end up here with rates that are out of date
    // in which case the application should let the user know
    // and ask for some fresh ones.

    log.shout("Rates are from 2 ${rates.whereHaveRatesComeFrom}");
  }

  static bool getIsBoatDataComplete() {
    log.info('TEST: boatLength: $boatLength');
    log.info('TEST: boatName: $boatName');
    log.info('TEST: isMember: $isMember');

    if (boatLength == "") return false;
    if (boatName == "" || boatName == '') return false;

    return true;
  }

  /*
  Setters

  Have explicit setters so that the prefs are saved

   */

  static void saveRates() {
    final prefs = SharedPreferences.getInstance();
    log.shout("SAVING RATES ${rates.visitorRate}");
    prefs.then((value) {
      log.shout("ENCODED RATES: ${jsonEncode(rates)}");
      value.setString('Rates', jsonEncode(rates));
    });
  }

  static void setRates(Rates newRates) {
    rates = newRates;
    saveRates();
  }

  static void setVisitorRate(double visitorRate) {
    rates.visitorRate = visitorRate;
    saveRates();
  }

  static void setStays(List<CalculatedStay> listOfStays) {
    final prefs = SharedPreferences.getInstance();
    stays = listOfStays;

    prefs.then((value) {
      // value is the value of the completed 'prefs'

      log.info('Encoding stays');

      for (var element in stays) {
        element.printCalculatedStay();
      }

      value.setString('Stays', json.encode(CalculatedStayList(stays)));
    }); // No error checking
  }

  static void setBoatLength(String valueToUse) {
    final prefs = SharedPreferences.getInstance();
    prefs.then((value) {
      value.setString('BoatLength', valueToUse);
    });

    boatLength = valueToUse;
  }

  static void setBoatName(String valueToUse) {
    final prefs = SharedPreferences.getInstance();
    prefs.then((value) {
      value.setString('BoatName', valueToUse);
    });

    boatName = valueToUse;
  }

  static void setIsMember(bool valueToUse) {
    final prefs = SharedPreferences.getInstance();
    prefs.then((value) {
      value.setBool('IsMember', valueToUse);
    });

    isMember = valueToUse;
  }

  static void setIsInFeet(bool valueToUse) {
    final prefs = SharedPreferences.getInstance();
    prefs.then((value) {
      value.setBool('IsInFeet', valueToUse);
    });

    isInFeet = valueToUse;
  }

  static void setShowWelcomeDialog(bool valueToUse) {
    final prefs = SharedPreferences.getInstance();
    prefs.then((value) {
      value.setBool('ShowWelcomeDialog', valueToUse);
    });

    showWelcomeDialog = valueToUse;
  }

  static void calculateToNearestHalfMeter() {
    //if (isInFeet == null) return;

    // Initialise
    //getIsInFeet();

    if (boatLength == '0' || boatLength == '') {
      boatLengthNearestHalfMeter = '0';
      return;
    }

    double boatLengthDouble = double.parse(boatLength);

    // Is the value in feet? Then convert to meters
    if (isInFeet) {
      boatLengthDouble = boatLengthDouble / 3.2808;
    }

    // String boatLengthString = boatLengthDouble.toString();
    // List<String> list = boatLengthString.split("\.");
    int wholeNumber =
        boatLengthDouble.truncateToDouble().toInt(); //int.parse(list.first);

    log.info('Boat length double: $boatLengthDouble');

    log.info('Boat length whole number: $wholeNumber');

    double decimalPart = boatLengthDouble - wholeNumber;

    log.info('Decimal part: $decimalPart');

    String rounded = '.0';

    if (decimalPart >= 0.25 && decimalPart < 0.75) {
      rounded = '.5';
    } else if (decimalPart >= 0.75) {
      wholeNumber += 1;
    }

    boatLengthNearestHalfMeter = '$wholeNumber$rounded';
  }
}

class Rates {
  static const String expiryNotice =
      "These rates have passed their expiry date.\n\nPlease update these"
      " rates and enter a new expiry date.\n";

  double standardRate;
  double visitorRate;
  double membersDiscountRate;
  DateTime dateExpires;
  String whereHaveRatesComeFrom = ''; // Mainly for debugging / testing

  Rates(this.standardRate, this.visitorRate, this.membersDiscountRate,
      this.dateExpires);

  Rates.fromJson(Map<String, dynamic> json)
      : standardRate = json['standardRate'],
        visitorRate = json['visitorRate'],
        membersDiscountRate = json['membersDiscountRate'],
        dateExpires = DateTime.parse(json['dateExpires']);

  Map<String, dynamic> toJson() => {
        'standardRate': standardRate,
        'visitorRate': visitorRate,
        'membersDiscountRate': membersDiscountRate,
        'dateExpires': dateExpires.toString()
      };

  // Could make static
  bool ratesHaveExpired(DateTime expiryDate) {
    bool value =
    expiryDate.difference(DateTime.now()).inDays < 0 ? true : false;
    return value;
  }

  static Future<Rates> fetchRates() async {
    log.shout("Fetch rates begin");

    try {
      log.shout("Fetch rates try block");
      http.Response response = await http
          .get(Uri.parse('https://stayingafloat.blog/rates.json'))
          .timeout(const Duration(seconds: 10));

      log.shout("Got response");

      if (response.statusCode == 200) {
        // If the server did return a 200 OK response,
        // then parse the JSON.
        Rates rates = Rates.fromJson(
            jsonDecode(response.body)['Rates'] as Map<String, dynamic>);

        rates.ratesHaveExpired(rates.dateExpires);
        return rates;
      } else {
        // If the server did not return a 200 OK response,
        // then throw an exception.
        throw Exception("Didn't get a 200 OK response when loading rates");
      }
    } on Exception catch (e) {
      log.shout("Exception: $e");
    }

    // Return rates that have a 'null effect'
    return Rates(0, 0, 0, DateTime(1970));
  }

  // Could be static
  String getFormattedRate(double rate) {
    return "£${rate.toStringAsFixed(2)}";
  }
}

/// Wrapper class for list of Calculated stays to be able to
/// serialise this list into JSON so that it can be stored in
/// preferences.

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
    for (var elem in decodedJson) {
      stays.add(CalculatedStay.fromJson(elem));
    }
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
      this.boatLengthNearestHalfMeter,
      this.paid);

  CalculatedStay.fromJson(Map<String, dynamic> json)
      : boatName = json['boatName'],
        startStay = DateTime.parse(json['startDate']),
        endStay = DateTime.parse(json['endDate']),
        fee = json['fee'],
        isMember = json['isMember'],
        standardRate = json['standardRate'],
        visitorRate = json['visitorRate'],
        membersDiscountRate = json['membersDiscountRate'],
        boatLengthNearestHalfMeter = json['lengthToHalfMeter'],
        paid = json['paid'];

  Map<String, dynamic> toJson() => {
        'boatName': boatName,
        'startDate': startStay.toString(),
        'endDate': endStay.toString(),
        'fee': fee,
        'isMember': isMember,
        'standardRate': standardRate,
        'visitorRate': visitorRate,
        'membersDiscountRate': membersDiscountRate,
        'lengthToHalfMeter': boatLengthNearestHalfMeter,
        'paid': paid
      };

  void printCalculatedStay() {
    log.info(
        "${boatName.toString()} ${startStay.toString()} ${endStay.toString()} "
        "£ ${fee.toString()} "
        "${isMember.toString()} "
        " ${paid.toString()}");
  }

  String getBreakdown() {
    String visitorRateText = "${daysAtVisitorRate.toString()}"
        " day(s) at "
        "${AppData.rates.getFormattedRate(visitorRate)}"
        '/M ';
    String standardRateText = "${daysAtStandardRate.toString()}"
        " day(s) at "
        "${AppData.rates.getFormattedRate(standardRate)}"
        "/M ";
    String discountRateText = "${daysAtMembersDiscountRate.toString()}"
        " day(s) at "
        "${AppData.rates.getFormattedRate(membersDiscountRate)}"
        "/M";

    log.info(
        'Days at visitor $visitorRateText $standardRateText $discountRateText');

    List<String> days = ['Mon', 'Tues', 'Weds', 'Thurs', 'Fri', 'Sat', 'Sun'];

    return 'Arrival\n${days[startStay.weekday]} - ${Constants.formatDate(startStay)}\n\n'
        'Departure\n${days[endStay.weekday]} - ${Constants.formatDate(endStay)}\n\n'
        '$boatName (${boatLengthNearestHalfMeter}M)\n\n'
        '${daysAtVisitorRate == 0 ? '' : '$visitorRateText\n\n'}'
        '${daysAtStandardRate == 0 ? '' : '$standardRateText\n\n'}'
        '${daysAtMembersDiscountRate == 0 ? '' : '$discountRateText\n\n'}Fee: $fee';
  }

  void calculateFee() {
    pontoonCharge = 0;
    daysAtVisitorRate = 0;
    daysAtStandardRate = 0;
    daysAtMembersDiscountRate = 0;

    double boatLength = double.parse(AppData.boatLengthNearestHalfMeter);
    //bool isMember = AppData.getIsMember();

    //if (errorMsg != '') return;

    Duration day = const Duration(days: 1);

    /* for (DateTime d = startStay;
        endStay.difference(d).inDays > 0;
        d = d.add(day)) {*/

    log.info('Start stay:$startStay');
    log.info('End stay:$endStay');

    //log.info('Difference in days ' + endStay.difference(d).inDays.toString());

    for (DateTime d = startStay;
        endStay.difference(d).inDays > 0;
        d = d.add(day)) {
      if (isMember == false) {
        pontoonCharge += AppData.rates.visitorRate * boatLength;
        daysAtVisitorRate++;
        continue;
      }

      if (d.weekday == DateTime.friday || d.weekday == DateTime.saturday) {
        pontoonCharge += AppData.rates.standardRate * boatLength;
        daysAtStandardRate++;
        log.info("Discount day");
      } else {
        pontoonCharge += AppData.rates.membersDiscountRate * boatLength;
        daysAtMembersDiscountRate++;
        log.info("Non Discount day");
      }
    }

    fee = AppData.rates.getFormattedRate(pontoonCharge);
  }

  static List<CalculatedStay> getCalculatedStayTestList() {
    List<CalculatedStay> list = <CalculatedStay>[];
    list.add(CalculatedStay("Dorado1", DateTime.now(), DateTime.now(), "34.54",
        true, 1.20, 2.40, 0.6, "7.5", true));
    list.add(CalculatedStay("Dorado2", DateTime.now(), DateTime.now(), "34.54",
        false, 1.20, 2.40, 0.6, "7.5", false));
    list.add(CalculatedStay("Dorado3", DateTime.now(), DateTime.now(), "34.54",
        true, 1.20, 2.40, 0.6, "7.5", true));
    list.add(CalculatedStay("Dorado4", DateTime.now(), DateTime.now(), "34.54",
        false, 1.20, 2.40, 0.6, "7.5", false));

    return list;
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
        // "hot reload" (s "r" in the console where you ran "flutter run",
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
        '/': (context) => const HomePage(),
        // When navigating to the "/second" route, build the SecondScreen widget.
        '/second': (context) => const CalculateFee(),
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
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  TextEditingController boatLengthTextEditingController =
      TextEditingController();

  TextEditingController boatNameTextEditingController = TextEditingController();

  CurrencyTextFieldController visitorsRateCurrencyEditingController =
      CurrencyTextFieldController(
          currencySymbol: "£", decimalSymbol: ".", thousandSymbol: ",");

  CurrencyTextFieldController membersRateCurrencyEditingController =
      CurrencyTextFieldController(
          currencySymbol: "£", decimalSymbol: ".", thousandSymbol: ",");

  CurrencyTextFieldController membersDiscountRateCurrencyEditingController =
      CurrencyTextFieldController(
          currencySymbol: "£", decimalSymbol: ".", thousandSymbol: ",");

  int memberOrVisitorRadioValue = -1;
  int feetOrMetersRadioValue = -1;

  String expiryNotice = "blah blah";

  DateTime newExpiryDate = DateTime.now();

  pushToScreen(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CalculateFee()));
  }

  @override
  void initState() {
    super.initState();

    if (AppData.isMember == true) {
      memberOrVisitorRadioValue = 0;
    } else {
      memberOrVisitorRadioValue = 1;
    }

    if (AppData.isInFeet == true) {
      feetOrMetersRadioValue = 0;
    } else {
      feetOrMetersRadioValue = 1;
    }

    AppData.calculateToNearestHalfMeter();

    /*
    if (AppData.getIsBoatDataComplete() == false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSetupDialog().then((_) {
          if (AppData.showWelcomeDialog) {
            showWelcomeDialogue();
          }
          if (AppData.rates.ratesHaveExpired() == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showUpdateRatesDialog();
            });
          }
        });
      });
    }
     */

    log.shout("Show welcome dialog: ${AppData.showWelcomeDialog}");
    log.shout("Is boat data complete: ${AppData.getIsBoatDataComplete()}");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AppData.rates.ratesHaveExpired(AppData.rates.dateExpires) == true) {
        expiryNotice = Rates.expiryNotice;
        showUpdateRatesDialog();
      }

      if (AppData.getIsBoatDataComplete() == false) {
        _showSetupDialog();
      }

      if (AppData.showWelcomeDialog) {
        showWelcomeDialogue();
      }
    });
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
      case "Update rates":
        if (AppData.rates.ratesHaveExpired(AppData.rates.dateExpires) == true) {
          expiryNotice = Rates.expiryNotice;
        } else {
          expiryNotice = "";
        }
        showUpdateRatesDialog();
        break;
    }
  }

  void calculatedStayListMenuClick(
      String value, CalculatedStay calcStay) async {
    switch (value) {
      case 'Show calculation':
        log.info('Show calculation');
        //calcStay.calculateFee();
        showCalculationDialog(calcStay);
        break;

      case 'Mark as paid':
        log.info('Mark as Paid');
        setState(() => calcStay.paid = true);
        AppData.setStays(AppData.stays);
        break;

      case 'Mark as owed':
        log.info('Mark as Owed');
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
          title: const Text("Are you sure?"),
          content: Text(text),
          actions: <Widget>[
            // usually buttons at the bottom of the dialog
            TextButton(
              child: const Text("Yes"),
              onPressed: () {
                Navigator.of(context).pop("Yes");
              },
            ),
            TextButton(
              child: const Text("No"),
              onPressed: () {
                Navigator.of(context).pop("No");
              },
            ),
          ],
        );
      },
    );
  }

  Future<dynamic> showMessageDialog(String title, String text) {
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
                  TextButton(
                    child: const Text("Done"),
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
    String ratesText = '\nVisitors:\n\n'
        '${AppData.rates.getFormattedRate(AppData.rates.visitorRate)}/M per night\n\n\n'
        'Members:\n\nSunday to Thursday night\n'
        '${AppData.rates.getFormattedRate(AppData.rates.membersDiscountRate)}/M per night\nFriday and Saturday night\n'
        '${AppData.rates.getFormattedRate(AppData.rates.standardRate)}/M per night\n';

    return showMessageDialog('Rates', ratesText);
  }

  Future<dynamic> showHowToPayDialogue() async {
    String howToPayText =
        'These are the different ways you can pay:\n\n blah blah blah';

    return showMessageDialog('How to pay', howToPayText);
  }

  Future<dynamic> showWelcomeDialogue() async {
    String welcomeText = 'This an app for '
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
                title: const Text('Welcome'),
                content: SingleChildScrollView(
                    child: Column(children: [
                  Text(welcomeText, style: Constants.welcomeTextStyle),
                  CheckboxListTile(
                      title: const Text('Do not show this message again'),
                      value: !AppData.showWelcomeDialog,
                      onChanged: (bool? value) {
                        setState(() {
                          AppData.setShowWelcomeDialog(
                              value == null ? false : !value);
                        });
                      })
                ])),
                actions: <Widget>[
                  // usually buttons at the bottom of the dialog
                  TextButton(
                    child: const Text("Done"),
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
          title: const Text('Pontoon Fee Calculation'),
          content: Text(calcStay.getBreakdown()),
          actions: <Widget>[
            // usually buttons at the bottom of the dialog
            TextButton(
              child: const Text("Copy to clipboard"),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: calcStay.getBreakdown()));
              },
            ),
            TextButton(
              child: const Text("Close"),
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
        title: const Text('Stays on the pontoon'),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: handleClick,
            itemBuilder: (BuildContext context) {
              return {
                'Your details',
                'Show rates',
                'How to pay',
                'Update rates'
              }.map((String choice) {
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
          onPressed: (() => Navigator.pushNamed(context, '/second')
              .whenComplete(
                  () => setState(() => log.info('Setting state Done')))),
          child: const Icon(Icons.add, color: Colors.black)),
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
                text:
                    '${calculatedStay.boatName} (${calculatedStay.boatLengthNearestHalfMeter}M)',
              ),
              const TextSpan(text: '\n'),
              const TextSpan(style: Constants.listTextStyle, text: 'Arrival: '),
              // TextSpan(text: '\n'),
              TextSpan(
                  style: Constants.boldStyle,
                  text:
                      '      ${Constants.formatDate(calculatedStay.startStay)}'),
              const TextSpan(text: '\n'),
              const TextSpan(
                  style: Constants.listTextStyle, text: 'Departure: '),
              //TextSpan(text: '\n'),
              TextSpan(
                  style: Constants.boldStyle,
                  text: Constants.formatDate(calculatedStay.endStay)),
              const TextSpan(text: '\n'),

              if (calculatedStay.paid == false)
                const TextSpan(
                  style: Constants.feeOwedStyle,
                  text: 'Marked as owed',
                )
              else
                const TextSpan(
                  style: Constants.feePaidStyle,
                  text: 'Marked as paid',
                ),
              const TextSpan(text: '\n'),
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
              text: calculatedStay.fee,
            ),
            const TextSpan(text: '\n'),
          ])),
    ]);
  }

  List<Widget> listBuilder() {
    List<Container> listTiles = <Container>[];

    //log.info('List Builder ' + AppData.getStays().length.toString());

    AppData.stays.map((calculatedStay) {
      log.info('Adding ListTile ${calculatedStay.fee}');
      listTiles.add(Container(
          decoration: calculatedStay.paid
              ? BoxDecoration(color: Colors.brown[50])
              : BoxDecoration(color: Colors.blue[50]),
          child: ListTile(
            title: Container(
                decoration: const BoxDecoration(), //color: Colors.green),
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
                title: const Text("About you and your boat"),
                content: SingleChildScrollView(
                    // Center is a layout widget. It takes a single child and positions it
                    // in the middle of the parent.
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                      TextField(
                        decoration: const InputDecoration(
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
                            constraints: const BoxConstraints(
                              minWidth: 70,
                              minHeight: 70,
                              maxWidth: 80,
                              maxHeight: 150,
                            ),
                            child: TextField(
                                decoration: const InputDecoration(
                                    labelText: "Length",
                                    labelStyle: Constants.textLabelStyle),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                onChanged: (text) {
                                  setState(() {
                                    AppData.setBoatLength(text);
                                    log.info("Changed length to: $text");
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
                        const Text(
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
                        const Text(
                          'M',
                          style: TextStyle(
                              color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ]),
                      const Text(
                        'Boat length to nearest half meter:',
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.normal),
                      ),
                      Text(
                        '${AppData.boatLengthNearestHalfMeter}M',
                        style: const TextStyle(
                            color: Colors.blueGrey,
                            fontWeight: FontWeight.normal,
                            fontSize: 25),
                      ),
                      const Text(
                        ' ',
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.normal),
                      ),
                      const Text(
                          'Are you a member of FCYC or RFYC, or are you a visitor?',
                          style: Constants.questionsStyle),
                      Row(children: <Widget>[
                        Radio(
                            value: 0,
                            groupValue: memberOrVisitorRadioValue,
                            onChanged: (value) {
                              setState(() {
                                log.info(
                                    'Member or visitor radio value: $value');
                                memberOrVisitorRadioValue = value as int;
                                AppData.setIsMember(true);
                              });
                            }),
                        const Text(
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
                                log.info(
                                    'Member or visitor radio value: $value');
                                memberOrVisitorRadioValue = value as int;
                                AppData.setIsMember(false);
                              });
                            }),
                        const Text(
                          'Visitor',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.normal),
                        ),
                      ]),
                      ElevatedButton(
                        onPressed: AppData.getIsBoatDataComplete()
                            ? () {
                                Navigator.pop(context);
                              }
                            : null,
                        child: const Text(
                            'Done'), // If null then button deactivated
                      ),
                    ])));
          });
        });
  }

  /// Get updated rates for birthing on the pontoon
  Future showUpdateRatesDialog() {

    // Currency editing controller needs two decimal places represented in the string
    // to parse the amount correctly (e.g. it will parse "0.5" as "0.05". A dart solution
    // could be to use num.toStringAsPrecision, but this behaves in the following way and
    // doesn't give us what we want:
    //
    // double a = 0.5; a.toStringAsPrecision(2); # this returns "0.50"
    // double b = 1.0; a.toStringAsPrecision(2); # this returns "1.0"
    // double b = 1.0; a.toStringAsPrecision(3); # this returns "1.00"
    //
    // so use sprintf("%.2f,[a]); instead.

    visitorsRateCurrencyEditingController.text =
        sprintf("%.2f", [AppData.rates.visitorRate]);
    membersRateCurrencyEditingController.text =
        sprintf("%.2f", [AppData.rates.standardRate]);
    membersDiscountRateCurrencyEditingController.text =
        sprintf("%.2f", [AppData.rates.membersDiscountRate]);

    newExpiryDate = AppData.rates.dateExpires.copyWith();

    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(builder: (context, setState) {
            return AlertDialog(
                title: const Text("Birthing rates"),
                content: SingleChildScrollView(
                    // Center is a layout widget. It takes a single child and positions it
                    // in the middle of the parent.
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                      Text(expiryNotice, style: Constants.questionsStyle),
                      TextField(
                        decoration: const InputDecoration(
                            labelText: "Visitor's rate (per night)",
                            labelStyle: Constants.textLabelStyle),
                        keyboardType: TextInputType.number,
                        controller: visitorsRateCurrencyEditingController,
                        onChanged: (text) {
                          setState(() {});
                        },
                        //inputFormatters: <TextInputFormatter>[
                        //   DecimalTextInputFormatter (decimalRange: 2)
                        //]
                      ),
                      TextField(
                        decoration: const InputDecoration(
                            labelText: "Member's rate (per night)",
                            labelStyle: Constants.textLabelStyle),
                        keyboardType: TextInputType.number,
                        controller: membersRateCurrencyEditingController,
                        onChanged: (text) {
                          setState(() {});
                        },
                        //inputFormatters: <TextInputFormatter>[
                        //   DecimalTextInputFormatter (decimalRange: 2)
                        //]
                      ),
                      TextField(
                        decoration: const InputDecoration(
                            // todo work out how to get the text to wrap.
                            labelText: "Member's discount rate (per night)",
                            labelStyle: Constants.textLabelStyle),
                        keyboardType: TextInputType.number,
                        controller:
                            membersDiscountRateCurrencyEditingController,
                        onChanged: (text) {
                          setState(() {});
                        },
                      ),
                      Table(columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(3)
                      }, children: [
                        TableRow(children: [
                          Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(top: 17.0),
                            child: Text(
                                AppData.rates.ratesHaveExpired(newExpiryDate)
                                    ? "Rates expired:"
                                    : "Rates expire:",
                                style: AppData.rates.ratesHaveExpired(newExpiryDate)
                                    ? Constants.alertStyle
                                    : Constants.questionsStyle),
                          ),
                          ElevatedButton(
                              child: Text(
                                Constants.formatDate(AppData.rates.dateExpires),
                                style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold),
                              ),
                              onPressed: () {
                                // Set state after get response from the datepicker
                                // so that the dialog gets redrawn
                                // Seems a bit convoluted, though. Don't have to do this like this
                                // in the getBoatDetails dialogue.
                                showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(), // Refer step 1
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                ).then ( (picked) {

                                if (picked != null) {
                                  newExpiryDate = picked;

                                  if (AppData.rates.ratesHaveExpired(newExpiryDate) == true) {
                                    expiryNotice = Rates.expiryNotice;
                                  } else {
                                    expiryNotice = "";
                                  }
                                }});
                                setState(() {});
                              })
                        ]),
                        // TableRow just to add a bit of space. Clunky,
                        // but if I use the spacer widget, the framework
                        // crashes horribly.
                        const TableRow(children: [Text(""), Text("")]),
                      ]),
                        Table(children: [
                        TableRow(children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                                'Cancel'), // If null then button deactivated
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);

                              AppData.rates.visitorRate =
                                  visitorsRateCurrencyEditingController
                                      .doubleValue;

                              AppData.rates.membersDiscountRate =
                                  membersDiscountRateCurrencyEditingController
                                      .doubleValue;

                              AppData.rates.standardRate =
                                  membersRateCurrencyEditingController
                                      .doubleValue;

                              AppData.rates.dateExpires = newExpiryDate;
                              AppData.saveRates();
                            },
                            child: const Text(
                                'Update'), // If null then button deactivated
                          ),
                        ]),
                      ])

                      /*
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                            'Done'), // If null then button deactivated
                      ),

                       */
                    ])));
          });
        });
  }
}

class CalculateFee extends StatefulWidget {
  const CalculateFee({Key? key, this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String? title;

  @override
  CalculateFeePageState createState() => CalculateFeePageState();
}

class CalculateFeePageState extends State<CalculateFee> {
  CalculatedStay calculatedStay = CalculatedStay(
      AppData.boatName,
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
      '',
      AppData.isMember,
      AppData.rates.standardRate,
      AppData.rates.visitorRate,
      AppData.rates.membersDiscountRate,
      AppData.boatLengthNearestHalfMeter,
      false);

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
    String text =
        'Sun to Thu £${AppData.rates.membersDiscountRate}Overnight rate for members\n Fri to Sat £${AppData.rates.standardRate}\n';

    if (AppData.isMember == false) {
      return Text(
          'Overnight rate for visitors: £${AppData.rates.visitorRate} per meter');
    }

    return Table(children: [
      TableRow(children: [
        const TableCell(child: Text('Fri to Sat ')),
        TableCell(child: Text('£${AppData.rates.standardRate}')),
      ]),
      TableRow(children: [
        const TableCell(child: Text('Sun to Thu ')),
        TableCell(child: Text('£${AppData.rates.membersDiscountRate}')),
      ]),
    ]);
  }

  Widget getSetDateTable(BuildContext context) {
    return Table(children: [
      getRateTableRow("Boat", AppData.boatName),
      getRateTableRow("Length", '${AppData.boatLengthNearestHalfMeter}M'),
      TableRow(children: [
        TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 50,
                  minHeight: Constants.rowHeight,
                  maxWidth: 70,
                  maxHeight: Constants.rowHeight,
                ),
                child: const Center(
                    child: Text('Arrival',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.normal,
                            fontSize: 20))))),
        TableCell(
          child: ElevatedButton(
            onPressed: () => _selectStartDate(context), // Refer step 3
            child: Text(
              Constants.formatDate(calculatedStay.startStay),
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        )
      ]),
      TableRow(children: [
        TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: 50,
                  minHeight: Constants.rowHeight,
                  maxWidth: 70,
                  maxHeight: Constants.rowHeight,
                ),
                child: const Center(
                    child: Text('Departure',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.normal,
                            fontSize: 20))))),
        TableCell(
          child: ElevatedButton(
            onPressed: () => _selectEndDate(context), // Refer step 3
            child: Text(
              Constants.formatDate(calculatedStay.endStay),
              style: const TextStyle(
                  color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ]),
      if (calculatedStay.daysAtVisitorRate != 0)
        getRateTableRow(
            'Days at ${AppData.rates.getFormattedRate(AppData.rates.visitorRate)}/M',
            calculatedStay.daysAtVisitorRate.toString()),
      if (calculatedStay.daysAtStandardRate != 0)
        getRateTableRow(
            'Days at ${AppData.rates.getFormattedRate(AppData.rates.standardRate)}/M',
            calculatedStay.daysAtStandardRate.toString()),
      if (calculatedStay.daysAtMembersDiscountRate != 0)
        getRateTableRow(
            'Days at ${AppData.rates.getFormattedRate(AppData.rates.membersDiscountRate)}/M',
            calculatedStay.daysAtMembersDiscountRate.toString()),
      getRateTableRow(
          "Fee", AppData.rates.getFormattedRate(calculatedStay.pontoonCharge)),
    ]);
  }

  TableRow getRateTableRow(String rate, String days) {
    return TableRow(children: [
      TableCell(
        verticalAlignment: TableCellVerticalAlignment.middle,
        child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 50,
              minHeight: Constants.rowHeight,
              maxWidth: 70,
              maxHeight: Constants.rowHeight,
            ),
            child: Center(
                child: Text(rate,
                    style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.normal,
                        fontSize: 20)))),
      ),
      TableCell(
          verticalAlignment: TableCellVerticalAlignment.middle,
          child: Center(
              child: Text(days,
                  style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.normal,
                      fontSize: 20)))),
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
          title: const Text("Calculate fee"),
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
                  errorMsg,
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: calculatedStay.pontoonCharge == 0
                      ? null
                      : () {
                          AppData.stays.insert(0, calculatedStay);
                          AppData.setStays(AppData.stays);
                          Navigator.pop(context);
                        },
                  child: const Text('Save'),
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
          value.substring(value.indexOf(".") + 1).length >
              (decimalRange as int)) {
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


