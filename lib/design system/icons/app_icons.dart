import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// AppIcons centralizza i riferimenti alle icone dell'app.
/// Mappa alle Phosphor Icons (set Regular) così possiamo gestire tutto da un unico posto.
class AppIcons {
  // Navigation / Sections
  static const IconData dashboard = PhosphorIconsRegular.squaresFour;
  static const IconData clients = PhosphorIconsRegular.addressBook;
  static const IconData matters = PhosphorIconsRegular.folderOpen;
  static const IconData calendar = PhosphorIconsRegular.calendarDots;
  static const IconData settings = PhosphorIconsRegular.gear;
  static const IconData notifications = PhosphorIconsRegular.bell;

  // Actions / Common
  static const IconData search = PhosphorIconsRegular.magnifyingGlass;
  static const IconData person = PhosphorIconsRegular.user;
  static const IconData chevronLeft = PhosphorIconsRegular.caretLeft;
  static const IconData chevronRight = PhosphorIconsRegular.caretRight;
  static const IconData star = PhosphorIconsRegular.star;
  static const IconData logout = PhosphorIconsRegular.signOut;
  static const IconData radioChecked = PhosphorIconsRegular.radioButton;
  static const IconData radioUnchecked = PhosphorIconsRegular.circle;
  static const IconData gavel = PhosphorIconsRegular.gavel;
  static const IconData description = PhosphorIconsRegular.fileText;
  static const IconData receiptLong = PhosphorIconsRegular.receipt;
  static const IconData invoice = PhosphorIconsRegular.invoice;
  static const IconData payments = PhosphorIconsRegular.creditCard;
  static const IconData currencyEur = PhosphorIconsRegular.currencyEur;
  static const IconData uploadFile = PhosphorIconsRegular.fileArrowUp;
  static const IconData playlistAddCheck = PhosphorIconsRegular.checkSquare;
  static const IconData schedule = PhosphorIconsRegular.clock;
  static const IconData checklist = PhosphorIconsRegular.checkSquare;
  static const IconData close = PhosphorIconsRegular.x;
  static const IconData clear = PhosphorIconsRegular.x;
  static const IconData event = PhosphorIconsRegular.calendar;
  static const IconData save = PhosphorIconsRegular.floppyDisk;
  static const IconData login = PhosphorIconsRegular.signIn;
  static const IconData flag = PhosphorIconsRegular.flag;
  static const IconData edit =
      PhosphorIconsRegular.pencil; // aggiornato a pencil
  static const IconData checkCircle = PhosphorIconsRegular.checkCircle;
  static const IconData refresh = PhosphorIconsRegular.arrowsCounterClockwise;
  static const IconData tableChart = PhosphorIconsRegular.table;
  static const IconData viewKanban = PhosphorIconsRegular.kanban;
  static const IconData openInNew = PhosphorIconsRegular.arrowSquareOut;
  static const IconData inbox = PhosphorIconsRegular.tray;
  static const IconData expandMore = PhosphorIconsRegular.caretDown;
  static const IconData arrowDropUp = PhosphorIconsRegular.caretUp;
  static const IconData arrowDropDown = PhosphorIconsRegular.caretDown;
  static const IconData insertDriveFile = PhosphorIconsRegular.file;
  static const IconData folder = PhosphorIconsRegular.folder;
  // Stampa
  static const IconData printer = PhosphorIconsRegular.printer;
  static const IconData warning = PhosphorIconsRegular.warning;
  static const IconData error = PhosphorIconsRegular.xCircle;
  static const IconData info = PhosphorIconsRegular.info;
  static const IconData add = PhosphorIconsRegular.plus;
  static const IconData upload = PhosphorIconsRegular.uploadSimple;
  static const IconData download = PhosphorIconsRegular.downloadSimple;
  static const IconData mergeType = PhosphorIconsRegular.gitMerge;
  static const IconData delete = PhosphorIconsRegular.trash;
  static const IconData switchAccount = PhosphorIconsRegular.arrowsLeftRight;
  static const IconData restart = PhosphorIconsRegular.arrowCounterClockwise;
  static const IconData personAdd = PhosphorIconsRegular.userPlus; // user-plus
  static const IconData accountCircle = PhosphorIconsRegular.userCircle;
  static const IconData driveFileRename = PhosphorIconsRegular.pencilLine;
  static const IconData addAlarm = PhosphorIconsRegular.alarm;
  static const IconData addCircle = PhosphorIconsRegular.plusCircle;
  static const IconData requestPage = PhosphorIconsRegular.fileText;
  static const IconData addTask = PhosphorIconsRegular.checks;
  static const IconData playlistAdd = PhosphorIconsRegular.listPlus;
  static const IconData hourglassBottom = PhosphorIconsRegular.hourglass;
  static const IconData hourglassMedium = PhosphorIconsRegular.hourglassMedium;
  static const IconData circleNotifications = PhosphorIconsRegular.bell;
  static const IconData folderAdd = PhosphorIconsRegular.folderPlus;
  // Nuova icona per "Memorandum": lampadina
  static const IconData lightbulb = PhosphorIconsRegular.lightbulb;

  // Nuove icone richieste per Clienti
  static const IconData trayArrowUp = PhosphorIconsRegular.trayArrowUp;
  static const IconData arrowUp = PhosphorIconsRegular.arrowUp;
  static const IconData arrowDown = PhosphorIconsRegular.arrowDown;
  static const IconData trendUp = PhosphorIconsRegular.trendUp;
  static const IconData trendDown = PhosphorIconsRegular.trendDown;

  // Alias per richieste specifiche UI Clienti
  // user-rectangle (Phosphor)
  static const IconData userRectangle = PhosphorIconsRegular.userRectangle;
  // building-office: alias verso l'icona più vicina disponibile (buildings)
  static const IconData buildingOffice = PhosphorIconsRegular.buildings;

  // Auth / Inputs
  static const IconData eye = PhosphorIconsRegular.eye;
  static const IconData eyeSlash = PhosphorIconsRegular.eyeSlash;
}
