import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:googleapis/sheets/v4.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sms.dart';
import 'google_auth.dart';

class SpreadsheetProvider extends Notifier<Spreadsheet?> {
  //region providers
  static final spreadsheet =
      NotifierProvider<SpreadsheetProvider, Spreadsheet?>(() => _instance);

  static final spreadsheetLastId = Provider<int?>((ref) {
    final ss = ref.watch(spreadsheet);
    return ss != null ? SpreadsheetProvider._calculateLastId(ss) : null;
  });

  static final updating = Provider<bool>((ref) =>
      ref.watch(spreadsheet) == null &&
      ref.watch(GoogleAuthProvider.authentication) != null &&
      ref.read(spreadsheet.notifier)._isSheetAvailableSync());

  static final dictionaryChannels = Provider<Map<String, String>>((ref) {
    final dict = ref.read(spreadsheet.notifier);
    return dict._dictionaries.getChannels();
  });

  //endregion providers

  //region members
  bool _readPreferences = false;
  String? _id;
  late final SheetsApi _api;
  late final SheetDictionariesStore _dictionaries;

  //endregion members

  //region Singleton
  static final SpreadsheetProvider _instance = SpreadsheetProvider._internal();

  factory SpreadsheetProvider() => _instance;

  SpreadsheetProvider._internal() {
    _dictionaries = SheetDictionariesStore(this);
  }

  /// After anyone subscribes to the provider,
  /// the method starts a request to retrieve the spreadsheet.
  @override
  Spreadsheet? build() {
    unawaited(getSpreadsheet(forceUpdate: true));
    return null;
  }

  //endregion Singleton

  /// Get or Create the spreadsheet from the Google Sheets API
  Future<Spreadsheet> getSpreadsheet({bool forceUpdate = false}) async {
    if (!forceUpdate && state != null) return Future.value(state);

    state = null;
    final sheet = (await _isSheetAvailable())
        ? await _api.spreadsheets
            .get(_id!, includeGridData: true)
            .onError<ApiRequestError>((error, __) async {
            if (error is DetailedApiRequestError && error.status == 404) {
              return await _createSpreadsheet();
            }
            throw error;
          })
        : await _createSpreadsheet();

    state = sheet;
    return sheet;
  }

  // region createSpreadsheet

  /// create a new spreadsheet
  Future<Spreadsheet> _createSpreadsheet() async {
    Spreadsheet ss = Spreadsheet(
      properties: SpreadsheetProperties(
        title: "HipaGora.RawData ${DateTime.now()}",
        timeZone: 'Europe/Belgrade',
        locale: 'hr_HR',
      ),
      sheets: [
        Sheet(
          data: [
            GridData(
              startColumn: 0,
              startRow: 1,
              rowData: [
                //Row with titles
                _buildSmsRow(SmsModel.titles),
                //Row with filters
                _buildSmsRow(SmsModel.titles, stringifier: (s) => "\t⧨"),
              ],
              columnMetadata: SmsModel.titles
                  .map((t) => DimensionProperties(
                        hiddenByUser: 'Raw' == t,
                      ))
                  .toList(growable: false),
            ),
          ],
          properties: SheetProperties(
            title: _Keys.rawDataSheet.value,
            sheetType: "GRID",
            gridProperties: GridProperties(
              rowCount: 1700,
              columnCount: SmsModel.titles.length,
              frozenRowCount: 3,
              frozenColumnCount: 4,
              columnGroupControlAfter: true,
              rowGroupControlAfter: true,
            ),
          ),
          developerMetadata: [
            DeveloperMetadata(
              metadataKey: _Keys.rawDataSheet.key,
              metadataValue: _Keys.rawDataSheet.value,
              visibility: "DOCUMENT",
            )
          ],
        ),
        Sheet(
          properties: SheetProperties(
            title: _Keys.dictionarySheet.value,
            sheetType: "GRID",
            gridProperties: GridProperties(
              rowCount: 100,
              columnCount: 30,
              frozenRowCount: 1,
              columnGroupControlAfter: true,
            ),
          ),
          developerMetadata: [
            DeveloperMetadata(
              metadataKey: _Keys.dictionarySheet.key,
              metadataValue: _Keys.dictionarySheet.value,
              visibility: "DOCUMENT",
            )
          ],
        )
      ],
      developerMetadata: [
        DeveloperMetadata(
          metadataKey: _Keys.hipoGora.key,
          metadataValue: _Keys.hipoGora.value,
          visibility: "DOCUMENT",
        )
      ],
    );
    ss = await _api.spreadsheets.create(ss);
    var req = Request(
      addProtectedRange: AddProtectedRangeRequest(
        protectedRange: ProtectedRange(
            description: "Please do not change the raw data.",
            warningOnly: true,
            // editors: Editors(domainUsersCanEdit: false, users: ['API']),
            range: GridRange(
              sheetId: ss.sheets![0].properties!.sheetId!,
              // startColumnIndex: 1,
              // endColumnIndex: SmsModel.titles.length,
              // startRowIndex: 1,
              // endRowIndex: 30,
            ),
            unprotectedRanges: [
              // TODO Define columns with comments
            ]),
      ),
    );
    ss = (await _batchUpdate([req], id: ss.spreadsheetId!)).updatedSpreadsheet!;
    await _dictionaries._setupDictionaries(id: ss.spreadsheetId!);
    _saveId(ss);
    return ss;
  }

  static RowData _buildSmsRow(List cells,
      {String? Function(String?)? stringifier}) {
    stringCell(String? cell) => CellData(
        userEnteredValue: ExtendedValue(stringValue: cell),
        userEnteredFormat: CellFormat(
          verticalAlignment: "MIDDLE",
          horizontalAlignment: (cell?.length ?? 9) < 4 ? "RIGHT" : "LEFT",
        ));

    var cellData = stringifier != null
        ? (cell) => stringCell(stringifier(cell?.toString()))
        : (cell) => switch (cell.runtimeType) {
              // ignore: prefer_void_to_null
              Null => stringCell(null),
              String => stringCell(cell),
              DateTime => CellData(
                  userEnteredValue: ExtendedValue(
                    numberValue: cell.millisecondsSinceEpoch / 86400000 + 25569,
                  ),
                  userEnteredFormat: CellFormat(
                    verticalAlignment: "MIDDLE",
                    horizontalAlignment: "RIGHT",
                    numberFormat: NumberFormat(
                      type: "DATE_TIME",
                      pattern: "yyyy.MM.dd\nHH:mm:ss",
                    ),
                  )),
              int => CellData(
                  userEnteredValue: ExtendedValue(numberValue: cell.toDouble()),
                  userEnteredFormat: CellFormat(
                    horizontalAlignment: "RIGHT",
                    verticalAlignment: "MIDDLE",
                    numberFormat: NumberFormat(
                      type: "NUMBER",
                      pattern: "#00",
                    ),
                  )),
              double => CellData(
                  userEnteredValue: ExtendedValue(numberValue: cell),
                  userEnteredFormat: CellFormat(
                    horizontalAlignment: "RIGHT",
                    verticalAlignment: "MIDDLE",
                    numberFormat: NumberFormat(
                      type: "NUMBER",
                      pattern: "#0.00",
                    ),
                  )),
              _ => stringCell(cell?.toString())
            };

    return RowData(
        values: cells.map((cell) => cellData(cell)).toList(growable: false));
  }

  //endregion createSpreadsheet

  // region tools
  bool _isSheetAvailableSync() {
    return _readPreferences && _id != null && _id!.isNotEmpty;
  }

  Future<bool> _isSheetAvailable() async {
    return (_isSheetAvailableSync()) ||
        await SharedPreferences.getInstance().then((sp) async {
          _api = await GoogleAuthProvider().sheetsApi;
          _id = sp.getString("spreadsheet.id");
          _readPreferences = true;
          return _id != null;
        });
  }

  _saveId(Spreadsheet? ss) {
    var id = ss?.spreadsheetId! ?? "";
    var url = ss?.spreadsheetUrl! ?? "";
    if (_id == id) return;
    _id = id;
    SharedPreferences.getInstance().then((sp) {
      sp.setString("spreadsheet.id", id);
      sp.setString("spreadsheet.url", url);
    });
  }

  clean() {
    _saveId(null);
    state = null;
  }

  static int _calculateLastId(Spreadsheet ss) {
    final idColumn = SmsModel.titles.indexOf(SmsModel.smsIdTitle);
    return ss.sheets?[0].data?[0].rowData
            ?.skip(3)
            .takeWhile((row) => row.values![0].formattedValue != null)
            .lastOrNull
            ?.values?[idColumn]
            .effectiveValue
            ?.numberValue
            ?.toInt() ??
        0;
  }

  // endregion tools

  // region populate data

  Future<Spreadsheet?> uploadSms(List<SmsMessage> messages) async {
    var counter = 0;
    state = null;

    var sheet = await getSpreadsheet();

    var lastId = SpreadsheetProvider._calculateLastId(sheet);

    var models = messages
        .where((m) => (m.id ?? 0) > lastId)
        .map((m) => SmsModel(m))
        .where((m) => m.forPublish)
        .toList(growable: false)
        .reversed;

    const pageSize = 500;

    while (models.isNotEmpty) {
      var rows = models.take(pageSize);
      await _addSmsRows(rows);
      sleep(const Duration(seconds: 1));
      models = models.skip(pageSize);
      print('Added ${counter += rows.length} rows');
    }

    return state;
  }

  // Future<void> addSmsRow(SmsModel sms) async {
  //   final sheet = state!;
  //           _batchUpdate(Request(
  //             appendCells: AppendCellsRequest(
  //               sheetId: sheet.sheets![0].properties!.sheetId!,
  //               fields: "*",
  //               rows: [
  //                 _buildSmsRow(sms.getRow()),
  //               ],
  //             ),
  //           ),
  // }

  Future<void> _addSmsRows(Iterable<SmsModel> list) async {
    final sheet = state!;
    state = null;

    final rows =
        list.map((sms) => _buildSmsRow(sms.getRow())).toList(growable: false);
    var request = Request(
      appendCells: AppendCellsRequest(
        sheetId: sheet.sheets![0].properties!.sheetId!,
        fields: "*",
        rows: rows,
      ),
    );
    await _batchUpdate([request]);
  }

  Future<BatchUpdateSpreadsheetResponse> _batchUpdate(List<Request> requests,
      {String? id, bool requestData = true}) async {
    id ??= _id!;
    state = null;
    var response = await _api.spreadsheets.batchUpdate(
        BatchUpdateSpreadsheetRequest(
          includeSpreadsheetInResponse: requestData,
          responseIncludeGridData: requestData,
          requests: requests,
        ),
        id);
    if (requestData) state = response.updatedSpreadsheet!;
    return response;
  }

  Future<AppendValuesResponse> _appendValues(
      {required String range,
      required List<List<Object?>> values,
      String? id,
      bool overwrite = false,
      bool userEntered = true}) async {
    id ??= _id!;
    state = null;
    var response = await _api.spreadsheets.values.append(
      ValueRange(majorDimension: "ROWS", range: range, values: values),
      id,
      range,
      insertDataOption: overwrite ? "OVERWRITE" : "INSERT_ROWS",
      valueInputOption: userEntered ? "USER_ENTERED" : "RAW",
    );
    // state = await getSpreadsheet();
    return response;
  }

  get _spreadsheet => state;

// endregion populate data
}

/// metadata keys
enum _Keys {
  hipoGora('HipoGora'),
  rawDataSheet('RawData'),
  dictionarySheet('Dictionary');

  final String key;
  final String value;

  const _Keys(this.key, {value}) : value = value ?? key;

  @override
  toString() => key;
}

class SheetDictionariesStore {
  //region metadata keys

  static _keyTest(_Keys key) =>
      (DeveloperMetadata data) => data.metadataKey == key.key;

  //endregion metadata keys

  //region members
  final SpreadsheetProvider _provider;

  Sheet? _dictionaries;

  SheetDictionariesStore(this._provider);

  //endregion members

  //region dictionary sheet preparation
  Sheet? getDictionaries() {
    var spreadsheet = _provider._spreadsheet;
    if (spreadsheet == null) {
      _dictionaries = null;
    } else {
      var sheet = spreadsheet.sheets?.where((sheet) {
        return sheet.developerMetadata?.any(_keyTest(_Keys.dictionarySheet)) ??
            false;
      }).firstOrNull;
      _dictionaries = sheet;
    }
    return _dictionaries;
  }

  Future<void> _setupDictionaries({String? id}) async {
    await _provider._appendValues(
      range: '${_Keys.dictionarySheet.value}!A1',
      values: [
        [
          null,
          'Channel',
          'ID',
          'Name',
          null,
          'Counterparty ID',
          'Counterparty Name',
          null,
          'Counterparty Name',
          'Category',
          'Subcategory',
        ],
        [
          null,
          'Hipotekarna',
          '=UNIQUE(RawData!D4:D)',
          '=ARRAYFORMULA(IF(C2:C=""; ""; C2:C))',
          null,
          '=UNIQUE(RawData!I4:I)',
          '=ARRAYFORMULA(IF(F2:F=""; ""; F2:F))',
          null,
          '=UNIQUE(G2:G)',
          '=ARRAYFORMULA(IF(I2:I=""; ""; I2:I))'
        ],
      ],
      overwrite: true,
      id: id,
    );
  }

  //endregion dictionary sheet preparation

  /// get data about channels
  Map<String, String> getChannels() {
    var sheet = getDictionaries();
    Map<String, String> result = {};
    if (sheet != null) {
      for (final row in sheet.data![0].rowData!.skip(1)) {
        var key = row.values![2].formattedValue;
        var value = row.values![3].formattedValue;
        if (key == null || key.isEmpty) break;
        result[key] = value ?? key;
      }
    }
    return result;
  }
}
