import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'FitEvo'**
  String get appTitle;

  /// No description provided for @somethingBroke.
  ///
  /// In en, this message translates to:
  /// **'Something broke on this screen'**
  String get somethingBroke;

  /// No description provided for @errorCopied.
  ///
  /// In en, this message translates to:
  /// **'Error copied to clipboard'**
  String get errorCopied;

  /// No description provided for @copyError.
  ///
  /// In en, this message translates to:
  /// **'Copy error'**
  String get copyError;

  /// No description provided for @continueBtn.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueBtn;

  /// No description provided for @startTracking.
  ///
  /// In en, this message translates to:
  /// **'Start tracking'**
  String get startTracking;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get saturday;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get sunday;

  /// No description provided for @monFull.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monFull;

  /// No description provided for @tueFull.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tueFull;

  /// No description provided for @wedFull.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wedFull;

  /// No description provided for @thuFull.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thuFull;

  /// No description provided for @friFull.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friFull;

  /// No description provided for @satFull.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get satFull;

  /// No description provided for @sunFull.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunFull;

  /// No description provided for @homeTab.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeTab;

  /// No description provided for @workoutTab.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workoutTab;

  /// No description provided for @progressTab.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progressTab;

  /// No description provided for @coachTab.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get coachTab;

  /// No description provided for @settingsTab.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTab;

  /// No description provided for @foodTab.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get foodTab;

  /// No description provided for @calories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get calories;

  /// No description provided for @protein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get protein;

  /// No description provided for @carbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get carbs;

  /// No description provided for @fat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get fat;

  /// No description provided for @fiber.
  ///
  /// In en, this message translates to:
  /// **'Fiber'**
  String get fiber;

  /// No description provided for @water.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get water;

  /// No description provided for @sodium.
  ///
  /// In en, this message translates to:
  /// **'Sodium'**
  String get sodium;

  /// No description provided for @kcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get kcal;

  /// No description provided for @grams.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get grams;

  /// No description provided for @kilograms.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get kilograms;

  /// No description provided for @centimeters.
  ///
  /// In en, this message translates to:
  /// **'cm'**
  String get centimeters;

  /// No description provided for @kilometers.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get kilometers;

  /// No description provided for @miles.
  ///
  /// In en, this message translates to:
  /// **'mi'**
  String get miles;

  /// No description provided for @milliliters.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get milliliters;

  /// No description provided for @ounces.
  ///
  /// In en, this message translates to:
  /// **'oz'**
  String get ounces;

  /// No description provided for @minutes.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutes;

  /// No description provided for @sets.
  ///
  /// In en, this message translates to:
  /// **'sets'**
  String get sets;

  /// No description provided for @reps.
  ///
  /// In en, this message translates to:
  /// **'reps'**
  String get reps;

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @bmi.
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get bmi;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;

  /// No description provided for @sedentary.
  ///
  /// In en, this message translates to:
  /// **'Sedentary'**
  String get sedentary;

  /// No description provided for @sedentaryDesc.
  ///
  /// In en, this message translates to:
  /// **'Mostly sitting, little exercise'**
  String get sedentaryDesc;

  /// No description provided for @lightlyActive.
  ///
  /// In en, this message translates to:
  /// **'Lightly active'**
  String get lightlyActive;

  /// No description provided for @lightlyActiveDesc.
  ///
  /// In en, this message translates to:
  /// **'1–3 light workouts / week'**
  String get lightlyActiveDesc;

  /// No description provided for @moderatelyActive.
  ///
  /// In en, this message translates to:
  /// **'Moderately active'**
  String get moderatelyActive;

  /// No description provided for @moderatelyActiveDesc.
  ///
  /// In en, this message translates to:
  /// **'3–5 workouts / week'**
  String get moderatelyActiveDesc;

  /// No description provided for @veryActive.
  ///
  /// In en, this message translates to:
  /// **'Very active'**
  String get veryActive;

  /// No description provided for @veryActiveDesc.
  ///
  /// In en, this message translates to:
  /// **'6–7 workouts / week'**
  String get veryActiveDesc;

  /// No description provided for @athlete.
  ///
  /// In en, this message translates to:
  /// **'Athlete'**
  String get athlete;

  /// No description provided for @athleteDesc.
  ///
  /// In en, this message translates to:
  /// **'Twice-daily training'**
  String get athleteDesc;

  /// No description provided for @buildMuscle.
  ///
  /// In en, this message translates to:
  /// **'Build muscle'**
  String get buildMuscle;

  /// No description provided for @buildMuscleDesc.
  ///
  /// In en, this message translates to:
  /// **'Modest surplus, high protein'**
  String get buildMuscleDesc;

  /// No description provided for @loseFat.
  ///
  /// In en, this message translates to:
  /// **'Lose fat'**
  String get loseFat;

  /// No description provided for @loseFatDesc.
  ///
  /// In en, this message translates to:
  /// **'Moderate deficit, preserve muscle'**
  String get loseFatDesc;

  /// No description provided for @recomp.
  ///
  /// In en, this message translates to:
  /// **'Recomp'**
  String get recomp;

  /// No description provided for @recompDesc.
  ///
  /// In en, this message translates to:
  /// **'Maintenance, slow change'**
  String get recompDesc;

  /// No description provided for @generalFitness.
  ///
  /// In en, this message translates to:
  /// **'General fitness'**
  String get generalFitness;

  /// No description provided for @generalFitnessDesc.
  ///
  /// In en, this message translates to:
  /// **'Stay healthy & strong'**
  String get generalFitnessDesc;

  /// No description provided for @omnivore.
  ///
  /// In en, this message translates to:
  /// **'Omnivore'**
  String get omnivore;

  /// No description provided for @vegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get vegetarian;

  /// No description provided for @vegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get vegan;

  /// No description provided for @pescatarian.
  ///
  /// In en, this message translates to:
  /// **'Pescatarian'**
  String get pescatarian;

  /// No description provided for @keto.
  ///
  /// In en, this message translates to:
  /// **'Keto'**
  String get keto;

  /// No description provided for @halal.
  ///
  /// In en, this message translates to:
  /// **'Halal'**
  String get halal;

  /// No description provided for @kosher.
  ///
  /// In en, this message translates to:
  /// **'Kosher'**
  String get kosher;

  /// No description provided for @jain.
  ///
  /// In en, this message translates to:
  /// **'Jain'**
  String get jain;

  /// No description provided for @never.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get never;

  /// No description provided for @lessThan1Month.
  ///
  /// In en, this message translates to:
  /// **'< 1 mo'**
  String get lessThan1Month;

  /// No description provided for @threeToSixMonths.
  ///
  /// In en, this message translates to:
  /// **'3–6 mo'**
  String get threeToSixMonths;

  /// No description provided for @sixTo24Months.
  ///
  /// In en, this message translates to:
  /// **'6–24 mo'**
  String get sixTo24Months;

  /// No description provided for @twoPlusYears.
  ///
  /// In en, this message translates to:
  /// **'2+ yrs'**
  String get twoPlusYears;

  /// No description provided for @pregnant.
  ///
  /// In en, this message translates to:
  /// **'Pregnant'**
  String get pregnant;

  /// No description provided for @breastfeeding.
  ///
  /// In en, this message translates to:
  /// **'Breastfeeding'**
  String get breastfeeding;

  /// No description provided for @eatingDisorderHistory.
  ///
  /// In en, this message translates to:
  /// **'Eating-disorder history'**
  String get eatingDisorderHistory;

  /// No description provided for @type1Diabetes.
  ///
  /// In en, this message translates to:
  /// **'Type 1 diabetes'**
  String get type1Diabetes;

  /// No description provided for @recoveringFromInjury.
  ///
  /// In en, this message translates to:
  /// **'Recovering from injury'**
  String get recoveringFromInjury;

  /// No description provided for @type2Diabetes.
  ///
  /// In en, this message translates to:
  /// **'Type 2 diabetes'**
  String get type2Diabetes;

  /// No description provided for @pcos.
  ///
  /// In en, this message translates to:
  /// **'PCOS'**
  String get pcos;

  /// No description provided for @hypothyroid.
  ///
  /// In en, this message translates to:
  /// **'Hypothyroid'**
  String get hypothyroid;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @everyOtherDay.
  ///
  /// In en, this message translates to:
  /// **'Every other day'**
  String get everyOtherDay;

  /// No description provided for @twicePerWeek.
  ///
  /// In en, this message translates to:
  /// **'2× / week'**
  String get twicePerWeek;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @diet.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get diet;

  /// No description provided for @nepal.
  ///
  /// In en, this message translates to:
  /// **'Nepal'**
  String get nepal;

  /// No description provided for @india.
  ///
  /// In en, this message translates to:
  /// **'India'**
  String get india;

  /// No description provided for @bangladesh.
  ///
  /// In en, this message translates to:
  /// **'Bangladesh'**
  String get bangladesh;

  /// No description provided for @pakistan.
  ///
  /// In en, this message translates to:
  /// **'Pakistan'**
  String get pakistan;

  /// No description provided for @sriLanka.
  ///
  /// In en, this message translates to:
  /// **'Sri Lanka'**
  String get sriLanka;

  /// No description provided for @australia.
  ///
  /// In en, this message translates to:
  /// **'Australia'**
  String get australia;

  /// No description provided for @brazil.
  ///
  /// In en, this message translates to:
  /// **'Brazil'**
  String get brazil;

  /// No description provided for @canada.
  ///
  /// In en, this message translates to:
  /// **'Canada'**
  String get canada;

  /// No description provided for @china.
  ///
  /// In en, this message translates to:
  /// **'China'**
  String get china;

  /// No description provided for @germany.
  ///
  /// In en, this message translates to:
  /// **'Germany'**
  String get germany;

  /// No description provided for @france.
  ///
  /// In en, this message translates to:
  /// **'France'**
  String get france;

  /// No description provided for @indonesia.
  ///
  /// In en, this message translates to:
  /// **'Indonesia'**
  String get indonesia;

  /// No description provided for @italy.
  ///
  /// In en, this message translates to:
  /// **'Italy'**
  String get italy;

  /// No description provided for @japan.
  ///
  /// In en, this message translates to:
  /// **'Japan'**
  String get japan;

  /// No description provided for @southKorea.
  ///
  /// In en, this message translates to:
  /// **'South Korea'**
  String get southKorea;

  /// No description provided for @mexico.
  ///
  /// In en, this message translates to:
  /// **'Mexico'**
  String get mexico;

  /// No description provided for @malaysia.
  ///
  /// In en, this message translates to:
  /// **'Malaysia'**
  String get malaysia;

  /// No description provided for @philippines.
  ///
  /// In en, this message translates to:
  /// **'Philippines'**
  String get philippines;

  /// No description provided for @singapore.
  ///
  /// In en, this message translates to:
  /// **'Singapore'**
  String get singapore;

  /// No description provided for @thailand.
  ///
  /// In en, this message translates to:
  /// **'Thailand'**
  String get thailand;

  /// No description provided for @turkey.
  ///
  /// In en, this message translates to:
  /// **'Turkey'**
  String get turkey;

  /// No description provided for @unitedKingdom.
  ///
  /// In en, this message translates to:
  /// **'United Kingdom'**
  String get unitedKingdom;

  /// No description provided for @unitedStates.
  ///
  /// In en, this message translates to:
  /// **'United States'**
  String get unitedStates;

  /// No description provided for @vietnam.
  ///
  /// In en, this message translates to:
  /// **'Vietnam'**
  String get vietnam;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign up'**
  String get signUp;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccount;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot?'**
  String get forgotPassword;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back.'**
  String get welcomeBack;

  /// No description provided for @createYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account.'**
  String get createYourAccount;

  /// No description provided for @signInToSync.
  ///
  /// In en, this message translates to:
  /// **'Sign in to back up and sync across devices.'**
  String get signInToSync;

  /// No description provided for @setUpAccount.
  ///
  /// In en, this message translates to:
  /// **'Set up your account to back up across devices.'**
  String get setUpAccount;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get alreadyHaveAccount;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @atLeast6Chars.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get atLeast6Chars;

  /// No description provided for @signInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed.'**
  String get signInFailed;

  /// No description provided for @somethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get somethingWrong;

  /// No description provided for @couldNotContinue.
  ///
  /// In en, this message translates to:
  /// **'Could not continue.'**
  String get couldNotContinue;

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent to {email}.'**
  String passwordResetSent(Object email);

  /// No description provided for @enterEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Enter your email above first, then tap \"Forgot?\".'**
  String get enterEmailFirst;

  /// No description provided for @couldNotSendReset.
  ///
  /// In en, this message translates to:
  /// **'Could not send reset email.'**
  String get couldNotSendReset;

  /// No description provided for @whatShouldWeCallYou.
  ///
  /// In en, this message translates to:
  /// **'What should we call you?'**
  String get whatShouldWeCallYou;

  /// No description provided for @enterEmailPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and password.'**
  String get enterEmailPassword;

  /// No description provided for @yourPassword.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get yourPassword;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @cloudBackup.
  ///
  /// In en, this message translates to:
  /// **'CLOUD BACKUP'**
  String get cloudBackup;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get preferences;

  /// No description provided for @accountSection.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get accountSection;

  /// No description provided for @lastBackup.
  ///
  /// In en, this message translates to:
  /// **'Last backup'**
  String get lastBackup;

  /// No description provided for @autoBackupOn.
  ///
  /// In en, this message translates to:
  /// **'Auto-backup is on — changes sync within ~30 seconds.'**
  String get autoBackupOn;

  /// No description provided for @backupNow.
  ///
  /// In en, this message translates to:
  /// **'Backup now'**
  String get backupNow;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @photosOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Progress photos and body measurements never leave your device.'**
  String get photosOnDevice;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @restoreFromCloud.
  ///
  /// In en, this message translates to:
  /// **'Restore from cloud?'**
  String get restoreFromCloud;

  /// No description provided for @restoreOverwrite.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite local entries with the cloud backup. Continue?'**
  String get restoreOverwrite;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutTitle;

  /// No description provided for @signOutBody.
  ///
  /// In en, this message translates to:
  /// **'Your local data stays on this device. Sign in again to keep syncing.'**
  String get signOutBody;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This wipes your Firebase account, cloud backup, AND every workout, meal, and weigh-in on this device. Cannot be undone.'**
  String get deleteAccountBody;

  /// No description provided for @deleteEverything.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get deleteEverything;

  /// No description provided for @backupComplete.
  ///
  /// In en, this message translates to:
  /// **'Backup complete.'**
  String get backupComplete;

  /// No description provided for @restoredFromCloud.
  ///
  /// In en, this message translates to:
  /// **'Restored from cloud.'**
  String get restoredFromCloud;

  /// No description provided for @guestAccount.
  ///
  /// In en, this message translates to:
  /// **'Guest account'**
  String get guestAccount;

  /// No description provided for @backingUpTemp.
  ///
  /// In en, this message translates to:
  /// **'Backing up under a temporary ID'**
  String get backingUpTemp;

  /// No description provided for @noAccountHint.
  ///
  /// In en, this message translates to:
  /// **'No account? You can still back up — Settings → Export my data shares the JSON to Drive, email, or Files. Restore by importing on any device.'**
  String get noAccountHint;

  /// No description provided for @upgradeToAccount.
  ///
  /// In en, this message translates to:
  /// **'UPGRADE TO A FULL ACCOUNT'**
  String get upgradeToAccount;

  /// No description provided for @addEmailGoogle.
  ///
  /// In en, this message translates to:
  /// **'Add an email or Google account so you can sign in on another device and never lose your progress.'**
  String get addEmailGoogle;

  /// No description provided for @createAccountLink.
  ///
  /// In en, this message translates to:
  /// **'Create account & link'**
  String get createAccountLink;

  /// No description provided for @signInLink.
  ///
  /// In en, this message translates to:
  /// **'Sign in & link'**
  String get signInLink;

  /// No description provided for @alreadyHaveAccountSign.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get alreadyHaveAccountSign;

  /// No description provided for @newHereCreate.
  ///
  /// In en, this message translates to:
  /// **'New here? Create an account'**
  String get newHereCreate;

  /// No description provided for @guestDataBackedUp.
  ///
  /// In en, this message translates to:
  /// **'Your guest data is already backed up to Firebase. Linking just lets you sign in from another device.'**
  String get guestDataBackedUp;

  /// No description provided for @signedIn.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get signedIn;

  /// No description provided for @profileAndTargets.
  ///
  /// In en, this message translates to:
  /// **'Profile & targets'**
  String get profileAndTargets;

  /// No description provided for @aboutYou.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get aboutYou;

  /// No description provided for @aboutYouDesc.
  ///
  /// In en, this message translates to:
  /// **'Basics we use to compute your targets.'**
  String get aboutYouDesc;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @activityDesc.
  ///
  /// In en, this message translates to:
  /// **'How active you are day-to-day, plus structured training.'**
  String get activityDesc;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @scheduleDesc.
  ///
  /// In en, this message translates to:
  /// **'Used to time water reminders during your waking hours.'**
  String get scheduleDesc;

  /// No description provided for @healthAndCadence.
  ///
  /// In en, this message translates to:
  /// **'Health & cadence'**
  String get healthAndCadence;

  /// No description provided for @healthAndCadenceDesc.
  ///
  /// In en, this message translates to:
  /// **'Body fat % unlocks Katch-McArdle. Health flags tune the math; sensitive cases trigger a \"see a pro\" note.'**
  String get healthAndCadenceDesc;

  /// No description provided for @supplements.
  ///
  /// In en, this message translates to:
  /// **'Supplements'**
  String get supplements;

  /// No description provided for @supplementsDesc.
  ///
  /// In en, this message translates to:
  /// **'Creatine raises your water target. Protein scoops do too.'**
  String get supplementsDesc;

  /// No description provided for @workoutType.
  ///
  /// In en, this message translates to:
  /// **'Workout type'**
  String get workoutType;

  /// No description provided for @workoutTypeDesc.
  ///
  /// In en, this message translates to:
  /// **'What you\'re training right now. Your routine, empty state and cues adapt to this.'**
  String get workoutTypeDesc;

  /// No description provided for @goal.
  ///
  /// In en, this message translates to:
  /// **'Goal'**
  String get goal;

  /// No description provided for @goalDesc.
  ///
  /// In en, this message translates to:
  /// **'We tune calories and protein for this.'**
  String get goalDesc;

  /// No description provided for @bodyFocusOptional.
  ///
  /// In en, this message translates to:
  /// **'Body focus (optional)'**
  String get bodyFocusOptional;

  /// No description provided for @bodyFocusDesc.
  ///
  /// In en, this message translates to:
  /// **'Tell the AI coach what you\'re working on. Tap any tag to add it, then add your own.'**
  String get bodyFocusDesc;

  /// No description provided for @overrideTargets.
  ///
  /// In en, this message translates to:
  /// **'Override targets'**
  String get overrideTargets;

  /// No description provided for @overrideDesc.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to use the auto-computed values.'**
  String get overrideDesc;

  /// No description provided for @noProfileYet.
  ///
  /// In en, this message translates to:
  /// **'No profile yet'**
  String get noProfileYet;

  /// No description provided for @finishOnboardingFirst.
  ///
  /// In en, this message translates to:
  /// **'Finish onboarding first — we\'ll build your targets from there.'**
  String get finishOnboardingFirst;

  /// No description provided for @years.
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get years;

  /// No description provided for @onboardingWelcome.
  ///
  /// In en, this message translates to:
  /// **'Log a meal in\none sentence.'**
  String get onboardingWelcome;

  /// No description provided for @onboardingWelcomeSub.
  ///
  /// In en, this message translates to:
  /// **'No searching, no databases. Type what you ate — we handle the math.'**
  String get onboardingWelcomeSub;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @aboutYouTitle.
  ///
  /// In en, this message translates to:
  /// **'A little about you'**
  String get aboutYouTitle;

  /// No description provided for @aboutYouSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We use these to set realistic targets.'**
  String get aboutYouSubtitle;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'YOUR NAME'**
  String get yourName;

  /// No description provided for @howShouldWeGreet.
  ///
  /// In en, this message translates to:
  /// **'How should we greet you?'**
  String get howShouldWeGreet;

  /// No description provided for @ageField.
  ///
  /// In en, this message translates to:
  /// **'AGE'**
  String get ageField;

  /// No description provided for @genderField.
  ///
  /// In en, this message translates to:
  /// **'GENDER'**
  String get genderField;

  /// No description provided for @countryField.
  ///
  /// In en, this message translates to:
  /// **'COUNTRY'**
  String get countryField;

  /// No description provided for @coachSuggests.
  ///
  /// In en, this message translates to:
  /// **'So the coach suggests dal-bhat in Nepal, not chicken Caesar salad.'**
  String get coachSuggests;

  /// No description provided for @pickCountry.
  ///
  /// In en, this message translates to:
  /// **'Pick your country'**
  String get pickCountry;

  /// No description provided for @searchDots.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get searchDots;

  /// No description provided for @dietField.
  ///
  /// In en, this message translates to:
  /// **'DIET'**
  String get dietField;

  /// No description provided for @bodyAndActivity.
  ///
  /// In en, this message translates to:
  /// **'Body & activity'**
  String get bodyAndActivity;

  /// No description provided for @bodyAndActivitySub.
  ///
  /// In en, this message translates to:
  /// **'Used for BMR + calorie burn estimates.'**
  String get bodyAndActivitySub;

  /// No description provided for @heightField.
  ///
  /// In en, this message translates to:
  /// **'HEIGHT'**
  String get heightField;

  /// No description provided for @weightField.
  ///
  /// In en, this message translates to:
  /// **'WEIGHT'**
  String get weightField;

  /// No description provided for @activityLevel.
  ///
  /// In en, this message translates to:
  /// **'ACTIVITY LEVEL'**
  String get activityLevel;

  /// No description provided for @whatsYourGoal.
  ///
  /// In en, this message translates to:
  /// **'What\'s your goal?'**
  String get whatsYourGoal;

  /// No description provided for @goalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll tune calories and protein for it.'**
  String get goalSubtitle;

  /// No description provided for @workoutTypeField.
  ///
  /// In en, this message translates to:
  /// **'WORKOUT TYPE'**
  String get workoutTypeField;

  /// No description provided for @workoutTypeHelper.
  ///
  /// In en, this message translates to:
  /// **'We\'ll generate a routine that fits your setup.'**
  String get workoutTypeHelper;

  /// No description provided for @strengthTrainingDays.
  ///
  /// In en, this message translates to:
  /// **'STRENGTH TRAINING DAYS / WEEK'**
  String get strengthTrainingDays;

  /// No description provided for @yogaSessions.
  ///
  /// In en, this message translates to:
  /// **'YOGA SESSIONS / WEEK'**
  String get yogaSessions;

  /// No description provided for @homeWorkoutDays.
  ///
  /// In en, this message translates to:
  /// **'HOME WORKOUT DAYS / WEEK'**
  String get homeWorkoutDays;

  /// No description provided for @gymDaysDesc.
  ///
  /// In en, this message translates to:
  /// **'Lifting, calisthenics, gym sessions.'**
  String get gymDaysDesc;

  /// No description provided for @yogaDaysDesc.
  ///
  /// In en, this message translates to:
  /// **'How many days per week you practice yoga.'**
  String get yogaDaysDesc;

  /// No description provided for @homeDaysDesc.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight, resistance band or dumbbell sessions.'**
  String get homeDaysDesc;

  /// No description provided for @gymExperience.
  ///
  /// In en, this message translates to:
  /// **'GYM EXPERIENCE'**
  String get gymExperience;

  /// No description provided for @gymExperienceHelper.
  ///
  /// In en, this message translates to:
  /// **'Affects how aggressively we tune calories.'**
  String get gymExperienceHelper;

  /// No description provided for @newToLifting.
  ///
  /// In en, this message translates to:
  /// **'New to lifting'**
  String get newToLifting;

  /// No description provided for @justStarted.
  ///
  /// In en, this message translates to:
  /// **'Just started'**
  String get justStarted;

  /// No description provided for @newbieGains.
  ///
  /// In en, this message translates to:
  /// **'Newbie gains'**
  String get newbieGains;

  /// No description provided for @intermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get intermediate;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @gymMinutes.
  ///
  /// In en, this message translates to:
  /// **'GYM MINUTES / SESSION'**
  String get gymMinutes;

  /// No description provided for @gymMinutesHelper.
  ///
  /// In en, this message translates to:
  /// **'Time you actually train (warm-up included).'**
  String get gymMinutesHelper;

  /// No description provided for @walkingKmDay.
  ///
  /// In en, this message translates to:
  /// **'WALKING KM / DAY'**
  String get walkingKmDay;

  /// No description provided for @walkingHelper.
  ///
  /// In en, this message translates to:
  /// **'Average walking on a typical day — steps, errands, commute.'**
  String get walkingHelper;

  /// No description provided for @runningKmDay.
  ///
  /// In en, this message translates to:
  /// **'RUNNING KM / DAY'**
  String get runningKmDay;

  /// No description provided for @runningHelper.
  ///
  /// In en, this message translates to:
  /// **'Average per day. Not sure which days you run? Leave 0 and log it from the home page on the days you actually run — you\'ll earn extra calories that day.'**
  String get runningHelper;

  /// No description provided for @bodyFocusField.
  ///
  /// In en, this message translates to:
  /// **'BODY FOCUS (OPTIONAL)'**
  String get bodyFocusField;

  /// No description provided for @bodyFocusHelper.
  ///
  /// In en, this message translates to:
  /// **'Tap any that apply. We use this to fine-tune calories + protein, and the AI coach will personalise suggestions.'**
  String get bodyFocusHelper;

  /// No description provided for @addAnythingElse.
  ///
  /// In en, this message translates to:
  /// **'Add anything else (optional)…'**
  String get addAnythingElse;

  /// No description provided for @recompMaySuit.
  ///
  /// In en, this message translates to:
  /// **'Recomp may suit you better.'**
  String get recompMaySuit;

  /// No description provided for @recompHintBody.
  ///
  /// In en, this message translates to:
  /// **'You picked Build muscle but flagged belly fat. A slight deficit + high protein lets you build muscle while losing fat.'**
  String get recompHintBody;

  /// No description provided for @switchToRecomp.
  ///
  /// In en, this message translates to:
  /// **'Switch to Recomp →'**
  String get switchToRecomp;

  /// No description provided for @dailyRhythm.
  ///
  /// In en, this message translates to:
  /// **'Daily rhythm'**
  String get dailyRhythm;

  /// No description provided for @dailyRhythmSub.
  ///
  /// In en, this message translates to:
  /// **'Used to time water reminders and adjust your hydration target.'**
  String get dailyRhythmSub;

  /// No description provided for @wakeAndSleep.
  ///
  /// In en, this message translates to:
  /// **'WAKE & SLEEP'**
  String get wakeAndSleep;

  /// No description provided for @wake.
  ///
  /// In en, this message translates to:
  /// **'Wake'**
  String get wake;

  /// No description provided for @sleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get sleep;

  /// No description provided for @differentTimeEachDay.
  ///
  /// In en, this message translates to:
  /// **'Different time each day?'**
  String get differentTimeEachDay;

  /// No description provided for @perDaySchedule.
  ///
  /// In en, this message translates to:
  /// **'Per-day schedule — set wake & sleep for each day'**
  String get perDaySchedule;

  /// No description provided for @supplementsField.
  ///
  /// In en, this message translates to:
  /// **'SUPPLEMENTS'**
  String get supplementsField;

  /// No description provided for @iDont.
  ///
  /// In en, this message translates to:
  /// **'I don\'t'**
  String get iDont;

  /// No description provided for @skipIDont.
  ///
  /// In en, this message translates to:
  /// **'Skip — I don\'t'**
  String get skipIDont;

  /// No description provided for @creatineNeedsWater.
  ///
  /// In en, this message translates to:
  /// **'Creatine especially needs more water. Skip if you don\'t take anything.'**
  String get creatineNeedsWater;

  /// No description provided for @iTakeSome.
  ///
  /// In en, this message translates to:
  /// **'I take some — add details'**
  String get iTakeSome;

  /// No description provided for @creatineGD.
  ///
  /// In en, this message translates to:
  /// **'CREATINE (G/DAY)'**
  String get creatineGD;

  /// No description provided for @proteinScoops.
  ///
  /// In en, this message translates to:
  /// **'PROTEIN SCOOPS'**
  String get proteinScoops;

  /// No description provided for @proteinGrams.
  ///
  /// In en, this message translates to:
  /// **'PROTEIN GRAMS'**
  String get proteinGrams;

  /// No description provided for @perDay.
  ///
  /// In en, this message translates to:
  /// **'per day'**
  String get perDay;

  /// No description provided for @multivitamin.
  ///
  /// In en, this message translates to:
  /// **'Multivitamin'**
  String get multivitamin;

  /// No description provided for @otherOptional.
  ///
  /// In en, this message translates to:
  /// **'OTHER (OPTIONAL)'**
  String get otherOptional;

  /// No description provided for @otherSupplementsHint.
  ///
  /// In en, this message translates to:
  /// **'Pre-workout, omega-3, vitamin D…'**
  String get otherSupplementsHint;

  /// No description provided for @restDaysField.
  ///
  /// In en, this message translates to:
  /// **'REST DAYS'**
  String get restDaysField;

  /// No description provided for @restDaysHelper.
  ///
  /// In en, this message translates to:
  /// **'Days you don\'t train. We\'ll show a lower calorie target for these days.'**
  String get restDaysHelper;

  /// No description provided for @weighInCadence.
  ///
  /// In en, this message translates to:
  /// **'WEIGH-IN CADENCE'**
  String get weighInCadence;

  /// No description provided for @weighInHelper.
  ///
  /// In en, this message translates to:
  /// **'After 2 weeks of weigh-ins, the adaptive coach takes over and stops being a guess.'**
  String get weighInHelper;

  /// No description provided for @bodyFatOptional.
  ///
  /// In en, this message translates to:
  /// **'BODY FAT % (OPTIONAL)'**
  String get bodyFatOptional;

  /// No description provided for @bodyFatHelper.
  ///
  /// In en, this message translates to:
  /// **'If you know it, we use Katch-McArdle (more accurate for lean/muscular bodies).'**
  String get bodyFatHelper;

  /// No description provided for @healthContextOptional.
  ///
  /// In en, this message translates to:
  /// **'HEALTH CONTEXT (OPTIONAL)'**
  String get healthContextOptional;

  /// No description provided for @healthContextHelper.
  ///
  /// In en, this message translates to:
  /// **'Helps tune calories. Sensitive cases will trigger a \"see a pro\" note.'**
  String get healthContextHelper;

  /// No description provided for @yourDailyTargets.
  ///
  /// In en, this message translates to:
  /// **'Your daily targets'**
  String get yourDailyTargets;

  /// No description provided for @editLater.
  ///
  /// In en, this message translates to:
  /// **'You can edit any of these later in Settings.'**
  String get editLater;

  /// No description provided for @caloriesLabel.
  ///
  /// In en, this message translates to:
  /// **'CALORIES'**
  String get caloriesLabel;

  /// No description provided for @floorsSafety.
  ///
  /// In en, this message translates to:
  /// **'Floors and pacing limits are applied so targets stay safe.'**
  String get floorsSafety;

  /// No description provided for @coachSays.
  ///
  /// In en, this message translates to:
  /// **'COACH SAYS'**
  String get coachSays;

  /// No description provided for @askingCoach.
  ///
  /// In en, this message translates to:
  /// **'Asking the coach…'**
  String get askingCoach;

  /// No description provided for @couldntReachCoach.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the coach. Tap to retry.'**
  String get couldntReachCoach;

  /// No description provided for @getCoachTake.
  ///
  /// In en, this message translates to:
  /// **'Get a coach\'s take on these numbers'**
  String get getCoachTake;

  /// No description provided for @coachSecondOpinion.
  ///
  /// In en, this message translates to:
  /// **'A short, personalized second opinion based on your inputs.'**
  String get coachSecondOpinion;

  /// No description provided for @talkToProfessional.
  ///
  /// In en, this message translates to:
  /// **'Talk to a professional'**
  String get talkToProfessional;

  /// No description provided for @proConsultBody.
  ///
  /// In en, this message translates to:
  /// **'These numbers are generic and may not be safe for your situation ({conditions}). Confirm calorie + macro targets with a doctor or registered dietitian before relying on them.'**
  String proConsultBody(Object conditions);

  /// No description provided for @restDayHint.
  ///
  /// In en, this message translates to:
  /// **'On rest days ({days}): aim for ~{restKcal} kcal ({delta} vs training).'**
  String restDayHint(Object days, Object delta, Object restKcal);

  /// No description provided for @am.
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get am;

  /// No description provided for @pm.
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get pm;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @areYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get areYouSure;

  /// No description provided for @thisCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone'**
  String get thisCannotBeUndone;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export data'**
  String get exportData;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import data'**
  String get importData;

  /// No description provided for @backupData.
  ///
  /// In en, this message translates to:
  /// **'Backup data'**
  String get backupData;

  /// No description provided for @restoreData.
  ///
  /// In en, this message translates to:
  /// **'Restore data'**
  String get restoreData;

  /// No description provided for @dataExported.
  ///
  /// In en, this message translates to:
  /// **'Data exported successfully'**
  String get dataExported;

  /// No description provided for @dataImported.
  ///
  /// In en, this message translates to:
  /// **'Data imported successfully'**
  String get dataImported;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get darkMode;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light mode'**
  String get lightMode;

  /// No description provided for @systemMode.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemMode;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @enableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Enable notifications'**
  String get enableNotifications;

  /// No description provided for @disableNotifications.
  ///
  /// In en, this message translates to:
  /// **'Disable notifications'**
  String get disableNotifications;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get termsOfService;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @buildNumber.
  ///
  /// In en, this message translates to:
  /// **'Build number'**
  String get buildNumber;

  /// No description provided for @rateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate app'**
  String get rateApp;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share app'**
  String get shareApp;

  /// No description provided for @inviteFriends.
  ///
  /// In en, this message translates to:
  /// **'Invite friends'**
  String get inviteFriends;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @dailyReport.
  ///
  /// In en, this message translates to:
  /// **'Daily Report'**
  String get dailyReport;

  /// No description provided for @dailyReportDesc.
  ///
  /// In en, this message translates to:
  /// **'See food + workout rings and AI summary for any day'**
  String get dailyReportDesc;

  /// No description provided for @streak.
  ///
  /// In en, this message translates to:
  /// **'STREAK'**
  String get streak;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get day;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get days;

  /// No description provided for @badges.
  ///
  /// In en, this message translates to:
  /// **'BADGES'**
  String get badges;

  /// No description provided for @weightField2.
  ///
  /// In en, this message translates to:
  /// **'WEIGHT'**
  String get weightField2;

  /// No description provided for @logBtn.
  ///
  /// In en, this message translates to:
  /// **'Log'**
  String get logBtn;

  /// No description provided for @current.
  ///
  /// In en, this message translates to:
  /// **'CURRENT'**
  String get current;

  /// No description provided for @sevenDayAvg.
  ///
  /// In en, this message translates to:
  /// **'7-DAY AVG'**
  String get sevenDayAvg;

  /// No description provided for @sinceFirstLog.
  ///
  /// In en, this message translates to:
  /// **'{delta} kg since first log'**
  String sinceFirstLog(Object delta);

  /// No description provided for @logFirstMeasurement.
  ///
  /// In en, this message translates to:
  /// **'Log your first measurement to see the trend.'**
  String get logFirstMeasurement;

  /// No description provided for @addOneMore.
  ///
  /// In en, this message translates to:
  /// **'Add one more measurement to see a trend.'**
  String get addOneMore;

  /// No description provided for @caloriesLast14.
  ///
  /// In en, this message translates to:
  /// **'CALORIES · LAST 14 DAYS'**
  String get caloriesLast14;

  /// No description provided for @dailyAvg.
  ///
  /// In en, this message translates to:
  /// **'DAILY AVG'**
  String get dailyAvg;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'TARGET'**
  String get target;

  /// No description provided for @strength.
  ///
  /// In en, this message translates to:
  /// **'STRENGTH'**
  String get strength;

  /// No description provided for @logWorkoutStrength.
  ///
  /// In en, this message translates to:
  /// **'Log a workout to see strength progression.'**
  String get logWorkoutStrength;

  /// No description provided for @strengthEst1RM.
  ///
  /// In en, this message translates to:
  /// **'STRENGTH · EST. 1RM'**
  String get strengthEst1RM;

  /// No description provided for @logExerciseMore.
  ///
  /// In en, this message translates to:
  /// **'Log this exercise more than once to see progression.'**
  String get logExerciseMore;

  /// No description provided for @progressPhotos.
  ///
  /// In en, this message translates to:
  /// **'PROGRESS PHOTOS'**
  String get progressPhotos;

  /// No description provided for @progressPhotosDesc.
  ///
  /// In en, this message translates to:
  /// **'Attach a photo when you log a measurement. Stays on device.'**
  String get progressPhotosDesc;

  /// No description provided for @onDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'On device only'**
  String get onDeviceOnly;

  /// No description provided for @coach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get coach;

  /// No description provided for @aiCoach.
  ///
  /// In en, this message translates to:
  /// **'AI Coach'**
  String get aiCoach;

  /// No description provided for @askCoach.
  ///
  /// In en, this message translates to:
  /// **'Ask your coach'**
  String get askCoach;

  /// No description provided for @coachThinking.
  ///
  /// In en, this message translates to:
  /// **'Coach is thinking...'**
  String get coachThinking;

  /// No description provided for @coachError.
  ///
  /// In en, this message translates to:
  /// **'Coach couldn\'t respond, try again'**
  String get coachError;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @startConversation.
  ///
  /// In en, this message translates to:
  /// **'Start a conversation with your AI coach'**
  String get startConversation;

  /// No description provided for @suggestion1.
  ///
  /// In en, this message translates to:
  /// **'Suggest a workout for today'**
  String get suggestion1;

  /// No description provided for @suggestion2.
  ///
  /// In en, this message translates to:
  /// **'How can I improve my form?'**
  String get suggestion2;

  /// No description provided for @suggestion3.
  ///
  /// In en, this message translates to:
  /// **'What should I eat post-workout?'**
  String get suggestion3;

  /// No description provided for @suggestion4.
  ///
  /// In en, this message translates to:
  /// **'Help me plan my weekly routine'**
  String get suggestion4;

  /// No description provided for @suggestion5.
  ///
  /// In en, this message translates to:
  /// **'Give me a stretching routine'**
  String get suggestion5;

  /// No description provided for @logWater.
  ///
  /// In en, this message translates to:
  /// **'Log water'**
  String get logWater;

  /// No description provided for @stayHydrated.
  ///
  /// In en, this message translates to:
  /// **'Stay hydrated!'**
  String get stayHydrated;

  /// No description provided for @noWaterLogged.
  ///
  /// In en, this message translates to:
  /// **'No water logged today'**
  String get noWaterLogged;

  /// No description provided for @waterIntake.
  ///
  /// In en, this message translates to:
  /// **'Water intake'**
  String get waterIntake;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'days ago'**
  String get daysAgo;

  /// No description provided for @noDataYet.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get noDataYet;

  /// No description provided for @tapToSeeHistory.
  ///
  /// In en, this message translates to:
  /// **'Tap to see history'**
  String get tapToSeeHistory;

  /// No description provided for @weeklyOverview.
  ///
  /// In en, this message translates to:
  /// **'Weekly overview'**
  String get weeklyOverview;

  /// No description provided for @noWorkoutsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'No workouts this week'**
  String get noWorkoutsThisWeek;

  /// No description provided for @startAWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start a workout to see stats here'**
  String get startAWorkout;

  /// No description provided for @noExercisesYet.
  ///
  /// In en, this message translates to:
  /// **'No exercises yet'**
  String get noExercisesYet;

  /// No description provided for @tapToExplore.
  ///
  /// In en, this message translates to:
  /// **'Tap to explore'**
  String get tapToExplore;

  /// No description provided for @noProgressData.
  ///
  /// In en, this message translates to:
  /// **'No progress data'**
  String get noProgressData;

  /// No description provided for @startWorkingOut.
  ///
  /// In en, this message translates to:
  /// **'Start working out to track progress'**
  String get startWorkingOut;

  /// No description provided for @heroGreeting1.
  ///
  /// In en, this message translates to:
  /// **'Ready to crush it today?'**
  String get heroGreeting1;

  /// No description provided for @heroGreeting2.
  ///
  /// In en, this message translates to:
  /// **'Let\'s make today count!'**
  String get heroGreeting2;

  /// No description provided for @heroGreeting3.
  ///
  /// In en, this message translates to:
  /// **'Time to level up!'**
  String get heroGreeting3;

  /// No description provided for @heroGreeting4.
  ///
  /// In en, this message translates to:
  /// **'Your goals are waiting!'**
  String get heroGreeting4;

  /// No description provided for @heroGreeting5.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get after it!'**
  String get heroGreeting5;

  /// No description provided for @heroGreeting6.
  ///
  /// In en, this message translates to:
  /// **'Today is your day!'**
  String get heroGreeting6;

  /// No description provided for @heroGreeting7.
  ///
  /// In en, this message translates to:
  /// **'Time to shine!'**
  String get heroGreeting7;

  /// No description provided for @heroGreeting8.
  ///
  /// In en, this message translates to:
  /// **'Let\'s build something great!'**
  String get heroGreeting8;

  /// No description provided for @heroGreeting9.
  ///
  /// In en, this message translates to:
  /// **'Your journey continues!'**
  String get heroGreeting9;

  /// No description provided for @heroGreeting10.
  ///
  /// In en, this message translates to:
  /// **'Stay consistent!'**
  String get heroGreeting10;

  /// No description provided for @badgeEarned.
  ///
  /// In en, this message translates to:
  /// **'Badge earned!'**
  String get badgeEarned;

  /// No description provided for @firstWorkout.
  ///
  /// In en, this message translates to:
  /// **'First workout completed'**
  String get firstWorkout;

  /// No description provided for @firstWorkoutDesc.
  ///
  /// In en, this message translates to:
  /// **'You completed your first workout'**
  String get firstWorkoutDesc;

  /// No description provided for @weekStreak.
  ///
  /// In en, this message translates to:
  /// **'7-day streak'**
  String get weekStreak;

  /// No description provided for @weekStreakDesc.
  ///
  /// In en, this message translates to:
  /// **'Worked out 7 days in a row'**
  String get weekStreakDesc;

  /// No description provided for @monthStreak.
  ///
  /// In en, this message translates to:
  /// **'30-day streak'**
  String get monthStreak;

  /// No description provided for @monthStreakDesc.
  ///
  /// In en, this message translates to:
  /// **'Worked out 30 days in a row'**
  String get monthStreakDesc;

  /// No description provided for @centuryClub.
  ///
  /// In en, this message translates to:
  /// **'Century club'**
  String get centuryClub;

  /// No description provided for @centuryClubDesc.
  ///
  /// In en, this message translates to:
  /// **'Completed 100 workouts'**
  String get centuryClubDesc;

  /// No description provided for @volumeKing.
  ///
  /// In en, this message translates to:
  /// **'Volume king'**
  String get volumeKing;

  /// No description provided for @volumeKingDesc.
  ///
  /// In en, this message translates to:
  /// **'Logged 100,000 kg total volume'**
  String get volumeKingDesc;

  /// No description provided for @earlyBird.
  ///
  /// In en, this message translates to:
  /// **'Early bird'**
  String get earlyBird;

  /// No description provided for @earlyBirdDesc.
  ///
  /// In en, this message translates to:
  /// **'Completed 10 workouts before 7 AM'**
  String get earlyBirdDesc;

  /// No description provided for @nightOwl.
  ///
  /// In en, this message translates to:
  /// **'Night owl'**
  String get nightOwl;

  /// No description provided for @nightOwlDesc.
  ///
  /// In en, this message translates to:
  /// **'Completed 10 workouts after 9 PM'**
  String get nightOwlDesc;

  /// No description provided for @marathonRunner.
  ///
  /// In en, this message translates to:
  /// **'Marathon runner'**
  String get marathonRunner;

  /// No description provided for @marathonRunnerDesc.
  ///
  /// In en, this message translates to:
  /// **'Ran a total of 42.2 km'**
  String get marathonRunnerDesc;

  /// No description provided for @flexibilityMaster.
  ///
  /// In en, this message translates to:
  /// **'Flexibility master'**
  String get flexibilityMaster;

  /// No description provided for @flexibilityMasterDesc.
  ///
  /// In en, this message translates to:
  /// **'Completed 50 stretching sessions'**
  String get flexibilityMasterDesc;

  /// No description provided for @nutritionPro.
  ///
  /// In en, this message translates to:
  /// **'Nutrition pro'**
  String get nutritionPro;

  /// No description provided for @nutritionProDesc.
  ///
  /// In en, this message translates to:
  /// **'Logged meals for 30 consecutive days'**
  String get nutritionProDesc;

  /// No description provided for @hydrationHero.
  ///
  /// In en, this message translates to:
  /// **'Hydration hero'**
  String get hydrationHero;

  /// No description provided for @hydrationHeroDesc.
  ///
  /// In en, this message translates to:
  /// **'Hit water goal for 30 days straight'**
  String get hydrationHeroDesc;

  /// No description provided for @progressionTip1.
  ///
  /// In en, this message translates to:
  /// **'Try adding 2.5 kg to your next session'**
  String get progressionTip1;

  /// No description provided for @progressionTip2.
  ///
  /// In en, this message translates to:
  /// **'Consider adding an extra set this week'**
  String get progressionTip2;

  /// No description provided for @progressionTip3.
  ///
  /// In en, this message translates to:
  /// **'Try reducing rest periods by 15 seconds'**
  String get progressionTip3;

  /// No description provided for @progressionTip4.
  ///
  /// In en, this message translates to:
  /// **'Focus on controlled eccentric this week'**
  String get progressionTip4;

  /// No description provided for @progressionTip5.
  ///
  /// In en, this message translates to:
  /// **'Try a pause rep to build strength'**
  String get progressionTip5;

  /// No description provided for @progressionTip6.
  ///
  /// In en, this message translates to:
  /// **'Consider a deload if feeling fatigued'**
  String get progressionTip6;

  /// No description provided for @progressionTip7.
  ///
  /// In en, this message translates to:
  /// **'Try a different grip or stance variation'**
  String get progressionTip7;

  /// No description provided for @progressionTip8.
  ///
  /// In en, this message translates to:
  /// **'Focus on mind-muscle connection'**
  String get progressionTip8;

  /// No description provided for @progressionTip9.
  ///
  /// In en, this message translates to:
  /// **'Try increasing reps before adding weight'**
  String get progressionTip9;

  /// No description provided for @progressionTip10.
  ///
  /// In en, this message translates to:
  /// **'Consider progressive overload with tempo'**
  String get progressionTip10;

  /// No description provided for @nudgeFact1.
  ///
  /// In en, this message translates to:
  /// **'Muscles grow during rest, not during workouts'**
  String get nudgeFact1;

  /// No description provided for @nudgeFact2.
  ///
  /// In en, this message translates to:
  /// **'Sleep is the most anabolic hormone'**
  String get nudgeFact2;

  /// No description provided for @nudgeFact3.
  ///
  /// In en, this message translates to:
  /// **'Protein synthesis peaks 24–48 hours post-workout'**
  String get nudgeFact3;

  /// No description provided for @nudgeFact4.
  ///
  /// In en, this message translates to:
  /// **'Consistency beats intensity every time'**
  String get nudgeFact4;

  /// No description provided for @nudgeFact5.
  ///
  /// In en, this message translates to:
  /// **'Progressive overload is the key to growth'**
  String get nudgeFact5;

  /// No description provided for @nudgeFact6.
  ///
  /// In en, this message translates to:
  /// **'Nutrition is 80% of your results'**
  String get nudgeFact6;

  /// No description provided for @nudgeFact7.
  ///
  /// In en, this message translates to:
  /// **'Water intake affects performance significantly'**
  String get nudgeFact7;

  /// No description provided for @nudgeFact8.
  ///
  /// In en, this message translates to:
  /// **'Recovery is just as important as training'**
  String get nudgeFact8;

  /// No description provided for @nudgeFact9.
  ///
  /// In en, this message translates to:
  /// **'Compound movements give the most bang for your buck'**
  String get nudgeFact9;

  /// No description provided for @nudgeFact10.
  ///
  /// In en, this message translates to:
  /// **'Tracking progress helps maintain motivation'**
  String get nudgeFact10;

  /// No description provided for @routinePushPullLegs.
  ///
  /// In en, this message translates to:
  /// **'Push / Pull / Legs'**
  String get routinePushPullLegs;

  /// No description provided for @routineUpperLower.
  ///
  /// In en, this message translates to:
  /// **'Upper / Lower'**
  String get routineUpperLower;

  /// No description provided for @routineFullBody.
  ///
  /// In en, this message translates to:
  /// **'Full Body'**
  String get routineFullBody;

  /// No description provided for @routineBroSplit.
  ///
  /// In en, this message translates to:
  /// **'Bro Split'**
  String get routineBroSplit;

  /// No description provided for @routinePPLDesc.
  ///
  /// In en, this message translates to:
  /// **'6-day push/pull/legs split'**
  String get routinePPLDesc;

  /// No description provided for @routineUpperLowerDesc.
  ///
  /// In en, this message translates to:
  /// **'4-day upper/lower split'**
  String get routineUpperLowerDesc;

  /// No description provided for @routineFullBodyDesc.
  ///
  /// In en, this message translates to:
  /// **'3-day full body routine'**
  String get routineFullBodyDesc;

  /// No description provided for @routineBroSplitDesc.
  ///
  /// In en, this message translates to:
  /// **'5-day body part split'**
  String get routineBroSplitDesc;

  /// No description provided for @routinePush.
  ///
  /// In en, this message translates to:
  /// **'Push Day'**
  String get routinePush;

  /// No description provided for @routinePull.
  ///
  /// In en, this message translates to:
  /// **'Pull Day'**
  String get routinePull;

  /// No description provided for @routineLegs.
  ///
  /// In en, this message translates to:
  /// **'Leg Day'**
  String get routineLegs;

  /// No description provided for @routineUpper.
  ///
  /// In en, this message translates to:
  /// **'Upper Body'**
  String get routineUpper;

  /// No description provided for @routineLower.
  ///
  /// In en, this message translates to:
  /// **'Lower Body'**
  String get routineLower;

  /// No description provided for @routineChestBack.
  ///
  /// In en, this message translates to:
  /// **'Chest & Back'**
  String get routineChestBack;

  /// No description provided for @routineShouldersArms.
  ///
  /// In en, this message translates to:
  /// **'Shoulders & Arms'**
  String get routineShouldersArms;

  /// No description provided for @routineLegsGlutes.
  ///
  /// In en, this message translates to:
  /// **'Legs & Glutes'**
  String get routineLegsGlutes;

  /// No description provided for @notificationWorkoutReminder.
  ///
  /// In en, this message translates to:
  /// **'Time to work out!'**
  String get notificationWorkoutReminder;

  /// No description provided for @notificationWaterReminder.
  ///
  /// In en, this message translates to:
  /// **'Stay hydrated! Drink some water'**
  String get notificationWaterReminder;

  /// No description provided for @notificationMealReminder.
  ///
  /// In en, this message translates to:
  /// **'Don\'t forget to log your meal'**
  String get notificationMealReminder;

  /// No description provided for @notificationRestReminder.
  ///
  /// In en, this message translates to:
  /// **'Rest day — recovery matters!'**
  String get notificationRestReminder;

  /// No description provided for @notificationStreakReminder.
  ///
  /// In en, this message translates to:
  /// **'Keep your streak going!'**
  String get notificationStreakReminder;

  /// No description provided for @notificationWeeklyReport.
  ///
  /// In en, this message translates to:
  /// **'Your weekly report is ready'**
  String get notificationWeeklyReport;

  /// No description provided for @notificationMotivation.
  ///
  /// In en, this message translates to:
  /// **'You\'re doing great! Keep it up!'**
  String get notificationMotivation;

  /// No description provided for @authErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get authErrorInvalidEmail;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'This email is already registered'**
  String get authErrorEmailInUse;

  /// No description provided for @authErrorUserNotFound.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email'**
  String get authErrorUserNotFound;

  /// No description provided for @authErrorWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password'**
  String get authErrorWrongPassword;

  /// No description provided for @authErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please try again later'**
  String get authErrorTooManyRequests;

  /// No description provided for @authErrorNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection'**
  String get authErrorNetworkError;

  /// No description provided for @authErrorAccountDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled'**
  String get authErrorAccountDisabled;

  /// No description provided for @authErrorInvalidCredential.
  ///
  /// In en, this message translates to:
  /// **'Invalid credentials'**
  String get authErrorInvalidCredential;

  /// No description provided for @authErrorOperationNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This sign-in method is not enabled'**
  String get authErrorOperationNotAllowed;

  /// No description provided for @bodyFocusChest.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get bodyFocusChest;

  /// No description provided for @bodyFocusBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get bodyFocusBack;

  /// No description provided for @bodyFocusShoulders.
  ///
  /// In en, this message translates to:
  /// **'Shoulders'**
  String get bodyFocusShoulders;

  /// No description provided for @bodyFocusBiceps.
  ///
  /// In en, this message translates to:
  /// **'Biceps'**
  String get bodyFocusBiceps;

  /// No description provided for @bodyFocusTriceps.
  ///
  /// In en, this message translates to:
  /// **'Triceps'**
  String get bodyFocusTriceps;

  /// No description provided for @bodyFocusAbs.
  ///
  /// In en, this message translates to:
  /// **'Abs'**
  String get bodyFocusAbs;

  /// No description provided for @bodyFocusQuads.
  ///
  /// In en, this message translates to:
  /// **'Quads'**
  String get bodyFocusQuads;

  /// No description provided for @bodyFocusHamstrings.
  ///
  /// In en, this message translates to:
  /// **'Hamstrings'**
  String get bodyFocusHamstrings;

  /// No description provided for @bodyFocusGlutes.
  ///
  /// In en, this message translates to:
  /// **'Glutes'**
  String get bodyFocusGlutes;

  /// No description provided for @bodyFocusCalves.
  ///
  /// In en, this message translates to:
  /// **'Calves'**
  String get bodyFocusCalves;

  /// No description provided for @bodyFocusForearms.
  ///
  /// In en, this message translates to:
  /// **'Forearms'**
  String get bodyFocusForearms;

  /// No description provided for @bodyFocusFullBody.
  ///
  /// In en, this message translates to:
  /// **'Full Body'**
  String get bodyFocusFullBody;

  /// No description provided for @kmInputLabel.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get kmInputLabel;

  /// No description provided for @workoutHistory.
  ///
  /// In en, this message translates to:
  /// **'Workout history'**
  String get workoutHistory;

  /// No description provided for @startWorkout.
  ///
  /// In en, this message translates to:
  /// **'Start workout'**
  String get startWorkout;

  /// No description provided for @createWorkout.
  ///
  /// In en, this message translates to:
  /// **'Create workout'**
  String get createWorkout;

  /// No description provided for @editWorkout.
  ///
  /// In en, this message translates to:
  /// **'Edit workout'**
  String get editWorkout;

  /// No description provided for @deleteWorkout.
  ///
  /// In en, this message translates to:
  /// **'Delete workout'**
  String get deleteWorkout;

  /// No description provided for @workoutSummary.
  ///
  /// In en, this message translates to:
  /// **'Workout summary'**
  String get workoutSummary;

  /// No description provided for @totalTime.
  ///
  /// In en, this message translates to:
  /// **'Total time'**
  String get totalTime;

  /// No description provided for @totalVolume.
  ///
  /// In en, this message translates to:
  /// **'Total volume'**
  String get totalVolume;

  /// No description provided for @personalBests.
  ///
  /// In en, this message translates to:
  /// **'Personal bests'**
  String get personalBests;

  /// No description provided for @noPersonalBests.
  ///
  /// In en, this message translates to:
  /// **'No personal bests yet'**
  String get noPersonalBests;

  /// No description provided for @keepTrainingForPBs.
  ///
  /// In en, this message translates to:
  /// **'Keep training to set personal bests!'**
  String get keepTrainingForPBs;

  /// No description provided for @estimatedOneRM.
  ///
  /// In en, this message translates to:
  /// **'Estimated 1RM'**
  String get estimatedOneRM;

  /// No description provided for @restTimer.
  ///
  /// In en, this message translates to:
  /// **'Rest timer'**
  String get restTimer;

  /// No description provided for @restTime.
  ///
  /// In en, this message translates to:
  /// **'Rest time'**
  String get restTime;

  /// No description provided for @startRest.
  ///
  /// In en, this message translates to:
  /// **'Start rest'**
  String get startRest;

  /// No description provided for @skipRest.
  ///
  /// In en, this message translates to:
  /// **'Skip rest'**
  String get skipRest;

  /// No description provided for @restComplete.
  ///
  /// In en, this message translates to:
  /// **'Rest complete!'**
  String get restComplete;

  /// No description provided for @logSet.
  ///
  /// In en, this message translates to:
  /// **'Log set'**
  String get logSet;

  /// No description provided for @completeWorkout.
  ///
  /// In en, this message translates to:
  /// **'Complete workout'**
  String get completeWorkout;

  /// No description provided for @cancelWorkout.
  ///
  /// In en, this message translates to:
  /// **'Cancel workout'**
  String get cancelWorkout;

  /// No description provided for @discardWorkout.
  ///
  /// In en, this message translates to:
  /// **'Discard workout'**
  String get discardWorkout;

  /// No description provided for @workoutComplete.
  ///
  /// In en, this message translates to:
  /// **'Workout complete!'**
  String get workoutComplete;

  /// No description provided for @greatJob.
  ///
  /// In en, this message translates to:
  /// **'Great job!'**
  String get greatJob;

  /// No description provided for @workoutSaved.
  ///
  /// In en, this message translates to:
  /// **'Workout saved'**
  String get workoutSaved;

  /// No description provided for @addExercise.
  ///
  /// In en, this message translates to:
  /// **'Add exercise'**
  String get addExercise;

  /// No description provided for @removeExercise.
  ///
  /// In en, this message translates to:
  /// **'Remove exercise'**
  String get removeExercise;

  /// No description provided for @exerciseNotes.
  ///
  /// In en, this message translates to:
  /// **'Exercise notes'**
  String get exerciseNotes;

  /// No description provided for @warmUp.
  ///
  /// In en, this message translates to:
  /// **'Warm up'**
  String get warmUp;

  /// No description provided for @dropSet.
  ///
  /// In en, this message translates to:
  /// **'Drop set'**
  String get dropSet;

  /// No description provided for @failure.
  ///
  /// In en, this message translates to:
  /// **'Failure'**
  String get failure;

  /// No description provided for @superSet.
  ///
  /// In en, this message translates to:
  /// **'Superset'**
  String get superSet;

  /// No description provided for @giantSet.
  ///
  /// In en, this message translates to:
  /// **'Giant set'**
  String get giantSet;

  /// No description provided for @timer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timer;

  /// No description provided for @stopwatch.
  ///
  /// In en, this message translates to:
  /// **'Stopwatch'**
  String get stopwatch;

  /// No description provided for @countdown.
  ///
  /// In en, this message translates to:
  /// **'Countdown'**
  String get countdown;

  /// No description provided for @elapsed.
  ///
  /// In en, this message translates to:
  /// **'Elapsed'**
  String get elapsed;

  /// No description provided for @remainingTime.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remainingTime;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @lap.
  ///
  /// In en, this message translates to:
  /// **'Lap'**
  String get lap;

  /// No description provided for @exerciseSearch.
  ///
  /// In en, this message translates to:
  /// **'Search exercises'**
  String get exerciseSearch;

  /// No description provided for @muscleGroup.
  ///
  /// In en, this message translates to:
  /// **'Muscle group'**
  String get muscleGroup;

  /// No description provided for @allMuscles.
  ///
  /// In en, this message translates to:
  /// **'All muscles'**
  String get allMuscles;

  /// No description provided for @equipment.
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get equipment;

  /// No description provided for @allEquipment.
  ///
  /// In en, this message translates to:
  /// **'All equipment'**
  String get allEquipment;

  /// No description provided for @noEquipment.
  ///
  /// In en, this message translates to:
  /// **'No equipment'**
  String get noEquipment;

  /// No description provided for @barbell.
  ///
  /// In en, this message translates to:
  /// **'Barbell'**
  String get barbell;

  /// No description provided for @dumbbell.
  ///
  /// In en, this message translates to:
  /// **'Dumbbell'**
  String get dumbbell;

  /// No description provided for @machine.
  ///
  /// In en, this message translates to:
  /// **'Machine'**
  String get machine;

  /// No description provided for @cable.
  ///
  /// In en, this message translates to:
  /// **'Cable'**
  String get cable;

  /// No description provided for @bodyweight.
  ///
  /// In en, this message translates to:
  /// **'Bodyweight'**
  String get bodyweight;

  /// No description provided for @bands.
  ///
  /// In en, this message translates to:
  /// **'Bands'**
  String get bands;

  /// No description provided for @kettlebell.
  ///
  /// In en, this message translates to:
  /// **'Kettlebell'**
  String get kettlebell;

  /// No description provided for @howTo.
  ///
  /// In en, this message translates to:
  /// **'How to'**
  String get howTo;

  /// No description provided for @watchVideo.
  ///
  /// In en, this message translates to:
  /// **'Watch video'**
  String get watchVideo;

  /// No description provided for @viewTutorial.
  ///
  /// In en, this message translates to:
  /// **'View tutorial'**
  String get viewTutorial;

  /// No description provided for @noVideoAvailable.
  ///
  /// In en, this message translates to:
  /// **'No video available'**
  String get noVideoAvailable;

  /// No description provided for @exerciseNotFound.
  ///
  /// In en, this message translates to:
  /// **'Exercise not found'**
  String get exerciseNotFound;

  /// No description provided for @customExercise.
  ///
  /// In en, this message translates to:
  /// **'Custom exercise'**
  String get customExercise;

  /// No description provided for @createExercise.
  ///
  /// In en, this message translates to:
  /// **'Create exercise'**
  String get createExercise;

  /// No description provided for @exerciseHistory.
  ///
  /// In en, this message translates to:
  /// **'Exercise history'**
  String get exerciseHistory;

  /// No description provided for @progressChart.
  ///
  /// In en, this message translates to:
  /// **'Progress chart'**
  String get progressChart;

  /// No description provided for @recentPerformance.
  ///
  /// In en, this message translates to:
  /// **'Recent performance'**
  String get recentPerformance;

  /// No description provided for @bestSet.
  ///
  /// In en, this message translates to:
  /// **'Best set'**
  String get bestSet;

  /// No description provided for @totalSets.
  ///
  /// In en, this message translates to:
  /// **'Total sets'**
  String get totalSets;

  /// No description provided for @noChartData.
  ///
  /// In en, this message translates to:
  /// **'No chart data available'**
  String get noChartData;

  /// No description provided for @selectExercise.
  ///
  /// In en, this message translates to:
  /// **'Select exercise'**
  String get selectExercise;

  /// No description provided for @selectDateRange.
  ///
  /// In en, this message translates to:
  /// **'Select date range'**
  String get selectDateRange;

  /// No description provided for @lastWeek.
  ///
  /// In en, this message translates to:
  /// **'Last week'**
  String get lastWeek;

  /// No description provided for @lastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get lastMonth;

  /// No description provided for @last3Months.
  ///
  /// In en, this message translates to:
  /// **'Last 3 months'**
  String get last3Months;

  /// No description provided for @last6Months.
  ///
  /// In en, this message translates to:
  /// **'Last 6 months'**
  String get last6Months;

  /// No description provided for @lastYear.
  ///
  /// In en, this message translates to:
  /// **'Last year'**
  String get lastYear;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get allTime;

  /// No description provided for @routineBuilder.
  ///
  /// In en, this message translates to:
  /// **'Routine builder'**
  String get routineBuilder;

  /// No description provided for @createRoutine.
  ///
  /// In en, this message translates to:
  /// **'Create routine'**
  String get createRoutine;

  /// No description provided for @editRoutine.
  ///
  /// In en, this message translates to:
  /// **'Edit routine'**
  String get editRoutine;

  /// No description provided for @deleteRoutine.
  ///
  /// In en, this message translates to:
  /// **'Delete routine'**
  String get deleteRoutine;

  /// No description provided for @routineName.
  ///
  /// In en, this message translates to:
  /// **'Routine name'**
  String get routineName;

  /// No description provided for @routineDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get routineDescription;

  /// No description provided for @addDay.
  ///
  /// In en, this message translates to:
  /// **'Add day'**
  String get addDay;

  /// No description provided for @removeDay.
  ///
  /// In en, this message translates to:
  /// **'Remove day'**
  String get removeDay;

  /// No description provided for @routineDay.
  ///
  /// In en, this message translates to:
  /// **'Routine day'**
  String get routineDay;

  /// No description provided for @routineDays.
  ///
  /// In en, this message translates to:
  /// **'Routine days'**
  String get routineDays;

  /// No description provided for @trainingSplit.
  ///
  /// In en, this message translates to:
  /// **'Training split'**
  String get trainingSplit;

  /// No description provided for @saveRoutine.
  ///
  /// In en, this message translates to:
  /// **'Save routine'**
  String get saveRoutine;

  /// No description provided for @routineSaved.
  ///
  /// In en, this message translates to:
  /// **'Routine saved'**
  String get routineSaved;

  /// No description provided for @useRoutine.
  ///
  /// In en, this message translates to:
  /// **'Use routine'**
  String get useRoutine;

  /// No description provided for @applyRoutine.
  ///
  /// In en, this message translates to:
  /// **'Apply routine'**
  String get applyRoutine;

  /// No description provided for @routineApplied.
  ///
  /// In en, this message translates to:
  /// **'Routine applied'**
  String get routineApplied;

  /// No description provided for @bodyWeight.
  ///
  /// In en, this message translates to:
  /// **'Body weight'**
  String get bodyWeight;

  /// No description provided for @overload.
  ///
  /// In en, this message translates to:
  /// **'Overload'**
  String get overload;

  /// No description provided for @lastWorkout.
  ///
  /// In en, this message translates to:
  /// **'Last workout'**
  String get lastWorkout;

  /// No description provided for @noWorkoutsYet.
  ///
  /// In en, this message translates to:
  /// **'No workouts yet'**
  String get noWorkoutsYet;

  /// No description provided for @startTraining.
  ///
  /// In en, this message translates to:
  /// **'Start training!'**
  String get startTraining;

  /// No description provided for @yourWorkoutsWillAppear.
  ///
  /// In en, this message translates to:
  /// **'Your workouts will appear here'**
  String get yourWorkoutsWillAppear;

  /// No description provided for @onboardingProgress.
  ///
  /// In en, this message translates to:
  /// **'Onboarding progress'**
  String get onboardingProgress;

  /// No description provided for @onboardingCompleted.
  ///
  /// In en, this message translates to:
  /// **'Onboarding completed'**
  String get onboardingCompleted;

  /// No description provided for @onboardingCompletedSub.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set'**
  String get onboardingCompletedSub;

  /// No description provided for @completedSteps.
  ///
  /// In en, this message translates to:
  /// **'Completed steps'**
  String get completedSteps;

  /// No description provided for @outOf.
  ///
  /// In en, this message translates to:
  /// **'out of'**
  String get outOf;

  /// No description provided for @welcomeToFitevo.
  ///
  /// In en, this message translates to:
  /// **'Welcome to FitEvo'**
  String get welcomeToFitevo;

  /// No description provided for @letsGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get started'**
  String get letsGetStarted;

  /// No description provided for @tailoredExperience.
  ///
  /// In en, this message translates to:
  /// **'A tailored experience for your fitness journey'**
  String get tailoredExperience;

  /// No description provided for @whatsYourName.
  ///
  /// In en, this message translates to:
  /// **'What\'s your name?'**
  String get whatsYourName;

  /// No description provided for @namePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get namePlaceholder;

  /// No description provided for @whatsYourCurrentWeight.
  ///
  /// In en, this message translates to:
  /// **'What\'s your current weight?'**
  String get whatsYourCurrentWeight;

  /// No description provided for @whatsYourTargetWeight.
  ///
  /// In en, this message translates to:
  /// **'What\'s your target weight?'**
  String get whatsYourTargetWeight;

  /// No description provided for @whatsYourHeight.
  ///
  /// In en, this message translates to:
  /// **'What\'s your height?'**
  String get whatsYourHeight;

  /// No description provided for @howManyWorkoutsPerWeek.
  ///
  /// In en, this message translates to:
  /// **'How many workouts per week?'**
  String get howManyWorkoutsPerWeek;

  /// No description provided for @workoutsPerWeek.
  ///
  /// In en, this message translates to:
  /// **'workouts/week'**
  String get workoutsPerWeek;

  /// No description provided for @whichDaysDoYouPrefer.
  ///
  /// In en, this message translates to:
  /// **'Which days do you prefer?'**
  String get whichDaysDoYouPrefer;

  /// No description provided for @selectYourWorkoutDays.
  ///
  /// In en, this message translates to:
  /// **'Select your workout days'**
  String get selectYourWorkoutDays;

  /// No description provided for @whichBodyAreas.
  ///
  /// In en, this message translates to:
  /// **'Which body areas do you focus on?'**
  String get whichBodyAreas;

  /// No description provided for @selectUpToThree.
  ///
  /// In en, this message translates to:
  /// **'Select up to 3'**
  String get selectUpToThree;

  /// No description provided for @foodName.
  ///
  /// In en, this message translates to:
  /// **'Food name'**
  String get foodName;

  /// No description provided for @servingSize.
  ///
  /// In en, this message translates to:
  /// **'Serving size'**
  String get servingSize;

  /// No description provided for @servings.
  ///
  /// In en, this message translates to:
  /// **'servings'**
  String get servings;

  /// No description provided for @addServing.
  ///
  /// In en, this message translates to:
  /// **'Add serving'**
  String get addServing;

  /// No description provided for @removeServing.
  ///
  /// In en, this message translates to:
  /// **'Remove serving'**
  String get removeServing;

  /// No description provided for @totalMacros.
  ///
  /// In en, this message translates to:
  /// **'Total macros'**
  String get totalMacros;

  /// No description provided for @dailySummary.
  ///
  /// In en, this message translates to:
  /// **'Daily summary'**
  String get dailySummary;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @logged.
  ///
  /// In en, this message translates to:
  /// **'Logged'**
  String get logged;

  /// No description provided for @mealsToday.
  ///
  /// In en, this message translates to:
  /// **'Meals today'**
  String get mealsToday;

  /// No description provided for @snacks.
  ///
  /// In en, this message translates to:
  /// **'Snacks'**
  String get snacks;

  /// No description provided for @breakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get breakfast;

  /// No description provided for @lunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get lunch;

  /// No description provided for @dinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get dinner;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get addNote;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @quickLog.
  ///
  /// In en, this message translates to:
  /// **'Quick log'**
  String get quickLog;

  /// No description provided for @recentFoods.
  ///
  /// In en, this message translates to:
  /// **'Recent foods'**
  String get recentFoods;

  /// No description provided for @favoriteFoods.
  ///
  /// In en, this message translates to:
  /// **'Favorite foods'**
  String get favoriteFoods;

  /// No description provided for @foodLibrary.
  ///
  /// In en, this message translates to:
  /// **'Food library'**
  String get foodLibrary;

  /// No description provided for @createFood.
  ///
  /// In en, this message translates to:
  /// **'Create food'**
  String get createFood;

  /// No description provided for @editFood.
  ///
  /// In en, this message translates to:
  /// **'Edit food'**
  String get editFood;

  /// No description provided for @deleteFood.
  ///
  /// In en, this message translates to:
  /// **'Delete food'**
  String get deleteFood;

  /// No description provided for @foodSaved.
  ///
  /// In en, this message translates to:
  /// **'Food saved'**
  String get foodSaved;

  /// No description provided for @foodDeleted.
  ///
  /// In en, this message translates to:
  /// **'Food deleted'**
  String get foodDeleted;

  /// No description provided for @barcodeScan.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get barcodeScan;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @aiFoodRecognition.
  ///
  /// In en, this message translates to:
  /// **'AI food recognition'**
  String get aiFoodRecognition;

  /// No description provided for @analyzingFood.
  ///
  /// In en, this message translates to:
  /// **'Analyzing food...'**
  String get analyzingFood;

  /// No description provided for @foodDetected.
  ///
  /// In en, this message translates to:
  /// **'Food detected'**
  String get foodDetected;

  /// No description provided for @foodNotDetected.
  ///
  /// In en, this message translates to:
  /// **'Food not detected, try again'**
  String get foodNotDetected;

  /// No description provided for @confirmFood.
  ///
  /// In en, this message translates to:
  /// **'Confirm food'**
  String get confirmFood;

  /// No description provided for @estimatedMacros.
  ///
  /// In en, this message translates to:
  /// **'Estimated macros'**
  String get estimatedMacros;

  /// No description provided for @perServing.
  ///
  /// In en, this message translates to:
  /// **'per serving'**
  String get perServing;

  /// No description provided for @per100g.
  ///
  /// In en, this message translates to:
  /// **'per 100g'**
  String get per100g;

  /// No description provided for @customServing.
  ///
  /// In en, this message translates to:
  /// **'Custom serving'**
  String get customServing;

  /// No description provided for @portionSize.
  ///
  /// In en, this message translates to:
  /// **'Portion size'**
  String get portionSize;

  /// No description provided for @howMuchDidYouEat.
  ///
  /// In en, this message translates to:
  /// **'How much did you eat?'**
  String get howMuchDidYouEat;

  /// No description provided for @addCustomFood.
  ///
  /// In en, this message translates to:
  /// **'Add custom food'**
  String get addCustomFood;

  /// No description provided for @whatDidYouEat.
  ///
  /// In en, this message translates to:
  /// **'What did you eat?'**
  String get whatDidYouEat;

  /// No description provided for @searchFoodHint.
  ///
  /// In en, this message translates to:
  /// **'Search food...'**
  String get searchFoodHint;

  /// No description provided for @combos.
  ///
  /// In en, this message translates to:
  /// **'Combos'**
  String get combos;

  /// No description provided for @foods.
  ///
  /// In en, this message translates to:
  /// **'Foods'**
  String get foods;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get viewAll;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @goalTarget.
  ///
  /// In en, this message translates to:
  /// **'TARGET'**
  String get goalTarget;

  /// No description provided for @goalReached.
  ///
  /// In en, this message translates to:
  /// **'Goal reached! ✓'**
  String get goalReached;

  /// No description provided for @notQuiteRight.
  ///
  /// In en, this message translates to:
  /// **'Not quite right?'**
  String get notQuiteRight;

  /// No description provided for @analyzedFood.
  ///
  /// In en, this message translates to:
  /// **'HERE\'S WHAT I SEE'**
  String get analyzedFood;

  /// No description provided for @alreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Already in this combo.'**
  String get alreadyAdded;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get added;

  /// No description provided for @logFromPhoto.
  ///
  /// In en, this message translates to:
  /// **'Log from a photo'**
  String get logFromPhoto;

  /// No description provided for @aiEstimatesNutrition.
  ///
  /// In en, this message translates to:
  /// **'AI estimates nutrition from the food in your photo.'**
  String get aiEstimatesNutrition;

  /// No description provided for @caloriesOver.
  ///
  /// In en, this message translates to:
  /// **'CALORIES OVER'**
  String get caloriesOver;

  /// No description provided for @caloriesLeft.
  ///
  /// In en, this message translates to:
  /// **'CALORIES LEFT'**
  String get caloriesLeft;

  /// No description provided for @ofTarget.
  ///
  /// In en, this message translates to:
  /// **'of {target} target'**
  String ofTarget(Object target);

  /// No description provided for @tapForDetails.
  ///
  /// In en, this message translates to:
  /// **'TAP FOR DETAILS'**
  String get tapForDetails;

  /// No description provided for @overLabel.
  ///
  /// In en, this message translates to:
  /// **'over'**
  String get overLabel;

  /// No description provided for @doneLabel.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get doneLabel;

  /// No description provided for @leftLabel.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get leftLabel;

  /// No description provided for @workoutLabel.
  ///
  /// In en, this message translates to:
  /// **'WORKOUT'**
  String get workoutLabel;

  /// No description provided for @setUpRoutine.
  ///
  /// In en, this message translates to:
  /// **'Set up your routine'**
  String get setUpRoutine;

  /// No description provided for @tapToGenerate.
  ///
  /// In en, this message translates to:
  /// **'Tap to generate a starter split.'**
  String get tapToGenerate;

  /// No description provided for @restDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Rest day'**
  String get restDayLabel;

  /// No description provided for @recoveryMatters.
  ///
  /// In en, this message translates to:
  /// **'Recovery matters as much as training.'**
  String get recoveryMatters;

  /// No description provided for @startBtn.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startBtn;

  /// No description provided for @hydrationGoal.
  ///
  /// In en, this message translates to:
  /// **'Hydration goal!'**
  String get hydrationGoal;

  /// No description provided for @greatJobKeepGoing.
  ///
  /// In en, this message translates to:
  /// **'Great job — keep flowing.'**
  String get greatJobKeepGoing;

  /// No description provided for @nothingLogged.
  ///
  /// In en, this message translates to:
  /// **'nothing logged'**
  String get nothingLogged;

  /// No description provided for @calculating.
  ///
  /// In en, this message translates to:
  /// **'Calculating…'**
  String get calculating;

  /// No description provided for @offlineNotes.
  ///
  /// In en, this message translates to:
  /// **'{count} offline note(s) · tap to add'**
  String offlineNotes(Object count);

  /// No description provided for @notesProcessed.
  ///
  /// In en, this message translates to:
  /// **'Notes processed'**
  String get notesProcessed;

  /// No description provided for @addedItems.
  ///
  /// In en, this message translates to:
  /// **'Added {count} item(s) · {kcal} kcal'**
  String addedItems(Object count, Object kcal);

  /// No description provided for @coachLabel.
  ///
  /// In en, this message translates to:
  /// **'COACH'**
  String get coachLabel;

  /// No description provided for @aiNeedsDetail.
  ///
  /// In en, this message translates to:
  /// **'AI NEEDS A DETAIL'**
  String get aiNeedsDetail;

  /// No description provided for @replyOrAsk.
  ///
  /// In en, this message translates to:
  /// **'Reply or ask anything…'**
  String get replyOrAsk;

  /// No description provided for @whatDidYouEatHint.
  ///
  /// In en, this message translates to:
  /// **'What did you eat?'**
  String get whatDidYouEatHint;

  /// No description provided for @answerAbove.
  ///
  /// In en, this message translates to:
  /// **'Answer above…'**
  String get answerAbove;

  /// No description provided for @addApiKey.
  ///
  /// In en, this message translates to:
  /// **'Add your free Groq (or Gemini) API key to enable AI logging.'**
  String get addApiKey;

  /// No description provided for @couldNotGenerateRoutine.
  ///
  /// In en, this message translates to:
  /// **'Could not generate routine.'**
  String get couldNotGenerateRoutine;

  /// No description provided for @couldNotRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Could not regenerate routine.'**
  String get couldNotRegenerate;

  /// No description provided for @couldNotDeleteRoutine.
  ///
  /// In en, this message translates to:
  /// **'Could not delete routine.'**
  String get couldNotDeleteRoutine;

  /// No description provided for @couldNotDeleteSession.
  ///
  /// In en, this message translates to:
  /// **'Could not delete session.'**
  String get couldNotDeleteSession;

  /// No description provided for @replaceRoutine.
  ///
  /// In en, this message translates to:
  /// **'Replace this routine?'**
  String get replaceRoutine;

  /// No description provided for @replaceRoutineBody.
  ///
  /// In en, this message translates to:
  /// **'AI will draft a new split. Your past sessions are kept.'**
  String get replaceRoutineBody;

  /// No description provided for @deleteRoutineTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this routine?'**
  String get deleteRoutineTitle;

  /// No description provided for @deleteRoutineBody.
  ///
  /// In en, this message translates to:
  /// **'All days in \"{name}\" will be removed. Past sessions are kept.'**
  String deleteRoutineBody(Object name);

  /// No description provided for @deleteSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this session?'**
  String get deleteSessionTitle;

  /// No description provided for @deleteSessionBody.
  ///
  /// In en, this message translates to:
  /// **'Started {when} · {day}. This can\'t be undone.'**
  String deleteSessionBody(Object day, Object when);

  /// No description provided for @regenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get regenerate;

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @thisWeek.
  ///
  /// In en, this message translates to:
  /// **'THIS WEEK'**
  String get thisWeek;

  /// No description provided for @recentSessions.
  ///
  /// In en, this message translates to:
  /// **'RECENT SESSIONS'**
  String get recentSessions;

  /// No description provided for @restAndRecover.
  ///
  /// In en, this message translates to:
  /// **'Rest & recover'**
  String get restAndRecover;

  /// No description provided for @exercisesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} exercises'**
  String exercisesCount(Object count);

  /// No description provided for @minKcal.
  ///
  /// In en, this message translates to:
  /// **'{min} min · ~{kcal} kcal'**
  String minKcal(Object kcal, Object min);

  /// No description provided for @minOnly.
  ///
  /// In en, this message translates to:
  /// **'{min} min'**
  String minOnly(Object min);

  /// No description provided for @timeForDeload.
  ///
  /// In en, this message translates to:
  /// **'Time for a deload'**
  String get timeForDeload;

  /// No description provided for @exerciseStalled.
  ///
  /// In en, this message translates to:
  /// **'{exercise} has stalled'**
  String exerciseStalled(Object exercise);

  /// No description provided for @stalledBody.
  ///
  /// In en, this message translates to:
  /// **'No progress in {sessions} sessions. Try a variation for a few weeks, change the rep range, or add a set.'**
  String stalledBody(Object sessions);

  /// No description provided for @noWorkoutsLogged.
  ///
  /// In en, this message translates to:
  /// **'No workouts logged yet — start today!'**
  String get noWorkoutsLogged;

  /// No description provided for @howDoYouTrain.
  ///
  /// In en, this message translates to:
  /// **'How do you train?'**
  String get howDoYouTrain;

  /// No description provided for @pickHowYouTrain.
  ///
  /// In en, this message translates to:
  /// **'Pick how you train — the AI builds the exercises around your sets and reps.'**
  String get pickHowYouTrain;

  /// No description provided for @setDefaultSetsReps.
  ///
  /// In en, this message translates to:
  /// **'Set your default sets and reps. Every exercise you add starts here — tweak any later.'**
  String get setDefaultSetsReps;

  /// No description provided for @setsPerExercise.
  ///
  /// In en, this message translates to:
  /// **'SETS PER EXERCISE'**
  String get setsPerExercise;

  /// No description provided for @repsPerSet.
  ///
  /// In en, this message translates to:
  /// **'REPS PER SET'**
  String get repsPerSet;

  /// No description provided for @pyramid.
  ///
  /// In en, this message translates to:
  /// **'Pyramid  ·  −2 / set'**
  String get pyramid;

  /// No description provided for @straight.
  ///
  /// In en, this message translates to:
  /// **'Straight  ·  same reps'**
  String get straight;

  /// No description provided for @topSetReps.
  ///
  /// In en, this message translates to:
  /// **'TOP SET REPS'**
  String get topSetReps;

  /// No description provided for @repsEachSet.
  ///
  /// In en, this message translates to:
  /// **'REPS EACH SET'**
  String get repsEachSet;

  /// No description provided for @eachSet.
  ///
  /// In en, this message translates to:
  /// **'EACH SET'**
  String get eachSet;

  /// No description provided for @previewForSets.
  ///
  /// In en, this message translates to:
  /// **'(preview for 4 sets — AI picks the count)'**
  String get previewForSets;

  /// No description provided for @aiDecides.
  ///
  /// In en, this message translates to:
  /// **'AI decides'**
  String get aiDecides;

  /// No description provided for @editRoutineMenu.
  ///
  /// In en, this message translates to:
  /// **'Edit routine'**
  String get editRoutineMenu;

  /// No description provided for @regenerateWithAI.
  ///
  /// In en, this message translates to:
  /// **'Regenerate with AI'**
  String get regenerateWithAI;

  /// No description provided for @deleteRoutineMenu.
  ///
  /// In en, this message translates to:
  /// **'Delete routine'**
  String get deleteRoutineMenu;

  /// No description provided for @logRunWalkCardio.
  ///
  /// In en, this message translates to:
  /// **'Log a run, walk or cardio'**
  String get logRunWalkCardio;

  /// No description provided for @mobility.
  ///
  /// In en, this message translates to:
  /// **'Mobility'**
  String get mobility;

  /// No description provided for @prs.
  ///
  /// In en, this message translates to:
  /// **'PRs'**
  String get prs;

  /// No description provided for @couldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save.'**
  String get couldNotSave;

  /// No description provided for @warningPregnancy.
  ///
  /// In en, this message translates to:
  /// **'pregnancy'**
  String get warningPregnancy;

  /// No description provided for @warningBreastfeeding.
  ///
  /// In en, this message translates to:
  /// **'breastfeeding'**
  String get warningBreastfeeding;

  /// No description provided for @warningEatingDisorder.
  ///
  /// In en, this message translates to:
  /// **'eating-disorder history'**
  String get warningEatingDisorder;

  /// No description provided for @warningType1Diabetes.
  ///
  /// In en, this message translates to:
  /// **'Type 1 diabetes'**
  String get warningType1Diabetes;

  /// No description provided for @nothingLoggedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing logged yet'**
  String get nothingLoggedYet;

  /// No description provided for @heroRecoverWell.
  ///
  /// In en, this message translates to:
  /// **'Recover well'**
  String get heroRecoverWell;

  /// No description provided for @heroYouHitIt.
  ///
  /// In en, this message translates to:
  /// **'You hit it'**
  String get heroYouHitIt;

  /// No description provided for @heroDayStrong.
  ///
  /// In en, this message translates to:
  /// **'Day strong'**
  String get heroDayStrong;

  /// No description provided for @heroGetSomeRest.
  ///
  /// In en, this message translates to:
  /// **'Get some rest'**
  String get heroGetSomeRest;

  /// No description provided for @heroLetsFuelUp.
  ///
  /// In en, this message translates to:
  /// **'Let\'s fuel up'**
  String get heroLetsFuelUp;

  /// No description provided for @heroStrongStart.
  ///
  /// In en, this message translates to:
  /// **'Strong start'**
  String get heroStrongStart;

  /// No description provided for @heroLightUpDay.
  ///
  /// In en, this message translates to:
  /// **'Light up the day'**
  String get heroLightUpDay;

  /// No description provided for @heroHalfwayThere.
  ///
  /// In en, this message translates to:
  /// **'Halfway there'**
  String get heroHalfwayThere;

  /// No description provided for @heroTimeToFuel.
  ///
  /// In en, this message translates to:
  /// **'Time to fuel'**
  String get heroTimeToFuel;

  /// No description provided for @heroKeepItGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep it going'**
  String get heroKeepItGoing;

  /// No description provided for @heroAlmostThere.
  ///
  /// In en, this message translates to:
  /// **'Almost there'**
  String get heroAlmostThere;

  /// No description provided for @heroPlentyLeft.
  ///
  /// In en, this message translates to:
  /// **'Plenty left to fuel'**
  String get heroPlentyLeft;

  /// No description provided for @heroWindDownWell.
  ///
  /// In en, this message translates to:
  /// **'Good pace'**
  String get heroWindDownWell;

  /// No description provided for @heroWindDown.
  ///
  /// In en, this message translates to:
  /// **'End of day'**
  String get heroWindDown;

  /// No description provided for @aiPowered.
  ///
  /// In en, this message translates to:
  /// **'AI POWERED'**
  String get aiPowered;

  /// No description provided for @emptyStateMealHint.
  ///
  /// In en, this message translates to:
  /// **'Open the dashboard and type a meal — your day fills in here.'**
  String get emptyStateMealHint;

  /// No description provided for @aiServiceNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'AI is not configured. Add your free Groq API key (console.groq.com) or Gemini key (aistudio.google.com) to enable logging.'**
  String get aiServiceNotConfigured;

  /// No description provided for @byRajendraPandey.
  ///
  /// In en, this message translates to:
  /// **' by Rajendra Pandey'**
  String get byRajendraPandey;

  /// No description provided for @key.
  ///
  /// In en, this message translates to:
  /// **' · '**
  String get key;

  /// No description provided for @key1.
  ///
  /// In en, this message translates to:
  /// **'%'**
  String get key1;

  /// No description provided for @key15s.
  ///
  /// In en, this message translates to:
  /// **'+15s'**
  String get key15s;

  /// No description provided for @key30s.
  ///
  /// In en, this message translates to:
  /// **'+30s'**
  String get key30s;

  /// No description provided for @key15s1.
  ///
  /// In en, this message translates to:
  /// **'-15s'**
  String get key15s1;

  /// No description provided for @key07.
  ///
  /// In en, this message translates to:
  /// **'0–7'**
  String get key07;

  /// No description provided for @key1Scoop1Bowl.
  ///
  /// In en, this message translates to:
  /// **'1 scoop, 1 bowl…'**
  String get key1Scoop1Bowl;

  /// No description provided for @adaptiveTarget.
  ///
  /// In en, this message translates to:
  /// **'ADAPTIVE TARGET'**
  String get adaptiveTarget;

  /// No description provided for @aiReport.
  ///
  /// In en, this message translates to:
  /// **'AI REPORT'**
  String get aiReport;

  /// No description provided for @aiTracking.
  ///
  /// In en, this message translates to:
  /// **'AI TRACKING'**
  String get aiTracking;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get appearance;

  /// No description provided for @armCm.
  ///
  /// In en, this message translates to:
  /// **'ARM (CM)'**
  String get armCm;

  /// No description provided for @avgHeartRateBpm.
  ///
  /// In en, this message translates to:
  /// **'AVG HEART RATE (BPM)'**
  String get avgHeartRateBpm;

  /// No description provided for @accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @addDay1.
  ///
  /// In en, this message translates to:
  /// **'Add day'**
  String get addDay1;

  /// No description provided for @addExercise1.
  ///
  /// In en, this message translates to:
  /// **'Add exercise'**
  String get addExercise1;

  /// No description provided for @addFirstLog.
  ///
  /// In en, this message translates to:
  /// **'Add first log'**
  String get addFirstLog;

  /// No description provided for @addProgressPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add progress photo'**
  String get addProgressPhoto;

  /// No description provided for @addThisExercise.
  ///
  /// In en, this message translates to:
  /// **'Add this exercise'**
  String get addThisExercise;

  /// No description provided for @analyzedFood1.
  ///
  /// In en, this message translates to:
  /// **'Analyzed Food'**
  String get analyzedFood1;

  /// No description provided for @anythingYouWantToRemember.
  ///
  /// In en, this message translates to:
  /// **'Anything you want to remember'**
  String get anythingYouWantToRemember;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @arm.
  ///
  /// In en, this message translates to:
  /// **'Arm'**
  String get arm;

  /// No description provided for @assignWeekday.
  ///
  /// In en, this message translates to:
  /// **'Assign weekday'**
  String get assignWeekday;

  /// No description provided for @attachAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Attach a photo'**
  String get attachAPhoto;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'BALANCE'**
  String get balance;

  /// No description provided for @begin.
  ///
  /// In en, this message translates to:
  /// **'BEGIN'**
  String get begin;

  /// No description provided for @bodyFat.
  ///
  /// In en, this message translates to:
  /// **'BODY FAT %'**
  String get bodyFat;

  /// No description provided for @bodyFatOptional1.
  ///
  /// In en, this message translates to:
  /// **'BODY FAT % (OPTIONAL)'**
  String get bodyFatOptional1;

  /// No description provided for @backingUpUnderATemporaryId.
  ///
  /// In en, this message translates to:
  /// **'Backing up under a temporary ID'**
  String get backingUpUnderATemporaryId;

  /// No description provided for @beginnerFriendly.
  ///
  /// In en, this message translates to:
  /// **'Beginner-friendly'**
  String get beginnerFriendly;

  /// No description provided for @between8AmAnd9PmOnYourInterval.
  ///
  /// In en, this message translates to:
  /// **'Between 8 AM and 9 PM, on your interval.'**
  String get between8AmAnd9PmOnYourInterval;

  /// No description provided for @bodyLogs.
  ///
  /// In en, this message translates to:
  /// **'Body Logs'**
  String get bodyLogs;

  /// No description provided for @bodyFat1.
  ///
  /// In en, this message translates to:
  /// **'Body fat'**
  String get bodyFat1;

  /// No description provided for @c.
  ///
  /// In en, this message translates to:
  /// **'C'**
  String get c;

  /// No description provided for @calorieTargetReTuneSuggested.
  ///
  /// In en, this message translates to:
  /// **'CALORIE TARGET — RE-TUNE SUGGESTED'**
  String get calorieTargetReTuneSuggested;

  /// No description provided for @cardioActivity.
  ///
  /// In en, this message translates to:
  /// **'CARDIO & ACTIVITY'**
  String get cardioActivity;

  /// No description provided for @cardioWk.
  ///
  /// In en, this message translates to:
  /// **'CARDIO / WK'**
  String get cardioWk;

  /// No description provided for @chestCm.
  ///
  /// In en, this message translates to:
  /// **'CHEST (CM)'**
  String get chestCm;

  /// No description provided for @cloudBackup1.
  ///
  /// In en, this message translates to:
  /// **'CLOUD BACKUP'**
  String get cloudBackup1;

  /// No description provided for @coachNoticed.
  ///
  /// In en, this message translates to:
  /// **'COACH NOTICED'**
  String get coachNoticed;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'COMING SOON'**
  String get comingSoon;

  /// No description provided for @commonMistakes.
  ///
  /// In en, this message translates to:
  /// **'COMMON MISTAKES'**
  String get commonMistakes;

  /// No description provided for @consumed.
  ///
  /// In en, this message translates to:
  /// **'CONSUMED'**
  String get consumed;

  /// No description provided for @creatineGDay.
  ///
  /// In en, this message translates to:
  /// **'CREATINE (G/DAY)'**
  String get creatineGDay;

  /// No description provided for @cyclePhase.
  ///
  /// In en, this message translates to:
  /// **'CYCLE PHASE'**
  String get cyclePhase;

  /// No description provided for @caloriesKcal.
  ///
  /// In en, this message translates to:
  /// **'Calories (kcal)'**
  String get caloriesKcal;

  /// No description provided for @carbohydrates.
  ///
  /// In en, this message translates to:
  /// **'Carbohydrates'**
  String get carbohydrates;

  /// No description provided for @carbsG.
  ///
  /// In en, this message translates to:
  /// **'Carbs (g)'**
  String get carbsG;

  /// No description provided for @cardio.
  ///
  /// In en, this message translates to:
  /// **'Cardio'**
  String get cardio;

  /// No description provided for @cardioHistory.
  ///
  /// In en, this message translates to:
  /// **'Cardio history'**
  String get cardioHistory;

  /// No description provided for @checkedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get checkedIn;

  /// No description provided for @chest.
  ///
  /// In en, this message translates to:
  /// **'Chest'**
  String get chest;

  /// No description provided for @chooseFromGallery1.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery1;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @cloudBackupResetAndReUploaded.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup reset and re-uploaded.'**
  String get cloudBackupResetAndReUploaded;

  /// No description provided for @coachCanDoBetter.
  ///
  /// In en, this message translates to:
  /// **'Coach can do better'**
  String get coachCanDoBetter;

  /// No description provided for @couldNotShare.
  ///
  /// In en, this message translates to:
  /// **'Could not share.'**
  String get couldNotShare;

  /// No description provided for @customAmount.
  ///
  /// In en, this message translates to:
  /// **'Custom amount'**
  String get customAmount;

  /// No description provided for @customAmount1.
  ///
  /// In en, this message translates to:
  /// **'Custom amount…'**
  String get customAmount1;

  /// No description provided for @customFoods.
  ///
  /// In en, this message translates to:
  /// **'Custom foods'**
  String get customFoods;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'DATA'**
  String get data;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'DATE'**
  String get date;

  /// No description provided for @doYouTrainAtAGym.
  ///
  /// In en, this message translates to:
  /// **'DO YOU TRAIN AT A GYM?'**
  String get doYouTrainAtAGym;

  /// No description provided for @dailyReport1.
  ///
  /// In en, this message translates to:
  /// **'Daily Report'**
  String get dailyReport1;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @dayName.
  ///
  /// In en, this message translates to:
  /// **'Day name'**
  String get dayName;

  /// No description provided for @deleteAccount1.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount1;

  /// No description provided for @deleteOldBackupData.
  ///
  /// In en, this message translates to:
  /// **'Delete old backup data'**
  String get deleteOldBackupData;

  /// No description provided for @deleteOldBackupData1.
  ///
  /// In en, this message translates to:
  /// **'Delete old backup data?'**
  String get deleteOldBackupData1;

  /// No description provided for @deleteThisLog.
  ///
  /// In en, this message translates to:
  /// **'Delete this log?'**
  String get deleteThisLog;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @discardWorkout1.
  ///
  /// In en, this message translates to:
  /// **'Discard workout'**
  String get discardWorkout1;

  /// No description provided for @discardWorkout2.
  ///
  /// In en, this message translates to:
  /// **'Discard workout?'**
  String get discardWorkout2;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @eachSet1.
  ///
  /// In en, this message translates to:
  /// **'EACH SET'**
  String get eachSet1;

  /// No description provided for @every.
  ///
  /// In en, this message translates to:
  /// **'EVERY'**
  String get every;

  /// No description provided for @end.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// No description provided for @exerciseNotFound1.
  ///
  /// In en, this message translates to:
  /// **'Exercise not found'**
  String get exerciseNotFound1;

  /// No description provided for @exercises.
  ///
  /// In en, this message translates to:
  /// **'Exercises'**
  String get exercises;

  /// No description provided for @f.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get f;

  /// No description provided for @fitevoDailyReport.
  ///
  /// In en, this message translates to:
  /// **'FITEVO · DAILY REPORT'**
  String get fitevoDailyReport;

  /// No description provided for @flow.
  ///
  /// In en, this message translates to:
  /// **'FLOW'**
  String get flow;

  /// No description provided for @foodLibrary1.
  ///
  /// In en, this message translates to:
  /// **'FOOD LIBRARY'**
  String get foodLibrary1;

  /// No description provided for @foodLogged.
  ///
  /// In en, this message translates to:
  /// **'FOOD LOGGED'**
  String get foodLogged;

  /// No description provided for @formCues.
  ///
  /// In en, this message translates to:
  /// **'FORM CUES'**
  String get formCues;

  /// No description provided for @fatG.
  ///
  /// In en, this message translates to:
  /// **'Fat (g)'**
  String get fatG;

  /// No description provided for @fib.
  ///
  /// In en, this message translates to:
  /// **'Fib'**
  String get fib;

  /// No description provided for @fiberG.
  ///
  /// In en, this message translates to:
  /// **'Fiber (g)'**
  String get fiberG;

  /// No description provided for @finishWithoutLogging.
  ///
  /// In en, this message translates to:
  /// **'Finish without logging?'**
  String get finishWithoutLogging;

  /// No description provided for @finishedThisSet.
  ///
  /// In en, this message translates to:
  /// **'Finished this set?'**
  String get finishedThisSet;

  /// No description provided for @food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get food;

  /// No description provided for @gymExperience1.
  ///
  /// In en, this message translates to:
  /// **'GYM EXPERIENCE'**
  String get gymExperience1;

  /// No description provided for @gymMinSession.
  ///
  /// In en, this message translates to:
  /// **'GYM MIN / SESSION'**
  String get gymMinSession;

  /// No description provided for @generateInsightsFromYourLogs.
  ///
  /// In en, this message translates to:
  /// **'Generate insights from your logs'**
  String get generateInsightsFromYourLogs;

  /// No description provided for @generateReportForThisDay.
  ///
  /// In en, this message translates to:
  /// **'Generate report for this day'**
  String get generateReportForThisDay;

  /// No description provided for @guestAccount1.
  ///
  /// In en, this message translates to:
  /// **'Guest account'**
  String get guestAccount1;

  /// No description provided for @healthSync.
  ///
  /// In en, this message translates to:
  /// **'HEALTH SYNC'**
  String get healthSync;

  /// No description provided for @howToDoIt.
  ///
  /// In en, this message translates to:
  /// **'HOW TO DO IT'**
  String get howToDoIt;

  /// No description provided for @healthSync1.
  ///
  /// In en, this message translates to:
  /// **'Health sync'**
  String get healthSync1;

  /// No description provided for @howShouldWeGreetYou.
  ///
  /// In en, this message translates to:
  /// **'How should we greet you?'**
  String get howShouldWeGreetYou;

  /// No description provided for @howSoreAreYou.
  ///
  /// In en, this message translates to:
  /// **'How sore are you?'**
  String get howSoreAreYou;

  /// No description provided for @imperial.
  ///
  /// In en, this message translates to:
  /// **'Imperial'**
  String get imperial;

  /// No description provided for @improveAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Improve accuracy'**
  String get improveAccuracy;

  /// No description provided for @ingredientsRecipeLinkEtc.
  ///
  /// In en, this message translates to:
  /// **'Ingredients, recipe link, etc.'**
  String get ingredientsRecipeLinkEtc;

  /// No description provided for @intervalTimer.
  ///
  /// In en, this message translates to:
  /// **'Interval timer'**
  String get intervalTimer;

  /// No description provided for @keepGoing.
  ///
  /// In en, this message translates to:
  /// **'Keep going'**
  String get keepGoing;

  /// No description provided for @l.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get l;

  /// No description provided for @last7Days.
  ///
  /// In en, this message translates to:
  /// **'LAST 7 DAYS'**
  String get last7Days;

  /// No description provided for @length.
  ///
  /// In en, this message translates to:
  /// **'LENGTH'**
  String get length;

  /// No description provided for @lastBackup1.
  ///
  /// In en, this message translates to:
  /// **'Last backup'**
  String get lastBackup1;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @leaveWorkout.
  ///
  /// In en, this message translates to:
  /// **'Leave workout?'**
  String get leaveWorkout;

  /// No description provided for @libraryNeedsInternetToLoadItsPhotos.
  ///
  /// In en, this message translates to:
  /// **'Library needs internet to load its photos.\n'**
  String get libraryNeedsInternetToLoadItsPhotos;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @loadingTheExerciseLibrary.
  ///
  /// In en, this message translates to:
  /// **'Loading the exercise library…'**
  String get loadingTheExerciseLibrary;

  /// No description provided for @logActivity.
  ///
  /// In en, this message translates to:
  /// **'Log activity'**
  String get logActivity;

  /// No description provided for @logActivityForThisDay.
  ///
  /// In en, this message translates to:
  /// **'Log activity for this day.'**
  String get logActivityForThisDay;

  /// No description provided for @logOutdoorCardioActivity.
  ///
  /// In en, this message translates to:
  /// **'Log outdoor / cardio activity'**
  String get logOutdoorCardioActivity;

  /// No description provided for @logToday.
  ///
  /// In en, this message translates to:
  /// **'Log today\"'**
  String get logToday;

  /// No description provided for @logYourShakesBreakfastOrAWholeComboInOneTap.
  ///
  /// In en, this message translates to:
  /// **'Log your shakes, breakfast or a whole combo in one tap.'**
  String get logYourShakesBreakfastOrAWholeComboInOneTap;

  /// No description provided for @macros.
  ///
  /// In en, this message translates to:
  /// **'MACROS'**
  String get macros;

  /// No description provided for @meals.
  ///
  /// In en, this message translates to:
  /// **'MEALS'**
  String get meals;

  /// No description provided for @mode.
  ///
  /// In en, this message translates to:
  /// **'MODE'**
  String get mode;

  /// No description provided for @muscleMap.
  ///
  /// In en, this message translates to:
  /// **'MUSCLE MAP'**
  String get muscleMap;

  /// No description provided for @musclesWorked.
  ///
  /// In en, this message translates to:
  /// **'MUSCLES WORKED'**
  String get musclesWorked;

  /// No description provided for @madeWith.
  ///
  /// In en, this message translates to:
  /// **'Made with '**
  String get madeWith;

  /// No description provided for @manualBandSync.
  ///
  /// In en, this message translates to:
  /// **'Manual band sync'**
  String get manualBandSync;

  /// No description provided for @mealNudges.
  ///
  /// In en, this message translates to:
  /// **'Meal nudges'**
  String get mealNudges;

  /// No description provided for @metric.
  ///
  /// In en, this message translates to:
  /// **'Metric'**
  String get metric;

  /// No description provided for @micPermissionNeededForVoiceInput.
  ///
  /// In en, this message translates to:
  /// **'Mic permission needed for voice input.'**
  String get micPermissionNeededForVoiceInput;

  /// No description provided for @mindfulness.
  ///
  /// In en, this message translates to:
  /// **'Mindfulness'**
  String get mindfulness;

  /// No description provided for @mixAndMatchRunWalkAndOtherInOneGo.
  ///
  /// In en, this message translates to:
  /// **'Mix and match — run, walk and other in one go.'**
  String get mixAndMatchRunWalkAndOtherInOneGo;

  /// No description provided for @muscleMap1.
  ///
  /// In en, this message translates to:
  /// **'Muscle map'**
  String get muscleMap1;

  /// No description provided for @newPr.
  ///
  /// In en, this message translates to:
  /// **'NEW PR!'**
  String get newPr;

  /// No description provided for @nextSetCall.
  ///
  /// In en, this message translates to:
  /// **'NEXT-SET CALL'**
  String get nextSetCall;

  /// No description provided for @notas.
  ///
  /// In en, this message translates to:
  /// **'NOTAS'**
  String get notas;

  /// No description provided for @note.
  ///
  /// In en, this message translates to:
  /// **'NOTE'**
  String get note;

  /// No description provided for @noteOptional1.
  ///
  /// In en, this message translates to:
  /// **'NOTE (OPTIONAL)'**
  String get noteOptional1;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'NOTES'**
  String get notes;

  /// No description provided for @na.
  ///
  /// In en, this message translates to:
  /// **'Na'**
  String get na;

  /// No description provided for @newTarget.
  ///
  /// In en, this message translates to:
  /// **'New target'**
  String get newTarget;

  /// No description provided for @noAlternativesInYourLibraryYet.
  ///
  /// In en, this message translates to:
  /// **'No alternatives in your library yet.'**
  String get noAlternativesInYourLibraryYet;

  /// No description provided for @noCardioLoggedYet.
  ///
  /// In en, this message translates to:
  /// **'No cardio logged yet.'**
  String get noCardioLoggedYet;

  /// No description provided for @noDemoAvailable.
  ///
  /// In en, this message translates to:
  /// **'No demo available'**
  String get noDemoAvailable;

  /// No description provided for @noFormGuideSavedForThisExerciseYet.
  ///
  /// In en, this message translates to:
  /// **'No form guide saved for this exercise yet.'**
  String get noFormGuideSavedForThisExerciseYet;

  /// No description provided for @noLogsYet.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get noLogsYet;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches.'**
  String get noMatches;

  /// No description provided for @noMuscleMapForThisExercise.
  ///
  /// In en, this message translates to:
  /// **'No muscle map for this exercise.'**
  String get noMuscleMapForThisExercise;

  /// No description provided for @noRecordsYet.
  ///
  /// In en, this message translates to:
  /// **'No records yet'**
  String get noRecordsYet;

  /// No description provided for @noSipsYetToday.
  ///
  /// In en, this message translates to:
  /// **'No sips yet today'**
  String get noSipsYetToday;

  /// No description provided for @noWorkingSetsLogged.
  ///
  /// In en, this message translates to:
  /// **'No working sets logged.'**
  String get noWorkingSetsLogged;

  /// No description provided for @notQuiteRight1.
  ///
  /// In en, this message translates to:
  /// **'Not Quite Right'**
  String get notQuiteRight1;

  /// No description provided for @notToday.
  ///
  /// In en, this message translates to:
  /// **'Not today\"'**
  String get notToday;

  /// No description provided for @notYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get notYet;

  /// No description provided for @otherCardio.
  ///
  /// In en, this message translates to:
  /// **'OTHER CARDIO'**
  String get otherCardio;

  /// No description provided for @otherCardioMin.
  ///
  /// In en, this message translates to:
  /// **'OTHER CARDIO (MIN)'**
  String get otherCardioMin;

  /// No description provided for @outdoorCardio.
  ///
  /// In en, this message translates to:
  /// **'OUTDOOR / CARDIO'**
  String get outdoorCardio;

  /// No description provided for @oldBackupDataDeleted.
  ///
  /// In en, this message translates to:
  /// **'Old backup data deleted.'**
  String get oldBackupDataDeleted;

  /// No description provided for @openOnYoutube.
  ///
  /// In en, this message translates to:
  /// **'Open on YouTube'**
  String get openOnYoutube;

  /// No description provided for @otherCardio1.
  ///
  /// In en, this message translates to:
  /// **'Other cardio'**
  String get otherCardio1;

  /// No description provided for @outdoorCardio1.
  ///
  /// In en, this message translates to:
  /// **'Outdoor & Cardio'**
  String get outdoorCardio1;

  /// No description provided for @overrideAnyAutoComputedTarget.
  ///
  /// In en, this message translates to:
  /// **'Override any auto-computed target.'**
  String get overrideAnyAutoComputedTarget;

  /// No description provided for @p.
  ///
  /// In en, this message translates to:
  /// **'P'**
  String get p;

  /// No description provided for @portion.
  ///
  /// In en, this message translates to:
  /// **'PORTION'**
  String get portion;

  /// No description provided for @profileTargets.
  ///
  /// In en, this message translates to:
  /// **'PROFILE & TARGETS'**
  String get profileTargets;

  /// No description provided for @progressPhotoPrivate.
  ///
  /// In en, this message translates to:
  /// **'PROGRESS PHOTO (PRIVATE)'**
  String get progressPhotoPrivate;

  /// No description provided for @personalRecords.
  ///
  /// In en, this message translates to:
  /// **'Personal records'**
  String get personalRecords;

  /// No description provided for @pickATemplate.
  ///
  /// In en, this message translates to:
  /// **'Pick a template'**
  String get pickATemplate;

  /// No description provided for @plateLoader.
  ///
  /// In en, this message translates to:
  /// **'Plate loader'**
  String get plateLoader;

  /// No description provided for @preWorkoutOmega3VitaminD.
  ///
  /// In en, this message translates to:
  /// **'Pre-workout, omega-3, vitamin D…'**
  String get preWorkoutOmega3VitaminD;

  /// No description provided for @prev.
  ///
  /// In en, this message translates to:
  /// **'Prev.'**
  String get prev;

  /// No description provided for @profileGoalAndTargets.
  ///
  /// In en, this message translates to:
  /// **'Profile, goal, and targets'**
  String get profileGoalAndTargets;

  /// No description provided for @proteinG.
  ///
  /// In en, this message translates to:
  /// **'Protein (g)'**
  String get proteinG;

  /// No description provided for @provenSplitsReadyToTrainReplacesYourRoutine.
  ///
  /// In en, this message translates to:
  /// **'Proven splits, ready to train. Replaces your routine.'**
  String get provenSplitsReadyToTrainReplacesYourRoutine;

  /// No description provided for @quickAdd.
  ///
  /// In en, this message translates to:
  /// **'QUICK ADD'**
  String get quickAdd;

  /// No description provided for @recovery.
  ///
  /// In en, this message translates to:
  /// **'RECOVERY'**
  String get recovery;

  /// No description provided for @reminders.
  ///
  /// In en, this message translates to:
  /// **'REMINDERS'**
  String get reminders;

  /// No description provided for @repsHigh.
  ///
  /// In en, this message translates to:
  /// **'REPS (HIGH)'**
  String get repsHigh;

  /// No description provided for @repsLow.
  ///
  /// In en, this message translates to:
  /// **'REPS (LOW)'**
  String get repsLow;

  /// No description provided for @repsTapToCount.
  ///
  /// In en, this message translates to:
  /// **'REPS · tap to count'**
  String get repsTapToCount;

  /// No description provided for @rest.
  ///
  /// In en, this message translates to:
  /// **'REST'**
  String get rest;

  /// No description provided for @restSeconds.
  ///
  /// In en, this message translates to:
  /// **'REST (SECONDS)'**
  String get restSeconds;

  /// No description provided for @routineName1.
  ///
  /// In en, this message translates to:
  /// **'ROUTINE NAME'**
  String get routineName1;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'RUNNING'**
  String get running;

  /// No description provided for @runningKm.
  ///
  /// In en, this message translates to:
  /// **'RUNNING (KM)'**
  String get runningKm;

  /// No description provided for @readingYour2WeekTrend.
  ///
  /// In en, this message translates to:
  /// **'Reading your 2-week trend…'**
  String get readingYour2WeekTrend;

  /// No description provided for @readingYourWeek.
  ///
  /// In en, this message translates to:
  /// **'Reading your week…'**
  String get readingYourWeek;

  /// No description provided for @reminders1.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get reminders1;

  /// No description provided for @removeDuplicateEntries.
  ///
  /// In en, this message translates to:
  /// **'Remove duplicate entries'**
  String get removeDuplicateEntries;

  /// No description provided for @removePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get removePhoto;

  /// No description provided for @resetReUpload.
  ///
  /// In en, this message translates to:
  /// **'Reset & Re-upload'**
  String get resetReUpload;

  /// No description provided for @resetReUploadCloud.
  ///
  /// In en, this message translates to:
  /// **'Reset & re-upload cloud'**
  String get resetReUploadCloud;

  /// No description provided for @resetCloudBackup.
  ///
  /// In en, this message translates to:
  /// **'Reset cloud backup?'**
  String get resetCloudBackup;

  /// No description provided for @resetTrainingData.
  ///
  /// In en, this message translates to:
  /// **'Reset training data?'**
  String get resetTrainingData;

  /// No description provided for @restoreFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get restoreFromBackup;

  /// No description provided for @restoredFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Restored from backup.'**
  String get restoredFromBackup;

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// No description provided for @running1.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get running1;

  /// No description provided for @sleepLastNightHrs.
  ///
  /// In en, this message translates to:
  /// **'SLEEP LAST NIGHT (HRS)'**
  String get sleepLastNightHrs;

  /// No description provided for @ss.
  ///
  /// In en, this message translates to:
  /// **'SS'**
  String get ss;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get start;

  /// No description provided for @steps.
  ///
  /// In en, this message translates to:
  /// **'STEPS'**
  String get steps;

  /// No description provided for @strengthWk.
  ///
  /// In en, this message translates to:
  /// **'STRENGTH / WK'**
  String get strengthWk;

  /// No description provided for @suggestMeals.
  ///
  /// In en, this message translates to:
  /// **'SUGGEST MEALS'**
  String get suggestMeals;

  /// No description provided for @symptoms.
  ///
  /// In en, this message translates to:
  /// **'SYMPTOMS'**
  String get symptoms;

  /// No description provided for @saveAFoodYouEatOften.
  ///
  /// In en, this message translates to:
  /// **'Save a food you eat often'**
  String get saveAFoodYouEatOften;

  /// No description provided for @saveCheckIn.
  ///
  /// In en, this message translates to:
  /// **'Save check-in'**
  String get saveCheckIn;

  /// No description provided for @saveMealsYouLogOften.
  ///
  /// In en, this message translates to:
  /// **'Save meals you log often'**
  String get saveMealsYouLogOften;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @serving.
  ///
  /// In en, this message translates to:
  /// **'Serving'**
  String get serving;

  /// No description provided for @sessionComplete.
  ///
  /// In en, this message translates to:
  /// **'Session complete'**
  String get sessionComplete;

  /// No description provided for @set.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get set;

  /// No description provided for @setWeight.
  ///
  /// In en, this message translates to:
  /// **'Set weight'**
  String get setWeight;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @signOut1.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut1;

  /// No description provided for @sodiumMg.
  ///
  /// In en, this message translates to:
  /// **'Sodium (mg)'**
  String get sodiumMg;

  /// No description provided for @startAnyway.
  ///
  /// In en, this message translates to:
  /// **'Start anyway'**
  String get startAnyway;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @staysOnThisDeviceNeverUploaded.
  ///
  /// In en, this message translates to:
  /// **'Stays on this device — never uploaded.'**
  String get staysOnThisDeviceNeverUploaded;

  /// No description provided for @staysOnThisDeviceNeverSynced.
  ///
  /// In en, this message translates to:
  /// **'Stays on this device. Never synced.'**
  String get staysOnThisDeviceNeverSynced;

  /// No description provided for @substituteExercise.
  ///
  /// In en, this message translates to:
  /// **'Substitute exercise'**
  String get substituteExercise;

  /// No description provided for @syncFromCloud.
  ///
  /// In en, this message translates to:
  /// **'Sync from cloud'**
  String get syncFromCloud;

  /// No description provided for @thighCm.
  ///
  /// In en, this message translates to:
  /// **'THIGH (CM)'**
  String get thighCm;

  /// No description provided for @thisSession.
  ///
  /// In en, this message translates to:
  /// **'THIS SESSION'**
  String get thisSession;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get total;

  /// No description provided for @trainingCalendar.
  ///
  /// In en, this message translates to:
  /// **'TRAINING CALENDAR'**
  String get trainingCalendar;

  /// No description provided for @takeAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takeAPhoto;

  /// No description provided for @tapToLogLongPressToEditOrDelete.
  ///
  /// In en, this message translates to:
  /// **'Tap + to log · long-press to edit or delete'**
  String get tapToLogLongPressToEditOrDelete;

  /// No description provided for @tapALevelForEachMuscle0Fresh4VerySore.
  ///
  /// In en, this message translates to:
  /// **'Tap a level for each muscle — 0 fresh, 4 very sore.'**
  String get tapALevelForEachMuscle0Fresh4VerySore;

  /// No description provided for @tapForFullMapBalanceWeeklyVolume.
  ///
  /// In en, this message translates to:
  /// **'Tap for full map · balance · weekly volume'**
  String get tapForFullMapBalanceWeeklyVolume;

  /// No description provided for @tellMeWhatToFixAndI.
  ///
  /// In en, this message translates to:
  /// **'Tell me what to fix and I\"'**
  String get tellMeWhatToFixAndI;

  /// No description provided for @thigh.
  ///
  /// In en, this message translates to:
  /// **'Thigh'**
  String get thigh;

  /// No description provided for @thisExerciseMayHaveBeenRemovedFromYourLibrary.
  ///
  /// In en, this message translates to:
  /// **'This exercise may have been removed from your library.'**
  String get thisExerciseMayHaveBeenRemovedFromYourLibrary;

  /// No description provided for @trainedInTheLast7Days.
  ///
  /// In en, this message translates to:
  /// **'Trained in the last 7 days'**
  String get trainedInTheLast7Days;

  /// No description provided for @units.
  ///
  /// In en, this message translates to:
  /// **'UNITS'**
  String get units;

  /// No description provided for @upgradeToAFullAccount.
  ///
  /// In en, this message translates to:
  /// **'UPGRADE TO A FULL ACCOUNT'**
  String get upgradeToAFullAccount;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @waistCm.
  ///
  /// In en, this message translates to:
  /// **'WAIST (CM)'**
  String get waistCm;

  /// No description provided for @walking.
  ///
  /// In en, this message translates to:
  /// **'WALKING'**
  String get walking;

  /// No description provided for @walkingKm.
  ///
  /// In en, this message translates to:
  /// **'WALKING (KM)'**
  String get walkingKm;

  /// No description provided for @weeklyRecap.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY RECAP'**
  String get weeklyRecap;

  /// No description provided for @weeklyVolume.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY VOLUME'**
  String get weeklyVolume;

  /// No description provided for @weightKg.
  ///
  /// In en, this message translates to:
  /// **'WEIGHT (KG)'**
  String get weightKg;

  /// No description provided for @waist.
  ///
  /// In en, this message translates to:
  /// **'Waist'**
  String get waist;

  /// No description provided for @walk.
  ///
  /// In en, this message translates to:
  /// **'Walk'**
  String get walk;

  /// No description provided for @walking1.
  ///
  /// In en, this message translates to:
  /// **'Walking'**
  String get walking1;

  /// No description provided for @waterMealReminders.
  ///
  /// In en, this message translates to:
  /// **'Water + meal reminders'**
  String get waterMealReminders;

  /// No description provided for @waterNudges.
  ///
  /// In en, this message translates to:
  /// **'Water nudges'**
  String get waterNudges;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @wellDone.
  ///
  /// In en, this message translates to:
  /// **'Well done'**
  String get wellDone;

  /// No description provided for @wipe.
  ///
  /// In en, this message translates to:
  /// **'Wipe'**
  String get wipe;

  /// No description provided for @wipeEverything.
  ///
  /// In en, this message translates to:
  /// **'Wipe everything?'**
  String get wipeEverything;

  /// No description provided for @workout.
  ///
  /// In en, this message translates to:
  /// **'Workout'**
  String get workout;

  /// No description provided for @yourName1.
  ///
  /// In en, this message translates to:
  /// **'YOUR NAME'**
  String get yourName1;

  /// No description provided for @yesLogIt.
  ///
  /// In en, this message translates to:
  /// **'Yes, log it'**
  String get yesLogIt;

  /// No description provided for @addedToToday.
  ///
  /// In en, this message translates to:
  /// **'added to today'**
  String get addedToToday;

  /// No description provided for @cyclingSwimHiit.
  ///
  /// In en, this message translates to:
  /// **'cycling, swim, HIIT…'**
  String get cyclingSwimHiit;

  /// No description provided for @eG240.
  ///
  /// In en, this message translates to:
  /// **'e.g. 240'**
  String get eG240;

  /// No description provided for @eG30.
  ///
  /// In en, this message translates to:
  /// **'e.g. 30'**
  String get eG30;

  /// No description provided for @eG4.
  ///
  /// In en, this message translates to:
  /// **'e.g. 4'**
  String get eG4;

  /// No description provided for @eG5.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5'**
  String get eG5;

  /// No description provided for @eG60.
  ///
  /// In en, this message translates to:
  /// **'e.g. 60'**
  String get eG60;

  /// No description provided for @eG685.
  ///
  /// In en, this message translates to:
  /// **'e.g. 68.5'**
  String get eG685;

  /// No description provided for @eG75.
  ///
  /// In en, this message translates to:
  /// **'e.g. 7.5'**
  String get eG75;

  /// No description provided for @eG72.
  ///
  /// In en, this message translates to:
  /// **'e.g. 72'**
  String get eG72;

  /// No description provided for @eG8420.
  ///
  /// In en, this message translates to:
  /// **'e.g. 8420'**
  String get eG8420;

  /// No description provided for @eGMom.
  ///
  /// In en, this message translates to:
  /// **'e.g. Mom\"'**
  String get eGMom;

  /// No description provided for @est1rm.
  ///
  /// In en, this message translates to:
  /// **'est. 1RM'**
  String get est1rm;

  /// No description provided for @feltStrongEasyPaceSoreKnee.
  ///
  /// In en, this message translates to:
  /// **'felt strong / easy pace / sore knee…'**
  String get feltStrongEasyPaceSoreKnee;

  /// No description provided for @hours.
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get hours;

  /// No description provided for @kcalLeft.
  ///
  /// In en, this message translates to:
  /// **'kcal left'**
  String get kcalLeft;

  /// No description provided for @kcalTotal.
  ///
  /// In en, this message translates to:
  /// **'kcal · total'**
  String get kcalTotal;

  /// No description provided for @kg.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get kg;

  /// No description provided for @less.
  ///
  /// In en, this message translates to:
  /// **'less'**
  String get less;

  /// No description provided for @ml.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get ml;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'more'**
  String get more;

  /// No description provided for @tapAboveTo1.
  ///
  /// In en, this message translates to:
  /// **'tap above to +1'**
  String get tapAboveTo1;

  /// No description provided for @youExampleCom.
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get youExampleCom;

  /// No description provided for @key2.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get key2;

  /// No description provided for @key3.
  ///
  /// In en, this message translates to:
  /// **'≈'**
  String get key3;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed.'**
  String get backupFailed;

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed.'**
  String get restoreFailed;

  /// No description provided for @signOutFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign out failed.'**
  String get signOutFailed;

  /// No description provided for @couldNotDelete.
  ///
  /// In en, this message translates to:
  /// **'Could not delete. You may need to sign in again first.'**
  String get couldNotDelete;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get exporting;

  /// No description provided for @exportMyData.
  ///
  /// In en, this message translates to:
  /// **'Export my data (JSON)'**
  String get exportMyData;

  /// No description provided for @clearing.
  ///
  /// In en, this message translates to:
  /// **'Clearing…'**
  String get clearing;

  /// No description provided for @resetTraining.
  ///
  /// In en, this message translates to:
  /// **'Reset training data'**
  String get resetTraining;

  /// No description provided for @resetFailed.
  ///
  /// In en, this message translates to:
  /// **'Reset failed.'**
  String get resetFailed;

  /// No description provided for @wiping.
  ///
  /// In en, this message translates to:
  /// **'Wiping…'**
  String get wiping;

  /// No description provided for @resetEverything.
  ///
  /// In en, this message translates to:
  /// **'Reset everything'**
  String get resetEverything;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed.'**
  String get exportFailed;

  /// No description provided for @backupShared.
  ///
  /// In en, this message translates to:
  /// **'Backup shared.'**
  String get backupShared;

  /// No description provided for @fitevoBackup.
  ///
  /// In en, this message translates to:
  /// **'Fitevo backup'**
  String get fitevoBackup;

  /// No description provided for @fitevoBackupRestore.
  ///
  /// In en, this message translates to:
  /// **'Fitevo backup — restore by importing this JSON on a fresh install.'**
  String get fitevoBackupRestore;

  /// No description provided for @wipesEvery.
  ///
  /// In en, this message translates to:
  /// **'Wipes every food log, workout session, weigh-in, and daily log. Profile, targets, custom foods, exercises, and routines stay. Cannot be undone.'**
  String get wipesEvery;

  /// No description provided for @localFood.
  ///
  /// In en, this message translates to:
  /// **'Local food, workouts, measurements, custom foods, and routines will be deleted. Your account stays — but cloud backup is unaffected by this action.'**
  String get localFood;

  /// No description provided for @healthSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter steps, heart rate, sleep from your band app.'**
  String get healthSyncDesc;

  /// No description provided for @periodFlowLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get periodFlowLight;

  /// No description provided for @periodFlowMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get periodFlowMedium;

  /// No description provided for @periodFlowHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get periodFlowHeavy;

  /// No description provided for @there.
  ///
  /// In en, this message translates to:
  /// **'there'**
  String get there;

  /// No description provided for @apiKeys.
  ///
  /// In en, this message translates to:
  /// **'API Keys'**
  String get apiKeys;

  /// No description provided for @apiKeysDescription.
  ///
  /// In en, this message translates to:
  /// **'Configure your API keys for AI services. You can get free keys at Groq (console.groq.com), Gemini (aistudio.google.com), and USDA (fdc.nal.usda.gov).'**
  String get apiKeysDescription;

  /// No description provided for @aiProxy.
  ///
  /// In en, this message translates to:
  /// **'AI Proxy (optional)'**
  String get aiProxy;

  /// No description provided for @aiPriority.
  ///
  /// In en, this message translates to:
  /// **'AI Priority'**
  String get aiPriority;

  /// No description provided for @aiPriorityDesc.
  ///
  /// In en, this message translates to:
  /// **'The app uses the Proxy when configured, then Groq, then Gemini. The first valid key found is used.'**
  String get aiPriorityDesc;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @chatHistory.
  ///
  /// In en, this message translates to:
  /// **'Chat history'**
  String get chatHistory;

  /// No description provided for @deleteChat.
  ///
  /// In en, this message translates to:
  /// **'Delete chat'**
  String get deleteChat;

  /// No description provided for @dismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// No description provided for @dismissForToday.
  ///
  /// In en, this message translates to:
  /// **'Dismiss for today'**
  String get dismissForToday;

  /// No description provided for @addLog.
  ///
  /// In en, this message translates to:
  /// **'Add log'**
  String get addLog;

  /// No description provided for @shareAsPdf.
  ///
  /// In en, this message translates to:
  /// **'Share as PDF'**
  String get shareAsPdf;

  /// No description provided for @notTodayWorkout.
  ///
  /// In en, this message translates to:
  /// **'Not today\'s workout'**
  String get notTodayWorkout;

  /// No description provided for @logTodayActivity.
  ///
  /// In en, this message translates to:
  /// **'Log today\'s activity'**
  String get logTodayActivity;

  /// No description provided for @howMuchFood.
  ///
  /// In en, this message translates to:
  /// **'How much {food}?'**
  String howMuchFood(Object food);

  /// No description provided for @tellMeWhatToFix.
  ///
  /// In en, this message translates to:
  /// **'Tell me what to fix and I\'ll recalculate.'**
  String get tellMeWhatToFix;

  /// No description provided for @speechError.
  ///
  /// In en, this message translates to:
  /// **'Speech error: {error}'**
  String speechError(Object error);

  /// No description provided for @errorX.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorX(Object error);

  /// No description provided for @failedX.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String failedX(Object error);

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String syncFailed(Object error);

  /// No description provided for @restoreFromBackupDate.
  ///
  /// In en, this message translates to:
  /// **'Restore {date} from backup?'**
  String restoreFromBackupDate(Object date);

  /// No description provided for @todayWeight.
  ///
  /// In en, this message translates to:
  /// **'Today\'s weight'**
  String get todayWeight;

  /// No description provided for @generatedByFitevo.
  ///
  /// In en, this message translates to:
  /// **'Generated by Fitevo · {timestamp}'**
  String generatedByFitevo(Object timestamp);

  /// No description provided for @minutesLabel.
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutesLabel;

  /// No description provided for @restoreFailedX.
  ///
  /// In en, this message translates to:
  /// **'Restore failed: {error}'**
  String restoreFailedX(Object error);

  /// No description provided for @resetFailedX.
  ///
  /// In en, this message translates to:
  /// **'Reset failed: {error}'**
  String resetFailedX(Object error);

  /// No description provided for @noDuplicatesFound.
  ///
  /// In en, this message translates to:
  /// **'No duplicates found.'**
  String get noDuplicatesFound;

  /// No description provided for @removedDuplicates.
  ///
  /// In en, this message translates to:
  /// **'Removed {count} duplicate {type}.'**
  String removedDuplicates(Object count, Object type);

  /// No description provided for @aiSummaryFailed.
  ///
  /// In en, this message translates to:
  /// **'AI summary failed.'**
  String get aiSummaryFailed;

  /// No description provided for @todayMealPlan.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S MEAL PLAN'**
  String get todayMealPlan;

  /// No description provided for @todaySips.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S SIPS'**
  String get todaySips;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'DURATION'**
  String get durationLabel;

  /// No description provided for @volume.
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get volume;

  /// No description provided for @kgMoved.
  ///
  /// In en, this message translates to:
  /// **'KG MOVED'**
  String get kgMoved;

  /// No description provided for @minLabel.
  ///
  /// In en, this message translates to:
  /// **'MIN'**
  String get minLabel;

  /// No description provided for @approxKcal.
  ///
  /// In en, this message translates to:
  /// **'≈ KCAL'**
  String get approxKcal;

  /// No description provided for @workoutSharedText.
  ///
  /// In en, this message translates to:
  /// **'{day} done 💪 {kg} kg moved, {sets} sets{pr}.'**
  String workoutSharedText(Object day, Object kg, Object pr, Object sets);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
